import Foundation

struct AppSettings: Codable {
    var themeMode: Int
    var defaultSavePath: String
    var maxConcurrentDownloads: Int
    var trueAmoledDark: Bool
    var showDownloadNotifications: Bool
    var speedLimitCap: Int
    var keepScreenAwake: Bool
    var keepScreenAwakeTimerMinutes: Int
    var smartFolderRouting: Bool
    var downloadOnWifiOnly: Bool
    var pauseLowBattery: Bool
    var requireBiometrics: Bool
    var lockType: String
    var customPinHash: String
    var securityQuestion: String
    var securityAnswer: String
    var autoLockSeconds: Int
    var clipboardMonitoring: Bool
    var clipboardPopupEnabled: Bool
    var clipboardAutoSave: Bool
    var clipboardMaxHistory: Int
    var clipboardAutoDeleteDays: Int
    var hapticFeedbackEnabled: Bool
    var retryCount: Int
    var retryDelaySeconds: Int
    var autoRetry: Bool
    var enableScheduler: Bool
    var schedulerWifiOnly: Bool
    var schedulerChargingOnly: Bool
    var autoCategorizeEnabled: Bool
    var appVersion: String

    static let defaults = AppSettings(
        themeMode: 0,
        defaultSavePath: "",
        maxConcurrentDownloads: 1,
        trueAmoledDark: true,
        showDownloadNotifications: true,
        speedLimitCap: 0,
        keepScreenAwake: false,
        keepScreenAwakeTimerMinutes: 0,
        smartFolderRouting: false,
        downloadOnWifiOnly: false,
        pauseLowBattery: false,
        requireBiometrics: false,
        lockType: "none",
        customPinHash: "",
        securityQuestion: "",
        securityAnswer: "",
        autoLockSeconds: 0,
        clipboardMonitoring: true,
        clipboardPopupEnabled: true,
        clipboardAutoSave: false,
        clipboardMaxHistory: 5000,
        clipboardAutoDeleteDays: 0,
        hapticFeedbackEnabled: true,
        retryCount: 3,
        retryDelaySeconds: 10,
        autoRetry: true,
        enableScheduler: false,
        schedulerWifiOnly: false,
        schedulerChargingOnly: false,
        autoCategorizeEnabled: true,
        appVersion: "Unknown"
    )

    private static let defaultsKey = "com.dirxplore.appSettings"

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return defaults
        }
        return settings
    }

    enum CodingKeys: String, CodingKey {
        case themeMode, defaultSavePath, maxConcurrentDownloads, trueAmoledDark,
             showDownloadNotifications, speedLimitCap, keepScreenAwake,
             keepScreenAwakeTimerMinutes, smartFolderRouting, downloadOnWifiOnly,
             pauseLowBattery, requireBiometrics, lockType, customPinHash,
             securityQuestion, securityAnswer, autoLockSeconds, clipboardMonitoring,
             clipboardPopupEnabled, clipboardAutoSave, clipboardMaxHistory,
             clipboardAutoDeleteDays, hapticFeedbackEnabled, retryCount,
             retryDelaySeconds, autoRetry, enableScheduler, schedulerWifiOnly,
             schedulerChargingOnly, autoCategorizeEnabled, appVersion
    }
}
