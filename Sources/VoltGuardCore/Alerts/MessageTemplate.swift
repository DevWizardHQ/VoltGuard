import Foundation

public struct MessageContext: Sendable {
    public let percentage: Int?
    public let threshold: Int
    public let chargingState: ChargingState
    public let powerSource: PowerSource
    public let date: Date

    public init(
        percentage: Int?,
        threshold: Int,
        chargingState: ChargingState,
        powerSource: PowerSource,
        date: Date
    ) {
        self.percentage = percentage
        self.threshold = threshold
        self.chargingState = chargingState
        self.powerSource = powerSource
        self.date = date
    }
}

public enum MessageTemplate {
    public static let placeholders = ["{battery}", "{threshold}", "{status}", "{power_source}", "{time}"]

    public static func defaultMessage(for rule: AlertRule) -> String {
        switch rule.direction {
        case .low:
            "Battery is at {battery}, at or below your {threshold} threshold. Please connect the charger."
        case .high:
            "Battery is at {battery}, at or above your {threshold} threshold. You can disconnect the charger."
        }
    }

    public static func defaultTitle(for rule: AlertRule) -> String {
        "\(rule.name) — {battery}"
    }

    public static func render(_ template: String, context: MessageContext) -> String {
        var output = template
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none

        let replacements: [String: String] = [
            "{battery}": context.percentage.map { "\($0)%" } ?? "unknown",
            "{threshold}": "\(context.threshold)%",
            "{status}": context.chargingState.displayName,
            "{power_source}": context.powerSource.displayName,
            "{time}": formatter.string(from: context.date),
        ]

        for (placeholder, value) in replacements {
            output = output.replacingOccurrences(of: placeholder, with: value)
        }
        return output
    }
}
