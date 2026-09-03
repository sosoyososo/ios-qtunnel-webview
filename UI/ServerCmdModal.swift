import SwiftUI
import UIKit

/// P8 — 显示 server start cmd + Copy 按钮
struct ServerCmdModal: View {
    let title: String
    let command: String

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                Text("Run this on your VPS:")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.labelSecondary)

                ScrollView {
                    Text(command)
                        .font(DS.Font.mono)
                        .padding(DS.Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DS.Color.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                }

                Button {
                    UIPasteboard.general.string = command
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy Command",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Color.accent)

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.xl)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
