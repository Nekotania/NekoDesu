import Foundation

enum RichPresenceConfiguration {
    /// The Application ID of NekoDesu's Discord application, from
    /// discord.com/developers. Rich Presence stays inert while this is empty.
    static let clientID = "1569963809081270292"
}

/// What Discord is asked to show on the user's profile.
struct PresenceActivity: Equatable {
    /// First line: the rank name.
    var details: String
    /// Second line.
    var state: String
    /// Discord shows the time elapsed since this moment.
    var startedAt: Date
}

enum RichPresencePolicy {
    /// Presence is shown only when the user opted in, holds a rank, and has
    /// the procrastination toggle on. Otherwise nothing is sent.
    static func activity(
        enabled: Bool,
        rank: Rank?,
        procrastinatingSince: Date?
    ) -> PresenceActivity? {
        guard enabled, let rank, let procrastinatingSince,
              let rankName = RankTable.entry(for: rank)?.name else { return nil }
        return PresenceActivity(
            details: rankName,
            state: VoiceCatalog.RichPresence.procrastinatingState,
            startedAt: procrastinatingSince
        )
    }
}
