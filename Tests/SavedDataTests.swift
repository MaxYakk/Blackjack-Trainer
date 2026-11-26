import Foundation
import Testing
@testable import BlackjackTrainer

// Saved-progress regressions: one bad value must not wipe everything, an
// unreadable save is backed up before anything overwrites it, and the daily
// challenge can't be re-run for a fresh "first" score.

@MainActor
struct SavedDataTests {

    // MARK: Fix 5 — tolerant loading, backup, schema version

    @Test func oneBadValueOnlyCostsThatValue() throws {
        let store = TestDefaults()
        let json = """
        {
          "handsPlayed": 12,
          "bankroll": "lots",
          "strategyTotal": 40,
          "strategyCorrect": 31,
          "spots": {"H16v10": {"correct": 3, "total": 5}, "BAD": "x", "S18v9": {"total": 4}},
          "days": {"2026-01-01": {"strategyCorrect": "oops", "strategyTotal": 4}},
          "challenges": {"2026-01-02": {"score": 7, "total": 10}, "2026-01-03": 5},
          "mistakeChoices": {"H16v10": {"Stand": 2, "Hit": "?"}, "H12v3": 9},
          "bankrollHistory": [1000, "x", 990],
          "dailyGoal": -4
        }
        """
        store.defaults.set(Data(json.utf8), forKey: Stats.storageKey)

        let stats = Stats(defaults: store.defaults)
        #expect(stats.loadIssue == nil, "A readable save with a few bad values is not an unreadable save")
        #expect(stats.data.handsPlayed == 12)
        #expect(stats.data.strategyTotal == 40 && stats.data.strategyCorrect == 31)
        #expect(stats.data.bankroll == 1000, "Unreadable bankroll falls back to the default")
        #expect(stats.data.spots["H16v10"]?.correct == 3)
        #expect(stats.data.spots["S18v9"]?.total == 4 && stats.data.spots["S18v9"]?.correct == 0)
        #expect(stats.data.spots["BAD"] == nil)
        #expect(stats.data.days["2026-01-01"]?.strategyTotal == 4)
        #expect(stats.data.days["2026-01-01"]?.date == "2026-01-01", "A missing date is repaired from its key")
        #expect(stats.data.challenges.count == 1 && stats.data.challenges["2026-01-02"]?.score == 7)
        #expect(stats.data.mistakeChoices["H16v10"] == ["Stand": 2])
        #expect(stats.data.bankrollHistory == [1000, 990])
        #expect(stats.data.dailyGoal == 20)
        #expect(stats.data.schemaVersion == StatsData.currentSchemaVersion)
        #expect(store.defaults.data(forKey: Stats.backupKey) == nil)
    }

    @Test func olderSaveWithoutNewFieldsLoads() throws {
        let store = TestDefaults()
        let json = #"{"handsPlayed": 3, "bankroll": 750, "challenges": {"2026-01-02": {"score": 9, "total": 10}}}"#
        store.defaults.set(Data(json.utf8), forKey: Stats.storageKey)
        let stats = Stats(defaults: store.defaults)
        #expect(stats.data.handsPlayed == 3 && stats.data.bankroll == 750)
        #expect(stats.data.inPlayWager == 0 && stats.data.challengesStarted.isEmpty)
        #expect(stats.data.schemaVersion == StatsData.currentSchemaVersion, "Upgraded on load")
    }

    @Test func unreadableSaveIsBackedUpBeforeStartingOver() throws {
        let store = TestDefaults()
        let garbage = Data("not json at all".utf8)
        store.defaults.set(garbage, forKey: Stats.storageKey)

        let stats = Stats(defaults: store.defaults)
        #expect(stats.loadIssue == .unreadableSaveBackedUp)
        #expect(store.defaults.data(forKey: Stats.backupKey) == garbage, "Original bytes are kept")
        #expect(stats.data.handsPlayed == 0)

        // The next save writes fresh progress, but the backup survives.
        stats.recordHandResult(.win)
        stats.flush()
        #expect(store.defaults.data(forKey: Stats.backupKey) == garbage)

        // A later failure never replaces the first (oldest, fullest) backup.
        store.defaults.set(Data("[1,2,3]".utf8), forKey: Stats.storageKey)
        _ = Stats(defaults: store.defaults)
        #expect(store.defaults.data(forKey: Stats.backupKey) == garbage)
    }

    @Test func roundTripKeepsNewFields() throws {
        var data = StatsData()
        data.inPlayWager = 15
        data.challengesStarted = ["2026-11-25"]
        data.days["2026-11-25"] = DayStat(date: "2026-11-25", strategyCorrect: 2, strategyTotal: 3)
        let decoded = try JSONDecoder().decode(StatsData.self, from: JSONEncoder().encode(data))
        #expect(decoded.inPlayWager == 15)
        #expect(decoded.challengesStarted == ["2026-11-25"])
        #expect(decoded.days["2026-11-25"]?.strategyCorrect == 2)
        #expect(decoded.schemaVersion == StatsData.currentSchemaVersion)
    }

    // MARK: Fix 8 — quitting the daily challenge midway can't buy a fresh first run

    private func totalDayDecisions(_ stats: Stats) -> Int {
        stats.data.days.values.reduce(0) { $0 + $1.strategyTotal }
    }

    @Test func quitChallengeRestartsAsPractice() {
        let store = TestDefaults()
        let dateKey = "2026-11-25"
        let stats = Stats(defaults: store.defaults)

        let first = DailyChallengeEngine(stats: stats, dateKey: dateKey)
        #expect(!first.isReplay)
        first.answer(.stand)
        #expect(totalDayDecisions(stats) == 1)
        stats.flush()   // the app goes to the background and is closed

        let relaunched = Stats(defaults: store.defaults)
        let second = DailyChallengeEngine(stats: relaunched, dateKey: dateKey)
        #expect(second.isReplay, "A restarted run has seen answers, so it's practice")
        #expect(second.isRestartOfUnfinishedRun)
        while !second.finished {
            second.answer(.hit)
            second.next()
        }
        #expect(totalDayDecisions(relaunched) == 1, "Practice answers don't count again")
        #expect(relaunched.data.challenges[dateKey] == nil, "No score recorded from a practice run")
    }

    @Test func openingWithoutAnsweringKeepsTheFirstRun() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        _ = DailyChallengeEngine(stats: stats, dateKey: "2026-11-25")
        let again = DailyChallengeEngine(stats: stats, dateKey: "2026-11-25")
        #expect(!again.isReplay, "Just looking at the screen doesn't use up the day's run")
    }

    @Test func finishedChallengeRecordsOnceAndClearsMarker() {
        let store = TestDefaults()
        let dateKey = "2026-11-25"
        let stats = Stats(defaults: store.defaults)
        let run = DailyChallengeEngine(stats: stats, dateKey: dateKey)
        while !run.finished {
            run.answer(.stand)
            run.next()
        }
        #expect(stats.data.challenges[dateKey]?.total == run.spots.count)
        #expect(!stats.data.challengesStarted.contains(dateKey))
        let replay = DailyChallengeEngine(stats: stats, dateKey: dateKey)
        #expect(replay.isReplay && !replay.isRestartOfUnfinishedRun)
    }
}
