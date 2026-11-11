/// What a click on the desk cat does. Only a rank-up arms it; nothing here
/// can create an achievement.
struct DeskCatSpeech: Equatable {
    /// Set by a rank-up, consumed by the next click that opens the bubble.
    private(set) var isArmed = false
    /// The line in the open bubble, or nil while it is closed.
    private(set) var visibleLine: String?

    mutating func arm() {
        isArmed = true
    }

    /// - Parameter latestLine: The line for the latest achievement, or nil
    ///   before the first one, in which case a click does nothing.
    mutating func click(latestLine: String?) {
        if visibleLine != nil {
            visibleLine = nil
            return
        }
        guard let latestLine else { return }
        visibleLine = latestLine
        isArmed = false
    }

    mutating func dismiss() {
        visibleLine = nil
    }
}
