import Foundation
import Testing
@testable import BlackjackTrainer

/// Green / yellow / red grading of moves: the EV threshold, the count rule
/// at index plays, and agreement between the EV calculator and the chart.
struct MoveGradingTests {
    private static func grade(_ action: Action, _ c: [Card], vs up: Rank,
                              tc: Double? = nil, h17: Bool = false,
                              canDouble: Bool = true, canSplit: Bool = true) -> MoveVerdict {
        MoveGrader.grade(action, cards: c, dealerUp: up, canDouble: canDouble, canSplit: canSplit,
                         dealerHitsSoft17: h17, trueCount: tc)
    }

    @Test func chartPlayIsGreen() {
        #expect(Self.grade(.hit, cards("10s", "6h"), vs: .ten).grade == .correct)
        #expect(Self.grade(.split, cards("8s", "8h"), vs: .ten).grade == .correct)
    }

    @Test func closeCallsAreYellow() {
        // Each costs under 2% of the bet.
        #expect(Self.grade(.stand, cards("10s", "6h"), vs: .ten).grade == .close)   // 0.06%
        #expect(Self.grade(.hit, cards("10s", "2h"), vs: .four).grade == .close)    // 0.25%
        #expect(Self.grade(.hit, cards("10s", "3h"), vs: .two).grade == .close)     // 1.5%
        #expect(Self.grade(.stand, cards("10s", "2h"), vs: .three).grade == .close) // 1.9%
        #expect(Self.grade(.double, cards("5s", "4h"), vs: .two).grade == .close)   // 9 vs 2, 1.3%
    }

    @Test func clearMistakesAreRed() {
        #expect(Self.grade(.stand, cards("10s", "2h"), vs: .two).grade == .wrong)   // 3.9%
        #expect(Self.grade(.stand, cards("10s", "6h"), vs: .nine).grade == .wrong)  // 3.4%
        #expect(Self.grade(.stand, cards("10s", "5h"), vs: .ten).grade == .wrong)   // 3.6%
        #expect(Self.grade(.hit, cards("8s", "8h"), vs: .ten).grade == .wrong)      // 5.9%
        #expect(Self.grade(.double, cards("10s", "6h"), vs: .ten).grade == .wrong)
        #expect(Self.grade(.stand, cards("10s", "2h"), vs: .six).grade == .correct)
        #expect(Self.grade(.hit, cards("10s", "7h"), vs: .six).grade == .wrong)
    }

    @Test func yellowFeedbackIsOneFriendlyLine() {
        let v = Self.grade(.stand, cards("10s", "6h"), vs: .ten)
        #expect(MoveGrader.closeText(v) == "Close. Hit is slightly better here.")
    }

    @Test func thresholdExamplesMatchTheDocumentedCosts() {
        let ev = ExpectedValue()
        let p16 = ev.plays(cards: cards("10s", "6h"), dealerUp: .ten, canDouble: true, canSplit: false)
        #expect(abs((p16.hit - p16.stand) - 0.0006) < 0.0005)
        let p12 = ev.plays(cards: cards("10s", "2h"), dealerUp: .two, canDouble: true, canSplit: false)
        #expect(abs((p12.hit - p12.stand) - 0.0394) < 0.0005)
    }

    // MARK: Count-based spots (index plays on)

    @Test func indexPlayEdgeIsYellowOnlyWithinOneTrueCount() {
        let c = cards("10s", "6h")   // 16 vs 10: stand at TC 0+, hit below
        // Played basic (hit) instead of the index play (stand).
        #expect(Self.grade(.hit, c, vs: .ten, tc: 1).grade == .close)
        #expect(Self.grade(.hit, c, vs: .ten, tc: 1.5).grade == .wrong)
        #expect(Self.grade(.hit, c, vs: .ten, tc: 4).grade == .wrong, "count rule wins over the neutral EV")
        // Made the index play just before its index.
        #expect(Self.grade(.stand, c, vs: .ten, tc: -1).grade == .close)
        #expect(Self.grade(.stand, c, vs: .ten, tc: -2).grade == .wrong)
        // Right side of the index is green.
        #expect(Self.grade(.stand, c, vs: .ten, tc: 0).grade == .correct)
        #expect(Self.grade(.hit, c, vs: .ten, tc: -0.5).grade == .correct)
        // Anything else is graded by EV: doubling 16 is red.
        #expect(Self.grade(.double, c, vs: .ten, tc: 0).grade == .wrong)
    }

