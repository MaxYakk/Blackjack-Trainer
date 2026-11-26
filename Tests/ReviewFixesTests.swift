import Testing
import Foundation
@testable import BlackjackTrainer

@MainActor
struct ReviewFixesTests {
    private func trophy(_ stats: Stats, _ id: String) -> Achievement? {
        stats.achievements.first { $0.id == id }
    }

    // MARK: 1. Earned trophies stay earned

    @Test func accuracyTrophyStaysUnlockedWhenAccuracyDips() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        for _ in 0..<50 { stats.recordQuiz(correct: true, streak: 1, spotKey: nil) }
        #expect(trophy(stats, "sharp")?.unlocked == true)
        let before = stats.achievements.filter(\.unlocked).count

        for _ in 0..<20 { stats.recordQuiz(correct: false, streak: 0, spotKey: nil) }
        #expect(stats.overallStrategyCorrect * 10 < stats.overallStrategyTotal * 9)
        #expect(trophy(stats, "sharp")?.unlocked == true, "Sharp must not un-earn")
        #expect(stats.achievements.filter(\.unlocked).count >= before)
    }

    @Test func keepingEarnedUnlocksAnyDatedTrophyIncludingUntrackedMarker() {
        let live = Achievements.all(from: Achievements.Inputs())
        let kept = Achievements.keepingEarned(live, dates: ["surgeon": "", "sharp": "2026-11-01"])
        #expect(kept.first { $0.id == "surgeon" }?.unlocked == true)
        #expect(kept.first { $0.id == "sharp" }?.unlocked == true)
        #expect(kept.first { $0.id == "century" }?.unlocked == false)
    }

    @Test func resetClearsKeptTrophies() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        for _ in 0..<50 { stats.recordQuiz(correct: true, streak: 1, spotKey: nil) }
        stats.resetAll()
        #expect(stats.achievements.allSatisfy { !$0.unlocked })
    }

    // MARK: 2. Daily Challenge result saved on the last answer

    @Test func challengeScoreIsSavedWhenTheTenthAnswerIsGraded() {
        let store = TestDefaults()
        let key = "2026-11-25"
        let stats = Stats(defaults: store.defaults)
        let run = DailyChallengeEngine(stats: stats, dateKey: key, today: { key })
        while run.index + 1 < run.spots.count {
            run.answer(.stand)
            run.next()
        }
        run.answer(.stand)
        #expect(!run.finished)
        #expect(stats.data.challenges[key]?.total == run.spots.count)
        #expect(stats.data.challenges[key]?.score == run.score)
        #expect(!stats.data.challengesStarted.contains(key))
        run.next()
        #expect(run.finished)
    }

    @Test func practiceReplayNeverOverwritesTheSavedScore() {
        let store = TestDefaults()
        let key = "2026-11-25"
        let stats = Stats(defaults: store.defaults)
        let first = DailyChallengeEngine(stats: stats, dateKey: key, today: { key })
        while !first.finished { first.answer(.stand); first.next() }
        let saved = stats.data.challenges[key]
        let replay = DailyChallengeEngine(stats: stats, dateKey: key, today: { key })
        while !replay.finished { replay.answer(.stand); replay.next() }
        #expect(stats.data.challenges[key]?.score == saved?.score)
    }

    // MARK: 3. Trophy dates

    @Test func trophiesEarnedAfterResetGetTodaysDateNotTheUntrackedMarker() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        stats.recordQuiz(correct: true, streak: 1, spotKey: nil)
        stats.resetAll()
        stats.recordQuiz(correct: true, streak: 1, spotKey: nil)
        #expect(stats.data.achievementDates["first-steps"] == stats.todayDateKey)
    }

    @Test func trophyIsDatedWhenEarnedWithoutVisitingProgress() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        stats.recordHandResult(.win)
        #expect(stats.data.achievementDates["first-hand"] == stats.todayDateKey)
    }

    // MARK: 6. Count drill result uses the drill's own shoe

    @Test func revealedCountDoesNotChangeWhenDecksSettingChanges() async {
        let store = TestDefaults()
        let engine = CountDrillEngine(stats: Stats(defaults: store.defaults), defaults: store.defaults)
        engine.numDecks = 2
        engine.cardsPerDrill = 5
        engine.speedSeconds = 0.01
        engine.start()
        for _ in 0..<200 where engine.phase != .guessing {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(engine.phase == .guessing)
        engine.submitGuess(engine.runningCount)
        let decks = engine.decksRemaining, trueCount = engine.trueCount
        #expect(decks == (Double(2 * 52) - 5) / 52)

        engine.numDecks = 8
        #expect(engine.decksRemaining == decks)
        #expect(engine.trueCount == trueCount)
    }

    // MARK: 7. One percent rounding

    @Test func percentRoundsToNearestEverywhere() {
        #expect(Achievements.roundedPercent(29.0 / 100.0) == 29)
        #expect(Achievements.roundedPercent(0.995) == 100)
        #expect(Achievements.roundedPercent(0.904) == 90)
        let text = Achievements.all(from: Achievements.Inputs(decisions: 100, decisionsCorrect: 89))
            .first { $0.id == "sharp" }?.progressText
        #expect(text == "89%/90%")
    }
}
