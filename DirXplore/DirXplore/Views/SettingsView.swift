import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var cellularEnabled = UserDefaults.standard.bool(forKey: "cellular_downloads")
    @State private var notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
    @State private var wifiOnly = UserDefaults.standard.bool(forKey: "wifi_only")
    @AppStorage("accent_color") private var accentColorString = "Blue"
    @AppStorage("app_theme") private var appTheme = "System"
    @State private var maxConcurrent = UserDefaults.standard.integer(forKey: "max_concurrent_downloads") == 0 ? 3 : UserDefaults.standard.integer(forKey: "max_concurrent_downloads")
    @State private var showClearConfirmation = false

    private var storageString: String {
        let total = manager.tasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                List {
                    appearanceSection
                    downloadsSection
                    networkSection
                    notificationsSection
                    storageSection
                    aboutSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Clear All Completed Downloads?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear All", role: .destructive) {
                    manager.clearCompleted()
                    clearFiles()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all completed download files from your device.")
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("App Theme", selection: $appTheme) {
                Text("System").tag("System")
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
            }
            .pickerStyle(.menu)

            HStack {
                Label("Accent Color", systemImage: "paintpalette")
                Spacer()
                HStack(spacing: 8) {
                    ForEach(AccentColorOption.allCases, id: \.self) { opt in
                        Circle()
                            .fill(opt.color)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(accentColorString == opt.rawValue ? Color.primary : Color.clear, lineWidth: 2)
                                    .padding(2)
                            )
                            .onTapGesture { accentColorString = opt.rawValue }
                    }
                }
            }
        }
    }

    private var downloadsSection: some View {
        Section("Downloads") {
            Toggle(isOn: $cellularEnabled) {
                Label("Cellular Downloads", systemImage: "antenna.radiowaves.left.and.right")
                Text("Allow downloads over cellular data")
            }
            .onChange(of: cellularEnabled) { _, v in UserDefaults.standard.set(v, forKey: "cellular_downloads") }

            Toggle(isOn: $wifiOnly) {
                Label("Wi-Fi Only", systemImage: "wifi")
                Text("Only download on Wi-Fi connections")
            }
            .onChange(of: wifiOnly) { _, v in UserDefaults.standard.set(v, forKey: "wifi_only") }

            Stepper(value: $maxConcurrent, in: 1...6) {
                HStack {
                    Label("Max Concurrent", systemImage: "arrow.triangle.branch")
                    Spacer()
                    Text("\(maxConcurrent)").foregroundStyle(.secondary)
                }
            }
            .onChange(of: maxConcurrent) { _, v in UserDefaults.standard.set(v, forKey: "max_concurrent_downloads") }
        }
    }

    private var networkSection: some View {
        Section("Network") {
            HStack {
                Label("Status", systemImage: "network")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "wifi").font(.caption)
                    Text("Connected").font(.subheadline).foregroundStyle(.green)
                }
            }
            HStack {
                Label("Active Downloads", systemImage: "arrow.down.circle")
                Spacer()
                Text("\(manager.activeDownloads)").foregroundStyle(.secondary)
            }
            HStack {
                Label("Total Downloaded", systemImage: "externaldrive")
                Spacer()
                Text(storageString).foregroundStyle(.secondary)
            }
        }
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle(isOn: $notificationsEnabled) {
                Label("Download Completed", systemImage: "bell")
                Text("Get notified when downloads finish")
            }
            .onChange(of: notificationsEnabled) { _, v in
                UserDefaults.standard.set(v, forKey: "notifications_enabled")
                if v { Task { await manager.requestNotificationPermission() } }
            }
        }
    }

    private var storageSection: some View {
        Section("Storage") {
            HStack {
                Label("Downloads", systemImage: "externaldrive")
                Spacer()
                Text(storageString).foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                showClearConfirmation = true
            } label: {
                Label("Clear Completed Downloads", systemImage: "trash")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Label("Version", systemImage: "info.circle")
                Spacer()
                Text("1.0.0").foregroundStyle(.secondary)
            }
            HStack {
                Label("Platform", systemImage: "iphone")
                Spacer()
                Text("iOS 17+").foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://dirxplore.com")!) {
                HStack {
                    Label("Website", systemImage: "safari")
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func clearFiles() {
        let completedNames = Set(manager.tasks.filter { $0.status == .completed }.map { $0.fileName })
        let documents = manager.documentsDir
        guard let files = try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else { return }
        for file in files where completedNames.contains(file.lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