    @Test func countRuleNamesTheIndexInTheFeedback() {
        let v = Self.grade(.hit, cards("10s", "6h"), vs: .ten, tc: 0.5)
        #expect(v.gradedByCount)
        #expect(MoveGrader.closeText(v) == "Close. 16 vs 10: stand at TC 0+.")
    }

    @Test func h17UsesItsOwnIndex() {
        // 12 vs 6 under H17: hit below -3 (S17: below -1).
        let c = cards("10s", "2h")
        #expect(Self.grade(.stand, c, vs: .six, tc: -2, h17: true).grade == .correct)
        #expect(Self.grade(.stand, c, vs: .six, tc: -4, h17: true).grade == .close)
        #expect(Self.grade(.stand, c, vs: .six, tc: -4.5, h17: true).grade == .wrong)
    }

    @Test func insuranceGrades() {
        #expect(MoveGrader.gradeInsurance(take: false, trueCount: 5, useDeviations: false) == .correct)
        #expect(MoveGrader.gradeInsurance(take: true, trueCount: 5, useDeviations: false) == .wrong)
        #expect(MoveGrader.gradeInsurance(take: true, trueCount: 3, useDeviations: true) == .correct)
        #expect(MoveGrader.gradeInsurance(take: true, trueCount: 2, useDeviations: true) == .close)
        #expect(MoveGrader.gradeInsurance(take: true, trueCount: 1.5, useDeviations: true) == .wrong)
        #expect(MoveGrader.gradeInsurance(take: false, trueCount: 4, useDeviations: true) == .close)
        #expect(MoveGrader.gradeInsurance(take: false, trueCount: 4.5, useDeviations: true) == .wrong)
    }

    // MARK: EV vs the chart

    /// Every two-card cell of the 4–8 deck chart, as (label, cards).
    static func chartHands() -> [(String, [Card])] {
        let hard: [Int: (Rank, Rank)] = [
            5: (.two, .three), 6: (.two, .four), 7: (.two, .five), 8: (.three, .five),
            9: (.four, .five), 10: (.four, .six), 11: (.five, .six), 12: (.ten, .two),
            13: (.ten, .three), 14: (.ten, .four), 15: (.ten, .five), 16: (.ten, .six), 17: (.ten, .seven),
        ]
        var out = (5...17).map { t in ("hard \(t)", [Card(rank: hard[t]!.0, suit: .clubs), Card(rank: hard[t]!.1, suit: .hearts)]) }
        for r in [Rank.two, .three, .four, .five, .six, .seven, .eight, .nine] {
            out.append(("A,\(r.rawValue)", [Card(rank: .ace, suit: .clubs), Card(rank: r, suit: .hearts)]))
        }
        for r in [Rank.two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .ace] {
            out.append(("\(r.strategyKey),\(r.strategyKey)", [Card(rank: r, suit: .clubs), Card(rank: r, suit: .hearts)]))
        }
        return out
    }

    static let upcards: [Rank] = [.two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .ace]

    /// The cells where the infinite-deck best play differs from the 4–8 deck
    /// chart. Both are known deck-count effects: with fewer decks removed,
    /// A,2 vs 5 and A,4 vs 4 are doubles; in an infinite deck, hits.
    static let knownDisagreements: [Bool: Set<String>] = [
        false: ["A,2 vs 5", "A,4 vs 4"],
        true: ["A,2 vs 5"],
    ]

    @Test(arguments: [false, true])
    func bestEVMatchesTheChartExceptKnownCells(h17: Bool) {
        let ev = MoveGrader.calculator(dealerHitsSoft17: h17)
        var disagree: Set<String> = []
        for (label, c) in Self.chartHands() {
            for up in Self.upcards {
                let isPair = c[0].rank == c[1].rank
                let chart = BasicStrategy.correctAction(cards: c, dealerUp: up, canDouble: true,
                                                        canSplit: isPair, dealerHitsSoft17: h17)
                let plays = ev.plays(cards: c, dealerUp: up, canDouble: true, canSplit: isPair)
                if plays.best.action != chart {
                    disagree.insert("\(label) vs \(up.strategyKey)")
                    // Never far off: the chart play is still a close call by EV.
                    #expect(plays.best.ev - plays.value(of: chart)! < 0.01, "\(label) vs \(up)")
                }
                // The chart play is always green.
                #expect(MoveGrader.grade(chart, cards: c, dealerUp: up, canDouble: true,
                                         canSplit: isPair, dealerHitsSoft17: h17).grade == .correct)
            }
        }
        #expect(disagree == Self.knownDisagreements[h17], "Disagreements: \(disagree.sorted())")
    }
}

