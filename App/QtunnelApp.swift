import SwiftUI

@main
struct QtunnelApp: App {
    @State private var env = AppEnvironment()
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ServerListView()
                .environment(env)
                .fullScreenCover(isPresented: $showOnboarding) {
                    HelpGuideView(mode: .onboarding) {
                        env.pendingShowAddServer = true
                    }
                    .environment(env)
                }
                .onAppear {
                    // 首次启动 + 500ms 缓冲（避免遮挡 splash → main 的过渡动画）
                    guard !env.store.hasSeenOnboarding else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showOnboarding = true
                    }
                }
        }
    }
}