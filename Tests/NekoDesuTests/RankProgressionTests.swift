import XCTest
@testable import NekoDesu

final class RankProgressionTests: XCTestCase {
    func testTableListsSixRanksInOrderWithSpecifiedThresholds() {
        XCTAssertEqual(
            RankTable.entries.map(\.rank),
            [.eKitten, .strayCat, .streetCat, .alleyCat, .houseCat, .greatOldCat]
        )
        XCTAssertEqual(RankTable.entries.map(\.procrastinationMinutes), [0, 30, 90, 180, 360, 720])
        XCTAssertEqual(Set(RankTable.entries.map(\.rank)).count, Rank.allCases.count)
    }

    func testNoRankBeforeTheRitualIsComplete() {
        XCTAssertNil(RankProgression.rank(ritualComplete: false, procrastinationMinutes: 0))
        XCTAssertNil(RankProgression.rank(ritualComplete: false, procrastinationMinutes: 10_000))
    }

    func testEveryThresholdAndItsBoundary() {
        let expectations: [(minutes: Int, rank: Rank)] = [
            (0, .eKitten), (29, .eKitten),
            (30, .strayCat), (89, .strayCat),
            (90, .streetCat), (179, .streetCat),
            (180, .alleyCat), (359, .alleyCat),
            (360, .houseCat), (719, .houseCat),
            (720, .greatOldCat), (100_000, .greatOldCat),
        ]
        for expectation in expectations {
            XCTAssertEqual(
                RankProgression.rank(ritualComplete: true, procrastinationMinutes: expectation.minutes),
                expectation.rank,
                "\(expectation.minutes) minutes"
            )
        }
    }

    func testHigherNeverDemotes() {
        XCTAssertEqual(RankProgression.higher(.alleyCat, .strayCat), .alleyCat)
        XCTAssertEqual(RankProgression.higher(.strayCat, .alleyCat), .alleyCat)
        XCTAssertEqual(RankProgression.higher(.houseCat, nil), .houseCat)
        XCTAssertEqual(RankProgression.higher(nil, .eKitten), .eKitten)
        XCTAssertNil(RankProgression.higher(nil, nil))
    }

    func testRitualProgressIsClamped() {
        XCTAssertEqual(
            RankProgression.progress(rank: nil, ritualFraction: 0.25, procrastinationMinutes: 0),
            .ritual(fraction: 0.25)
        )
        XCTAssertEqual(
            RankProgression.progress(rank: nil, ritualFraction: 3, procrastinationMinutes: 0),
            .ritual(fraction: 1)
        )
    }

    func testProgressBetweenThresholds() {
        XCTAssertEqual(
            RankProgression.progress(rank: .eKitten, ritualFraction: 1, procrastinationMinutes: 15),
            .towardNext(next: .strayCat, minutes: 15, minutesRequired: 30, fraction: 0.5)
        )
        // 90 → 180: 135 total minutes is halfway.
        XCTAssertEqual(
            RankProgression.progress(rank: .streetCat, ritualFraction: 1, procrastinationMinutes: 135),
            .towardNext(next: .alleyCat, minutes: 135, minutesRequired: 180, fraction: 0.5)
        )
        XCTAssertEqual(
            RankProgression.progress(rank: .strayCat, ritualFraction: 1, procrastinationMinutes: 30),
            .towardNext(next: .streetCat, minutes: 30, minutesRequired: 90, fraction: 0)
        )
    }

    func testMaximumRankHasNoNextRank() {
        XCTAssertEqual(
            RankProgression.progress(rank: .greatOldCat, ritualFraction: 1, procrastinationMinutes: 720),
            .maximumRank
        )
        XCTAssertEqual(
            RankProgression.progress(rank: .greatOldCat, ritualFraction: 1, procrastinationMinutes: 999_999),
            .maximumRank
        )
    }

    func testEveryLaterRankHasALine() {
        for entry in RankTable.entries where entry.rank != .eKitten {
            XCTAssertNotNil(entry.rankUpLine, entry.name)
        }
    }
}
