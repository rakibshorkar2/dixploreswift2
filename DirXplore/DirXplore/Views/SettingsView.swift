import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: DownloadManager
    @State private var cellularEnabled = UserDefaults.standard.bool(forKey: "cellular_downloads")
    @State private var notificationsEnabled = UserDefaults.standard.bool(forKey: "notifications_enabled")
    @State private var wifiOnly = UserDefaults.standard.bool(forKey: "wifi_only")
    @State private var accentColor: AccentColorOption = .blue
    @State private var showClearConfirmation = false

    enum AccentColorOption: String, CaseIterable {
        case blue = "Blue"
        case purple = "Purple"
        case pink = "Pink"
        case orange = "Orange"
        case green = "Green"
        case teal = "Teal"

        var color: Color {
            switch self {
            case .blue: return .blue
            case .purple: return .purple
            case .pink: return .pink
            case .orange: return .orange
            case .green: return .green
            case .teal: return .teal
            }
        }
    }

    private var storageString: String {
        let total = manager.tasks.filter { $0.status == .completed }.reduce(0) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                downloadsSection
                networkSection
                notificationsSection
                storageSection
                aboutSection
            }
            .listStyle(.insetGrouped)
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
    }

    private var appearanceSection: some View {
        Section("Appearance") {
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
                                    .stroke(accentColor == opt ? Color.primary : Color.clear, lineWidth: 2)
                                    .padding(2)
                            )
                            .onTapGesture { accentColor = opt }
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

            HStack {
                Label("Max Concurrent", systemImage: "arrow.triangle.branch")
                Spacer()
                Text("3").foregroundStyle(.secondary)
            }
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
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        guard let files = try? FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) else { return }
        for file in files { try? FileManager.default.removeItem(at: file) }
    }
}
