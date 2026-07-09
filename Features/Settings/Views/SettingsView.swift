import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel.shared
    @State private var showPinSetup = false
    @State private var showPinChange = false
    @State private var pinInput = ""
    @State private var pinQuestion = ""
    @State private var pinAnswer = ""
    @State private var showSaveFolderPicker = false

    var body: some View {
        ZStack {
            backgroundGradient

            List {
                appearanceSection
                downloadSection
                smartAutomationSection
                retrySection
                schedulerSection
                categorizationSection
                hapticsSection
                securitySection
                clipboardSettingsSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPinSetup) {
            pinSetupSheet
        }
        .sheet(isPresented: $showPinChange) {
            pinChangeSheet
        }
        .sheet(isPresented: $showSaveFolderPicker) {
            folderPickerSheet
        }
        .task { await viewModel.load() }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(.systemBackground), Color(.secondarySystemBackground).opacity(0.8)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ).ignoresSafeArea()
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        Section {
            Picker("Theme", selection: $viewModel.themeMode) {
                Text("System").tag(ThemeMode.system)
                Text("Light").tag(ThemeMode.light)
                Text("Dark").tag(ThemeMode.dark)
            }
            .onChange(of: viewModel.themeMode) { _, new in viewModel.setThemeMode(new) }

            Toggle("True AMOLED Black", isOn: $viewModel.trueAmoledDark)
                .onChange(of: viewModel.trueAmoledDark) { _, new in viewModel.setTrueAmoledDark(new) }

            Toggle("Keep Screen Awake", isOn: $viewModel.keepScreenAwake)
                .onChange(of: viewModel.keepScreenAwake) { _, new in viewModel.setKeepScreenAwake(new) }

            if viewModel.keepScreenAwake {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-off Timer: \(viewModel.keepScreenAwakeTimerMinutes == 0 ? "Off" : "\(viewModel.keepScreenAwakeTimerMinutes) min")")
                        .font(.subheadline)
                    Slider(value: Binding(get: { Double(viewModel.keepScreenAwakeTimerMinutes) }, set: { viewModel.setKeepScreenAwakeTimerMinutes(Int($0)) }),
                           in: 0...Double(SettingsViewModel.screenAwakeTimerMax), step: 5)
                }
            }

            Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedbackEnabled)
                .onChange(of: viewModel.hapticFeedbackEnabled) { _, new in viewModel.setHapticFeedbackEnabled(new) }
        } header: {
            Label("UI & Appearance", systemImage: "paintbrush")
        }
    }

    private var downloadSection: some View {
        Section {
            Button {
                showSaveFolderPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Save Directory")
                        Text(viewModel.defaultSavePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "folder")
                        .foregroundStyle(.accent)
                }
            }

            Picker("Max Concurrent", selection: $viewModel.maxConcurrentDownloads) {
                ForEach(SettingsViewModel.concurrentOptions, id: \.self) { val in
                    Text("\(val)").tag(val)
                }
            }
            .onChange(of: viewModel.maxConcurrentDownloads) { _, new in viewModel.setMaxConcurrentDownloads(new) }

            Toggle("Show Download Notifications", isOn: $viewModel.showDownloadNotifications)
                .onChange(of: viewModel.showDownloadNotifications) { _, new in viewModel.setShowDownloadNotifications(new) }

            VStack(alignment: .leading, spacing: 4) {
                Text("Speed Limiter: \(viewModel.speedLimitCap == 0 ? "Unlimited" : "\(viewModel.speedLimitCap) KB/s")")
                    .font(.subheadline)
                Slider(value: Binding(get: { Double(viewModel.speedLimitCap) }, set: { viewModel.setSpeedLimitCap(Int($0)) }),
                       in: 0...10000, step: 500)
            }
        } header: {
            Label("Downloads", systemImage: "arrow.down.circle")
        }
    }

    private var smartAutomationSection: some View {
        Section {
            Toggle("Smart Folder Routing", isOn: $viewModel.smartFolderRouting)
                .onChange(of: viewModel.smartFolderRouting) { _, new in viewModel.setSmartFolderRouting(new) }
            Toggle("Download on Wi-Fi Only", isOn: $viewModel.downloadOnWifiOnly)
                .onChange(of: viewModel.downloadOnWifiOnly) { _, new in viewModel.setDownloadOnWifiOnly(new) }
            Toggle("Pause If Battery < 15%", isOn: $viewModel.pauseLowBattery)
                .onChange(of: viewModel.pauseLowBattery) { _, new in viewModel.setPauseLowBattery(new) }
        } header: {
            Label("Smart Automation", systemImage: "gearshape.2")
        }
    }

    private var retrySection: some View {
        Section {
            Picker("Max Retry Count", selection: $viewModel.retryCount) {
                ForEach(SettingsViewModel.retryOptions, id: \.self) { val in
                    Text("\(val) retr\(val == 1 ? "y" : "ies")").tag(val)
                }
            }
            .onChange(of: viewModel.retryCount) { _, new in viewModel.setRetryCount(new) }

            Picker("Retry Delay", selection: $viewModel.retryDelaySeconds) {
                ForEach(SettingsViewModel.retryDelayOptions, id: \.self) { val in
                    Text("\(val)s").tag(val)
                }
            }
            .onChange(of: viewModel.retryDelaySeconds) { _, new in viewModel.setRetryDelaySeconds(new) }

            Toggle("Auto Retry", isOn: $viewModel.autoRetry)
                .onChange(of: viewModel.autoRetry) { _, new in viewModel.setAutoRetry(new) }
        } header: {
            Label("Smart Retry", systemImage: "arrow.clockwise")
        }
    }

    private var schedulerSection: some View {
        Section {
            Toggle("Enable Scheduler", isOn: $viewModel.enableScheduler)
                .onChange(of: viewModel.enableScheduler) { _, new in viewModel.setEnableScheduler(new) }

            if viewModel.enableScheduler {
                Toggle("Wi-Fi Only Scheduling", isOn: $viewModel.schedulerWifiOnly)
                    .onChange(of: viewModel.schedulerWifiOnly) { _, new in viewModel.setSchedulerWifiOnly(new) }
                Toggle("Charging Only", isOn: $viewModel.schedulerChargingOnly)
                    .onChange(of: viewModel.schedulerChargingOnly) { _, new in viewModel.setSchedulerChargingOnly(new) }
            }
        } header: {
            Label("Download Scheduler", systemImage: "clock")
        }
    }

    private var categorizationSection: some View {
        Section {
            Toggle("Auto-Categorize Downloads", isOn: $viewModel.autoCategorizeEnabled)
                .onChange(of: viewModel.autoCategorizeEnabled) { _, new in viewModel.setAutoCategorizeEnabled(new) }
        } header: {
            Label("Auto-Categorization", systemImage: "tray.full")
        }
    }

    private var hapticsSection: some View {
        Section {
            Toggle("Haptic Feedback", isOn: $viewModel.hapticFeedbackEnabled)
                .onChange(of: viewModel.hapticFeedbackEnabled) { _, new in viewModel.setHapticFeedbackEnabled(new) }
        } header: {
            Label("Haptics & Feedback", systemImage: "hand.tap")
        }
    }

    private var securitySection: some View {
        Section {
            Picker("App Lock Type", selection: Binding(get: { viewModel.lockType }, set: { newVal in
                if newVal == "custom" && viewModel.customPinHash.isEmpty {
                    showPinSetup = true
                } else {
                    viewModel.setLockType(newVal)
                }
            })) {
                Text("None").tag("none")
                Text("Device").tag("device")
                Text("Custom PIN").tag("custom")
            }

            if viewModel.lockType == "device" {
                Toggle("Require Biometrics", isOn: $viewModel.requireBiometrics)
                    .onChange(of: viewModel.requireBiometrics) { _, new in viewModel.setRequireBiometrics(new) }
            }

            Picker("Auto-Lock", selection: $viewModel.autoLockSeconds) {
                ForEach(SettingsViewModel.autoLockOptions, id: \.0) { sec, label in
                    Text(label).tag(sec)
                }
            }
            .onChange(of: viewModel.autoLockSeconds) { _, new in viewModel.setAutoLockSeconds(new) }

            if viewModel.lockType == "custom" {
                Button("Configure Custom PIN") {
                    showPinChange = true
                }
            }
        } header: {
            Label("Security & Privacy", systemImage: "lock.shield")
        }
    }

    private var clipboardSettingsSection: some View {
        Section {
            Toggle("Clipboard Monitoring", isOn: $viewModel.clipboardMonitoring)
                .onChange(of: viewModel.clipboardMonitoring) { _, new in viewModel.setClipboardMonitoring(new) }
            Toggle("Show Clipboard Popup", isOn: $viewModel.clipboardPopupEnabled)
                .onChange(of: viewModel.clipboardPopupEnabled) { _, new in viewModel.setClipboardPopupEnabled(new) }
            Toggle("Auto-Save Clipboard", isOn: $viewModel.clipboardAutoSave)
                .onChange(of: viewModel.clipboardAutoSave) { _, new in viewModel.setClipboardAutoSave(new) }

            Picker("Max History Size", selection: $viewModel.clipboardMaxHistory) {
                ForEach(SettingsViewModel.clipboardHistoryOptions, id: \.self) { val in
                    Text("\(val) items").tag(val)
                }
            }
            .onChange(of: viewModel.clipboardMaxHistory) { _, new in viewModel.setClipboardMaxHistory(new) }

            Picker("Auto-Delete After", selection: $viewModel.clipboardAutoDeleteDays) {
                ForEach(SettingsViewModel.clipboardAutoDeleteOptions, id: \.0) { days, label in
                    Text(label).tag(days)
                }
            }
            .onChange(of: viewModel.clipboardAutoDeleteDays) { _, new in viewModel.setClipboardAutoDeleteDays(new) }
        } header: {
            Label("Clipboard", systemImage: "doc.on.clipboard")
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Created by")
                Spacer()
                Text("RAKIB")
                    .fontWeight(.black)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Label("About", systemImage: "info.circle")
        }
    }

    // MARK: - Sheets

    private var pinSetupSheet: some View {
        NavigationStack {
            Form {
                Section("Create PIN") {
                    SecureField("Enter PIN", text: $pinInput)
                        .keyboardType(.numberPad)
                }
                Section("Security Question (Optional)") {
                    TextField("Question", text: $pinQuestion)
                    SecureField("Answer", text: $pinAnswer)
                }
                Section {
                    Button("Set PIN") {
                        guard !pinInput.isEmpty else { return }
                        let hash = pinInput.sha256()
                        viewModel.setCustomPin(pin: hash, question: pinQuestion, answer: pinAnswer)
                        viewModel.setLockType("custom")
                        showPinSetup = false
                    }
                    .disabled(pinInput.isEmpty)
                }
            }
            .navigationTitle("Setup Custom PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPinSetup = false }
                }
            }
        }
    }

    private var pinChangeSheet: some View {
        NavigationStack {
            Form {
                Section("Current PIN") {
                    SecureField("Enter current PIN", text: $pinInput)
                        .keyboardType(.numberPad)
                }
                Section("New Security Question (Optional)") {
                    TextField("Question", text: $pinQuestion)
                    SecureField("Answer", text: $pinAnswer)
                }
                Section {
                    Button("Change PIN") {
                        guard !pinInput.isEmpty, viewModel.verifyPin(pinInput) else { return }
                        let hash = pinInput.sha256()
                        viewModel.setCustomPin(pin: hash, question: pinQuestion, answer: pinAnswer)
                        showPinChange = false
                    }
                    .disabled(pinInput.isEmpty)

                    Button("Remove PIN", role: .destructive) {
                        viewModel.resetCustomPin()
                        showPinChange = false
                    }
                }
            }
            .navigationTitle("Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showPinChange = false }
                }
            }
        }
    }

    private var folderPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Choose where downloads are saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Downloads saved to the app's Documents folder will be deleted if the app is uninstalled.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Use Default Documents Folder") {
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let path = docs.appendingPathComponent("DirXplore").path
                    viewModel.setDefaultSavePath(path)
                    showSaveFolderPicker = false
                }
                .buttonStyle(.bordered)

                Button("Use Custom Folder") {
                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let path = docs.appendingPathComponent("DirXplore/Downloads").path
                    viewModel.setDefaultSavePath(path)
                    showSaveFolderPicker = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Save Directory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSaveFolderPicker = false }
                }
            }
        }
    }
}
