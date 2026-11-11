enum RankProgress: Equatable {
    /// No rank yet: progress through the Discord ritual, 0...1.
    case ritual(fraction: Double)
    /// `minutes` and `minutesRequired` are totals, not per-rank amounts.
    case towardNext(next: Rank, minutes: Int, minutesRequired: Int, fraction: Double)
    case maximumRank
}

/// Pure rank rules. Nothing here reads the clock or stored state.
enum RankProgression {
    /// The rank the given progress entitles the user to, ignoring any rank
    /// already held.
    static func rank(
        ritualComplete: Bool,
        procrastinationMinutes: Int,
        table: [RankEntry] = RankTable.entries
    ) -> Rank? {
        guard ritualComplete else { return nil }
        return table.last { $0.procrastinationMinutes <= procrastinationMinutes }?.rank
    }

    /// Ranks only increase: returns whichever of the two is higher.
    static func higher(_ current: Rank?, _ candidate: Rank?, table: [RankEntry] = RankTable.entries) -> Rank? {
        guard let candidate, let candidateIndex = RankTable.index(of: candidate, in: table) else { return current }
        guard let current, let currentIndex = RankTable.index(of: current, in: table) else { return candidate }
        return candidateIndex > currentIndex ? candidate : current
    }

    static func progress(
        rank: Rank?,
        ritualFraction: Double,
        procrastinationMinutes: Int,
        table: [RankEntry] = RankTable.entries
    ) -> RankProgress {
        guard let rank, let index = RankTable.index(of: rank, in: table) else {
            return .ritual(fraction: clampedFraction(ritualFraction))
        }
        guard index + 1 < table.count else { return .maximumRank }

        let current = table[index]
        let next = table[index + 1]
        let span = next.procrastinationMinutes - current.procrastinationMinutes
        let into = procrastinationMinutes - current.procrastinationMinutes
        let fraction = span > 0 ? clampedFraction(Double(into) / Double(span)) : 1
        return .towardNext(
            next: next.rank,
            minutes: max(0, procrastinationMinutes),
            minutesRequired: next.procrastinationMinutes,
            fraction: fraction
        )
    }

    private static func clampedFraction(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
