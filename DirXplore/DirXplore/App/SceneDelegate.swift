import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        configureAppearance()
        let window = UIWindow(windowScene: windowScene)

        // Check for SwiftUI entry point or UIKit
        if let _ = NSClassFromString("DirXplore.DirXploreApp") {
            // This is a SwiftUI app, but SceneDelegate is present.
            // In modern SwiftUI apps, SceneDelegate is usually not used unless explicitly opted in.
            // If the user sees UI issues, it might be due to a conflict or bad setup here.
            // We will force UIKit to ensure consistency with HomeViewController if SwiftUI is not the primary.
        }

        let tabBar = MainTabBarController()
        tabBar.view.backgroundColor = .systemBackground
        window.rootViewController = tabBar
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {
        DownloadManager.shared.setupBackgroundSession()
    }

    private func configureAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
