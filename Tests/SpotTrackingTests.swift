import Foundation

@main
struct SpotTrackingTests {
    static func main() {
        spotKeyTests()
        displayNameTests()
        correctActionTests()
        h17Tests()
        weakestSpotTests()
        recurringMistakeTests()
        drillWeightTests()
        dailyStreakTests()
        skillRatingTests()
        dailyChallengeDealTests()
        longestStreakTests()
        achievementTests()
        chipSizingTests()
    }

    // MARK: - ProgressMetrics.recurringMistakes

    private static func recurringMistakeTests() {
        let spots = [
            "H16v10": SpotStat(correct: 1, total: 6),
            "H12v3": SpotStat(correct: 2, total: 6),
            "H11v6": SpotStat(correct: 4, total: 5),
            "P8v10": SpotStat(correct: 9, total: 10),
        ]
        let choices = [
            "H16v10": ["Stand": 4, "Double": 1],
            "H12v3": ["Stand": 4],
            "H11v6": ["Hit": 1],
            "P8v10": ["Stand": 5],
        ]

        let review = ProgressMetrics.recurringMistakes(in: spots, choices: choices)
        precondition(review.map(\.key) == ["H16v10", "H12v3"],
                     "Repeated misses should rank by mistake count and exclude one-offs")
        precondition(review[0].commonChoice == "Stand" && review[0].choiceCount == 4,
                     "The review should explain the player's most common wrong choice")
        precondition(review[0].mistakeCount == 5,
                     "All recorded wrong choices should contribute to recurrence")

        let noHistory = ProgressMetrics.recurringMistakes(in: spots, choices: [:])
        precondition(noHistory.isEmpty, "Old accuracy data without recorded choices is not a recurring pattern")
    }

    // MARK: - ChipSizing

    private static func chipSizingTests() {
        // Every configurable minimum must be coverable by its tray's biggest
        // chip — the old ceiling-based bump left a $10K minimum with $1K chips.
        for minimum in ChipSizing.minimumOptions {
            for buyIn in [minimum, minimum * 2, minimum * 20, 500_000] {
                let denoms = ChipSizing.denominations(buyIn: buyIn, tableMinimum: minimum)
                precondition(denoms.max()! >= minimum,
                             "Largest chip \(denoms.max()!) can't reach minimum \(minimum) at buy-in \(buyIn)")
            }
        }
        // Small tables keep their small-chip trays.
        precondition(ChipSizing.denominations(buyIn: 100, tableMinimum: 1) == [0.10, 0.25, 1, 5, 25])
    }

    // MARK: - ProgressMetrics.longestStreak

    private static func longestStreakTests() {
        // Best run is in the middle of history, not at the end.
        let totals = [
            "2026-07-01": 25, "2026-07-02": 20, "2026-07-03": 30, "2026-07-04": 22,
            "2026-07-06": 21,
            "2026-07-10": 25, "2026-07-11": 3,
        ]
        precondition(ProgressMetrics.longestStreak(dayTotals: totals, goal: 20) == 4,
                     "Expected best run of 4")
        precondition(ProgressMetrics.longestStreak(dayTotals: [:], goal: 20) == 0)
        precondition(ProgressMetrics.longestStreak(dayTotals: ["2026-07-01": 50], goal: 20) == 1)
    }

    // MARK: - Achievements

