import Foundation

enum CertificateState: Equatable {
    case missing
    case available
    /// The last attempt to create it failed; the rank is unaffected.
    case failed
}

/// Everything that happens around a rank-up besides the rank itself. Each
/// step is best effort and independent, so one failing cannot block another.
@MainActor
final class RankCeremony: ObservableObject {
    @Published private(set) var certificateState: CertificateState = .missing
    @Published private(set) var notificationAuthorization: NotificationAuthorization = .notDetermined

    private let notifications: NotificationService
    private let certificates: CertificateStore
    private let playEarAnimation: () -> Void
    private let armDeskCat: () -> Void

    init(
        notifications: NotificationService,
        certificates: CertificateStore,
        playEarAnimation: @escaping () -> Void,
        armDeskCat: @escaping () -> Void
    ) {
        self.notifications = notifications
        self.certificates = certificates
        self.playEarAnimation = playEarAnimation
        self.armDeskCat = armDeskCat
    }

    /// Called exactly once per rank-up, after the rank has been saved.
    func perform(_ event: RankUpEvent) {
        playEarAnimation()
        armDeskCat()
        notifications.post(
            identifier: "rank-\(event.rank.rawValue)",
            title: RankCopy.notificationTitle(rankName: event.rankName),
            body: event.line
        )
        if event.rank == .eKitten {
            createCertificate()
        }
    }

    func createCertificate() {
        do {
            try certificates.generate()
            certificateState = .available
        } catch {
            certificateState = .failed
        }
    }

    func revealCertificate() {
        guard certificates.exists() else {
            certificateState = .missing
            return
        }
        certificates.revealInFinder()
    }

    /// Re-reads what can change outside the app: the certificate file and
    /// the notification permission.
    func refresh() async {
        if certificates.exists() {
            certificateState = .available
        } else if certificateState == .available {
            certificateState = .missing
        }
        notificationAuthorization = await notifications.authorization()
    }

    func requestNotificationAuthorization() async {
        notificationAuthorization = await notifications.requestAuthorization()
    }
}
