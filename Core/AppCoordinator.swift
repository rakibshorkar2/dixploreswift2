import SwiftUI

enum AppTab: Int, CaseIterable {
    case browser, downloads, proxy, clipboard, settings
}

@MainActor
class AppCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .browser
    @Published var isLocked: Bool = true
    @Published var showPinSetup: Bool = false
    @Published var isAuthenticated: Bool = false

    private var authenticationContinuation: CheckedContinuation<Bool, Never>?

    func authenticate() async -> Bool {
        return await withCheckedContinuation { continuation in
            authenticationContinuation = continuation
        }
    }

    func fulfillAuthentication(_ success: Bool) {
        authenticationContinuation?.resume(returning: success)
        authenticationContinuation = nil
        isAuthenticated = success
        if success {
            isLocked = false
        }
    }

    func lock() {
        isLocked = true
        isAuthenticated = false
    }

    func unlock() {
        isLocked = false
        isAuthenticated = true
    }
}