    private static func achievementTests() {
        let fresh = Achievements.all(from: Achievements.Inputs())
        precondition(!fresh.isEmpty, "Catalog should not be empty")
        precondition(fresh.allSatisfy { !$0.unlocked },
                     "A fresh player should have nothing unlocked")
        precondition(Set(fresh.map(\.id)).count == fresh.count, "Achievement ids must be unique")
        precondition(fresh.allSatisfy { Achievements.categories.contains($0.category) },
                     "Every achievement must belong to a known category")

        // Count-based: progress and unlock.
        var i = Achievements.Inputs()
        i.decisions = 50
        let century = Achievements.all(from: i).first { $0.id == "century" }!
        precondition(!century.unlocked && century.progress == 0.5,
                     "50/100 should be half way, got \(century.progress)")
        i.decisions = 150
        precondition(Achievements.all(from: i).first { $0.id == "century" }!.unlocked)

        // Gated accuracy trophies can't unlock on volume or accuracy alone.
        var sharp = Achievements.Inputs()
        sharp.decisions = 30; sharp.decisionsCorrect = 30   // 100% but tiny sample
        precondition(!Achievements.all(from: sharp).first { $0.id == "sharp" }!.unlocked,
                     "100% over 30 must not unlock Sharp (needs 50+)")
        sharp.decisions = 60; sharp.decisionsCorrect = 50   // volume ok, 83%
        precondition(!Achievements.all(from: sharp).first { $0.id == "sharp" }!.unlocked,
                     "83% must not unlock Sharp (needs 90%)")
        sharp.decisions = 60; sharp.decisionsCorrect = 56   // 93% over 60
        precondition(Achievements.all(from: sharp).first { $0.id == "sharp" }!.unlocked)

        // Bankroll trophies key off the best session profit, not the live
        // bankroll — a big buy-in alone must not unlock them.
        var roller = Achievements.Inputs()
        roller.bestSessionNet = 500
        let rollerAll = Achievements.all(from: roller)
        precondition(rollerAll.first { $0.id == "high-roller" }!.unlocked,
                     "$500 up should unlock High Roller")
        precondition(!rollerAll.first { $0.id == "whale" }!.unlocked,
                     "$500 up must not unlock Whale (needs $1,500)")

        // Streak trophies key off the longest run ever, supplied as input.
        var streaky = Achievements.Inputs()
        streaky.longestDailyStreak = 7
        let unlockedIds = Set(Achievements.all(from: streaky).filter(\.unlocked).map(\.id))
        precondition(unlockedIds.contains("streak-3") && unlockedIds.contains("streak-7")
                     && !unlockedIds.contains("streak-30"))
    }

    // MARK: - SkillRating

    private static func skillRatingTests() {
        // A brand-new player is a Beginner with score 0.
        let fresh = SkillRating.compute(from: SkillRating.Inputs())
        precondition(fresh.score == 0 && fresh.level == .beginner,
                     "Fresh player should be Beginner at 0, got \(fresh.level.name) at \(fresh.score)")
        precondition(!fresh.nextStep.isEmpty, "There should always be a next step")

        // A strong all-around player lands in the top tiers.
        var strong = SkillRating.Inputs()
        strong.strategyCorrect = 195; strong.strategyTotal = 200
        strong.spotsPracticed = 280; strong.chartCells = 310
        strong.drillsCorrect = 58; strong.drillsCompleted = 60
        strong.countChecksCorrect = 10; strong.countChecks = 10
        strong.betCorrect = 38; strong.betDecisions = 40
        let sharp = SkillRating.compute(from: strong)
        precondition(sharp.level == .sharp || sharp.level == .advantage,
                     "Strong player should be Sharp+, got \(sharp.level.name) at \(sharp.score)")

        // Small samples can't fake mastery: 3/3 correct is nowhere near 100.
        var tiny = SkillRating.Inputs()
        tiny.strategyCorrect = 3; tiny.strategyTotal = 3
        let small = SkillRating.compute(from: tiny)
        precondition(small.score < 10, "3/3 should score low on confidence, got \(small.score)")

        // The tip targets the weakest component: great strategy, no counting.
        var lopsided = strong
        lopsided.drillsCorrect = 0; lopsided.drillsCompleted = 0
        lopsided.countChecksCorrect = 0; lopsided.countChecks = 0
        let tip = SkillRating.compute(from: lopsided).nextStep
        precondition(tip.contains("count"), "Tip should target counting, got: \(tip)")

        // levelProgress stays in 0...1.
        for rating in [fresh, sharp, small] {
            precondition((0...1).contains(rating.levelProgress))
        }
    }

    // MARK: - Daily challenge dealing

    private static func dailyChallengeDealTests() {
        precondition(DailyChallengeDeal.seed(for: "2026-07-16") == DailyChallengeDeal.seed(for: "2026-07-16"))
        precondition(DailyChallengeDeal.seed(for: "2026-07-16") != DailyChallengeDeal.seed(for: "2026-07-17"))

        let a = DailyChallengeDeal.spots(for: "2026-07-16")
        let b = DailyChallengeDeal.spots(for: "2026-07-16")
        precondition(a.count == DailyChallengeDeal.handCount)
        let sig = { (s: [CatalogSpot]) in
            s.map { "\($0.playerRanks.0.rawValue)\($0.playerRanks.1.rawValue)v\($0.dealerRank.rawValue)" }
                .joined(separator: "|")
        }
        precondition(sig(a) == sig(b), "Same date must deal the same spots")
        let c = DailyChallengeDeal.spots(for: "2026-07-17")
        precondition(sig(a) != sig(c), "Different dates should deal different spots")
    }

