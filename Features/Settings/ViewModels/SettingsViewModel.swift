import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()

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

    private let manager = SettingsManager.shared

    private init() {}

    func load() async {
        await manager.load()

        themeMode = manager.themeMode
        defaultSavePath = manager.defaultSavePath
        maxConcurrentDownloads = manager.maxConcurrentDownloads
        trueAmoledDark = manager.trueAmoledDark
        showDownloadNotifications = manager.showDownloadNotifications
        speedLimitCap = manager.speedLimitCap
        keepScreenAwake = manager.keepScreenAwake
        keepScreenAwakeTimerMinutes = manager.keepScreenAwakeTimerMinutes
        smartFolderRouting = manager.smartFolderRouting
        downloadOnWifiOnly = manager.downloadOnWifiOnly
        pauseLowBattery = manager.pauseLowBattery
        requireBiometrics = manager.requireBiometrics
        lockType = manager.lockType
        customPinHash = manager.customPinHash
        securityQuestion = manager.securityQuestion
        securityAnswer = manager.securityAnswer
        autoLockSeconds = manager.autoLockSeconds
        clipboardMonitoring = manager.clipboardMonitoring
        clipboardPopupEnabled = manager.clipboardPopupEnabled
        clipboardAutoSave = manager.clipboardAutoSave
        clipboardMaxHistory = manager.clipboardMaxHistory
        clipboardAutoDeleteDays = manager.clipboardAutoDeleteDays
        hapticFeedbackEnabled = manager.hapticFeedbackEnabled
        retryCount = manager.retryCount
        retryDelaySeconds = manager.retryDelaySeconds
        autoRetry = manager.autoRetry
        enableScheduler = manager.enableScheduler
        schedulerWifiOnly = manager.schedulerWifiOnly
        schedulerChargingOnly = manager.schedulerChargingOnly
        autoCategorizeEnabled = manager.autoCategorizeEnabled
        appVersion = manager.appVersion
    }

    var isSecurityEnabled: Bool { lockType != "none" }

    // MARK: - Theme

    func setThemeMode(_ mode: ThemeMode) {
        manager.setThemeMode(mode)
        themeMode = mode
    }

    // MARK: - Download

    func setDefaultSavePath(_ path: String) {
        manager.setDefaultSavePath(path)
        defaultSavePath = path
    }

    func setMaxConcurrentDownloads(_ max: Int) {
        manager.setMaxConcurrentDownloads(max)
        maxConcurrentDownloads = max
        DownloadManager.shared.setMaxConcurrent(max)
    }

    func setShowDownloadNotifications(_ val: Bool) {
        manager.setShowDownloadNotifications(val)
        showDownloadNotifications = val
    }

    func setSpeedLimitCap(_ val: Int) {
        manager.setSpeedLimitCap(val)
        speedLimitCap = val
    }

    func setSmartFolderRouting(_ val: Bool) {
        manager.setSmartFolderRouting(val)
        smartFolderRouting = val
    }

    func setDownloadOnWifiOnly(_ val: Bool) {
        manager.setDownloadOnWifiOnly(val)
        downloadOnWifiOnly = val
    }

    func setPauseLowBattery(_ val: Bool) {
        manager.setPauseLowBattery(val)
        pauseLowBattery = val
    }

    func setAutoCategorizeEnabled(_ val: Bool) {
        manager.setAutoCategorizeEnabled(val)
        autoCategorizeEnabled = val
    }

    // MARK: - Display

    func setTrueAmoledDark(_ val: Bool) {
        manager.setTrueAmoledDark(val)
        trueAmoledDark = val
    }

    func setKeepScreenAwake(_ val: Bool) {
        manager.setKeepScreenAwake(val)
        keepScreenAwake = val
    }

    func setKeepScreenAwakeTimerMinutes(_ minutes: Int) {
        manager.setKeepScreenAwakeTimerMinutes(minutes)
        keepScreenAwakeTimerMinutes = minutes
    }

    func setHapticFeedbackEnabled(_ val: Bool) {
        manager.setHapticFeedbackEnabled(val)
        hapticFeedbackEnabled = val
    }

    // MARK: - Retry

    func setRetryCount(_ val: Int) {
        manager.setRetryCount(val)
        retryCount = val
    }

    func setRetryDelaySeconds(_ val: Int) {
        manager.setRetryDelaySeconds(val)
        retryDelaySeconds = val
    }

    func setAutoRetry(_ val: Bool) {
        manager.setAutoRetry(val)
        autoRetry = val
    }

    // MARK: - Security

    func setLockType(_ type: String) {
        manager.setLockType(type)
        lockType = type
        if type == "none" {
            requireBiometrics = false
        }
    }

    func setRequireBiometrics(_ val: Bool) {
        manager.setRequireBiometrics(val)
        requireBiometrics = val
    }

    func setAutoLockSeconds(_ seconds: Int) {
        manager.setAutoLockSeconds(seconds)
        autoLockSeconds = seconds
    }

    func setCustomPin(pin: String, question: String, answer: String) {
        manager.setCustomPin(pin: pin, question: question, answer: answer)
        customPinHash = pin
        securityQuestion = question
        securityAnswer = answer
    }

    func resetCustomPin() {
        manager.resetCustomPin()
        customPinHash = ""
        securityQuestion = ""
        securityAnswer = ""
        lockType = "none"
        requireBiometrics = false
    }

    func verifyPin(_ pin: String) -> Bool {
        AuthManager.shared.verifyPin(pin)
    }

    // MARK: - Clipboard

    func setClipboardMonitoring(_ val: Bool) {
        manager.setClipboardMonitoring(val)
        clipboardMonitoring = val
        ClipboardService.shared.setMonitoring(val)
    }

    func setClipboardPopupEnabled(_ val: Bool) {
        manager.setClipboardPopupEnabled(val)
        clipboardPopupEnabled = val
        ClipboardService.shared.setPopupEnabled(val)
    }

    func setClipboardAutoSave(_ val: Bool) {
        manager.setClipboardAutoSave(val)
        clipboardAutoSave = val
        ClipboardService.shared.setAutoSave(val)
    }

    func setClipboardMaxHistory(_ val: Int) {
        manager.setClipboardMaxHistory(val)
        clipboardMaxHistory = val
        ClipboardService.shared.setMaxHistorySize(val)
    }

    func setClipboardAutoDeleteDays(_ val: Int) {
        manager.setClipboardAutoDeleteDays(val)
        clipboardAutoDeleteDays = val
    }

    // MARK: - Scheduler

    func setEnableScheduler(_ val: Bool) {
        manager.setEnableScheduler(val)
        enableScheduler = val
    }

    func setSchedulerWifiOnly(_ val: Bool) {
        manager.setSchedulerWifiOnly(val)
        schedulerWifiOnly = val
    }

    func setSchedulerChargingOnly(_ val: Bool) {
        manager.setSchedulerChargingOnly(val)
        schedulerChargingOnly = val
    }

    // MARK: - Utilities

    func pickDownloadFolder() async -> String? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("DirXplore").path
    }

    static let concurrentOptions = [1, 2, 3, 4, 5, 10]
    static let retryOptions = [1, 2, 3, 5, 10]
    static let retryDelayOptions = [5, 10, 15, 30, 60, 120]
    static let autoLockOptions = [(0, "Immediate"), (30, "30s"), (60, "1m"), (120, "2m")]
    static let clipboardHistoryOptions = [100, 500, 1000, 5000, 10000]
    static let clipboardAutoDeleteOptions = [(0, "Never"), (7, "7 days"), (30, "30 days"), (90, "90 days")]
    static let screenAwakeTimerMax = 60
}
