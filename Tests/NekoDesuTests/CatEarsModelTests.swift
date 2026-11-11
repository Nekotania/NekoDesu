import XCTest
@testable import NekoDesu

@MainActor
final class CatEarsModelTests: XCTestCase {
    private var store: FakePersistenceStore!
    private var appModel: AppModel!
    private var discord: FakeDiscord!
    private var clock: TimeInterval = 1_000
    private var events: [RankUpEvent] = []
    private var chosenIndex = 0
    private var scheduledTick: (() -> Void)?
    private var scheduleCount = 0
    private var cancelCount = 0

    private let visibleIdle = DiscordObservation(presence: .visible, microphone: .idle)
    private let visibleInCall = DiscordObservation(presence: .visible, microphone: .inUse)

    private func makeModel(_ state: StoredAppState = .safeDefaults) -> CatEarsModel {
        store = FakePersistenceStore(state: state)
        appModel = AppModel(persistence: store)
        discord = FakeDiscord()
        return CatEarsModel(
            appModel: appModel,
            discord: discord,
            now: { [unowned self] in self.clock },
            chooseIndex: { [unowned self] _ in self.chosenIndex },
            scheduleTicks: { [unowned self] _, action in
                self.scheduleCount += 1
                self.scheduledTick = { action() }
                return { self.cancelCount += 1; self.scheduledTick = nil }
            },
            onRankUp: { [unowned self] in self.events.append($0) }
        )
    }

    private func eKittenState(procrastinationMinutes: Double = 0) -> StoredAppState {
        var state = StoredAppState.safeDefaults
        state.catEars.rank = .eKitten
        state.catEars.ritualSeconds = 1_200
        state.catEars.procrastinationSeconds = procrastinationMinutes * 60
        state.catEars.ceremonyLineID = CeremonyCopy.standardLines[1].id
        return state
    }

    /// Advances the clock in tick-sized steps, ticking after each.
    private func run(_ model: CatEarsModel, seconds: TimeInterval, step: TimeInterval = 5) {
        var remaining = seconds
        while remaining > 0 {
            let delta = min(step, remaining)
            clock += delta
            remaining -= delta
            model.tick()
        }
    }

    // MARK: Ritual clock

    func testVisibleIdleDiscordEarnsEKittenInTwentyMinutes() {
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()

        run(model, seconds: 19 * 60 + 55)
        XCTAssertNil(model.rank)
        XCTAssertTrue(events.isEmpty)

        run(model, seconds: 5)
        XCTAssertEqual(model.rank, .eKitten)
        XCTAssertEqual(events.map(\.rank), [.eKitten])
    }

    func testInCallTakesEightyMinutes() {
        let model = makeModel()
        discord.observation = visibleInCall
        model.start()

        run(model, seconds: 79 * 60)
        XCTAssertNil(model.rank)
        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 79 * 60 / 4, accuracy: 0.001)

