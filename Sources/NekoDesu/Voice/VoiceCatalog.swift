/// The single source of truth for user-facing copy.
enum VoiceCatalog {
    enum Panel {
        static let title = "NekoDesu"
        static let quit = "Quit NekoDesu"
        static let storedStateProblem =
            "Saved progress couldn't be read or written, so NekoDesu is using defaults."
    }

    enum DeskCat {
        static let missingSpritesFallback = "Desk cat\n(no sprites yet)"
    }
}
