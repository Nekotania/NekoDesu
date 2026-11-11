import XCTest
@testable import NekoDesu

final class RitualClockTests: XCTestCase {
    private let configuration = RitualConfiguration()

    private func multiplier(_ presence: DiscordPresence, _ microphone: MicrophoneActivity) -> Double {
        configuration.multiplier(for: DiscordObservation(presence: presence, microphone: microphone))
    }

    func testTwentyMinutesAtFullRate() {
        XCTAssertEqual(configuration.requiredSeconds, 20 * 60)
        XCTAssertEqual(multiplier(.visible, .idle), 1)
    }

    func testInCallIsQuarterRate() {
        XCTAssertEqual(multiplier(.visible, .inUse), 0.25)
        XCTAssertEqual(configuration.requiredSeconds / multiplier(.visible, .inUse), 80 * 60)
    }

    func testNotRunningIsPausedWhateverTheMicrophoneSays() {
        XCTAssertEqual(multiplier(.notRunning, .idle), 0)
        XCTAssertEqual(multiplier(.notRunning, .inUse), 0)
        XCTAssertEqual(multiplier(.notRunning, .unknown), 0)
    }

    func testBackgroundUsesTheConfiguredMultiplier() {
        var custom = RitualConfiguration()
        custom.backgroundMultiplier = 0.1
        let observation = DiscordObservation(presence: .background, microphone: .idle)

        XCTAssertEqual(custom.multiplier(for: observation), 0.1)
        XCTAssertLessThan(multiplier(.background, .idle), 1)
        XCTAssertGreaterThan(multiplier(.background, .idle), 0)
    }

    func testBackgroundInCallUsesTheSlowerRate() {
        XCTAssertEqual(multiplier(.background, .inUse), 0.25)
    }

    func testUnknownMicrophoneIsNotTreatedAsACall() {
        XCTAssertEqual(multiplier(.visible, .unknown), multiplier(.visible, .idle))
        XCTAssertEqual(multiplier(.background, .unknown), multiplier(.background, .idle))
    }

    /// Documented false positive: any app using a microphone looks the same
    /// as a Discord call, so the in-call rate applies.
    func testAnotherAppUsingTheMicrophoneCountsAsInCall() {
        XCTAssertEqual(multiplier(.visible, .inUse), configuration.inCallMultiplier)
    }

    func testCreditedIntervalCountsElapsedTime() {
        XCTAssertEqual(TimeAccounting.creditedInterval(from: 100, to: 105, maximumGap: 30), 5)
        // A late callback is credited for what actually elapsed.
        XCTAssertEqual(TimeAccounting.creditedInterval(from: 100, to: 122.5, maximumGap: 30), 22.5)
        XCTAssertEqual(TimeAccounting.creditedInterval(from: 100, to: 130, maximumGap: 30), 30)
    }

    func testCreditedIntervalDiscardsUnobservedTime() {
        XCTAssertEqual(TimeAccounting.creditedInterval(from: nil, to: 500, maximumGap: 30), 0)
        // Long suspension.
        XCTAssertEqual(TimeAccounting.creditedInterval(from: 100, to: 130.1, maximumGap: 30), 0)
        XCTAssertEqual(TimeAccounting.creditedInterval(from: 100, to: 100 + 8 * 3600, maximumGap: 30), 0)
        // Clock went backwards or did not move.
        XCTAssertEqual(TimeAccounting.creditedInterval(from: 100, to: 40, maximumGap: 30), 0)
        XCTAssertEqual(TimeAccounting.creditedInterval(from: 100, to: 100, maximumGap: 30), 0)
    }
}

final class DiscordActivityMonitorTests: XCTestCase {
    private func monitor(
        processID: pid_t?,
        hasWindow: Bool = false,
        microphone: MicrophoneActivity = .idle
    ) -> DiscordActivityMonitor {
        DiscordActivityMonitor(
            runningProcessID: { processID },
            hasOnScreenWindow: { _ in hasWindow },
            microphoneActivity: { microphone }
        )
    }

    func testUsesTheSpecifiedBundleIdentifier() {
        XCTAssertEqual(DiscordActivityMonitor.discordBundleIdentifier, "com.hnc.discord")
    }

    func testBundleIdentifierMatchIgnoresCaseButNotHelpers() {
        XCTAssertTrue(DiscordProbes.isDiscord(bundleIdentifier: "com.hnc.discord"))
        XCTAssertTrue(DiscordProbes.isDiscord(bundleIdentifier: "com.hnc.Discord"))
        XCTAssertFalse(DiscordProbes.isDiscord(bundleIdentifier: "com.hnc.Discord.helper"))
        XCTAssertFalse(DiscordProbes.isDiscord(bundleIdentifier: nil))
    }

    func testDiscordAbsent() {
        XCTAssertEqual(monitor(processID: nil, hasWindow: true).currentObservation().presence, .notRunning)
    }

    func testDiscordVisible() {
        XCTAssertEqual(
            monitor(processID: 42, hasWindow: true).currentObservation(),
            DiscordObservation(presence: .visible, microphone: .idle)
        )
    }

    func testDiscordRunningWithoutAVisibleWindow() {
        XCTAssertEqual(
            monitor(processID: 42, hasWindow: false, microphone: .inUse).currentObservation(),
            DiscordObservation(presence: .background, microphone: .inUse)
        )
    }

    func testAudioQueryUnavailableIsReportedAsUnknown() {
        XCTAssertEqual(
            monitor(processID: 42, hasWindow: true, microphone: .unknown).currentObservation().microphone,
            .unknown
        )
    }

    func testWindowCheckIsAskedAboutTheDiscordProcess() {
        var asked: [pid_t] = []
        let monitor = DiscordActivityMonitor(
            runningProcessID: { 4242 },
            hasOnScreenWindow: { asked.append($0); return true },
            microphoneActivity: { .idle }
        )
        _ = monitor.currentObservation()
        XCTAssertEqual(asked, [4242])
    }
}
