import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@main
struct QuietWallApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegateApplication

    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
    
}

enum AppPhase { case onboarding, main }
