import Foundation
import SwiftUI

@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var themeMode: ThemeMode = .system
    @Published var defaultSavePath: String = ""
    @Published var maxConcurrentDownloads: Int = 1
    @Published var trueAmoledDark: Bool = true
    @Published var showDownloadNotifications: Bool = true
    @Published var speedLimitCap: Int = 0
    @Published var keepScreenAwake: Bool = false
    @Published var keepScreenAwakeTimerMinutes: Int = 0
    @Published var smartFolderRouting: Bool = false
    @Published var downloadOnWifiOnly: Bool = false
    @Published var pauseLowBattery: Bool = false
    @Published var requireBiometrics: Bool = false
    @Published var lockType: String = "none"
    @Published var customPinHash: String = ""
    @Published var securityQuestion: String = ""
    @Published var securityAnswer: String = ""
    @Published var autoLockSeconds: Int = 0
    @Published var clipboardMonitoring: Bool = true
    @Published var clipboardPopupEnabled: Bool = true
    @Published var clipboardAutoSave: Bool = false
    @Published var clipboardMaxHistory: Int = 5000
    @Published var clipboardAutoDeleteDays: Int = 0
    @Published var hapticFeedbackEnabled: Bool = true
    @Published var retryCount: Int = 3
    @Published var retryDelaySeconds: Int = 10
    @Published var autoRetry: Bool = true
    @Published var enableScheduler: Bool = false
    @Published var schedulerWifiOnly: Bool = false
    @Published var schedulerChargingOnly: Bool = false
    @Published var autoCategorizeEnabled: Bool = true
    @Published var appVersion: String = "Unknown"
    @Published var isInitialized: Bool = false

    private let defaults: UserDefaults
    private var keepAwakeTimer: Timer?

    private init() {
        defaults = UserDefaults.standard
    }

    func load() async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        defaultSavePath = defaults.string(forKey: "savePath") ?? docs.appendingPathComponent("DirXplore").path

        let tIdx = defaults.integer(forKey: "themeMode")
        themeMode = ThemeMode(rawValue: tIdx) ?? .system
        maxConcurrentDownloads = defaults.integer(forKey: "maxConcurrent")
        if maxConcurrentDownloads == 0 { maxConcurrentDownloads = 1 }

        trueAmoledDark = defaults.object(forKey: "trueAmoledDark") as? Bool ?? true
        showDownloadNotifications = defaults.object(forKey: "showDownloadNotifications") as? Bool ?? true
        speedLimitCap = defaults.integer(forKey: "speedLimitCap")
        keepScreenAwake = defaults.bool(forKey: "keepScreenAwake")
        keepScreenAwakeTimerMinutes = defaults.integer(forKey: "keepScreenAwakeTimerMinutes")
        smartFolderRouting = defaults.bool(forKey: "smartFolderRouting")
        downloadOnWifiOnly = defaults.bool(forKey: "downloadOnWifiOnly")
        pauseLowBattery = defaults.bool(forKey: "pauseLowBattery")
        requireBiometrics = defaults.bool(forKey: "requireBiometrics")
        lockType = defaults.string(forKey: "lockType") ?? "none"
        customPinHash = defaults.string(forKey: "customPinHash") ?? ""
        securityQuestion = defaults.string(forKey: "securityQuestion") ?? ""
        securityAnswer = defaults.string(forKey: "securityAnswer") ?? ""
        autoLockSeconds = defaults.integer(forKey: "autoLockSeconds")
        clipboardMonitoring = defaults.object(forKey: "clipboardMonitoring") as? Bool ?? true
        clipboardPopupEnabled = defaults.object(forKey: "clipboardPopupEnabled") as? Bool ?? true
        clipboardAutoSave = defaults.bool(forKey: "clipboardAutoSave")
        clipboardMaxHistory = defaults.integer(forKey: "clipboardMaxHistory")
        if clipboardMaxHistory == 0 { clipboardMaxHistory = 5000 }
        clipboardAutoDeleteDays = defaults.integer(forKey: "clipboardAutoDeleteDays")
        hapticFeedbackEnabled = defaults.object(forKey: "hapticFeedbackEnabled") as? Bool ?? true

        retryCount = defaults.integer(forKey: "retryCount")
        if retryCount == 0 { retryCount = 3 }
        retryDelaySeconds = defaults.integer(forKey: "retryDelaySeconds")
        if retryDelaySeconds == 0 { retryDelaySeconds = 10 }
        autoRetry = defaults.object(forKey: "autoRetry") as? Bool ?? true
        enableScheduler = defaults.bool(forKey: "enableScheduler")
        schedulerWifiOnly = defaults.bool(forKey: "schedulerWifiOnly")
        schedulerChargingOnly = defaults.bool(forKey: "schedulerChargingOnly")
        autoCategorizeEnabled = defaults.object(forKey: "autoCategorizeEnabled") as? Bool ?? true
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        isInitialized = true
    }

    // MARK: - Setters

    func setThemeMode(_ mode: ThemeMode) {
        themeMode = mode
        defaults.set(mode.rawValue, forKey: "themeMode")
    }

    func setDefaultSavePath(_ path: String) {
        defaultSavePath = path
        defaults.set(path, forKey: "savePath")
    }

    func setMaxConcurrentDownloads(_ max: Int) {
        maxConcurrentDownloads = max
        defaults.set(max, forKey: "maxConcurrent")
    }

    func setTrueAmoledDark(_ val: Bool) {
        trueAmoledDark = val
        defaults.set(val, forKey: "trueAmoledDark")
    }

    func setShowDownloadNotifications(_ val: Bool) {
        showDownloadNotifications = val
        defaults.set(val, forKey: "showDownloadNotifications")
    }

    func setSpeedLimitCap(_ val: Int) {
        speedLimitCap = val
        defaults.set(val, forKey: "speedLimitCap")
    }

    func setKeepScreenAwake(_ val: Bool) {
        keepAwakeTimer?.invalidate()
        keepAwakeTimer = nil
        keepScreenAwake = val
        if val && keepScreenAwakeTimerMinutes > 0 {
            keepAwakeTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(keepScreenAwakeTimerMinutes * 60), repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.setKeepScreenAwake(false)
                }
            }
        }
        defaults.set(val, forKey: "keepScreenAwake")
    }

    func setKeepScreenAwakeTimerMinutes(_ minutes: Int) {
        keepScreenAwakeTimerMinutes = min(max(minutes, 0), 60)
        if keepScreenAwake {
            keepAwakeTimer?.invalidate()
            keepAwakeTimer = nil
            if minutes > 0 {
                keepAwakeTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.setKeepScreenAwake(false)
                    }
                }
            }
        }
        defaults.set(keepScreenAwakeTimerMinutes, forKey: "keepScreenAwakeTimerMinutes")
    }

    func notifyDownloadsComplete() {
        guard keepScreenAwake else { return }
        keepAwakeTimer?.invalidate()
        keepAwakeTimer = nil
        keepScreenAwake = false
        defaults.set(false, forKey: "keepScreenAwake")
    }

    func setSmartFolderRouting(_ val: Bool) {
        smartFolderRouting = val
        defaults.set(val, forKey: "smartFolderRouting")
    }

    func setDownloadOnWifiOnly(_ val: Bool) {
        downloadOnWifiOnly = val
        defaults.set(val, forKey: "downloadOnWifiOnly")
    }

    func setPauseLowBattery(_ val: Bool) {
        pauseLowBattery = val
        defaults.set(val, forKey: "pauseLowBattery")
    }

    func setRequireBiometrics(_ val: Bool) {
        requireBiometrics = val
        defaults.set(val, forKey: "requireBiometrics")
    }

    func setLockType(_ type: String) {
        lockType = type
        defaults.set(type, forKey: "lockType")
    }

    func setCustomPin(pin: String, question: String, answer: String) {
        customPinHash = pin
        securityQuestion = question
        securityAnswer = answer
        defaults.set(pin, forKey: "customPinHash")
        defaults.set(question, forKey: "securityQuestion")
        defaults.set(answer, forKey: "securityAnswer")
    }

    func resetCustomPin() {
        customPinHash = ""
        securityQuestion = ""
        securityAnswer = ""
        lockType = "none"
        requireBiometrics = false
        defaults.removeObject(forKey: "customPinHash")
        defaults.removeObject(forKey: "securityQuestion")
        defaults.removeObject(forKey: "securityAnswer")
        defaults.set(false, forKey: "requireBiometrics")
        defaults.set("none", forKey: "lockType")
    }

    var isSecurityEnabled: Bool { lockType != "none" }

    func setAutoLockSeconds(_ seconds: Int) {
        autoLockSeconds = seconds
        defaults.set(seconds, forKey: "autoLockSeconds")
    }

    func setClipboardMonitoring(_ val: Bool) {
        clipboardMonitoring = val
        defaults.set(val, forKey: "clipboardMonitoring")
    }

    func setClipboardPopupEnabled(_ val: Bool) {
        clipboardPopupEnabled = val
        defaults.set(val, forKey: "clipboardPopupEnabled")
    }

    func setClipboardAutoSave(_ val: Bool) {
        clipboardAutoSave = val
        defaults.set(val, forKey: "clipboardAutoSave")
    }

    func setClipboardMaxHistory(_ val: Int) {
        clipboardMaxHistory = val
        defaults.set(val, forKey: "clipboardMaxHistory")
    }

    func setClipboardAutoDeleteDays(_ val: Int) {
        clipboardAutoDeleteDays = val
        defaults.set(val, forKey: "clipboardAutoDeleteDays")
    }

    func setHapticFeedbackEnabled(_ val: Bool) {
        hapticFeedbackEnabled = val
        defaults.set(val, forKey: "hapticFeedbackEnabled")
    }

    func setRetryCount(_ val: Int) {
        retryCount = min(max(val, 1), 10)
        defaults.set(retryCount, forKey: "retryCount")
    }

    func setRetryDelaySeconds(_ val: Int) {
        retryDelaySeconds = min(max(val, 5), 300)
        defaults.set(retryDelaySeconds, forKey: "retryDelaySeconds")
    }

    func setAutoRetry(_ val: Bool) {
        autoRetry = val
        defaults.set(val, forKey: "autoRetry")
    }

    func setEnableScheduler(_ val: Bool) {
        enableScheduler = val
        defaults.set(val, forKey: "enableScheduler")
    }

    func setSchedulerWifiOnly(_ val: Bool) {
        schedulerWifiOnly = val
        defaults.set(val, forKey: "schedulerWifiOnly")
    }

    func setSchedulerChargingOnly(_ val: Bool) {
        schedulerChargingOnly = val
        defaults.set(val, forKey: "schedulerChargingOnly")
    }

    func setAutoCategorizeEnabled(_ val: Bool) {
        autoCategorizeEnabled = val
        defaults.set(val, forKey: "autoCategorizeEnabled")
    }
}
