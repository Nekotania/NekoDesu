import Combine
import Foundation

/// Keeps Discord's Rich Presence in step with the procrastination toggle.
/// Sends nothing unless the user has turned the feature on.
@MainActor
final class RichPresenceController: ObservableObject {
    /// Result of the latest attempt; nil when nothing has been sent.
    @Published private(set) var lastDelivery: RichPresenceDelivery?

    /// How often a shown presence is re-sent, which restores it after Discord
    /// restarts or was not running when the toggle went on.
    let refreshInterval: TimeInterval = 15

    private let appModel: AppModel
    private let catEars: CatEarsModel
    private let transport: RichPresenceTransport?
    private let now: () -> Date
    private let scheduleRefresh: CatEarsModel.TickScheduler

    private var subscription: AnyCancellable?
    private var cancelRefresh: (() -> Void)?
    private var procrastinatingSince: Date?
    private var shown: PresenceActivity?

    /// - Parameter transport: Nil when no Discord application ID is configured.
    init(
        appModel: AppModel,
        catEars: CatEarsModel,
        transport: RichPresenceTransport?,
        now: @escaping () -> Date = Date.init,
        scheduleRefresh: CatEarsModel.TickScheduler? = nil
    ) {
        self.appModel = appModel
        self.catEars = catEars
        self.transport = transport
        self.now = now
        self.scheduleRefresh = scheduleRefresh ?? CatEarsModel.timerScheduler
    }

    var isConfigured: Bool { transport != nil }
    var isEnabled: Bool { appModel.stored.preferences.discordRichPresenceEnabled }

    func setEnabled(_ enabled: Bool) {
        appModel.update { $0.preferences.discordRichPresenceEnabled = enabled }
    }

    func start() {
        guard subscription == nil else { return }
        // `@Published` emits before the property changes, so the new values
        // are taken from the publishers rather than read back.
        subscription = appModel.$stored
            .combineLatest(catEars.$isProcrastinating)
            .sink { [weak self] stored, isProcrastinating in
                self?.reconcile(stored: stored, isProcrastinating: isProcrastinating)
            }
    }

    func stop() {
        subscription = nil
        stopRefreshing()
        shown = nil
        transport?.shutdown()
    }

    private func reconcile(stored: StoredAppState, isProcrastinating: Bool) {
        if !isProcrastinating {
            procrastinatingSince = nil
        } else if procrastinatingSince == nil {
            procrastinatingSince = now()
        }

        let wanted = RichPresencePolicy.activity(
            enabled: stored.preferences.discordRichPresenceEnabled,
            rank: stored.catEars.rank,
            procrastinatingSince: procrastinatingSince
        )
        guard wanted != shown else { return }
        shown = wanted
        send(wanted)

        if wanted == nil {
            stopRefreshing()
            lastDelivery = nil
        } else if cancelRefresh == nil {
            cancelRefresh = scheduleRefresh(refreshInterval) { [weak self] in
                guard let self else { return }
                self.send(self.shown)
            }
        }
    }

    private func send(_ activity: PresenceActivity?) {
        transport?.update(activity) { [weak self] delivery in
            // A late reply about a presence that is no longer wanted is stale.
            guard let self, self.shown != nil else { return }
            self.lastDelivery = delivery
        }
    }

    private func stopRefreshing() {
        cancelRefresh?()
        cancelRefresh = nil
    }
}
