import Foundation
import OSLog

public enum LogCategory: String, CaseIterable {
    case monitoring, alerts, storage, updates, ui, system
}

public enum Log {
    public static let subsystem = "com.devwizardhq.voltguard"

    private static var loggers: [LogCategory: Logger] = [:]
    private static let lock = NSLock()

    public static func logger(_ category: LogCategory) -> Logger {
        lock.lock()
        defer { lock.unlock() }
        if let existing = loggers[category] { return existing }
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }

    public static func info(_ category: LogCategory, _ message: String) {
        logger(category).info("\(message, privacy: .public)")
        FileLogSink.shared.write(level: "INFO", category: category, message: message)
    }

    public static func debug(_ category: LogCategory, _ message: String) {
        logger(category).debug("\(message, privacy: .public)")
        FileLogSink.shared.write(level: "DEBUG", category: category, message: message)
    }

    public static func warning(_ category: LogCategory, _ message: String) {
        logger(category).warning("\(message, privacy: .public)")
        FileLogSink.shared.write(level: "WARNING", category: category, message: message)
    }

    public static func error(_ category: LogCategory, _ message: String) {
        logger(category).error("\(message, privacy: .public)")
        FileLogSink.shared.write(level: "ERROR", category: category, message: message)
    }
}