    // MARK: - SpotID.key

    private static func spotKeyTests() {
        expectKey("P8v10", cards: [(.eight, .spades), (.eight, .hearts)], dealer: .king, canSplit: true)
        expectKey("PAvA", cards: [(.ace, .spades), (.ace, .hearts)], dealer: .ace, canSplit: true)
        expectKey("P10v6", cards: [(.king, .spades), (.jack, .hearts)], dealer: .six, canSplit: true)
        // A pair that can't be split is just its total.
        expectKey("H16v10", cards: [(.eight, .spades), (.eight, .hearts)], dealer: .ten, canSplit: false)
        expectKey("S18v9", cards: [(.ace, .spades), (.seven, .hearts)], dealer: .nine, canSplit: false)
        expectKey("H16v10", cards: [(.ten, .spades), (.six, .hearts)], dealer: .queen, canSplit: false)
        // Multi-card hands: the ace drops to 1, so A+3+9 is hard 13.
        expectKey("H13v10", cards: [(.ace, .spades), (.three, .hearts), (.nine, .clubs)], dealer: .ten, canSplit: false)
        // Totals beyond the chart clamp onto the edge rows (17 = "17+", 5 = lowest).
        expectKey("H17v6", cards: [(.ten, .spades), (.five, .hearts), (.four, .clubs)], dealer: .six, canSplit: false)
        expectKey("H5v2", cards: [(.two, .spades), (.two, .hearts)], dealer: .two, canSplit: false)
        // Chart-cell form used by the heatmap matches the hand form.
        precondition(SpotID.key(category: "H", row: "16", dealerCol: "10") == "H16v10")
        precondition(SpotID.key(category: "P", row: "A", dealerCol: "A") == "PAvA")
    }

    private static func expectKey(
        _ expected: String,
        cards: [(Rank, Suit)],
        dealer: Rank,
        canSplit: Bool
    ) {
        let hand = cards.map { Card(rank: $0.0, suit: $0.1) }
        let key = SpotID.key(cards: hand, dealerUp: dealer, canSplit: canSplit)
        precondition(key == expected, "Expected \(expected), got \(key)")
    }

    // MARK: - SpotID.displayName

    private static func displayNameTests() {
        expectName("Hard 16 vs 10", for: "H16v10")
        expectName("Soft 18 vs 9", for: "S18v9")
        expectName("8,8 vs 10", for: "P8v10")
        expectName("A,A vs A", for: "PAvA")
        expectName("Hard 17+ vs 6", for: "H17v6")
    }

    private static func expectName(_ expected: String, for key: String) {
        let name = SpotID.displayName(key)
        precondition(name == expected, "Expected \(expected), got \(name)")
    }

    // MARK: - SpotID.correctActionName

    private static func correctActionTests() {
        expectAction("Hit", for: "H16v10")
        expectAction("Stand", for: "H13v2")
        expectAction("Double", for: "H11v6")
        expectAction("Split", for: "P8vA")
        expectAction("Double (else stand)", for: "S18v3")
        expectAction("Double (else hit)", for: "S17v4")
        precondition(SpotID.correctActionName("X99v10") == nil, "Bad key should yield nil")
    }

    private static func expectAction(_ expected: String, for key: String) {
        let action = SpotID.correctActionName(key)
        precondition(action == expected, "Expected \(expected) for \(key), got \(action ?? "nil")")
    }

    // MARK: - BasicStrategy H17 grading

