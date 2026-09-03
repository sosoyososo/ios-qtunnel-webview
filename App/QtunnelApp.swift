import SwiftUI

@main
struct QtunnelApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            ServerListView()
                .environment(env)
        }
    }
}
