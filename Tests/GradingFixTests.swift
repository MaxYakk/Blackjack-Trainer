import Foundation
import Testing
@testable import BlackjackTrainer

/// Regression tests for grading bugs that taught wrong plays.
struct GradingFixTests {
    private static func hand(_ ranks: Rank...) -> [Card] {
        ranks.map { Card(rank: $0, suit: .spades) }
    }

    private static func countPlay(_ cards: [Card], vs up: Rank, tc: Double,
                                  canDouble: Bool = true, canSplit: Bool = true,
                                  h17: Bool = false) -> Action {
        Deviations.correctAction(cards: cards, dealerUp: up, trueCount: tc,
                                 canDouble: canDouble, canSplit: canSplit,
                                 dealerHitsSoft17: h17)
    }

    // MARK: Bug 1: index plays must not override pair splits

    @Test func eightsSplitAgainstNineAndTenAtAnyCount() {
        for up in [Rank.nine, .ten, .king] {
            for tc in [-3.0, 0, 5, 8] {
                #expect(Self.countPlay(Self.hand(.eight, .eight), vs: up, tc: tc) == .split)
            }
        }
        #expect(Deviations.matching(cards: Self.hand(.eight, .eight), dealerUp: .ten, canSplit: true) == nil)
    }

    @Test func sixesSplitAgainstTwoThroughSixAtAnyCount() {
        for up in [Rank.two, .three, .four, .five, .six] {
            for tc in [-4.0, 0, 4] {
                #expect(Self.countPlay(Self.hand(.six, .six), vs: up, tc: tc) == .split)
            }
        }
    }

    @Test func unsplittablePairUsesHardTotalIndexPlay() {
        // 8,8 that can't be split is a hard 16: stand vs 10 at TC 0+, hit below.
        #expect(Self.countPlay(Self.hand(.eight, .eight), vs: .ten, tc: 1, canSplit: false) == .stand)
        #expect(Self.countPlay(Self.hand(.eight, .eight), vs: .ten, tc: -1, canSplit: false) == .hit)
        #expect(Deviations.matching(cards: Self.hand(.eight, .eight), dealerUp: .ten)?.handKey == "16")
        // 6,6 that can't be split vs 2 is hard 12: stand at TC +3.
        #expect(Self.countPlay(Self.hand(.six, .six), vs: .two, tc: 3, canSplit: false) == .stand)
    }

    @Test func pairsTheChartDoesNotSplitKeepTheirTotalIndexPlays() {
        // 5,5 is played as hard 10: double vs 10 at TC +4.
        #expect(Self.countPlay(Self.hand(.five, .five), vs: .ten, tc: 4) == .double)
        #expect(Self.countPlay(Self.hand(.five, .five), vs: .ten, tc: 3) == .hit)
        // Tens keep their own split index plays.
        #expect(Self.countPlay(Self.hand(.ten, .king), vs: .six, tc: 4) == .split)
        #expect(Self.countPlay(Self.hand(.ten, .king), vs: .six, tc: 3) == .stand)
        #expect(Self.countPlay(Self.hand(.ten, .king), vs: .six, tc: 5, canSplit: false) == .stand)
    }

    @Test func nonPairIndexPlaysStillApply() {
        #expect(Self.countPlay(Self.hand(.ten, .six), vs: .ten, tc: 0) == .stand)
        #expect(Self.countPlay(Self.hand(.ten, .two), vs: .four, tc: -1) == .hit)
    }

    // MARK: Bug 2: soft 12 always hits

