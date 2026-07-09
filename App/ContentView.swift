import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsManager
    @StateObject private var authManager = AuthManager.shared
    @State private var scenePhase: ScenePhase = .active
    @State private var inactivityTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if coordinator.isLocked {
                if settings.lockType == "custom" && !settings.customPinHash.isEmpty {
                    PinLockView()
                } else {
                    BiometricLockView()
                }
            } else {
                MainTabView()
            }

            if coordinator.showPinSetup {
                PinSetupView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if ClipboardService.shared.showPopup, let item = ClipboardService.shared.pendingPopupItem {
                clipboardPopupView(item: item)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
                    .padding(.top, safeAreaTop)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.isLocked)
        .animation(.easeInOut(duration: 0.25), value: coordinator.showPinSetup)
        .animation(.easeInOut(duration: 0.3), value: ClipboardService.shared.showPopup)
        .onAppear {
            AuthManager.shared.configure(coordinator: coordinator)
            if settings.lockType != "none" {
                Task { await AuthManager.shared.authenticate() }
            } else {
                coordinator.unlock()
            }
            startInactivityTimer()
        }
        .onChange(of: scenePhase) { newPhase in
            AuthManager.shared.handleAppLifecycleChange(newPhase)
            switch newPhase {
            case .active:
                coordinator.isLocked = !coordinator.isAuthenticated
                if !coordinator.isLocked {
                    startInactivityTimer()
                }
            case .background:
                cancelInactivityTimer()
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            scenePhase = .background
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            scenePhase = .active
        }
    }

    private func startInactivityTimer() {
        cancelInactivityTimer()
        let seconds = settings.autoLockSeconds
        guard seconds > 0 else { return }
        inactivityTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                AuthManager.shared.lock()
            }
        }
    }

    private func cancelInactivityTimer() {
        inactivityTask?.cancel()
        inactivityTask = nil
    }

    private var safeAreaTop: CGFloat {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            return window.safeAreaInsets.top
        }
        return 0
    }

    @ViewBuilder
    private func clipboardPopupView(item: ClipboardItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("New Clipboard Item")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(item.preview)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    ClipboardService.shared.acceptPopup()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                }

                Button {
                    ClipboardService.shared.dismissPopup()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
