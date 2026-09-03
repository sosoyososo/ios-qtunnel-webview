import XCTest
@testable import Qtunnel

@MainActor
final class StoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "qtunnel.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func test_roundtripsAllEntities() {
        let store = Store(defaults: defaults)
        let server = Server(name: "Test", host: "127.0.0.1", port: 9001)
        store.upsertServer(server)
        let cfg = ClientConfig(
            name: "Admin",
            serverId: server.id,
            cryptoMethod: .rc4,
            secret: "abcdefghijklmnopqrstuvwxyz0123",
            backendHost: "127.0.0.1",
            backendPort: 8080
        )
        store.upsertClientConfig(cfg)
        let inst = ClientInstance(clientConfigId: cfg.id, localPort: 54321)
        store.upsertClientInstance(inst)
        let wv = WebViewState(clientInstanceId: inst.id, indexInConfig: 1, isFocused: true)
        store.upsertWebView(wv)

        // 重新加载
        let reloaded = Store(defaults: defaults)
        XCTAssertEqual(reloaded.data.servers.count, 1)
        XCTAssertEqual(reloaded.data.clientConfigs.count, 1)
        XCTAssertEqual(reloaded.data.clientInstances.count, 1)
        XCTAssertEqual(reloaded.data.webViews.count, 1)
        XCTAssertEqual(reloaded.data.servers[0].name, "Test")
        XCTAssertEqual(reloaded.data.clientConfigs[0].secret, "abcdefghijklmnopqrstuvwxyz0123")
    }

    func test_cascadeDeleteServer() {
        let store = Store(defaults: defaults)
        let server = Server(name: "S", host: "h", port: 1)
        store.upsertServer(server)
        let cfg = ClientConfig(name: "C", serverId: server.id, cryptoMethod: .rc4, secret: "x", backendHost: "y", backendPort: 1)
        store.upsertClientConfig(cfg)
        let inst = ClientInstance(clientConfigId: cfg.id)
        store.upsertClientInstance(inst)
        store.upsertWebView(WebViewState(clientInstanceId: inst.id, indexInConfig: 1))

        store.deleteServer(server.id)
        XCTAssertTrue(store.data.servers.isEmpty)
        XCTAssertTrue(store.data.clientConfigs.isEmpty)
        XCTAssertTrue(store.data.clientInstances.isEmpty)
        XCTAssertTrue(store.data.webViews.isEmpty)
    }

    func test_recoversFromCorruptJSON() {
        defaults.set(Data([0, 1, 2, 3]), forKey: Keys.store)
        let store = Store(defaults: defaults)
        XCTAssertTrue(store.data.servers.isEmpty)
    }
}
