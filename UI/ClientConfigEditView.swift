import SwiftUI

/// P4 — 新增 / 编辑 clientConfig
/// Config = name + tunnelPort(server's listen port) + backendPort + crypto + secret
struct ClientConfigEditView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let server: Server
    let config: ClientConfig?

    @State private var name: String
    @State private var tunnelPortText: String
    @State private var cryptoMethod: CryptoMethod
    @State private var secret: String
    @State private var backendPortText: String
    @State private var nameSuggestion: String
    @State private var showingCmd = false
    @State private var showingRegenerateConfirm = false
    @State private var isSaving = false

    init(server: Server, config: ClientConfig?) {
        self.server = server
        self.config = config
        _name = State(initialValue: config?.name ?? "")
        _tunnelPortText = State(initialValue: config.map { String($0.tunnelPort) } ?? "")
        _cryptoMethod = State(initialValue: config?.cryptoMethod ?? .rc4)
        _secret = State(initialValue: config?.secret ?? Password.generate())
        _backendPortText = State(initialValue: config.map { String($0.backendPort) } ?? "")
        _nameSuggestion = State(initialValue: DockerName.suggest())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Config") {
                    TextField("Name", text: $name, prompt: Text(nameSuggestion))
                        .textInputAutocapitalization(.never)
                }
                Section("Server") {
                    LabeledContent("Host", value: server.host)
                    LabeledContent("Public Port") {
                        TextField("tunnel listens on", text: $tunnelPortText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Private Port") {
                        TextField("forwards to backend", text: $backendPortText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
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
                Section {
                    Button {
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
        !secret.isEmpty
            && (Int(tunnelPortText).map { $0 > 0 && $0 < 65536 } ?? false)
            && (Int(backendPortText).map { $0 > 0 && $0 < 65536 } ?? false)
    }

    private func generatedCmd() -> String {
        let listen = Int(tunnelPortText) ?? 0
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
        guard let qp = Int(tunnelPortText),
              let bp = Int(backendPortText) else { return }
        // Name 留空 → 回退用 placeholder（Docker 风格随机名）
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let finalName = trimmed.isEmpty ? nameSuggestion : trimmed
        let cfg = ClientConfig(
            id: config?.id ?? UUID(),
            name: finalName,
            serverId: server.id,
            tunnelPort: qp,
            cryptoMethod: cryptoMethod,
            secret: secret,
            backendPort: bp
        )
        env.store.upsertClientConfig(cfg)
    }
}

/// Docker 容器名风格的随机双段名：`<形容词>_<科学家>`，仅作 TextField 占位符。
/// 用户键入即覆盖；清空则占位符重新出现。
enum DockerName {
    private static let adjectives = [
        "admiring", "adoring", "affectionate", "blissful", "brave", "clever",
        "compassionate", "confident", "dazzling", "determined", "eager",
        "ecstatic", "elastic", "elated", "elegant", "eloquent", "epic",
        "fervent", "festive", "focused", "furious", "gallant", "goofy",
        "happy", "hopeful", "jovial", "keen", "kind", "loving",
        "modest", "nostalgic", "peaceful", "pensive", "proud", "quirky",
        "recursing", "relaxed", "resolute", "silly", "sleepy", "stoic",
        "stunning", "wonderful", "zen"
    ]

    private static let scientists = [
        "agnesi", "albattani", "archimedes", "aryabhata", "babbage", "bardeen",
        "bartik", "bohr", "brahmagupta", "cannon", "carson", "cerf",
        "chandrasekhar", "chaplygin", "chebyshev", "clarke", "cori", "cray",
        "curie", "darwin", "davinci", "dijkstra", "dirac", "einstein",
        "elion", "engelbart", "euclid", "euler", "faraday", "fermi",
        "feynman", "franklin", "galileo", "galois", "gauss", "germain",
        "goldberg", "hawking", "heisenberg", "herschel", "hodgkin", "hopper",
        "hypatia", "jackson", "jemison", "joliot", "kalam", "kepler",
        "khayyam", "khorana", "knuth", "lamport", "leavitt", "lovelace",
        "maxwell", "mayer", "mccarthy", "mcclintock", "meitner", "mendel",
        "mendeleev", "merkle", "mirzakhani", "morse", "napier", "nash",
        "neumann", "newton", "nightingale", "nobel", "noether", "noyce",
        "panini", "pascal", "pasteur", "perlman", "pike", "poincare",
        "raman", "ramanujan", "ritchie", "robinson", "rosalind", "rubin",
        "sammet", "shamir", "shannon", "shockley", "sutherland", "tesla",
        "thompson", "torvalds", "turing", "varahamihira", "visvesvaraya",
        "volhard", "wiles", "williams", "wolfram", "wozniak", "wright",
        "yalow", "yonath"
    ]

    static func suggest() -> String {
        let adj = adjectives.randomElement() ?? "happy"
        let sci = scientists.randomElement() ?? "curie"
        return "\(adj)_\(sci)"
    }
}
