import Foundation
import LocalAuthentication
import CommonCrypto

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated: Bool = false
    @Published var isAuthenticating: Bool = false

    private var lastAuthSuccessTime: Date?
    private var inactivityTimer: Timer?
    private let context = LAContext()
    private weak var appCoordinator: AppCoordinator?

    private init() {}

    func configure(coordinator: AppCoordinator) {
        appCoordinator = coordinator
    }

    var canUseBiometrics: Bool {
        context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var canUseDeviceAuth: Bool {
        context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    var biometryType: LABiometryType {
        context.biometryType
    }

    func authenticate(reason: String = "Please authenticate to access DirXplore") async -> Bool {
        guard !isAuthenticated else { return true }
        guard !isAuthenticating else { return false }

        let settings = SettingsManager.shared
        if settings.lockType == "none" {
            isAuthenticated = true
            appCoordinator?.unlock()
            return true
        }

        if settings.lockType == "custom" {
            appCoordinator?.showPinSetup = true
            return false
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let localContext = LAContext()
            let canEvaluate = localContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
            guard canEvaluate else {
                isAuthenticated = true
                appCoordinator?.unlock()
                resetInactivityTimer()
                return true
            }

            let success = try await localContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            isAuthenticated = success
            if success {
                lastAuthSuccessTime = Date()
                appCoordinator?.unlock()
                resetInactivityTimer()
            }
            return success
        } catch {
            isAuthenticated = true
            appCoordinator?.unlock()
            resetInactivityTimer()
            return true
        }
    }

    func authenticateWithPin(_ pin: String) -> Bool {
        let settings = SettingsManager.shared
        guard settings.lockType == "custom", !settings.customPinHash.isEmpty else { return false }
        let hash = pin.sha256()
        guard hash == settings.customPinHash else { return false }
        isAuthenticated = true
        lastAuthSuccessTime = Date()
        appCoordinator?.unlock()
        resetInactivityTimer()
        return true
    }

    func verifyPin(_ pin: String) -> Bool {
        let settings = SettingsManager.shared
        guard !settings.customPinHash.isEmpty else { return true }
        return pin.sha256() == settings.customPinHash
    }

    func lock() {
        isAuthenticated = false
        appCoordinator?.lock()
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }

    func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        let settings = SettingsManager.shared
        guard settings.autoLockSeconds > 0, isAuthenticated else { return }
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.autoLockSeconds), repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }

    func handleAppLifecycleChange(_ state: ScenePhase) {
        let settings = SettingsManager.shared
        guard settings.lockType != "none" else { return }

        switch state {
        case .active:
            guard isAuthenticated, !isAuthenticating else { return }
            if let last = lastAuthSuccessTime, Date().timeIntervalSince(last) > 3 {
                if settings.autoLockSeconds == 0 {
                    isAuthenticated = false
                    Task { await authenticate() }
                } else {
                    resetInactivityTimer()
                }
            } else {
                resetInactivityTimer()
            }
        case .background:
            if settings.autoLockSeconds == 0, !isAuthenticating {
                isAuthenticated = false
            }
        default:
            break
        }
    }
}

extension String {
    func sha256() -> String {
        let data = Data(utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
