import Foundation

@MainActor
final class AppDependencyContainer: ObservableObject {
    let downloadManager: DownloadManager
    let proxyManager: ProxyManager
    let authManager: AuthManager
    let settingsManager: SettingsManager
    let clipboardService: ClipboardService
    let databaseService: DatabaseService
    let networkService: NetworkService
    let proxyTunnelService: ProxyTunnelService
    let liveActivityManager: LiveActivityManager
    let appCoordinator: AppCoordinator

    static let shared = AppDependencyContainer()

    private init() {
        downloadManager = .shared
        proxyManager = .shared
        authManager = .shared
        settingsManager = .shared
        clipboardService = .shared
        databaseService = .shared
        proxyTunnelService = .shared
        networkService = NetworkService()
        liveActivityManager = LiveActivityManager.shared
        appCoordinator = AppCoordinator()

        authManager.configure(coordinator: appCoordinator)
    }

    func initialize() async {
        await databaseService.open()
        await settingsManager.load()
        await clipboardService.load()
        await downloadManager.load()
        await proxyManager.load()
    }

    func makeBrowserViewModel() -> BrowserViewModel {
        BrowserViewModel()
    }

    func makeDownloadsViewModel() -> DownloadsViewModel {
        DownloadsViewModel()
    }

    func makeClipboardViewModel() -> ClipboardViewModel {
        ClipboardViewModel()
    }

    func makeProxyViewModel() -> ProxyViewModel {
        ProxyViewModel()
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel()
    }

    func makePlayerViewModel() -> PlayerViewModel {
        PlayerViewModel()
    }
}