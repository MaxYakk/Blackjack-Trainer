import Foundation
import Testing
@testable import BlackjackTrainer

/// The quiz's "review missed hands" mode and the trimmed achievements list.
@MainActor
struct QuizReviewTests {
    // MARK: Spot keys map back to dealable hands

    @Test func everyChartCellHasAHandThatMapsBackToItsKey() {
        let dealers = BasicStrategy.dealerCols
        var keys: [String] = []
        for row in BasicStrategy.hard.keys { for d in dealers { keys.append("H\(row)v\(d)") } }
        for row in BasicStrategy.soft.keys { for d in dealers { keys.append("S\(row)v\(d)") } }
        for row in BasicStrategy.pairs.keys { for d in dealers { keys.append("P\(row)v\(d)") } }
        #expect(!keys.isEmpty)
        for key in keys {
            guard let spot = SpotCatalog.spot(forKey: key) else {
                Issue.record("No hand for \(key)")
                continue
            }
            #expect(SpotID.key(cards: spot.cards, dealerUp: spot.dealerRank, canSplit: spot.isPair) == key,
                    "Hand for \(key) maps to a different spot")
        }
    }

    @Test func malformedKeysHaveNoHand() {
        for key in ["", "H16", "X16v10", "H99v10", "S12v5", "P1v5", "H16vZ"] {
            #expect(SpotCatalog.spot(forKey: key) == nil, "\(key) should not make a hand")
        }
    }

    // MARK: Review queue

    @Test func queueRanksMostMissedFirstAndSkipsClearedHands() {
        let spots = ["H16v10": SpotStat(correct: 1, total: 6),
                     "H12v3": SpotStat(correct: 2, total: 6),
                     "P8v10": SpotStat(correct: 4, total: 5)]
        let choices = ["H16v10": ["Stand": 4, "Double": 1],
                       "H12v3": ["Stand": 4],
                       "P8v10": ["Stand": 1]]
        let all = ProgressMetrics.reviewQueue(spots: spots, choices: choices, streaks: [:])
        #expect(all.map(\.key) == ["H16v10", "H12v3", "P8v10"])

        // One right answer is not enough; two in a row clears the hand.
        let one = ProgressMetrics.reviewQueue(spots: spots, choices: choices, streaks: ["H16v10": 1])
        #expect(one.map(\.key).contains("H16v10"))
        let two = ProgressMetrics.reviewQueue(spots: spots, choices: choices, streaks: ["H16v10": 2])
        #expect(two.map(\.key) == ["H12v3", "P8v10"])
    }

    @Test func queueIgnoresHandsNeverMissedAndUnknownKeys() {
        let spots = ["H16v10": SpotStat(correct: 5, total: 5), "ZZ": SpotStat(correct: 0, total: 3)]
        let choices = ["ZZ": ["Hit": 3], "H12v3": [:]]
        #expect(ProgressMetrics.reviewQueue(spots: spots, choices: choices, streaks: [:]).isEmpty)
        #expect(ProgressMetrics.reviewQueue(spots: [:], choices: [:], streaks: [:]).isEmpty)
    }

    @Test func tiesBreakByLowerAccuracyThenKey() {
        let spots = ["H10v5": SpotStat(correct: 3, total: 4), "H11v5": SpotStat(correct: 1, total: 4),
                     "H12v5": SpotStat(correct: 1, total: 4)]
        let choices = ["H10v5": ["Hit": 2], "H11v5": ["Hit": 2], "H12v5": ["Hit": 2]]
        let queue = ProgressMetrics.reviewQueue(spots: spots, choices: choices, streaks: [:])
        #expect(queue.map(\.key) == ["H11v5", "H12v5", "H10v5"])
    }

    // MARK: Dealing order

    @Test func passVisitsEveryHandBeforeRepeatingAndNeverRepeatsBackToBack() {
        let queue = ["A", "B", "C"]
        var served = Set<String>()
        var last: String?
        var order: [String] = []
        for _ in 0..<6 {
            let pick = ProgressMetrics.nextReviewKey(queue: queue, served: served, last: last)!
            order.append(pick.key)
            served = pick.served
            last = pick.key
        }
        #expect(order.prefix(3) == ["A", "B", "C"], "Most missed first, each once per pass")
        #expect(zip(order, order.dropFirst()).allSatisfy { $0 != $1 })
    }

    @Test func singleHandRepeatsAndEmptyQueueDealsNothing() {
        let pick = ProgressMetrics.nextReviewKey(queue: ["A"], served: ["A"], last: "A")
        #expect(pick?.key == "A")
        #expect(ProgressMetrics.nextReviewKey(queue: [], served: [], last: nil) == nil)
    }

    // MARK: Streaks in Stats

    @Test func twoRightInARowClearsAMissedHandAndAMissBringsItBack() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        let key = "H16v10"
        stats.recordQuiz(correct: false, streak: 0, spotKey: key)
        stats.logMistake(spotKey: key, chose: "Stand", correctPlay: "Hit")
        #expect(stats.reviewQueue.map(\.key) == [key])

        stats.recordQuiz(correct: true, streak: 1, spotKey: key)
        #expect(stats.reviewQueue.map(\.key) == [key], "One right answer keeps it on the list")
        stats.recordQuiz(correct: true, streak: 2, spotKey: key)
        #expect(stats.reviewQueue.isEmpty, "Two in a row clears it")

        stats.recordQuiz(correct: false, streak: 0, spotKey: key)
        stats.logMistake(spotKey: key, chose: "Stand", correctPlay: "Hit")
        #expect(stats.reviewQueue.map(\.key) == [key], "Missing it again puts it back")
    }

    @Test func aMissBetweenRightAnswersResetsTheStreak() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        let key = "S18v9"
        stats.recordDecision(correct: false, spotKey: key)
        stats.logMistake(spotKey: key, chose: "Stand", correctPlay: "Hit")
        stats.recordDecision(correct: true, spotKey: key)
        stats.recordDecision(correct: false, spotKey: key)
        stats.logMistake(spotKey: key, chose: "Stand", correctPlay: "Hit")
        stats.recordDecision(correct: true, spotKey: key)
        #expect(stats.reviewQueue.map(\.key) == [key])
    }

    @Test func streaksSurviveSaveAndLoadAndOldSavesStillLoad() throws {
        let store = TestDefaults()
        var data = StatsData()
        data.spots["H16v10"] = SpotStat(correct: 1, total: 3)
        data.mistakeChoices["H16v10"] = ["Stand": 2]
        data.spotStreaks["H16v10"] = 1
        let roundTrip = try JSONDecoder().decode(StatsData.self, from: JSONEncoder().encode(data))
        #expect(roundTrip.spotStreaks["H16v10"] == 1)

        // A save written before review existed has no streak field at all.
        let old = #"{"quizTotal": 7, "spots": {"H16v10": {"correct": 1, "total": 3}}, "mistakeChoices": {"H16v10": {"Stand": 2}}}"#
        store.defaults.set(Data(old.utf8), forKey: Stats.storageKey)
        let stats = Stats(defaults: store.defaults)
        #expect(stats.data.quizTotal == 7, "Old progress must not be wiped")
        #expect(stats.reviewQueue.map(\.key) == ["H16v10"])
    }

    // MARK: Engine

    @Test func reviewModeDealsMissedHandsAndEmptiesWhenCleared() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        let engine = QuizEngine(stats: stats)
        engine.difficulty = .normal
        engine.startReview()
        #expect(engine.isReviewing && engine.reviewIsEmpty, "Nothing missed yet: empty state")
        #expect(engine.dealerUp == nil)

        // Miss a hand in the quiz, then review it.
        engine.endReview()
        #expect(engine.difficulty == .normal, "Back to the mode the player came from")
        stats.recordQuiz(correct: false, streak: 0, spotKey: "H16v10")
        stats.logMistake(spotKey: "H16v10", chose: "Stand", correctPlay: "Hit")
        engine.startReview()
        #expect(!engine.reviewIsEmpty)
        #expect(engine.reviewRemaining == 1)
        #expect(engine.handText == "Hard 16")
        #expect(engine.dealerUp?.rank.strategyKey == "10")

        let right = BasicStrategy.correctAction(cards: engine.player, dealerUp: engine.dealerUp!.rank,
                                                canDouble: true, canSplit: engine.canSplit)
        engine.answer(right)
        #expect(engine.feedback.hasSuffix("One more right answer clears it."))
        engine.next()
        engine.answer(right)
        #expect(engine.feedback.hasSuffix("Cleared from your review list."))
        #expect(engine.reviewRemaining == 0)
        engine.next()
        #expect(engine.reviewIsEmpty, "Last hand cleared: all caught up")
    }

    @Test func wrongAnswerInReviewKeepsTheHandOnTheList() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        stats.recordQuiz(correct: false, streak: 0, spotKey: "H16v10")
        stats.logMistake(spotKey: "H16v10", chose: "Stand", correctPlay: "Hit")
        let engine = QuizEngine(stats: stats)
        engine.startReview()
        let right = BasicStrategy.correctAction(cards: engine.player, dealerUp: engine.dealerUp!.rank,
                                                canDouble: true, canSplit: engine.canSplit)
        let wrong: Action = right == .stand ? .hit : .stand
        engine.answer(wrong)
        #expect(engine.feedback.hasSuffix("It stays on your review list."))
        #expect(engine.reviewRemaining == 1)
    }

    // MARK: Achievements

    private func sample() -> [Achievement] {
        Achievements.all(from: Achievements.Inputs(decisions: 60, decisionsCorrect: 55, spotsPracticed: 12,
                                                    handsPlayed: 3, blackjacks: 1))
    }

    @Test func spotlightShowsTheClosestTwoAndNeverMoreThanTwoRecent() {
        let all = sample()
        let dates = Dictionary(uniqueKeysWithValues: all.filter(\.unlocked).map { ($0.id, "2026-11-20") })
        let spot = Achievements.spotlight(all: all, dates: dates, since: "2026-11-01")
        #expect(spot.next.count == 2)
        #expect(spot.next.allSatisfy { !$0.unlocked })
        #expect(spot.next[0].progress >= spot.next[1].progress)
        #expect(spot.recent.count == 2, "Capped at two even with more earned")
        #expect(spot.recent.allSatisfy { $0.unlocked })
    }

    @Test func oldAndUntrackedTrophiesAreNotRecent() {
        let all = sample()
        let unlocked = all.filter(\.unlocked)
        let untracked = Dictionary(uniqueKeysWithValues: unlocked.map { ($0.id, "") })
        #expect(Achievements.spotlight(all: all, dates: untracked, since: "2026-11-01").recent.isEmpty)
        let stale = Dictionary(uniqueKeysWithValues: unlocked.map { ($0.id, "2026-01-05") })
        #expect(Achievements.spotlight(all: all, dates: stale, since: "2026-11-01").recent.isEmpty)
    }

    @Test func firstSyncStampsEarnedTrophiesAsOldThenNewOnesAsToday() {
        let first = Achievements.updatedDates(existing: [:], seeded: false, unlocked: ["a", "b"], today: "2026-11-26")
        #expect(first.dates == ["a": "", "b": ""] && first.seeded)
        let later = Achievements.updatedDates(existing: first.dates, seeded: true, unlocked: ["a", "b", "c"],
                                              today: "2026-11-27")
        #expect(later.dates["c"] == "2026-11-27")
        #expect(later.dates["a"] == "", "Existing stamps are never rewritten")
    }

    @Test func freshPlayerSeededAtLaunchGetsTheirFirstTrophyAsRecent() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        #expect(stats.data.achievementsSeeded, "Launch seeds the dates")
        stats.recordQuiz(correct: true, streak: 1, spotKey: "H16v10")
        stats.syncAchievementDates()
        #expect(stats.data.achievementDates["first-steps"] == stats.todayDateKey)
    }
}
