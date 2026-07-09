import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsManager
    @State private var previousTab: AppTab = .browser

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            BrowserView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Browser")
                }
                .tag(AppTab.browser)

            DownloadsView()
                .tabItem {
                    Image(systemName: "arrow.down")
                    Text("Downloads")
                }
                .tag(AppTab.downloads)

            ProxyView()
                .tabItem {
                    Image(systemName: "shield")
                    Text("Proxy")
                }
                .tag(AppTab.proxy)

            ClipboardView()
                .tabItem {
                    Image(systemName: "doc.on.clipboard")
                    Text("Clipboard")
                }
                .tag(AppTab.clipboard)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(AppTab.settings)
        }
        .onChange(of: coordinator.selectedTab) { newTab in
            if settings.hapticFeedbackEnabled && newTab != previousTab {
                HapticService.shared.selection()
            }
            previousTab = coordinator.selectedTab
        }
    }
}

struct BrowserView: View {
    var body: some View {
        NavigationStack {
            Text("Browser")
                .navigationTitle("Browser")
        }
    }
}

struct DownloadsView: View {
    var body: some View {
        NavigationStack {
            Text("Downloads")
                .navigationTitle("Downloads")
        }
    }
}

struct ProxyView: View {
    var body: some View {
        NavigationStack {
            Text("Proxy")
                .navigationTitle("Proxy")
        }
    }
}

struct ClipboardView: View {
    var body: some View {
        NavigationStack {
            Text("Clipboard")
                .navigationTitle("Clipboard")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("Settings")
                .navigationTitle("Settings")
        }
    }
}
