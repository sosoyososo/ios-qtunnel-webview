import SwiftUI

/// P2 — 新增 / 编辑 Server
struct ServerEditView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var portText: String = "9001"

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.never)
                    TextField("Host", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $portText)
                        .keyboardType(.numberPad)
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
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !host.trimmingCharacters(in: .whitespaces).isEmpty
            && (Int(portText).map { $0 > 0 && $0 < 65536 } ?? false)
    }

    private func save() {
        guard let port = Int(portText) else { return }
        let server = Server(name: name.trimmingCharacters(in: .whitespaces),
                            host: host.trimmingCharacters(in: .whitespaces),
                            port: port)
        env.store.upsertServer(server)
        env.registerServer(server)
        dismiss()
    }
}
