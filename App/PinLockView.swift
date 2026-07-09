import SwiftUI

struct PinLockView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var authManager = AuthManager.shared
    @State private var pin = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var shakeOffset: CGFloat = 0

    private let pinLength = 4

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Enter PIN")
                    .font(.title2)
                    .fontWeight(.semibold)

                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity)
                }

                HStack(spacing: 16) {
                    ForEach(0..<pinLength, id: \.self) { index in
                        Circle()
                            .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 2)
                            .background(Circle().fill(index < pin.count ? Color.accentColor : Color.clear))
                            .frame(width: 20, height: 20)
                            .animation(.easeInOut(duration: 0.15), value: pin.count)
                    }
                }
                .offset(x: shakeOffset)
                .padding(.vertical, 8)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(1...9, id: \.self) { number in
                        pinButton("\(number)")
                    }

                    pinButton("")
                        .hidden()

                    pinButton("0")

                    Button {
                        deleteTapped()
                    } label: {
                        Image(systemName: "delete.left")
                            .font(.title2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 48)

                Spacer()
            }
        }
        .onChange(of: pin) { newValue in
            if newValue.count == pinLength {
                verifyPin()
            }
        }
    }

    private func pinButton(_ label: String) -> some View {
        Button {
            digitTapped(label)
        } label: {
            Text(label)
                .font(.title)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundColor(.primary)
        }
    }

    private func digitTapped(_ digit: String) {
        guard pin.count < pinLength else { return }
        pin.append(digit)
        HapticService.shared.light()
    }

    private func deleteTapped() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
        HapticService.shared.light()
    }

    private func verifyPin() {
        let isValid = authManager.authenticateWithPin(pin)
        if isValid {
            HapticService.shared.success()
            coordinator.unlock()
        } else {
            HapticService.shared.error()
            errorMessage = "Incorrect PIN"
            showError = true
            withAnimation(.default.repeatCount(3, autoreverses: true)) {
                shakeOffset = 20
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                shakeOffset = 0
                pin = ""
            }
        }
    }
}
