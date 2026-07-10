import UIKit

@MainActor
final class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTabs()
    }

    private func setupTabs() {
        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(title: "Home", image: UIImage(systemName: "house"), tag: 0)

        let browser = UINavigationController(rootViewController: BrowserViewController())
        browser.tabBarItem = UITabBarItem(title: "Browser", image: UIImage(systemName: "safari"), tag: 1)

        let downloads = UINavigationController(rootViewController: DownloadsViewController())
        downloads.tabBarItem = UITabBarItem(title: "Downloads", image: UIImage(systemName: "arrow.down.circle"), tag: 2)

        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 3)

        viewControllers = [home, browser, downloads, settings]
    }
}
