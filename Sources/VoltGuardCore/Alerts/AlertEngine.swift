import Foundation

public enum EvaluationMode: Sendable {
    case normal
    /// After launch or wake: re-arm without firing, so a state the user already
    /// saw is not replayed.
    case reconciling
}

public struct EvaluationResult: Equatable, Sendable {
    public let events: [AlertEvent]
    public let suppressions: [UUID: SuppressionReason]

    public init(events: [AlertEvent], suppressions: [UUID: SuppressionReason]) {
        self.events = events
        self.suppressions = suppressions
    }

    public static let none = EvaluationResult(events: [], suppressions: [:])
}

public struct AlertEngine: Sendable {
    public private(set) var latches: [UUID: RuleLatch]
    public private(set) var powerSessionID: UUID
    private var lastPowerSource: PowerSource?
    /// A released latch forgets its generation, so the counter lives here and
    /// keeps re-entries distinguishable for deduplication.
    private var generations: [UUID: Int] = [:]

    public init(
        latches: [UUID: RuleLatch] = [:],
        powerSessionID: UUID = UUID(),
        lastPowerSource: PowerSource? = nil
    ) {
        self.latches = latches
        self.powerSessionID = powerSessionID
        self.lastPowerSource = lastPowerSource
        self.generations = latches.mapValues(\.generation)
    }

    public func latch(for ruleID: UUID) -> RuleLatch {
        latches[ruleID] ?? .clear
    }

    public mutating func forget(ruleIDs: Set<UUID>) {
        latches = latches.filter { ruleIDs.contains($0.key) }
    }

    public mutating func evaluate(
        snapshot: BatterySnapshot,
        rules: [AlertRule],
        now: Date,
        mode: EvaluationMode = .normal
    ) -> EvaluationResult {
        rotatePowerSessionIfNeeded(snapshot.powerSource)

        var events: [AlertEvent] = []
        var suppressions: [UUID: SuppressionReason] = [:]

        for rule in rules {
            guard rule.isEnabled else {
                latches[rule.id] = .clear
                continue
            }

            let current = latch(for: rule.id)
            let matches = rule.matches(snapshot)

            switch current {
            case .clear:
                guard matches else { continue }
                let generation = (generations[rule.id] ?? current.generation) + 1
                generations[rule.id] = generation
                if mode == .reconciling {
                    latches[rule.id] = .armed(
                        generation: generation,
                        enteredAt: now,
                        lastFiredAt: now,
                        fireCount: 0
                    )
                    suppressions[rule.id] = .reconcilingAfterRestartOrWake
                    continue
                }
                latches[rule.id] = .armed(
                    generation: generation,
                    enteredAt: now,
                    lastFiredAt: now,
                    fireCount: 1
                )
                events.append(makeEvent(rule: rule, snapshot: snapshot, generation: generation, now: now))

            case let .armed(generation, enteredAt, lastFiredAt, fireCount):
                if rule.hasReleased(snapshot) {
                    latches[rule.id] = .clear
                    continue
                }
                guard matches else { continue }

                guard shouldRefire(rule: rule, lastFiredAt: lastFiredAt, now: now) else {
                    suppressions[rule.id] =
                        fireCount == 0
                        ? .reconcilingAfterRestartOrWake
                        : repetitionSuppression(for: rule)
                    continue
                }
                latches[rule.id] = .armed(
                    generation: generation,
                    enteredAt: enteredAt,
                    lastFiredAt: now,
                    fireCount: fireCount + 1
                )
                events.append(makeEvent(rule: rule, snapshot: snapshot, generation: generation, now: now))
            }
        }

        return EvaluationResult(events: events, suppressions: suppressions)
    }

    private mutating func rotatePowerSessionIfNeeded(_ source: PowerSource) {
        guard lastPowerSource != source else { return }
        if lastPowerSource != nil { powerSessionID = UUID() }
        lastPowerSource = source
    }

    private func repetitionSuppression(for rule: AlertRule) -> SuppressionReason {
        rule.repetition == .once ? .alreadyFiredThisGeneration : .repetitionIntervalNotElapsed
    }

    private func shouldRefire(rule: AlertRule, lastFiredAt: Date?, now: Date) -> Bool {
        guard let lastFiredAt else { return true }
        switch rule.repetition {
        case .once:
            return false
        case .untilConditionChanges:
            return true
        case let .interval(seconds):
            let elapsed = now.timeIntervalSince(lastFiredAt)
            // A backwards clock change must not trap the user in silence.
            return elapsed < 0 || elapsed >= seconds
        }
    }

    private func makeEvent(
        rule: AlertRule,
        snapshot: BatterySnapshot,
        generation: Int,
        now: Date
    ) -> AlertEvent {
        let context = MessageContext(
            percentage: snapshot.combinedPercentage,
            threshold: rule.threshold,
            chargingState: snapshot.chargingState,
            powerSource: snapshot.powerSource,
            date: now
        )
        return AlertEvent(
            key: AlertEventKey(ruleID: rule.id, generation: generation, powerSessionID: powerSessionID),
            rule: rule,
            snapshot: snapshot,
            title: MessageTemplate.render(MessageTemplate.defaultTitle(for: rule), context: context),
            body: MessageTemplate.render(
                rule.message ?? MessageTemplate.defaultMessage(for: rule), context: context),
            firedAt: now
        )
    }
}
