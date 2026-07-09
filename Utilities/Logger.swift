import Foundation
import os

enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }
}

final class Logger {
    static let shared = Logger()

    var minimumLevel: LogLevel = .debug
    private let osLog: OSLog

    private init() {
        osLog = OSLog(subsystem: "com.dirxplore", category: "DirXplore")
    }

    func debug(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .debug, message: message, file: file, line: line)
    }

    func info(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .info, message: message, file: file, line: line)
    }

    func warning(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .warning, message: message, file: file, line: line)
    }

    func error(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .error, message: message, file: file, line: line)
    }

    private func log(level: LogLevel, message: String, file: String, line: Int) {
        guard level >= minimumLevel else { return }
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(level.label)] [\(fileName):\(line)] \(message)"

        switch level {
        case .debug:
            os_log("%{public}@", log: osLog, type: .debug, logMessage)
        case .info:
            os_log("%{public}@", log: osLog, type: .info, logMessage)
        case .warning:
            os_log("%{public}@", log: osLog, type: .default, logMessage)
        case .error:
            os_log("%{public}@", log: osLog, type: .error, logMessage)
        }
    }
}
