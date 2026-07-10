import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("accent_color") private var accentColorString = "Blue"

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            BrowserView()
                .tabItem {
                    Label("Browser", systemImage: selectedTab == 1 ? "safari.fill" : "safari")
                }
                .tag(1)

            DownloadsView()
                .tabItem {
                    Label("Downloads", systemImage: selectedTab == 2 ? "arrow.down.circle.fill" : "arrow.down.circle")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: selectedTab == 3 ? "gearshape.fill" : "gearshape")
                }
                .tag(3)
        }
        .tint(AccentColorOption(rawValue: accentColorString)?.color ?? .blue)
    }
}
