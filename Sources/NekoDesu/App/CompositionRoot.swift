import AppKit

/// The one place where feature models and system adapters are constructed.
@MainActor
struct CompositionRoot {
    let appModel: AppModel
    let catEars: CatEarsModel
    let ceremony: RankCeremony
    let deskCat: DeskCatController
    let earAnimator: EarAnimator
    let richPresence: RichPresenceController
    private let notifications: UserNotificationService

    static func live() -> CompositionRoot {
        let appModel = AppModel(
            persistence: FilePersistenceStore(fileURL: FilePersistenceStore.defaultFileURL())
        )
        let earAnimator = EarAnimator()
        let notifications = UserNotificationService()
        let deskCat = DeskCatController(
            sprites: DeskCatConfiguration().loadSprites(),
            primaryVisibleFrame: {
                // `screens.first` is the display with the menu bar; `NSScreen.main`
                // would follow whichever screen has keyboard focus.
                NSScreen.screens.first?.visibleFrame
            }
        )
        let ceremony = RankCeremony(
            notifications: notifications,
            certificates: FileCertificateStore(fileURL: FileCertificateStore.defaultFileURL()),
            playEarAnimation: { earAnimator.play() },
            armDeskCat: { deskCat.arm() }
        )
        let catEars = CatEarsModel(
            appModel: appModel,
            discord: DiscordActivityMonitor(),
            onRankUp: { ceremony.perform($0) }
        )
        deskCat.latestLine = { [weak catEars] in catEars?.latestLine }

        let clientID = RichPresenceConfiguration.clientID
        let richPresence = RichPresenceController(
            appModel: appModel,
            catEars: catEars,
            transport: clientID.isEmpty ? nil : DiscordIPCTransport(clientID: clientID)
        )

        return CompositionRoot(
            appModel: appModel,
            catEars: catEars,
            ceremony: ceremony,
            deskCat: deskCat,
            earAnimator: earAnimator,
            richPresence: richPresence,
            notifications: notifications
        )
    }

    /// Starts everything that observes the system or shows on screen.
    func start() {
        notifications.activate()
        deskCat.show()
        catEars.start()
        richPresence.start()
    }

    func stop() {
        richPresence.stop()
        catEars.stop()
        deskCat.hide()
    }
}
