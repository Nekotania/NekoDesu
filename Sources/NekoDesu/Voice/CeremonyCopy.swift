struct CeremonyLine: Equatable {
    /// Persisted to remember which line was selected; do not rename.
    let id: String
    let text: String
}

enum CeremonyCopy {
    private static let firstStandardLine = CeremonyLine(
        id: "application-approved",
        text: "Congratulations. Your e-kitten application has been approved. Please collect your complimentary cat ears."
    )

    static let standardLines: [CeremonyLine] = [
        firstStandardLine,
        CeremonyLine(
            id: "paperwork-finalized",
            text: "You've been online long enough. The transformation paperwork has been finalized."
        ),
        CeremonyLine(
            id: "creature-of-the-internet",
            text: "Discord has determined that you are now legally a creature of the internet."
        ),
        CeremonyLine(
            id: "cat-distribution-system",
            text: "The cat distribution system has reviewed your application. You have been selected."
        ),
        CeremonyLine(
            id: "previous-rank-revoked",
            text: "Your previous rank has been revoked. Please familiarize yourself with your new meow-based responsibilities."
        ),
    ]

    /// The one Discord Daddy Mode line. It exists only here.
    static let discordDaddyModeLine = CeremonyLine(
        id: "discord-daddy-mode",
        text: "You're an e-kitten now. Prepare the cat ears, m'lady."
    )

    /// Lines the ceremony may pick from under the current setting.
    static func candidates(discordDaddyModeEnabled: Bool) -> [CeremonyLine] {
        discordDaddyModeEnabled ? standardLines + [discordDaddyModeLine] : standardLines
    }

    /// The line to show for a stored selection. The Discord Daddy Mode line
    /// is never returned while the setting is off, and an unknown id falls
    /// back to a standard line.
    static func line(id: String?, discordDaddyModeEnabled: Bool) -> CeremonyLine {
        candidates(discordDaddyModeEnabled: discordDaddyModeEnabled).first { $0.id == id } ?? firstStandardLine
    }

    static let certificateBody =
        "This hereby certifies that the bearer has achieved the prestigious rank of E-Kitten, "
        + "following extensive Discord-based research."
    static let certificateSignature = "Signed: The Great Old Cat."
    static let certificateFileName = "E-Kitten Certificate.png"
}
