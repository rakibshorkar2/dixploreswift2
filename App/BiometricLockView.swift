import SwiftUI

struct BiometricLockView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var authManager = AuthManager.shared
    @State private var isUnlocking = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: biometryIcon)
                    .font(.system(size: 72))
                    .foregroundStyle(.secondary)

                Text("App Locked")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Unlock with your device security")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    performUnlock()
                } label: {
                    HStack {
                        Image(systemName: biometryIcon)
                        Text("Unlock")
                    }
                    .font(.headline)
                    .frame(maxWidth: 260)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isUnlocking)

                Spacer()
            }
            .padding()
        }
        .onAppear {
            performUnlock()
        }
    }

    private var biometryIcon: String {
        switch authManager.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.shield"
        }
    }

    private func performUnlock() {
        guard !isUnlocking else { return }
        isUnlocking = true
        Task {
            let success = await authManager.authenticate()
            if success {
                coordinator.unlock()
            }
            isUnlocking = false
        }
    }
}