/// Half credit for yellow in every stat, review-list rules, and old saves.
@MainActor
struct HalfCreditTests {
    @Test func accuracyGivesHalfCredit() {
        #expect(Accuracy.fraction(correct: 1, close: 1, total: 2) == 0.75)
        #expect(Accuracy.fraction(correct: 0, close: 0, total: 0) == nil)
        #expect(SpotStat(correct: 2, total: 4, close: 2).accuracy == 0.75)
        #expect(DayStat(date: "2026-11-26", strategyCorrect: 1, strategyTotal: 4, strategyClose: 2).accuracy == 0.5)
        #expect(ChallengeResult(score: 7, total: 10, close: 2).points == 8)
    }

    @Test func displayHelpersShowHalfCredit() {
        #expect(ChallengeResult(score: 8, total: 10, close: 1).pointsText == "8½")
        #expect(ChallengeResult(score: 8, total: 10, close: 1).pointsSpoken == "8 and a half")
        #expect(ChallengeResult(score: 8, total: 10, close: 2).pointsText == "9")
        // A cell played only with close calls is 50%, not 0%.
        #expect(ChartAccuracy.percent(for: SpotStat(correct: 0, total: 2, close: 2)) == 50)
        #expect(ChartAccuracy.percent(for: SpotStat(correct: 0, total: 2, close: 0)) == 0)
        #expect(ChartAccuracy.percent(for: SpotStat(correct: 3, total: 4, close: 1)) == 88)
    }