    private static func h17Tests() {
        func play(_ ranks: [Rank], vs dealer: Rank, h17: Bool, canDouble: Bool = true) -> Action {
            BasicStrategy.correctAction(
                cards: ranks.map { Card(rank: $0, suit: .spades) },
                dealerUp: dealer, canDouble: canDouble, canSplit: false,
                dealerHitsSoft17: h17)
        }
        // The three multi-deck cells that flip when the dealer hits soft 17.
        precondition(play([.six, .five], vs: .ace, h17: false) == .hit, "11 vs A is hit under S17")
        precondition(play([.six, .five], vs: .ace, h17: true) == .double, "11 vs A doubles under H17")
        precondition(play([.ace, .seven], vs: .two, h17: false) == .stand, "Soft 18 vs 2 stands under S17")
        precondition(play([.ace, .seven], vs: .two, h17: true) == .double, "Soft 18 vs 2 doubles under H17")
        precondition(play([.ace, .eight], vs: .six, h17: false) == .stand, "Soft 19 vs 6 stands under S17")
        precondition(play([.ace, .eight], vs: .six, h17: true) == .double, "Soft 19 vs 6 doubles under H17")
        // When doubling isn't available, the H17 overrides fall back correctly.
        precondition(play([.two, .four, .five], vs: .ace, h17: true, canDouble: false) == .hit,
                     "Multi-card 11 vs A hits when it can't double")
        precondition(play([.ace, .three, .four], vs: .two, h17: true, canDouble: false) == .stand,
                     "Multi-card soft 18 vs 2 stands when it can't double")
        precondition(play([.ace, .four, .four], vs: .six, h17: true, canDouble: false) == .stand,
                     "Multi-card soft 19 vs 6 stands when it can't double")
        // Cells outside the three overrides are untouched by the flag.
        precondition(play([.ten, .six], vs: .ten, h17: true) == .hit)
        precondition(play([.ace, .seven], vs: .three, h17: true) == .double, "Soft 18 vs 3 already doubled under S17")
    }

    // MARK: - ProgressMetrics.weakestSpots

    private static func weakestSpotTests() {
        let spots: [String: SpotStat] = [
            "H16v10": SpotStat(correct: 2, total: 10),   // 20% — worst
            "S18v9": SpotStat(correct: 3, total: 6),     // 50%
            "P8v10": SpotStat(correct: 4, total: 5),     // 80%
            "H12v2": SpotStat(correct: 1, total: 2),     // below min attempts — excluded
            "H11v6": SpotStat(correct: 10, total: 10),   // mastered — excluded
        ]
        let weakest = ProgressMetrics.weakestSpots(in: spots, minAttempts: 3, masteredAt: 0.9, limit: 5)
        precondition(weakest.map(\.key) == ["H16v10", "S18v9", "P8v10"],
                     "Wrong leak ranking: \(weakest.map(\.key))")

        let limited = ProgressMetrics.weakestSpots(in: spots, minAttempts: 3, masteredAt: 0.9, limit: 2)
        precondition(limited.count == 2 && limited[0].key == "H16v10")

        precondition(ProgressMetrics.weakestSpots(in: [:]).isEmpty)
    }

    // MARK: - ProgressMetrics.drillWeight

    private static func drillWeightTests() {
        precondition(ProgressMetrics.drillWeight(for: nil) == 3, "Unseen spots should get a strong pull")
        let mastered = ProgressMetrics.drillWeight(for: SpotStat(correct: 10, total: 10))
        precondition(mastered == 0.5, "Mastered spots should stay in rotation but rare")
        let hopeless = ProgressMetrics.drillWeight(for: SpotStat(correct: 0, total: 5))
        precondition(hopeless == 7, "0% spots should get the maximum weight")
        let mid = ProgressMetrics.drillWeight(for: SpotStat(correct: 5, total: 10))
        precondition(mid == 4, "50% accuracy should sit mid-range, got \(mid)")
    }

    // MARK: - ProgressMetrics.dailyStreak

    private static func dailyStreakTests() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = f.date(from: "2026-07-16")!

        // Goal met today and the two prior days.
        var totals = ["2026-07-16": 25, "2026-07-15": 20, "2026-07-14": 30]
        precondition(ProgressMetrics.dailyStreak(dayTotals: totals, goal: 20, today: today) == 3)

        // Today not yet at goal: yesterday's run still counts.
        totals["2026-07-16"] = 5
        precondition(ProgressMetrics.dailyStreak(dayTotals: totals, goal: 20, today: today) == 2)

        // A gap breaks the streak.
        totals = ["2026-07-16": 25, "2026-07-14": 30]
        precondition(ProgressMetrics.dailyStreak(dayTotals: totals, goal: 20, today: today) == 1)

        // Nothing recorded at all.
        precondition(ProgressMetrics.dailyStreak(dayTotals: [:], goal: 20, today: today) == 0)

        // A day that exists but misses the goal breaks the run.
        totals = ["2026-07-16": 25, "2026-07-15": 3, "2026-07-14": 30]
        precondition(ProgressMetrics.dailyStreak(dayTotals: totals, goal: 20, today: today) == 1)
    }
}
