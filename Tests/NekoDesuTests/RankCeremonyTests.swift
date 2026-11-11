import XCTest
@testable import NekoDesu

@MainActor
final class RankCeremonyTests: XCTestCase {
    private var notifications: FakeNotifications!
    private var certificates: FakeCertificates!
    private var earAnimations = 0
    private var arms = 0

    private func makeCeremony() -> RankCeremony {
        notifications = FakeNotifications()
        certificates = FakeCertificates()
        return RankCeremony(
            notifications: notifications,
            certificates: certificates,
            playEarAnimation: { [unowned self] in self.earAnimations += 1 },
            armDeskCat: { [unowned self] in self.arms += 1 }
        )
    }

    private let eKitten = RankUpEvent(rank: .eKitten, rankName: "E-Kitten", line: "ceremony line")
    private let strayCat = RankUpEvent(rank: .strayCat, rankName: "Stray Cat", line: "stray line")

    func testEKittenCeremonyAnimatesArmsNotifiesAndCreatesTheCertificate() {
        let ceremony = makeCeremony()

        ceremony.perform(eKitten)

        XCTAssertEqual(earAnimations, 1)
        XCTAssertEqual(arms, 1)
        XCTAssertEqual(notifications.posted.count, 1)
        XCTAssertEqual(notifications.posted.first?.title, "New rank: E-Kitten")
        XCTAssertEqual(notifications.posted.first?.body, "ceremony line")
        XCTAssertEqual(certificates.generateCount, 1)
        XCTAssertEqual(ceremony.certificateState, .available)
    }

    func testLaterRankUpsDoNotCreateACertificate() {
        let ceremony = makeCeremony()

        ceremony.perform(strayCat)

        XCTAssertEqual(earAnimations, 1)
        XCTAssertEqual(arms, 1)
        XCTAssertEqual(notifications.posted.first?.body, "stray line")
        XCTAssertEqual(notifications.posted.first?.identifier, "rank-strayCat")
        XCTAssertEqual(certificates.generateCount, 0)
    }

    func testCertificateFailureIsReportedAndCanBeRetried() {
        let ceremony = makeCeremony()
        certificates.generateError = CocoaError(.fileWriteNoPermission)

        ceremony.perform(eKitten)
        XCTAssertEqual(ceremony.certificateState, .failed)
        // The other steps still happened.
        XCTAssertEqual(notifications.posted.count, 1)
        XCTAssertEqual(arms, 1)

        certificates.generateError = nil
        ceremony.createCertificate()
        XCTAssertEqual(ceremony.certificateState, .available)
    }

    func testRevealOnlyWhenTheFileExists() {
        let ceremony = makeCeremony()
        ceremony.perform(eKitten)

        ceremony.revealCertificate()
        XCTAssertEqual(certificates.revealCount, 1)

        certificates.fileExists = false
        ceremony.revealCertificate()
        XCTAssertEqual(certificates.revealCount, 1)
        XCTAssertEqual(ceremony.certificateState, .missing)
    }

    func testRefreshPicksUpAnExistingCertificateAndPermission() async {
        let ceremony = makeCeremony()
        certificates.fileExists = true
        notifications.currentAuthorization = .denied

        await ceremony.refresh()

        XCTAssertEqual(ceremony.certificateState, .available)
        XCTAssertEqual(ceremony.notificationAuthorization, .denied)
    }

    func testRequestingNotificationPermissionUpdatesTheState() async {
        let ceremony = makeCeremony()

        await ceremony.requestNotificationAuthorization()

        XCTAssertEqual(ceremony.notificationAuthorization, .authorized)
    }

    func testCertificateIsWrittenAsAPNG() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NekoDesuTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileCertificateStore(
            fileURL: directory.appendingPathComponent("Certificates/\(CeremonyCopy.certificateFileName)")
        )
        XCTAssertFalse(store.exists())

        try store.generate()

        XCTAssertTrue(store.exists())
        let image = try XCTUnwrap(NSBitmapImageRep(data: Data(contentsOf: store.fileURL)))
        XCTAssertEqual(image.pixelsWide, CertificateRenderer.pixelSize.width)
        XCTAssertEqual(image.pixelsHigh, CertificateRenderer.pixelSize.height)
    }

    func testCertificateTextIsVerbatim() {
        XCTAssertEqual(
            CeremonyCopy.certificateBody,
            "This hereby certifies that the bearer has achieved the prestigious rank of E-Kitten, following extensive Discord-based research."
        )
        XCTAssertEqual(CeremonyCopy.certificateSignature, "Signed: The Great Old Cat.")
    }
}
