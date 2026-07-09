import SwiftUI
import UserNotifications
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        DownloadManager.registerNotificationCategories()
        UNUserNotificationCenter.current().delegate = self

        DownloadManager.shared.registerBackgroundTask()
        DownloadManager.shared.scheduleBackgroundTask()

        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == DownloadManager.backgroundSessionIdentifier else {
            completionHandler()
            return
        }
        DownloadManager.shared.backgroundCompletionHandler = completionHandler
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        let downloadId = response.notification.request.identifier
        Task { @MainActor in
            switch response.actionIdentifier {
            case "PAUSE":
                await DownloadManager.shared.pause(downloadId)
            case "RESUME":
                await DownloadManager.shared.resume(downloadId)
            case "CANCEL":
                await DownloadManager.shared.stop(downloadId)
            default:
                break
            }
        }
        completionHandler()
    }
}

@main
struct DirXploreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
                .environmentObject(settingsManager)
        }
    }
}
