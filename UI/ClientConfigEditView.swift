import SwiftUI

/// P4 — 新增 / 编辑 clientConfig
/// Config = name + qtunnelPort(server's listen port) + backendPort + crypto + secret
struct ClientConfigEditView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let server: Server
    let config: ClientConfig?

    @State private var name: String
    @State private var qtunnelPortText: String
    @State private var cryptoMethod: CryptoMethod
    @State private var secret: String
    @State private var backendPortText: String
    @State private var showingCmd = false
    @State private var showingRegenerateConfirm = false
    @State private var isSaving = false

    init(server: Server, config: ClientConfig?) {
        self.server = server
        self.config = config
        _name = State(initialValue: config?.name ?? "")
        _qtunnelPortText = State(initialValue: config.map { String($0.qtunnelPort) } ?? "9001")
        _cryptoMethod = State(initialValue: config?.cryptoMethod ?? .rc4)
        _secret = State(initialValue: config?.secret ?? Password.generate())
        _backendPortText = State(initialValue: config.map { String($0.backendPort) } ?? "8080")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Config") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.never)
                }
                Section("Server") {
                    LabeledContent("Host", value: server.host)
                    TextField("qtunnel Port", text: $qtunnelPortText)
                        .keyboardType(.numberPad)
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
                Section("Backend Service") {
                    LabeledContent("Host", value: "127.0.0.1")
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
                    Button("Save") {
                        guard !isSaving else { return }
                        isSaving = true
                        saveConfig()
                        dismiss()
                    }
                    .disabled(!isValid || isSaving)
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
            && (Int(qtunnelPortText).map { $0 > 0 && $0 < 65536 } ?? false)
            && (Int(backendPortText).map { $0 > 0 && $0 < 65536 } ?? false)
    }

    private func generatedCmd() -> String {
        let listen = Int(qtunnelPortText) ?? 0
        let bePort = Int(backendPortText) ?? 0
        return ServerCmd.build(
            listenPort: listen,
            backendHost: "127.0.0.1",
            backendPort: bePort,
            crypto: cryptoMethod.cliValue,
            secret: secret
        )
    }

    private func saveConfig() {
        guard let qp = Int(qtunnelPortText),
              let bp = Int(backendPortText) else { return }
        let cfg = ClientConfig(
            id: config?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            serverId: server.id,
            qtunnelPort: qp,
            cryptoMethod: cryptoMethod,
            secret: secret,
            backendPort: bp
        )
        env.store.upsertClientConfig(cfg)
    }
}
