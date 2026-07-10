import SwiftUI

@main
struct DirXploreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var manager = DownloadManager.shared
    @AppStorage("app_theme") private var appTheme = "System"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .preferredColorScheme(colorScheme(for: appTheme))
                .onAppear {
                    configureAppearance()
                }
        }
    }

    private func colorScheme(for theme: String) -> ColorScheme? {
        switch theme {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    private func configureAppearance() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