    @Test func yellowDecisionIsHalfCreditEverywhere() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        stats.recordDecision(grade: .correct, spotKey: "H16v10")
        stats.recordDecision(grade: .close, spotKey: "H16v10")
        #expect(stats.strategyAccuracy == 0.75)
        #expect(stats.sessionAccuracy == 0.75)
        #expect(stats.data.spots["H16v10"]?.accuracy == 0.75)
        #expect(stats.todayDecisions == 2, "A close call still counts toward the daily goal")
        stats.recordBet(grade: .close)
        stats.recordBet(grade: .correct)
        #expect(stats.betAccuracy == 0.75)
        stats.recordQuiz(grade: .close, streak: 0, spotKey: nil)
        #expect(stats.quizAccuracy == 0.5)
    }

    @Test func skillRatingAndTrophiesUseHalfCredit() {
        let allClose = SkillRating.compute(from: .init(strategyCorrect: 0, strategyTotal: 200, strategyClose: 200))
        let allRight = SkillRating.compute(from: .init(strategyCorrect: 200, strategyTotal: 200))
        #expect(abs(allClose.score * 2 - allRight.score) < 1e-9)
        // 90% accuracy trophy: 50 right + 8 close of 60 = 90% with half credit
        // (50 of 60 = 83% without it).
        let trophies = Achievements.all(from: .init(decisions: 60, decisionsCorrect: 50, decisionsClose: 8))
        let sharp = trophies.first { $0.detail.contains("90% accuracy") }
        #expect(sharp?.unlocked == true)
        let fewer = Achievements.all(from: .init(decisions: 60, decisionsCorrect: 50, decisionsClose: 6))
        #expect(fewer.first { $0.detail.contains("90% accuracy") }?.unlocked == false)
    }

    @Test func yellowNeverJoinsOrClearsTheReviewList() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        let key = "H16v10"
        stats.recordQuiz(grade: .wrong, streak: 0, spotKey: key)
        stats.logMistake(spotKey: key, chose: "Stand", correctPlay: "Hit")
        stats.recordQuiz(grade: .correct, streak: 1, spotKey: key)
        stats.recordQuiz(grade: .close, streak: 1, spotKey: key)
        #expect(stats.spotStreak(key) == 1, "A close call neither adds to nor resets the streak")
        #expect(stats.reviewQueue.map(\.key) == [key])
        stats.recordQuiz(grade: .correct, streak: 2, spotKey: key)
        #expect(stats.reviewQueue.isEmpty)
    }

    @Test func oldSavesLoadWithZeroCloseCalls() throws {
        let store = TestDefaults()
        let json = """
        {"strategyTotal": 10, "strategyCorrect": 8, "quizTotal": 4, "quizCorrect": 3,
         "betDecisions": 5, "betCorrect": 4,
         "spots": {"H16v10": {"correct": 3, "total": 5}},
         "days": {"2026-01-01": {"date": "2026-01-01", "strategyCorrect": 2, "strategyTotal": 4}},
         "challenges": {"2026-01-02": {"score": 7, "total": 10}}}
        """
        store.defaults.set(Data(json.utf8), forKey: Stats.storageKey)
        let stats = Stats(defaults: store.defaults)
        #expect(stats.loadIssue == nil)
        #expect(stats.data.strategyTotal == 10 && stats.data.strategyCorrect == 8 && stats.data.strategyClose == 0)
        #expect(stats.data.quizClose == 0 && stats.data.betClose == 0)
        #expect(stats.strategyAccuracy == 0.8)
        #expect(stats.data.spots["H16v10"]?.close == 0 && stats.data.spots["H16v10"]?.accuracy == 0.6)
        #expect(stats.data.days["2026-01-01"]?.strategyClose == 0)
        #expect(stats.data.challenges["2026-01-02"]?.close == 0 && stats.data.challenges["2026-01-02"]?.points == 7)
    }

    @Test func closeCountsSurviveSaveAndLoad() throws {
        var data = StatsData()
        data.strategyClose = 3
        data.quizClose = 2
        data.betClose = 1
        data.spots["H12v3"] = SpotStat(correct: 1, total: 4, close: 2)
        data.days["2026-11-26"] = DayStat(date: "2026-11-26", strategyCorrect: 1, strategyTotal: 3, strategyClose: 1)
        data.challenges["2026-11-26"] = ChallengeResult(score: 8, total: 10, close: 1)
        let back = try JSONDecoder().decode(StatsData.self, from: JSONEncoder().encode(data))
        #expect(back.strategyClose == 3 && back.quizClose == 2 && back.betClose == 1)
        #expect(back.spots["H12v3"]?.close == 2)
        #expect(back.days["2026-11-26"]?.strategyClose == 1)
        #expect(back.challenges["2026-11-26"]?.points == 8.5)
    }

    @Test func damagedCloseCountsAreClamped() throws {
        let store = TestDefaults()
        let json = #"{"spots": {"H16v10": {"correct": 3, "total": 5, "close": 9}, "S18v9": {"correct": 1, "total": 2, "close": "x"}}}"#
        store.defaults.set(Data(json.utf8), forKey: Stats.storageKey)
        let stats = Stats(defaults: store.defaults)
        #expect(stats.data.spots["H16v10"]?.close == 2, "close can't exceed total minus correct")
        #expect(stats.data.spots["S18v9"]?.close == 0 && stats.data.spots["S18v9"]?.correct == 1)
    }
}

/// The table, quiz and daily challenge use the three tiers end to end.
@MainActor
struct GradedFlowTests {
    private func table(_ store: TestDefaults, stack: [Card]) -> (Stats, PlayEngine) {
        let (stats, engine) = makeTable(store, buyIn: 500, minimum: 5)
        engine.askCountChecks = false
        let filler = Array(repeating: Card(rank: .nine, suit: .spades), count: 60)
        engine.installShoe(Shoe(numDecks: 6, stackedCards: stack + filler))
        return (stats, engine)
    }

    @Test func standing16Vs10IsYellowAndStaysOffTheReviewList() async {
        let store = TestDefaults()
        // Player 10,6; dealer 10 up, 7 in the hole.
        let (stats, engine) = table(store, stack: cards("10s", "10h", "6c", "7d"))
        betEverySpot(engine, 5)
        await dealAndWait(engine)
        #expect(engine.phase == .playing)
        engine.stand()
        #expect(engine.feedbackGrade == .close)
        #expect(!engine.feedbackGood)
        #expect(engine.feedbackText == "Close. Hit is slightly better here.")
        #expect(stats.data.strategyClose == 1 && stats.data.strategyCorrect == 0)
        #expect(stats.data.spots["H16v10"]?.close == 1)
        #expect(stats.data.mistakeChoices["H16v10"] == nil)
        #expect(stats.sessionMistakes.isEmpty)
        #expect(stats.reviewQueue.isEmpty)
    }

