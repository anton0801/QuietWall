import SwiftUI

struct RootView: View {
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var store = AppStore()
    @StateObject private var notifications = NotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue

    private var appearance: AppAppearance { AppAppearance(rawValue: appearanceRaw) ?? .dark }
    @State private var phase: AppPhase = .main

    var body: some View {
        ZStack {
            switch phase {
            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    withAnimation(.easeInOut(duration: 0.5)) { phase = .main }
                }
                .transition(.opacity)

            case .main:
                RootTabView()
                    .transition(.opacity)
            }
        }
        .environmentObject(store)
        .environmentObject(notifications)
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            configureGlobalAppearance()
            if !hasCompletedOnboarding {
                phase = .onboarding
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { store.flush() }
            if phase == .active { notifications.refreshStatus() }
        }
    }
    
    /// List/Form are UITableView-backed on iOS 14; clear their background so the
    /// acoustic backdrop shows through, and make navigation bars transparent.
    private func configureGlobalAppearance() {
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
        UITextView.appearance().backgroundColor = .clear

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [.foregroundColor: UIColor(hex: 0xB9B0DC)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(hex: 0xEFEAFF)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(hex: 0x8B5CF6)
    }
    
}
