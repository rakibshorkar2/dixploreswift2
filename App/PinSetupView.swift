import SwiftUI

struct PinSetupView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsManager
    @State private var step: PinSetupStep = .enter
    @State private var firstPin = ""
    @State private var confirmPin = ""
    @State private var securityQuestion = ""
    @State private var securityAnswer = ""
    @State private var showSecurityFields = false
    @State private var errorMessage = ""
    @State private var showError = false

    private let pinLength = 4

    enum PinSetupStep {
        case enter, confirm
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text(step == .enter ? "Set PIN" : "Confirm PIN")
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
                            .background(Circle().fill(
                                (step == .enter ? index < firstPin.count : index < confirmPin.count)
                                ? Color.accentColor : Color.clear
                            ))
                            .frame(width: 20, height: 20)
                            .animation(.easeInOut(duration: 0.15), value: step == .enter ? firstPin.count : confirmPin.count)
                    }
                }

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

                if step == .confirm {
                    Button("Re-enter PIN") {
                        withAnimation { step = .enter }
                        confirmPin = ""
                    }
                    .font(.caption)
                }

                if showSecurityFields {
                    VStack(spacing: 12) {
                        TextField("Security Question (optional)", text: $securityQuestion)
                            .textFieldStyle(.roundedBorder)

                        SecureField("Security Answer (optional)", text: $securityAnswer)
                            .textFieldStyle(.roundedBorder)

                        Button("Save") {
                            savePin()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(confirmPin.count != pinLength)
                    }
                    .padding(.horizontal, 48)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
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
        guard !showSecurityFields else { return }
        if step == .enter {
            guard firstPin.count < pinLength else { return }
            firstPin.append(digit)
            if firstPin.count == pinLength {
                step = .confirm
            }
        } else {
            guard confirmPin.count < pinLength else { return }
            confirmPin.append(digit)
            if confirmPin.count == pinLength {
                if firstPin == confirmPin {
                    withAnimation {
                        showSecurityFields = true
                    }
                } else {
                    errorMessage = "PINs do not match"
                    showError = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showError = false
                        reset()
                    }
                }
            }
        }
        HapticService.shared.light()
    }

    private func deleteTapped() {
        guard !showSecurityFields else { return }
        if step == .confirm && !confirmPin.isEmpty {
            confirmPin.removeLast()
        } else if step == .enter && !firstPin.isEmpty {
            firstPin.removeLast()
        }
        HapticService.shared.light()
    }

    private func savePin() {
        let hash = firstPin.sha256()
        settings.setCustomPin(pin: hash, question: securityQuestion, answer: securityAnswer)
        settings.setLockType("custom")
        HapticService.shared.success()
        coordinator.showPinSetup = false
    }

    private func reset() {
        step = .enter
        firstPin = ""
        confirmPin = ""
    }
}
