/// User-facing copy for the panel. Rank lines are in `RankCopy`, ceremony
/// lines in `CeremonyCopy`, and privacy text in `PrivacyDisclosure`.
enum VoiceCatalog {
    enum Panel {
        static let title = "NekoDesu"
        static let quit = "Quit NekoDesu"
        static let storedStateProblem =
            "Saved progress couldn't be read or written, so NekoDesu is using defaults."
    }

    enum CatEars {
        static let unranked = "Unranked"
        static let ritualDescription =
            "The ancient en-kittening ritual."
        static let toggle = "I'm procrastinating"
        static let toggleLocked = "Unlocks once you're an E-Kitten."
        static let maximumRank = "Maximum rank reached."
        static let progressLabel = "Progress to next rank"

        static func ritualProgress(percent: Int) -> String {
            "Ritual progress: \(percent)%"
        }

        static func progress(minutes: Int, minutesRequired: Int, nextRankName: String) -> String {
            "\(minutes) of \(minutesRequired) minutes · next: \(nextRankName)"
        }

        static func ritualStatus(for observation: DiscordObservation) -> String {
            switch (observation.presence, observation.microphone) {
            case (.notRunning, _):
                return "Discord isn't running. The ritual is paused."
            case (.visible, .inUse):
                return "Discord is open and a microphone is in use. The ritual is running at the in-call rate."
            case (.visible, .idle):
                return "Discord is open. The ritual is running."
            case (.visible, .unknown):
                return "Discord is open. The ritual is running, but microphone activity couldn't be checked."
            case (.background, .unknown):
                return "Discord has no visible window. The ritual is running slowly, "
                    + "and microphone activity couldn't be checked."
            case (.background, _):
                return "Discord has no visible window. The ritual is running slowly."
            }
        }
    }

    enum Certificate {
        static let reveal = "Show Certificate in Finder"
        static let create = "Create Certificate"
        static let failed = "The certificate couldn't be created. Your rank is safe."
    }

    enum Notifications {
        static let explanation = "NekoDesu announces a new rank with a notification."
        static let allow = "Allow Notifications"
        static let denied =
            "Notifications are off for NekoDesu, so new ranks only show here. "
            + "You can allow them in System Settings."
    }

    enum Settings {
        static let discordDaddyMode = "Discord Daddy Mode"
    }

    enum RichPresence {
        static let toggle = "Discord Rich Presence"
        static let disclosure =
            "While \"I'm procrastinating\" is on, your rank and a timer are sent to Discord, "
            + "which shows them on your profile. Nothing else is sent, and nothing at all while this is off."
        static let missingClientID =
            "Not set up yet: add NekoDesu's Discord application ID in RichPresenceActivity.swift."
        static let discordUnavailable = "Discord isn't reachable right now, so nothing is being shown."
        static let rejected = "Discord refused the status. Check the application ID."
        /// Second line of the status on the Discord profile.
        static let procrastinatingState = "Procrastinating"
    }

    enum DeskCat {
        static let missingSprites = "The desk cat's art is missing from the app, so she isn't shown."
    }
}