    @Test func standing12Vs2IsRedAndLogged() async {
        let store = TestDefaults()
        let (stats, engine) = table(store, stack: cards("10s", "2h", "2c", "7d"))
        betEverySpot(engine, 5)
        await dealAndWait(engine)
        engine.stand()
        #expect(engine.feedbackGrade == .wrong)
        #expect(engine.feedbackText == "Not quite. Basic strategy says Hit.")
        #expect(stats.data.mistakeChoices["H12v2"] == ["Stand": 1])
    }

    @Test func threeTenDollarHandsOnAHundredIsYellow() async {
        let store = TestDefaults()
        let (stats, engine) = makeTable(store, buyIn: 100, minimum: 5, hands: 3)
        engine.askCountChecks = false
        engine.betHints = true
        engine.installShoe(Shoe(numDecks: 6))
        betEverySpot(engine, 10)
        await dealAndWait(engine)
        #expect(engine.betGrade == .close)
        #expect(engine.betAdviceText.hasPrefix("A bit risky for your balance"), "Got: \(engine.betAdviceText)")
        #expect(stats.data.betClose == 1)
    }

    @Test func tenDollarsOnAHundredIsGreen() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 100, minimum: 5)
        engine.askCountChecks = false
        engine.installShoe(Shoe(numDecks: 6))
        betEverySpot(engine, 10)
        await dealAndWait(engine)
        #expect(engine.betGrade == .correct)
        #expect(engine.betAdviceText == "Good bet.")
    }

    @Test func tooMuchForTheBalanceIsRed() async {
        let store = TestDefaults()
        let (_, engine) = makeTable(store, buyIn: 50, minimum: 5)
        engine.askCountChecks = false
        engine.installShoe(Shoe(numDecks: 6))
        betEverySpot(engine, 30)
        await dealAndWait(engine)
        #expect(engine.betGrade == .wrong)
        #expect(engine.betAdviceText == "Too much for your balance.")
    }

    @Test func quizCloseCallKeepsStreakAndReviewProgress() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        stats.recordQuiz(grade: .wrong, streak: 0, spotKey: "H16v10")
        stats.logMistake(spotKey: "H16v10", chose: "Double", correctPlay: "Hit")
        let engine = QuizEngine(stats: stats)
        engine.startReview()
        #expect(engine.handText == "Hard 16")
        engine.answer(.hit)
        #expect(engine.grade == .correct && engine.streak == 1)
        engine.next()
        engine.answer(.stand)
        #expect(engine.grade == .close)
        #expect(engine.streak == 1, "A close call doesn't break the streak")
        #expect(engine.feedback == "Close. Hit is slightly better here. It stays on your review list.")
        #expect(stats.data.mistakeChoices["H16v10"] == ["Double": 1], "Not logged as a mistake")
        engine.next()
        engine.answer(.hit)
        #expect(engine.reviewRemaining == 0, "Two right answers clear it; the close call in between didn't reset")
    }

    @Test func dailyChallengeCloseCallIsHalfAPoint() throws {
        // Find a day whose deal has a hand with a yellow option.
        func closeAction(_ spot: CatalogSpot) -> Action? {
            [Action.hit, .stand, .double, .split].first {
                MoveGrader.grade($0, cards: spot.cards, dealerUp: spot.dealerRank,
                                 canDouble: true, canSplit: spot.isPair).grade == .close
            }
        }
        let day = try #require((1...28).map { String(format: "2026-02-%02d", $0) }.first { key in
            DailyChallengeDeal.spots(for: key).contains { closeAction($0) != nil }
        })
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        let engine = DailyChallengeEngine(stats: stats, dateKey: day, today: { day })
        var expectedClose = 0
        while let spot = engine.current, !engine.finished {
            if let action = closeAction(spot) {
                engine.answer(action)
                expectedClose += 1
                #expect(engine.grade == .close && engine.feedback.hasPrefix("Close."))
            } else {
                engine.answer(BasicStrategy.correctAction(cards: spot.cards, dealerUp: spot.dealerRank,
                                                          canDouble: true, canSplit: spot.isPair))
            }
            engine.next()
        }
        #expect(engine.closeCount == expectedClose && expectedClose > 0)
        #expect(engine.points == Double(engine.score) + 0.5 * Double(expectedClose))
        let saved = try #require(stats.data.challenges[day])
        #expect(saved.close == expectedClose && !saved.isPerfect)
        #expect(stats.data.mistakeChoices.isEmpty)
    }
}