        run(model, seconds: 60)
        XCTAssertEqual(model.rank, .eKitten)
    }

    func testRitualIsPausedWhileDiscordIsNotRunning() {
        let model = makeModel()
        model.start()

        run(model, seconds: 3_600)

        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 0)
        XCTAssertNil(model.rank)
        XCTAssertTrue(store.saved.isEmpty)
        XCTAssertEqual(model.discordObservation?.presence, .notRunning)
    }

    func testQuittingDiscordPausesTheClock() {
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()
        run(model, seconds: 60)

        discord.observation = DiscordObservation(presence: .notRunning, microphone: .unknown)
        run(model, seconds: 600)

        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 60, accuracy: 0.001)
    }

    func testBackgroundDiscordUsesTheConfiguredMultiplier() {
        let model = makeModel()
        discord.observation = DiscordObservation(presence: .background, microphone: .idle)
        model.start()

        run(model, seconds: 100)

        XCTAssertEqual(
            appModel.stored.catEars.ritualSeconds,
            100 * model.configuration.backgroundMultiplier,
            accuracy: 0.001
        )
    }

    func testAStateChangeCreditsTheSlowerRateForThatInterval() {
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()

        discord.observation = visibleInCall
        run(model, seconds: 5)
        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 1.25, accuracy: 0.001)

        discord.observation = visibleIdle
        run(model, seconds: 5)
        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 2.5, accuracy: 0.001)

        run(model, seconds: 5)
        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 7.5, accuracy: 0.001)
    }

    func testDelayedCallbackIsCreditedByElapsedTimeNotCallbackCount() {
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()

        clock += 20
        model.tick()
        model.tick()
        model.tick()

        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 20, accuracy: 0.001)
    }

    func testLongSuspensionAwardsNothing() {
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()
        run(model, seconds: 10)

        clock += 8 * 3_600
        model.tick()
        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 10, accuracy: 0.001)

        // Accounting resumes normally afterwards.
        run(model, seconds: 5)
        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 15, accuracy: 0.001)
    }

    func testClockGoingBackwardsAwardsNothing() {
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()

        clock -= 500
        model.tick()

        XCTAssertEqual(appModel.stored.catEars.ritualSeconds, 0)
    }

    func testRitualStopsWatchingDiscordAfterEKitten() {
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()
        run(model, seconds: 20 * 60)
        XCTAssertEqual(model.rank, .eKitten)

        XCTAssertEqual(cancelCount, 1)
        XCTAssertNil(scheduledTick)
        XCTAssertNil(model.discordObservation)

        let observations = discord.observationCount
        model.setProcrastinating(true)
        run(model, seconds: 60)
        XCTAssertEqual(discord.observationCount, observations)
    }

    func testAlreadyRankedLaunchDoesNotWatchOrAnnounce() {
        let model = makeModel(eKittenState(procrastinationMinutes: 45))
        model.start()

        XCTAssertEqual(scheduleCount, 0)
        XCTAssertEqual(discord.observationCount, 0)
        XCTAssertTrue(events.isEmpty)
        XCTAssertFalse(model.isProcrastinating)
    }

    func testStartTwiceSchedulesOneTicker() {
        let model = makeModel()
        model.start()
        model.start()

        XCTAssertEqual(scheduleCount, 1)
    }

    // MARK: Ceremony

    func testCeremonyRunsOnceAcrossRepeatedUpdatesAndRelaunch() {
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()
        run(model, seconds: 20 * 60)
        run(model, seconds: 600)
        model.tick()
        XCTAssertEqual(events.count, 1)

        // Relaunch from what was saved.
        let saved = appModel.stored
        events = []
        let relaunched = makeModel(saved)
        discord.observation = visibleIdle
        relaunched.start()
        relaunched.tick()

        XCTAssertEqual(relaunched.rank, .eKitten)
        XCTAssertTrue(events.isEmpty)
    }

    func testCeremonyLineComesFromTheStandardPoolWhenDaddyModeIsOff() {
        chosenIndex = 3
        let model = makeModel()
        discord.observation = visibleIdle
        model.start()
        run(model, seconds: 20 * 60)

        XCTAssertEqual(events.first?.line, CeremonyCopy.standardLines[3].text)
        XCTAssertEqual(events.first?.rankName, "E-Kitten")
        XCTAssertEqual(model.latestLine, CeremonyCopy.standardLines[3].text)
        XCTAssertEqual(appModel.stored.catEars.ceremonyLineID, CeremonyCopy.standardLines[3].id)
    }

    func testDaddyModeLineIsOnlyACandidateWhenEnabled() {
        XCTAssertFalse(CeremonyCopy.candidates(discordDaddyModeEnabled: false).contains(CeremonyCopy.discordDaddyModeLine))
        XCTAssertEqual(CeremonyCopy.candidates(discordDaddyModeEnabled: false).count, 5)
        XCTAssertEqual(CeremonyCopy.candidates(discordDaddyModeEnabled: true).count, 6)

        chosenIndex = 5
        var state = StoredAppState.safeDefaults
        state.preferences.discordDaddyModeCopyEnabled = true
        let model = makeModel(state)
        discord.observation = visibleIdle
        model.start()
        run(model, seconds: 20 * 60)

        XCTAssertEqual(events.first?.line, CeremonyCopy.discordDaddyModeLine.text)
    }

    func testTurningDaddyModeOffRetiresTheDaddyModeLine() {
        var state = eKittenState()
        state.preferences.discordDaddyModeCopyEnabled = true
        state.catEars.ceremonyLineID = CeremonyCopy.discordDaddyModeLine.id
        chosenIndex = 2
        let model = makeModel(state)
        XCTAssertEqual(model.latestLine, CeremonyCopy.discordDaddyModeLine.text)

        model.setDiscordDaddyModeEnabled(false)

        XCTAssertEqual(model.latestLine, CeremonyCopy.standardLines[2].text)
        XCTAssertEqual(appModel.stored.catEars.ceremonyLineID, CeremonyCopy.standardLines[2].id)
        XCTAssertTrue(events.isEmpty)
    }

    func testStoredDaddyModeLineIsNeverShownWhileTheSettingIsOff() {
        var state = eKittenState()
        state.catEars.ceremonyLineID = CeremonyCopy.discordDaddyModeLine.id
        let model = makeModel(state)

        XCTAssertNotEqual(model.latestLine, CeremonyCopy.discordDaddyModeLine.text)
        XCTAssertTrue(CeremonyCopy.standardLines.map(\.text).contains(model.latestLine ?? ""))
    }

    // MARK: Procrastination toggle

    func testToggleIsOffAtLaunchAndLockedBeforeEKitten() {
        let model = makeModel()
        model.start()
        XCTAssertFalse(model.isProcrastinating)

        model.setProcrastinating(true)

        XCTAssertFalse(model.isProcrastinating)
        XCTAssertNil(model.latestLine)
    }

    func testOnePointPerFullMinuteWhileEnabled() {
        let model = makeModel(eKittenState())
        model.start()
        model.setProcrastinating(true)

        run(model, seconds: 59)
        XCTAssertEqual(appModel.stored.catEars.procrastinationMinutes, 0)

        run(model, seconds: 1)
        XCTAssertEqual(appModel.stored.catEars.procrastinationMinutes, 1)
    }

    func testTurningTheToggleOffStopsAccumulationImmediately() {
        let model = makeModel(eKittenState())
        model.start()
        model.setProcrastinating(true)
        run(model, seconds: 60)

        clock += 3
        model.setProcrastinating(false)
        XCTAssertEqual(appModel.stored.catEars.procrastinationSeconds, 63, accuracy: 0.001)
        XCTAssertNil(scheduledTick)

        clock += 5_000
        model.tick()
        XCTAssertEqual(appModel.stored.catEars.procrastinationSeconds, 63, accuracy: 0.001)

        // Time spent off is not credited when the toggle comes back on.
        model.setProcrastinating(true)
        run(model, seconds: 5)
        XCTAssertEqual(appModel.stored.catEars.procrastinationSeconds, 68, accuracy: 0.001)
    }

    func testProgressSurvivesRelaunch() {
        let model = makeModel(eKittenState())
        model.start()
        model.setProcrastinating(true)
        run(model, seconds: 10 * 60)

        let relaunched = makeModel(store.saved.last ?? .safeDefaults)
        relaunched.start()

        XCTAssertEqual(appModel.stored.catEars.procrastinationMinutes, 10)
        XCTAssertFalse(relaunched.isProcrastinating)
        XCTAssertEqual(
            relaunched.progress,
            .towardNext(next: .strayCat, minutes: 10, minutesRequired: 30, fraction: 10.0 / 30.0)
        )
    }

    func testToggleMinutesEarnEachLaterRankOnce() {
        let model = makeModel(eKittenState())
        model.start()
        model.setProcrastinating(true)

        run(model, seconds: 30 * 60)
        XCTAssertEqual(model.rank, .strayCat)
        XCTAssertEqual(events.map(\.rank), [.strayCat])
        XCTAssertEqual(events.last?.line, RankTable.entry(for: .strayCat)?.rankUpLine)
        XCTAssertEqual(model.latestLine, RankTable.entry(for: .strayCat)?.rankUpLine)

        run(model, seconds: 690 * 60)
        XCTAssertEqual(model.rank, .greatOldCat)
        XCTAssertEqual(events.map(\.rank), [.strayCat, .streetCat, .alleyCat, .houseCat, .greatOldCat])
        XCTAssertEqual(model.progress, .maximumRank)

        run(model, seconds: 600)
        XCTAssertEqual(events.count, 5)
    }

    func testStoredRankIsNeverLowered() {
        // A higher rank than the minutes justify stays.
        var state = eKittenState(procrastinationMinutes: 5)
        state.catEars.rank = .alleyCat
        let model = makeModel(state)
        model.start()
        model.setProcrastinating(true)

        run(model, seconds: 120)

        XCTAssertEqual(model.rank, .alleyCat)
        XCTAssertTrue(events.isEmpty)
    }

    func testFirstRankIsAlwaysEKittenEvenWithBankedMinutes() {
        var state = StoredAppState.safeDefaults
        state.catEars.procrastinationSeconds = 200 * 60
        let model = makeModel(state)
        discord.observation = visibleIdle
        model.start()

        run(model, seconds: 20 * 60)

        XCTAssertEqual(events.map(\.rank), [.eKitten])
        XCTAssertEqual(model.rank, .eKitten)
    }

    func testRankIsSavedBeforeTheCeremonyRuns() {
        let model = makeModel()
        discord.observation = visibleIdle
        var savedRankAtCeremony: Rank?
        let observing = CatEarsModel(
            appModel: appModel,
            discord: discord,
            now: { [unowned self] in self.clock },
            scheduleTicks: { _, _ in {} },
            onRankUp: { [unowned self] _ in savedRankAtCeremony = self.store.saved.last?.catEars.rank }
        )
        _ = model
        observing.start()
        run(observing, seconds: 20 * 60)

        XCTAssertEqual(savedRankAtCeremony, .eKitten)
    }
}
