import Foundation

enum DiscordPresence: Equatable {
    case notRunning
    case visible
    /// Running with no on-screen window: minimized, hidden, or on another Space.
    case background
}

enum MicrophoneActivity: Equatable {
    case idle
    /// Some app is using an input device. This does not prove it is Discord.
    case inUse
    /// The audio system could not be queried.
    case unknown
}

struct DiscordObservation: Equatable {
    var presence: DiscordPresence
    var microphone: MicrophoneActivity
}

struct RitualConfiguration: Equatable {
    /// Full-rate seconds needed for E-Kitten: 20 minutes.
    var requiredSeconds: TimeInterval = 20 * 60
    /// 20 minutes becomes 80 while a microphone is in use.
    var inCallMultiplier: Double = 0.25
    /// PLACEHOLDER: the spec only says "slower" (decision D-01).
    var backgroundMultiplier: Double = 0.5

    /// How fast ritual time accrues for an observation; 0 means paused.
    /// An unknown microphone state is never treated as a call.
    func multiplier(for observation: DiscordObservation) -> Double {
        let presenceMultiplier: Double
        switch observation.presence {
        case .notRunning: return 0
        case .visible: presenceMultiplier = 1
        case .background: presenceMultiplier = backgroundMultiplier
        }
        // Background and in a call at once is unspecified (decision D-08);
        // the slower of the two applies.
        return observation.microphone == .inUse
            ? min(presenceMultiplier, inCallMultiplier)
            : presenceMultiplier
    }
}

enum TimeAccounting {
    /// Seconds to credit between two readings of a monotonic clock.
    ///
    /// A gap longer than `maximumGap` means the app was not observing (sleep,
    /// suspension, a stalled run loop), so the whole interval is discarded
    /// rather than guessed at. Backwards readings are discarded too.
    static func creditedInterval(
        from previous: TimeInterval?,
        to now: TimeInterval,
        maximumGap: TimeInterval
    ) -> TimeInterval {
        guard let previous else { return 0 }
        let elapsed = now - previous
        guard elapsed > 0, elapsed <= maximumGap else { return 0 }
        return elapsed
    }
}
