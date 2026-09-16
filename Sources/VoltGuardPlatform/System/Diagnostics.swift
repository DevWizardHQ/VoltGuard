import AppKit
import Foundation
import VoltGuardCore

public enum Diagnostics {
    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    public static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    public static var modelIdentifier: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    /// Assembled for the user to read before anything leaves the machine.
    public static func report(
        configurationSummary: String,
        logLineLimit: Int = 80
    ) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var report = """
            VoltGuard Diagnostic Report
            ===========================

            VoltGuard version : \(appVersion) (\(buildNumber))
            macOS version     : \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)
            Mac model         : \(modelIdentifier)
            Architecture      : \(architecture)

            Configuration
            -------------
            \(configurationSummary)

            Power source (pmset -g batt)
            ----------------------------
            \(pmsetOutput())

            Recent log lines
            ----------------

            """
        report += FileLogSink.shared.recentLines(limit: logLineLimit).joined(separator: "\n")
        return report
    }

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }

    /// Only used here, where a human reads the text; never on the hot path.
    private static func pmsetOutput() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8) ?? "unavailable"
        } catch {
            return "unavailable: \(error.localizedDescription)"
        }
    }
}
