import Foundation

public actor MonitoringEngine {
    private let clock: any VoltGuardClock
    private let reader: any PowerSourceReader
    private let recorder: any HistoryRecording
    private let dispatcher: any AlertDelivering

    private var configuration: EngineConfiguration
    private var alertEngine: AlertEngine
    private var state: MonitoringStateKind = .active
    private var lastSnapshot: BatterySnapshot?
    private var lastRecordedSnapshot: BatterySnapshot?
    private var lastEvaluation: Date?
    private var lastErrorDescription: String?
    private var consecutiveFailures = 0
    private var needsReconcile = true
    private var isAsleep = false
    private var runLoop: Task<Void, Never>?
    private var nextCheck: Date?

    private var statusContinuations: [UUID: AsyncStream<MonitoringStatus>.Continuation] = [:]

    private static let degradedFloor: TimeInterval = 30
    private static let degradedCeiling: TimeInterval = 300
    private static let outsideScheduleInterval: TimeInterval = 300

    public init(
        clock: any VoltGuardClock = SystemClock(),
        reader: any PowerSourceReader,
        recorder: any HistoryRecording,
        dispatcher: any AlertDelivering,
        configuration: EngineConfiguration = EngineConfiguration(),
        latches: [UUID: RuleLatch] = [:]
    ) {
        self.clock = clock
        self.reader = reader
        self.recorder = recorder
        self.dispatcher = dispatcher
        self.configuration = configuration
        self.alertEngine = AlertEngine(latches: latches)
    }

    // MARK: - Observation

    public var statusStream: AsyncStream<MonitoringStatus> {
        AsyncStream { continuation in
            let id = UUID()
            statusContinuations[id] = continuation
            continuation.yield(currentStatus())
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func removeContinuation(_ id: UUID) {
        statusContinuations[id] = nil
    }

    public func currentStatus() -> MonitoringStatus {
        MonitoringStatus(
            state: state,
            snapshot: lastSnapshot,
            nextCheck: nextCheck,
            lastErrorDescription: lastErrorDescription
        )
    }

    public func latchSnapshot() -> [UUID: RuleLatch] { alertEngine.latches }

    // MARK: - Lifecycle

    public func start() {
        guard runLoop == nil else { return }
        runLoop = Task { [weak self] in
            await self?.runLoopBody()
        }
    }

    public func stop() {
        runLoop?.cancel()
        runLoop = nil
        nextCheck = nil
    }

    public func apply(configuration newValue: EngineConfiguration) async {
        let intervalChanged = configuration.monitoring.interval != newValue.monitoring.interval
        configuration = newValue
        alertEngine.forget(ruleIDs: Set(newValue.rules.map(\.id)))
        if intervalChanged { restartLoop() }
        await tick(trigger: .manual)
    }

    public func setPaused(_ paused: Bool) async {
        configuration.monitoring.isEnabled = !paused
        if paused {
            transition(to: .pausedByUser)
            publish()
        } else {
            needsReconcile = true
            await tick(trigger: .manual)
        }
    }

    public func systemWillSleep() {
        isAsleep = true
        transition(to: .systemAsleep)
        publish()
    }

    public func systemDidWake() async {
        isAsleep = false
        needsReconcile = true
        await tick(trigger: .wake)
    }

    // MARK: - Run loop

    private func restartLoop() {
        guard runLoop != nil else { return }
        stop()
        start()
    }

    private func runLoopBody() async {
        await tick(trigger: .manual)
        while !Task.isCancelled {
            let delay = nextDelay()
            nextCheck = clock.now.addingTimeInterval(delay)
            publish()
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } catch {
                return
            }
            await tick(trigger: .timer)
        }
    }

    private func nextDelay() -> TimeInterval {
        switch state {
        case .degraded:
            let backoff = Self.degradedFloor * pow(2, Double(max(consecutiveFailures - 1, 0)))
            return min(backoff, Self.degradedCeiling)
        case .outsideSchedule:
            return min(Self.outsideScheduleInterval, configuration.monitoring.interval)
        case .noBatteryMac:
            return Self.degradedCeiling
        default:
            return configuration.monitoring.interval
        }
    }

    // MARK: - Tick

    public func tick(trigger: TickTrigger) async {
        if state == .noBatteryMac, trigger != .powerSourceChanged, trigger != .manual { return }
        if isAsleep, trigger != .wake { return }

        let snapshot: BatterySnapshot
        do {
            snapshot = try await reader.read()
            consecutiveFailures = 0
            lastErrorDescription = nil
        } catch {
            consecutiveFailures += 1
            lastErrorDescription = String(describing: error)
            transition(to: .degraded)
            publish()
            return
        }

        lastSnapshot = snapshot

        guard snapshot.hasBattery else {
            transition(to: .noBatteryMac)
            publish()
            return
        }

        let resolved = resolveState(at: snapshot.timestamp)
        transition(to: resolved)

        if SamplingPolicy.shouldRecord(
            previous: lastRecordedSnapshot,
            current: snapshot,
            maxGap: configuration.monitoring.maxSampleGap
        ) {
            lastRecordedSnapshot = snapshot
            await recorder.record(snapshot: snapshot, monitoringState: resolved)
        }

        guard resolved.evaluatesRules else {
            publish()
            return
        }

        guard
            SamplingPolicy.shouldEvaluate(
                trigger: trigger,
                previous: lastEvaluation == nil ? nil : lastSnapshot,
                current: snapshot,
                lastEvaluation: lastEvaluation,
                interval: configuration.monitoring.interval
            )
        else {
            publish()
            return
        }

        lastEvaluation = snapshot.timestamp

        guard configuration.monitoring.alertsGloballyEnabled else {
            publish()
            return
        }

        let mode: EvaluationMode = needsReconcile ? .reconciling : .normal
        needsReconcile = false

        let result = alertEngine.evaluate(
            snapshot: snapshot,
            rules: configuration.rules,
            now: snapshot.timestamp,
            mode: mode
        )

        publish()

        for event in result.events {
            let outcomes = await dispatcher.deliver(event)
            await recorder.record(delivery: AlertDelivery(event: event, outcomes: outcomes))
        }
    }

    // MARK: - State

    private func resolveState(at date: Date) -> MonitoringStateKind {
        if !configuration.monitoring.isEnabled { return .pausedByUser }
        if isAsleep { return .systemAsleep }
        if !configuration.schedule.isActive(at: date, calendar: clock.calendar) { return .outsideSchedule }
        return .active
    }

    private func transition(to newState: MonitoringStateKind) {
        guard state != newState else { return }
        state = newState
        if newState != .active { lastEvaluation = nil }
    }

    private func publish() {
        let status = currentStatus()
        for continuation in statusContinuations.values {
            continuation.yield(status)
        }
    }
}
