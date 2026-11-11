import XCTest
@testable import NekoDesu

final class FakeRichPresenceTransport: RichPresenceTransport {
    var delivery: RichPresenceDelivery = .delivered
    private(set) var updates: [PresenceActivity?] = []
    private(set) var shutdownCount = 0

    func update(_ activity: PresenceActivity?, completion: @escaping @MainActor (RichPresenceDelivery) -> Void) {
        updates.append(activity)
        let delivery = self.delivery
        MainActor.assumeIsolated { completion(delivery) }
    }

    func shutdown() { shutdownCount += 1 }
}

final class DiscordIPCTests: XCTestCase {
    func testFrameIsLittleEndianOpcodeThenLengthThenPayload() {
        let payload = Data(#"{"v":1}"#.utf8)

        let frame = DiscordIPCFrame.encode(.frame, payload: payload)

        XCTAssertEqual([UInt8](frame.prefix(8)), [1, 0, 0, 0, 7, 0, 0, 0])
        XCTAssertEqual(frame.dropFirst(8), payload)
    }

    func testHeaderRoundTripsAndRejectsNonsense() {
        let frame = DiscordIPCFrame.encode(.ping, payload: Data(count: 300))
        let header = DiscordIPCFrame.decodeHeader(frame.prefix(8))

        XCTAssertEqual(header?.opcode, 3)
        XCTAssertEqual(header?.length, 300)
        XCTAssertNil(DiscordIPCFrame.decodeHeader(Data([1, 0, 0])))
        // Negative and absurd lengths.
        XCTAssertNil(DiscordIPCFrame.decodeHeader(Data([1, 0, 0, 0, 0xFF, 0xFF, 0xFF, 0xFF])))
        XCTAssertNil(DiscordIPCFrame.decodeHeader(Data([1, 0, 0, 0, 0, 0, 0, 0x7F])))
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testHandshakeCarriesVersionAndClientID() throws {
        let handshake = try object(DiscordIPCMessages.handshake(clientID: "1234"))

        XCTAssertEqual(handshake["v"] as? Int, 1)
        XCTAssertEqual(handshake["client_id"] as? String, "1234")
    }

    func testSetActivityContainsOnlyRankStateAndStartTime() throws {
        let activity = PresenceActivity(
            details: "Stray Cat",
            state: "Procrastinating",
            startedAt: Date(timeIntervalSince1970: 1_800_000_000.9)
        )

        let message = try object(DiscordIPCMessages.setActivity(activity, processID: 77, nonce: "n"))
        let arguments = try XCTUnwrap(message["args"] as? [String: Any])
        let sent = try XCTUnwrap(arguments["activity"] as? [String: Any])

        XCTAssertEqual(message["cmd"] as? String, "SET_ACTIVITY")
        XCTAssertEqual(message["nonce"] as? String, "n")
        XCTAssertEqual(arguments["pid"] as? Int, 77)
        XCTAssertEqual(Set(sent.keys), ["details", "state", "timestamps"])
        XCTAssertEqual(sent["details"] as? String, "Stray Cat")
        XCTAssertEqual(sent["state"] as? String, "Procrastinating")
        XCTAssertEqual((sent["timestamps"] as? [String: Any])?["start"] as? Int, 1_800_000_000)
    }

    func testClearingOmitsTheActivity() throws {
        let message = try object(DiscordIPCMessages.setActivity(nil, processID: 77, nonce: "n"))
        let arguments = try XCTUnwrap(message["args"] as? [String: Any])

        XCTAssertEqual(Set(arguments.keys), ["pid"])
    }

    func testErrorRepliesAreRecognized() {
        XCTAssertTrue(DiscordIPCMessages.isError(Data(#"{"cmd":"SET_ACTIVITY","evt":"ERROR","data":{"code":4000}}"#.utf8)))
        XCTAssertFalse(DiscordIPCMessages.isError(Data(#"{"cmd":"SET_ACTIVITY","evt":null,"data":{}}"#.utf8)))
        XCTAssertFalse(DiscordIPCMessages.isError(Data("garbage".utf8)))
    }

    func testSocketPathsCoverTenSlotsInTheTemporaryDirectory() {
        let paths = DiscordIPCTransport.socketPaths(temporaryDirectory: "/tmp/x/")

        XCTAssertEqual(paths.count, 10)
        XCTAssertEqual(paths.first, "/tmp/x/discord-ipc-0")
        XCTAssertEqual(paths.last, "/tmp/x/discord-ipc-9")
    }

    func testConnectingToAMissingSocketFailsCleanly() {
        XCTAssertNil(UnixSocket(path: "/tmp/nekodesu-no-such-socket-\(UUID().uuidString)"))
        XCTAssertNil(UnixSocket(path: String(repeating: "x", count: 500)))
    }

    func testPolicyRequiresOptInRankAndAnActiveToggle() {
        let since = Date(timeIntervalSince1970: 100)

        XCTAssertNil(RichPresencePolicy.activity(enabled: false, rank: .strayCat, procrastinatingSince: since))
        XCTAssertNil(RichPresencePolicy.activity(enabled: true, rank: nil, procrastinatingSince: since))
        XCTAssertNil(RichPresencePolicy.activity(enabled: true, rank: .strayCat, procrastinatingSince: nil))
        XCTAssertEqual(
            RichPresencePolicy.activity(enabled: true, rank: .strayCat, procrastinatingSince: since),
            PresenceActivity(details: "Stray Cat", state: "Procrastinating", startedAt: since)
        )
    }
}

@MainActor
final class RichPresenceControllerTests: XCTestCase {
    private var appModel: AppModel!
    private var catEars: CatEarsModel!
    private var transport: FakeRichPresenceTransport!
    private var refresh: (() -> Void)?
    private var refreshCancelled = 0
    private var date = Date(timeIntervalSince1970: 5_000)

    private func makeController(
        enabled: Bool,
        rank: Rank? = .eKitten,
        minutes: Double = 0,
        configured: Bool = true
    ) -> RichPresenceController {
        var state = StoredAppState.safeDefaults
        state.preferences.discordRichPresenceEnabled = enabled
        state.catEars.rank = rank
        state.catEars.procrastinationSeconds = minutes * 60
        appModel = AppModel(persistence: FakePersistenceStore(state: state))
        catEars = CatEarsModel(
            appModel: appModel,
            discord: FakeDiscord(),
            now: { 0 },
            scheduleTicks: { _, _ in {} },
            onRankUp: { _ in }
        )
        transport = FakeRichPresenceTransport()
        let controller = RichPresenceController(
            appModel: appModel,
            catEars: catEars,
            transport: configured ? transport : nil,
            now: { [unowned self] in self.date },
            scheduleRefresh: { [unowned self] _, action in
                self.refresh = { action() }
                return { self.refreshCancelled += 1; self.refresh = nil }
            }
        )
        controller.start()
        return controller
    }

    func testNothingIsSentWhileTheFeatureIsOff() {
        let controller = makeController(enabled: false)

        catEars.setProcrastinating(true)
        catEars.setProcrastinating(false)

        XCTAssertTrue(transport.updates.isEmpty)
        XCTAssertNil(controller.lastDelivery)
        XCTAssertNil(refresh)
    }

    func testNothingIsSentWhileNotProcrastinating() {
        let controller = makeController(enabled: true)
        defer { controller.stop() }

        XCTAssertTrue(transport.updates.isEmpty)
    }

    func testTogglingProcrastinationShowsThenClearsThePresence() {
        let controller = makeController(enabled: true, rank: .strayCat, minutes: 40)

        catEars.setProcrastinating(true)
        XCTAssertEqual(
            transport.updates,
            [PresenceActivity(details: "Stray Cat", state: "Procrastinating", startedAt: date)]
        )
        XCTAssertEqual(controller.lastDelivery, .delivered)
        XCTAssertNotNil(refresh)

        catEars.setProcrastinating(false)
        XCTAssertEqual(transport.updates.count, 2)
        XCTAssertNil(transport.updates[1])
        XCTAssertNil(refresh)
        XCTAssertNil(controller.lastDelivery)
    }

    func testProgressTicksDoNotResendAnUnchangedPresence() {
        let controller = makeController(enabled: true)
        defer { controller.stop() }
        catEars.setProcrastinating(true)

        appModel.update { $0.catEars.procrastinationSeconds += 5 }
        appModel.update { $0.catEars.procrastinationSeconds += 5 }

        XCTAssertEqual(transport.updates.count, 1)
    }

    func testRankUpUpdatesThePresenceKeepingTheStartTime() {
        let controller = makeController(enabled: true)
        defer { controller.stop() }
        catEars.setProcrastinating(true)
        let started = date
        date = date.addingTimeInterval(1_800)

        appModel.update { $0.catEars.rank = .strayCat }

        XCTAssertEqual(
            transport.updates.last,
            PresenceActivity(details: "Stray Cat", state: "Procrastinating", startedAt: started)
        )
    }

    func testTurningTheFeatureOffWhileShownClearsIt() {
        let controller = makeController(enabled: true)
        catEars.setProcrastinating(true)

        controller.setEnabled(false)

        XCTAssertEqual(transport.updates.count, 2)
        XCTAssertNil(transport.updates[1])
        XCTAssertFalse(controller.isEnabled)
    }

    func testTurningTheFeatureOnWhileProcrastinatingShowsIt() {
        let controller = makeController(enabled: false)
        catEars.setProcrastinating(true)
        XCTAssertTrue(transport.updates.isEmpty)

        controller.setEnabled(true)

        XCTAssertEqual(transport.updates.count, 1)
        XCTAssertEqual(transport.updates[0]?.details, "E-Kitten")
    }

    func testRefreshResendsTheShownPresence() {
        let controller = makeController(enabled: true)
        transport.delivery = .discordUnavailable
        catEars.setProcrastinating(true)
        XCTAssertEqual(controller.lastDelivery, .discordUnavailable)

        transport.delivery = .delivered
        refresh?()

        XCTAssertEqual(transport.updates.count, 2)
        XCTAssertEqual(transport.updates[0], transport.updates[1])
        XCTAssertEqual(controller.lastDelivery, .delivered)
    }

    func testStopShutsTheConnectionDown() {
        let controller = makeController(enabled: true)
        catEars.setProcrastinating(true)

        controller.stop()
        catEars.setProcrastinating(false)

        XCTAssertEqual(transport.shutdownCount, 1)
        XCTAssertEqual(transport.updates.count, 1)
        XCTAssertNil(refresh)
    }

    func testWithoutAnApplicationIDTheFeatureIsInert() {
        let controller = makeController(enabled: true, configured: false)

        catEars.setProcrastinating(true)

        XCTAssertFalse(controller.isConfigured)
        XCTAssertTrue(transport.updates.isEmpty)
        XCTAssertNil(controller.lastDelivery)
    }
}
