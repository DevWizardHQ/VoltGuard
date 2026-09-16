import Foundation

public final class FileLogSink: @unchecked Sendable {
    public static let shared = FileLogSink()

    public var isDebugEnabled = false

    private let queue = DispatchQueue(label: "com.devwizardhq.voltguard.log")
    private let maximumBytes = 1_048_576
    private let generations = 3
    private let formatter: ISO8601DateFormatter

    public private(set) lazy var directory: URL = {
        let base =
            FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        let logs = base.appendingPathComponent("Logs/VoltGuard", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs
    }()

    public var fileURL: URL { directory.appendingPathComponent("voltguard.log") }

    private init() {
        formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
    }

    func write(level: String, category: LogCategory, message: String) {
        if level == "DEBUG" && !isDebugEnabled { return }
        let line = "\(formatter.string(from: Date())) [\(level)] [\(category.rawValue)] \(message)\n"
        queue.async { [self] in
            rotateIfNeeded()
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    private func rotateIfNeeded() {
        let manager = FileManager.default
        guard
            let attributes = try? manager.attributesOfItem(atPath: fileURL.path),
            let size = attributes[.size] as? Int,
            size >= maximumBytes
        else { return }

        let oldest = directory.appendingPathComponent("voltguard.\(generations).log")
        try? manager.removeItem(at: oldest)
        for index in stride(from: generations - 1, through: 1, by: -1) {
            let source = directory.appendingPathComponent("voltguard.\(index).log")
            let destination = directory.appendingPathComponent("voltguard.\(index + 1).log")
            try? manager.moveItem(at: source, to: destination)
        }
        try? manager.moveItem(at: fileURL, to: directory.appendingPathComponent("voltguard.1.log"))
    }

    public func recentLines(limit: Int = 200) -> [String] {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return Array(contents.split(separator: "\n").suffix(limit).map(String.init))
    }

    public func clear() {
        queue.async { [self] in
            let manager = FileManager.default
            try? manager.removeItem(at: fileURL)
            for index in 1...generations {
                try? manager.removeItem(at: directory.appendingPathComponent("voltguard.\(index).log"))
            }
        }
    }
}
