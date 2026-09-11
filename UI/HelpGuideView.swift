import SwiftUI
import UIKit

/// 双页指南视图 —— 共用于 onboarding（首次启动）和 help（toolbar ? / 空状态）
///
/// - mode = .onboarding：top-right "Skip"；最后一页 CTA "Create first server"
///                     关闭时写 `store.hasSeenOnboarding = true`
/// - mode = .help       ：top-right "✕ Close"；最后一页 CTA "Got it"
struct HelpGuideView: View {
    enum Mode { case onboarding, help }

    let mode: Mode
    /// onboarding 末尾"Create first server"按钮的回调（host 用以打开 ServerEditView）
    var onCreateFirstServer: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $currentPage) {
                page(
                    title: "How Porta works",
                    subtitle: "Porta builds an encrypted tunnel between your iPhone and your own server. Only one entry point is exposed to the public Internet — your private services stay private.",
                    imageName: "HowItWorks"
                )
                .tag(0)

                page(
                    title: "How to use Porta",
                    subtitle: "Five steps to your first private service. Follow them in order; you can revisit this guide anytime via the ? button.",
                    imageName: "HowToUse"
                )
                .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            bottomBar
        }
        .background(DS.Color.bgGrouped.ignoresSafeArea())
    }

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        HStack {
            switch mode {
            case .help:
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.Color.labelPrimary)
                        .frame(width: 32, height: 32)
                }
                .accessibilityLabel("Close")
            case .onboarding:
                Button {
                    markOnboardingSeen()
                    dismiss()
                } label: {
                    Text("Skip")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.accent)
                }
                .accessibilityLabel("Skip onboarding")
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.xs)
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .fill(i == currentPage ? DS.Color.accent : DS.Color.separator)
                        .frame(width: 7, height: 7)
                }
            }

            primaryButton
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.bottom, DS.Spacing.xl)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch mode {
        case .onboarding where currentPage == 1:
            Button {
                markOnboardingSeen()
                onCreateFirstServer?()
                dismiss()
            } label: {
                Label("Create first server", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DS.Color.accent)

        case .onboarding:
            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Next").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DS.Color.accent)

        case .help:
            Button {
                dismiss()
            } label: {
                Text("Got it").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DS.Color.accent)
        }
    }

    // MARK: - Page builder

    private func page(title: String, subtitle: String, imageName: String) -> some View {
        VStack(spacing: DS.Spacing.m) {
            VStack(spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Font.title2)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(DS.Font.subhead)
                    .foregroundStyle(DS.Color.labelSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.s)

            ZoomableImageView(image: UIImage(named: imageName) ?? UIImage())
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("Pinch to zoom · Double-tap to reset")
                .font(DS.Font.caption1)
                .foregroundStyle(DS.Color.labelTertiary)
                .padding(.bottom, DS.Spacing.s)
        }
    }

    // MARK: -

    private func markOnboardingSeen() {
        env.store.hasSeenOnboarding = true
    }
}

/// 嵌入式帮助按钮（用于空状态 / 工具栏旁的链接样式）
struct HelpButton: View {
    var label: String = "What is Porta?"
    var action: () -> Void
    var prominent: Bool = false

    var body: some View {
        if prominent {
            Button(action: action) {
                Label(label, systemImage: "info.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Color.accent)
        } else {
            Button(action: action) {
                Label(label, systemImage: "info.circle")
            }
            .buttonStyle(.bordered)
            .tint(DS.Color.accent)
        }
    }
}