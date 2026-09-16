import Foundation

public struct RuleWarning: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let ruleID: UUID?
    public let message: String

    public init(id: UUID = UUID(), ruleID: UUID?, message: String) {
        self.id = id
        self.ruleID = ruleID
        self.message = message
    }
}

public enum RuleValidator {
    public static func validate(_ rules: [AlertRule]) -> [RuleWarning] {
        var warnings: [RuleWarning] = []
        let enabled = rules.filter(\.isEnabled)

        for rule in enabled where rule.channels.isEmpty {
            warnings.append(
                RuleWarning(
                    ruleID: rule.id,
                    message: "\(rule.name) has no alert channel enabled and will never notify you."
                ))
        }

        for direction in ThresholdDirection.allCases {
            let sameDirection = enabled.filter { $0.direction == direction }
            let duplicates = Dictionary(grouping: sameDirection, by: \.threshold).filter {
                $0.value.count > 1
            }
            for (threshold, group) in duplicates {
                warnings.append(
                    RuleWarning(
                        ruleID: group.first?.id,
                        message:
                            "\(group.count) enabled \(direction.displayName.lowercased()) rules share the \(threshold)% threshold."
                    ))
            }
        }

        let lowest = enabled.filter { $0.direction == .high }.map(\.threshold).min()
        if let lowest {
            for rule in enabled where rule.direction == .low && rule.threshold >= lowest {
                warnings.append(
                    RuleWarning(
                        ruleID: rule.id,
                        message:
                            "\(rule.name) triggers at \(rule.threshold)%, at or above a high rule at \(lowest)%."
                    ))
            }
        }

        return warnings
    }
}
