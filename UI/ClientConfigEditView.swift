import SwiftUI

/// P4 — 新增 / 编辑 clientConfig
struct ClientConfigEditView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let server: Server
    let config: ClientConfig?

    @State private var name: String
    @State private var cryptoMethod: CryptoMethod
    @State private var secret: String
    @State private var backendHost: String
    @State private var backendPortText: String
    @State private var showingCmd = false
    @State private var showingRegenerateConfirm = false

    init(server: Server, config: ClientConfig?) {
        self.server = server
        self.config = config
        _name = State(initialValue: config?.name ?? "")
        _cryptoMethod = State(initialValue: config?.cryptoMethod ?? .rc4)
        _secret = State(initialValue: config?.secret ?? Password.generate())
        _backendHost = State(initialValue: config?.backendHost ?? "127.0.0.1")
        _backendPortText = State(initialValue: config.map { String($0.backendPort) } ?? "8080")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Config") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.never)
                }
                Section("Crypto") {
                    Picker("Method", selection: $cryptoMethod) {
                        ForEach(CryptoMethod.allCases, id: \.self) { m in
                            Text(m.cliValue).tag(m)
                        }
                    }
                    HStack {
                        Text(secret).font(DS.Font.mono).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button("Regenerate") {
                            showingRegenerateConfirm = true
                        }
                        .foregroundStyle(DS.Color.accent)
                    }
                }
                Section("Backend") {
                    TextField("Host", text: $backendHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $backendPortText)
                        .keyboardType(.numberPad)
                }
                Section {
                    Button {
                        saveConfig()
                        showingCmd = true
                    } label: {
                        Label("Generate Server Cmd", systemImage: "terminal")
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle(config == nil ? "New Config" : "Edit Config")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveConfig() }
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingCmd) {
                ServerCmdModal(
                    title: "Server Start Command",
                    command: generatedCmd()
                )
            }
            .alert("Regenerate Password?", isPresented: $showingRegenerateConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Regenerate") {
                    secret = Password.generate()
                }
            } message: {
                Text("Old server command will stop working. Copy the new command after saving.")
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !secret.isEmpty
            && !backendHost.trimmingCharacters(in: .whitespaces).isEmpty
            && (Int(backendPortText).map { $0 > 0 && $0 < 65536 } ?? false)
    }

    private func generatedCmd() -> String {
        let port = Int(backendPortText) ?? 0
        return ServerCmd.build(
            listenPort: server.port,
            backendHost: backendHost,
            backendPort: port,
            crypto: cryptoMethod.cliValue,
            secret: secret
        )
    }

    private func saveConfig() {
        guard let port = Int(backendPortText) else { return }
        let cfg = ClientConfig(
            id: config?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            serverId: server.id,
            cryptoMethod: cryptoMethod,
            secret: secret,
            backendHost: backendHost.trimmingCharacters(in: .whitespaces),
            backendPort: port
        )
        env.store.upsertClientConfig(cfg)
    }
}
