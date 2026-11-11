import Foundation

/// The versioned, on-disk representation of everything NekoDesu persists.
///
/// Only non-sensitive state belongs here. Never add clipboard text, browser
/// page text, Discord content, or audio.
struct StoredAppState: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int = StoredAppState.currentSchemaVersion
    var preferences = Preferences()

    struct Preferences: Codable, Equatable {
        var discordDaddyModeCopyEnabled = false
    }

    /// What a clean install starts from.
    static let safeDefaults = StoredAppState()
}
