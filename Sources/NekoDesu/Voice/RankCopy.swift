struct RankEntry: Equatable {
    let rank: Rank
    let name: String
    /// Total procrastination minutes needed. E-Kitten needs none: it is
    /// earned by the Discord ritual instead.
    let procrastinationMinutes: Int
    /// What the desk cat and the notification say for this rank.
    /// E-Kitten has none here; it uses a ceremony line from `CeremonyCopy`.
    let rankUpLine: String?
}

/// The one ordered rank table: lowest rank first.
enum RankTable {
    static let entries: [RankEntry] = [
        RankEntry(rank: .eKitten, name: "E-Kitten", procrastinationMinutes: 0, rankUpLine: nil),
        RankEntry(
            rank: .strayCat, name: "Stray Cat", procrastinationMinutes: 30,
            rankUpLine: "Stray Cat. Thirty minutes of not doing the thing. I'm so proud I could cough up a hairball."
        ),
        RankEntry(
            rank: .streetCat, name: "Street Cat", procrastinationMinutes: 90,
            rankUpLine: "Street Cat. You've made procrastination a place. It has a smell."
        ),
        RankEntry(
            rank: .alleyCat, name: "Alley Cat", procrastinationMinutes: 180,
            rankUpLine: "Alley Cat. At this point the task is a rumor."
        ),
        RankEntry(
            rank: .houseCat, name: "House Cat", procrastinationMinutes: 360,
            rankUpLine: "House Cat. You live here now. The work does not."
        ),
        RankEntry(
            rank: .greatOldCat, name: "The Great Old Cat", procrastinationMinutes: 720,
            rankUpLine: "The Great Old Cat. I sat on this corner the entire time. You did the rest, which was nothing."
        ),
    ]

    static func entry(for rank: Rank, in table: [RankEntry] = entries) -> RankEntry? {
        table.first { $0.rank == rank }
    }

    static func index(of rank: Rank, in table: [RankEntry] = entries) -> Int? {
        table.firstIndex { $0.rank == rank }
    }
}

enum RankCopy {
    static func notificationTitle(rankName: String) -> String {
        "New rank: \(rankName)"
    }
}
