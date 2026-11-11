import Foundation

struct RankUpEvent: Equatable {
    let rank: Rank
    let rankName: String
    /// The line for the notification and the desk cat.
    let line: String
}

/// Runs the two clocks (Discord ritual, procrastination toggle) and turns
/// their progress into ranks.
@MainActor
final class CatEarsModel: ObservableObject {
    /// Starts a repeating tick and returns a way to cancel it.
    typealias TickScheduler = (TimeInterval, @escaping @MainActor () -> Void) -> (() -> Void)

    /// Never persisted, so the toggle is always off at launch.
    @Published private(set) var isProcrastinating = false
    /// What the ritual last saw. Nil while the ritual is not watching.
    @Published private(set) var discordObservation: DiscordObservation?

    let configuration: RitualConfiguration
    let tickInterval: TimeInterval
    /// Longest gap between ticks that still counts as observed time.
    let maximumObservedGap: TimeInterval

    private let appModel: AppModel
    private let discord: DiscordActivityObserving
    private let now: () -> TimeInterval
    private let chooseIndex: (Int) -> Int
    private let scheduleTicks: TickScheduler
    private let onRankUp: (RankUpEvent) -> Void

    private var cancelTicks: (() -> Void)?
    private var lastTickTime: TimeInterval?
    private var previousRitualMultiplier: Double = 0

    /// - Parameters:
    ///   - now: A monotonic clock in seconds that does not advance during sleep.
    ///   - chooseIndex: Picks an index below the given count; random in the app.
    ///   - scheduleTicks: Defaults to a main-run-loop timer.
    init(
        appModel: AppModel,
        discord: DiscordActivityObserving,
        configuration: RitualConfiguration = RitualConfiguration(),
        tickInterval: TimeInterval = 5,
        maximumObservedGap: TimeInterval = 30,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        chooseIndex: @escaping (Int) -> Int = { Int.random(in: 0..<$0) },
        scheduleTicks: TickScheduler? = nil,
        onRankUp: @escaping (RankUpEvent) -> Void
    ) {
        self.appModel = appModel
        self.discord = discord
        self.configuration = configuration
        self.tickInterval = tickInterval
        self.maximumObservedGap = maximumObservedGap
        self.now = now
        self.chooseIndex = chooseIndex
        self.scheduleTicks = scheduleTicks ?? CatEarsModel.timerScheduler
        self.onRankUp = onRankUp
    }

    static let timerScheduler: TickScheduler = { interval, action in
        let timer = MainTimer.schedule(after: interval, repeats: true, action: action)
        timer.tolerance = interval / 10
        return { timer.invalidate() }
    }

    // MARK: Derived state

    var rank: Rank? { appModel.stored.catEars.rank }

    var progress: RankProgress {
        let catEars = appModel.stored.catEars
        return RankProgression.progress(
            rank: catEars.rank,
            ritualFraction: catEars.ritualSeconds / configuration.requiredSeconds,
            procrastinationMinutes: catEars.procrastinationMinutes
        )
    }

    /// The line for the latest rank, or nil before the first rank.
    var latestLine: String? {
        guard let rank else { return nil }
        return line(for: rank, in: appModel.stored)
    }

    // MARK: Lifecycle

    /// Begins watching if there is anything to watch. Safe to call again.
    func start() {
        updateTicking()
    }

    func stop() {
        setProcrastinating(false)
        stopTicking()
    }

    // MARK: User actions

    func setProcrastinating(_ enabled: Bool) {
        guard enabled != isProcrastinating else { return }
        // The toggle earns the ranks after E-Kitten, so it stays off until then.
        if enabled && rank == nil { return }

        // Settle the time up to this moment under the old setting first.
        if cancelTicks != nil { tick() }
        isProcrastinating = enabled
        updateTicking()
    }

    func setDiscordDaddyModeEnabled(_ enabled: Bool) {
        appModel.update { state in
            state.preferences.discordDaddyModeCopyEnabled = enabled
            // Turning the setting off must also retire an already-selected
            // Discord Daddy Mode line.
            if !enabled && state.catEars.ceremonyLineID == CeremonyCopy.discordDaddyModeLine.id {
                state.catEars.ceremonyLineID = chooseCeremonyLine(discordDaddyModeEnabled: false).id
            }
        }
    }

