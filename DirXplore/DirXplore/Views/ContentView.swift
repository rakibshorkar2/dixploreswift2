import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            DownloadsView()
                .tabItem {
                    Label("Downloads", systemImage: selectedTab == 1 ? "arrow.down.circle.fill" : "arrow.down.circle")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: selectedTab == 2 ? "gearshape.fill" : "gearshape")
                }
                .tag(2)
        }
        .tint(.blue)
    }
}