    @Test func unsplittableAcesHitAgainstEveryUpcard() {
        for up in [Rank.two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .ace] {
            for h17 in [false, true] {
                #expect(BasicStrategy.correctAction(cards: Self.hand(.ace, .ace), dealerUp: up,
                                                    canDouble: true, canSplit: false,
                                                    dealerHitsSoft17: h17) == .hit)
            }
            #expect(Self.countPlay(Self.hand(.ace, .ace), vs: up, tc: 6, canSplit: false) == .hit)
            #expect(BasicStrategy.correctAction(cards: Self.hand(.ace, .ace), dealerUp: up,
                                                canDouble: true, canSplit: true) == .split)
        }
    }

    @Test func otherSoftTotalsGradeCorrectly() {
        // Multi-card soft 21 and blackjack stand.
        #expect(BasicStrategy.correctAction(cards: Self.hand(.ace, .five, .five), dealerUp: .six,
                                            canDouble: false, canSplit: false) == .stand)
        #expect(BasicStrategy.correctAction(cards: Self.hand(.ace, .king), dealerUp: .ace,
                                            canDouble: true, canSplit: false) == .stand)
        // Multi-card soft 18 vs 3: "double else stand" becomes stand.
        #expect(BasicStrategy.correctAction(cards: Self.hand(.ace, .three, .four), dealerUp: .three,
                                            canDouble: false, canSplit: false) == .stand)
        // Multi-card soft 17 vs 4: "double else hit" becomes hit.
        #expect(BasicStrategy.correctAction(cards: Self.hand(.ace, .two, .four), dealerUp: .four,
                                            canDouble: false, canSplit: false) == .hit)
        // Soft 13 from three cards (A,A,A) uses the soft chart: double vs 5.
        #expect(BasicStrategy.correctAction(cards: Self.hand(.ace, .ace, .ace), dealerUp: .five,
                                            canDouble: true, canSplit: false) == .double)
    }

    // MARK: Bug 3: H17 index values

    @Test func elevenVersusAceUnderH17DoublesDownToMinusOne() {
        let eleven = Self.hand(.six, .five)
        #expect(Self.countPlay(eleven, vs: .ace, tc: 0, h17: true) == .double)
        #expect(Self.countPlay(eleven, vs: .ace, tc: -1, h17: true) == .double)
        #expect(Self.countPlay(eleven, vs: .ace, tc: -1.5, h17: true) == .hit)
        // S17 unchanged: hit below +1.
        #expect(Self.countPlay(eleven, vs: .ace, tc: 0, h17: false) == .hit)
        #expect(Self.countPlay(eleven, vs: .ace, tc: 1, h17: false) == .double)
        #expect(Deviations.matching(cards: eleven, dealerUp: .ace, dealerHitsSoft17: true)?.index == -1)
    }

    @Test func tenVersusAceUnderH17DoublesAtPlusThree() {
        let ten = Self.hand(.six, .four)
        #expect(Self.countPlay(ten, vs: .ace, tc: 3, h17: true) == .double)
        #expect(Self.countPlay(ten, vs: .ace, tc: 2.5, h17: true) == .hit)
        #expect(Self.countPlay(ten, vs: .ace, tc: 3, h17: false) == .hit)
        #expect(Self.countPlay(ten, vs: .ace, tc: 4, h17: false) == .double)
    }

    @Test func twelveVersusSixUnderH17HitsBelowMinusThree() {
        let twelve = Self.hand(.ten, .two)
        #expect(Self.countPlay(twelve, vs: .six, tc: -2, h17: true) == .stand)
        #expect(Self.countPlay(twelve, vs: .six, tc: -3.5, h17: true) == .hit)
        #expect(Self.countPlay(twelve, vs: .six, tc: -2, h17: false) == .hit)
    }

    @Test func h17NotesMatchTheGradedIndex() {
        let dev = Deviations.matching(cards: Self.hand(.six, .five), dealerUp: .ace, dealerHitsSoft17: true)
        #expect(dev?.note.contains("negative 1") == true)
        let s17 = Deviations.matching(cards: Self.hand(.six, .five), dealerUp: .ace)
        #expect(s17?.index == 1)
        // Entries without an H17 value are unchanged.
        #expect(Deviations.matching(cards: Self.hand(.ten, .six), dealerUp: .ten, dealerHitsSoft17: true)?.index == 0)
    }

    // MARK: Bug 4: bet grading tests the count

    private static func bet(_ amount: Double, count: Int, min: Double = 25,
                            bankroll: Double = 10_000) -> BetSizingVerdict {
        BetSizingEvaluator.verdict(spotBet: amount, countUnits: count, tableMinimum: min,
                                   bankroll: bankroll, spreadCap: 6)
    }

    @Test func bigBetAtNegativeCountIsTooHigh() {
        // $10,000 stack at $25: the stack could carry $150, but the count says $25.
        #expect(Self.bet(150, count: 1) == .tooHigh)
        #expect(Self.bet(75, count: 1) == .tooHigh)
        #expect(Self.bet(50, count: 1) == .acceptable)
        #expect(Self.bet(25, count: 1) == .acceptable)
    }

    @Test func flatBettingTheMinimumFailsOnceTheCountRises() {
        for count in 2...6 {
            #expect(Self.bet(25, count: count) == .tooLow, "count \(count)")
        }
        #expect(Self.bet(50, count: 2) == .acceptable)
        #expect(Self.bet(150, count: 6) == .acceptable)
        #expect(Self.bet(100, count: 6) == .acceptable)
        #expect(Self.bet(75, count: 6) == .tooLow)
    }

    @Test func stackCapStillApplies() {
        // $1,500 at $25 carries $100 a spot even when the count wants $150.
        #expect(Self.bet(150, count: 6, bankroll: 1500) == .tooHigh)
        #expect(Self.bet(100, count: 6, bankroll: 1500) == .acceptable)
        #expect(BetSizingEvaluator.exceedsStack(spotBet: 125, tableMinimum: 25, bankroll: 1500, spreadCap: 6))
        #expect(!BetSizingEvaluator.exceedsStack(spotBet: 75, tableMinimum: 25, bankroll: 1500, spreadCap: 6))
    }

    @Test func zeroTableMinimumDoesNotCrash() {
        #expect(Self.bet(25, count: 3, min: 0) == .acceptable)
        #expect(Self.bet(25, count: 3, min: -5) == .acceptable)
        #expect(BetSizingEvaluator.recommendedUnits(countUnits: 4, maxBet: 0, tableMinimum: 0) == 1)
        #expect(BetSizingEvaluator.maxBet(bankroll: 1000, tableMinimum: 0, spreadCap: 6) == 0)
    }
}