    // MARK: Accounting

    /// Credits the time since the previous tick. Driven by the scheduler.
    func tick() {
        let current = now()
        let credited = TimeAccounting.creditedInterval(
            from: lastTickTime,
            to: current,
            maximumGap: maximumObservedGap
        )
        lastTickTime = current

        var ritualSeconds: TimeInterval = 0
        if rank == nil {
            let multiplier = observeDiscord()
            // The state may have changed anywhere inside the interval, so
            // credit the slower of the rates seen at its two ends.
            ritualSeconds = credited * min(previousRitualMultiplier, multiplier)
            previousRitualMultiplier = multiplier
        }
        let procrastinationSeconds = isProcrastinating ? credited : 0

        award(ritualSeconds: ritualSeconds, procrastinationSeconds: procrastinationSeconds)
    }

    private func award(ritualSeconds: TimeInterval, procrastinationSeconds: TimeInterval) {
        guard ritualSeconds > 0 || procrastinationSeconds > 0 else { return }

        var event: RankUpEvent?
        appModel.update { state in
            state.catEars.ritualSeconds = min(
                configuration.requiredSeconds,
                state.catEars.ritualSeconds + ritualSeconds
            )
            state.catEars.procrastinationSeconds += procrastinationSeconds

            guard let newRank = earnedRank(in: state.catEars), newRank != state.catEars.rank else { return }
            if newRank == .eKitten {
                let enabled = state.preferences.discordDaddyModeCopyEnabled
                state.catEars.ceremonyLineID = chooseCeremonyLine(discordDaddyModeEnabled: enabled).id
            }
            state.catEars.rank = newRank
            event = RankUpEvent(
                rank: newRank,
                rankName: RankTable.entry(for: newRank)?.name ?? "",
                line: line(for: newRank, in: state)
            )
        }

        if let event {
            // The rank is already saved; nothing below can undo it.
            onRankUp(event)
            updateTicking()
        }
    }

    /// The rank the stored progress now entitles the user to. The first rank
    /// is always E-Kitten, whatever else is stored.
    private func earnedRank(in catEars: StoredAppState.CatEars) -> Rank? {
        guard let current = catEars.rank else {
            return catEars.ritualSeconds >= configuration.requiredSeconds ? .eKitten : nil
        }
        let entitled = RankProgression.rank(
            ritualComplete: true,
            procrastinationMinutes: catEars.procrastinationMinutes
        )
        return RankProgression.higher(current, entitled)
    }

    private func chooseCeremonyLine(discordDaddyModeEnabled: Bool) -> CeremonyLine {
        let candidates = CeremonyCopy.candidates(discordDaddyModeEnabled: discordDaddyModeEnabled)
        let index = chooseIndex(candidates.count)
        return candidates.indices.contains(index)
            ? candidates[index]
            : CeremonyCopy.line(id: nil, discordDaddyModeEnabled: discordDaddyModeEnabled)
    }

    private func line(for rank: Rank, in state: StoredAppState) -> String {
        if let line = RankTable.entry(for: rank)?.rankUpLine { return line }
        return CeremonyCopy.line(
            id: state.catEars.ceremonyLineID,
            discordDaddyModeEnabled: state.preferences.discordDaddyModeCopyEnabled
        ).text
    }

    // MARK: Ticking

    private var needsTicking: Bool {
        // The ritual only matters until E-Kitten; after that Discord is no
        // longer watched at all.
        rank == nil || isProcrastinating
    }

    private func updateTicking() {
        if needsTicking {
            startTickingIfNeeded()
        } else {
            stopTicking()
        }
        if rank != nil { discordObservation = nil }
    }

    private func startTickingIfNeeded() {
        guard cancelTicks == nil else { return }
        lastTickTime = now()
        previousRitualMultiplier = rank == nil ? observeDiscord() : 0
        cancelTicks = scheduleTicks(tickInterval) { [weak self] in
            self?.tick()
        }
    }

    private func stopTicking() {
        cancelTicks?()
        cancelTicks = nil
        lastTickTime = nil
        discordObservation = nil
    }

    private func observeDiscord() -> Double {
        let observation = discord.currentObservation()
        discordObservation = observation
        return configuration.multiplier(for: observation)
    }
}
