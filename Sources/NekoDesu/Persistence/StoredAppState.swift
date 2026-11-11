import Foundation

/// The versioned, on-disk representation of everything NekoDesu persists.
///
/// Only non-sensitive state belongs here. Never add clipboard text, browser
/// page text, Discord content, or audio.
struct StoredAppState: Codable, Equatable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int = StoredAppState.currentSchemaVersion
    var preferences = Preferences()
    var catEars = CatEars()

    struct Preferences: Codable, Equatable {
        var discordDaddyModeCopyEnabled = false
        /// Opt-in: nothing is sent to Discord while this is false.
        var discordRichPresenceEnabled = false

        init() {}

        // Preferences added after a schema version shipped are optional on
        // disk, so older files keep loading with the default.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            discordDaddyModeCopyEnabled = try container.decode(Bool.self, forKey: .discordDaddyModeCopyEnabled)
            discordRichPresenceEnabled =
                try container.decodeIfPresent(Bool.self, forKey: .discordRichPresenceEnabled) ?? false
        }
    }

    struct CatEars: Codable, Equatable {
        /// Nil until the Discord ritual is complete. Stored rather than
        /// derived so a rank can never be lost.
        var rank: Rank?
        /// Rate-weighted seconds of the Discord ritual.
        var ritualSeconds: Double = 0
        /// Seconds spent with the procrastination toggle on. One point per
        /// full minute.
        var procrastinationSeconds: Double = 0
        /// Which ceremony line was selected when E-Kitten was earned.
        var ceremonyLineID: String?

        var procrastinationMinutes: Int {
            Int(procrastinationSeconds / 60)
        }
    }

    /// What a clean install starts from.
    static let safeDefaults = StoredAppState()

    var isPlausible: Bool {
        catEars.ritualSeconds.isFinite && catEars.ritualSeconds >= 0
            && catEars.procrastinationSeconds.isFinite && catEars.procrastinationSeconds >= 0
    }
}

/// Schema version 1 held preferences only.
struct StoredAppStateV1: Decodable {
    var preferences: StoredAppState.Preferences

    var migrated: StoredAppState {
        var state = StoredAppState.safeDefaults
        state.preferences = preferences
        return state
    }
}
