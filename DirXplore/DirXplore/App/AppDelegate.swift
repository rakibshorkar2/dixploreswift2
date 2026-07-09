import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        registerDefaults()
        Task { await DownloadManager.shared.requestNotificationPermission() }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        DownloadManager.shared.setupBackgroundSession()
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "cellular_downloads": true,
            "notifications_enabled": true,
            "wifi_only": false,
        ])
    }
}
