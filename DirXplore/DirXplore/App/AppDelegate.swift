import UIKit

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
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
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
