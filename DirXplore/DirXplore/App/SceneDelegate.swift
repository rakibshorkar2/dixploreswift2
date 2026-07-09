import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabBarController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        Task {
            await DownloadManager.shared.setupBackgroundSession()
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else { return }

        Task {
            let resolved = await LinkResolver.shared.resolve(url.absoluteString)
            if resolved.error == nil {
                await DownloadManager.shared.addTask(
                    url: resolved.url,
                    fileName: resolved.fileName,
                    sourceType: resolved.sourceType
                )
            }
        }
    }
}
