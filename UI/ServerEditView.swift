import SwiftUI

/// P2 — 新增 / 编辑 Server
/// Server 只承载 name + host；qtunnel 端口由 ClientConfig 持有
struct ServerEditView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var reachability: Reachability = .checking

    enum Reachability: Equatable {
        case checking
        case up
        case down(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.never)
                    TextField("Host or IP", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: host) { _, _ in checkReachability() }
                }
                Section("Reachability") {
                    HStack(spacing: DS.Spacing.s) {
                        Circle().fill(reachColor).frame(width: 10, height: 10)
                        Text(reachText).font(DS.Font.body)
                        Spacer()
                    }
                }
            }
            .navigationTitle("New Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || reachability == .down(""))
                }
            }
            .onAppear { checkReachability() }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !host.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var reachColor: Color {
        switch reachability {
        case .up: return DS.Color.statusUp
        case .down: return DS.Color.statusDown
        case .checking: return DS.Color.statusUnknown
        }
    }

    private var reachText: String {
        switch reachability {
        case .checking: return "Checking…"
        case .up: return "Reachable"
        case .down(let reason): return reason.isEmpty ? "Unreachable" : "Unreachable: \(reason)"
        }
    }

    private func checkReachability() {
        let h = host.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else {
            reachability = .down("")
            return
        }
        reachability = .checking
        Task {
            let s = await StatusProbe.probeOnce(host: h)
            await MainActor.run {
                self.reachability = (s == .up) ? .up : .down("host not resolvable or offline")
            }
        }
    }

    private func save() {
        let server = Server(name: name.trimmingCharacters(in: .whitespaces),
                            host: host.trimmingCharacters(in: .whitespaces))
        env.store.upsertServer(server)
        env.registerServer(server)
        dismiss()
    }
}
