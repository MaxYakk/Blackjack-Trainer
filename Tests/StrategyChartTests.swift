import Foundation
import Testing
@testable import BlackjackTrainer

/// The Strategy tab: tap-a-cell explanations, "My accuracy" levels and the
/// rules for which Play decisions count toward a chart cell.
struct StrategyChartTests {
    private static let categories: [(ChartLookup.Category, [String])] = [
        (.hard, (5...17).map(String.init)),
        (.soft, (13...20).map(String.init)),
        (.pair, ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A"]),
    ]

    private static func hand(_ ranks: Rank...) -> [Card] {
        ranks.map { Card(rank: $0, suit: .spades) }
    }

    // MARK: Cell explanations

    @Test func everyCellHasARepresentativeHandOnItsOwnSpotKey() {
        for (category, rows) in Self.categories {
            for row in rows {
                let hand = ChartCellExplainer.cards(category: category, row: row)
                #expect(hand != nil, "no hand for \(category) \(row)")
                guard let hand else { continue }
                for col in BasicStrategy.dealerCols {
                    let dealer = ChartCellExplainer.rank(forLabel: col)!
                    // The hand must land on exactly this cell's spot key, so the
                    // accuracy shown for a cell is that cell's own stats.
                    #expect(SpotID.key(cards: hand, dealerUp: dealer, canSplit: true)
                            == SpotID.key(category: category.rawValue, row: row, dealerCol: col))
                }
            }
        }
    }

    @Test func explanationMatchesTheChartForEveryCell() {
        for numDecks in [2, 6] {
            for h17 in [false, true] {
                for (category, rows) in Self.categories {
                    for row in rows {
                        for col in BasicStrategy.dealerCols {
                            let code = ChartLookup.code(category: category, row: row, dealerCol: col,
                                                        numDecks: numDecks, dealerHitsSoft17: h17)
                            let info = ChartCellExplainer.explain(category: category, row: row, dealerCol: col,
                                                                  numDecks: numDecks, dealerHitsSoft17: h17)
                            #expect(info?.code == code)
                            #expect(!(info?.reason.isEmpty ?? true))
                            // On screen copy never uses dashes.
                            #expect(!(info?.reason.contains("\u{2014}") ?? false))
                            #expect(!(info?.reason.contains("\u{2013}") ?? false))
                        }
                    }
                }
            }
        }
    }

    @Test func playNamesAndFallbacks() {
        let double = ChartCellExplainer.explain(category: .hard, row: "11", dealerCol: "6",
                                                numDecks: 6, dealerHitsSoft17: false)
        #expect(double?.playName == "Double")
        #expect(double?.fallback == "If you can't double, hit.")

        let ds = ChartCellExplainer.explain(category: .soft, row: "18", dealerCol: "6",
                                            numDecks: 6, dealerHitsSoft17: false)
        #expect(ds?.code == "Ds")
        #expect(ds?.fallback == "If you can't double, stand.")

        let split = ChartCellExplainer.explain(category: .pair, row: "8", dealerCol: "10",
                                               numDecks: 6, dealerHitsSoft17: false)
        #expect(split?.playName == "Split")
        #expect(split?.fallback == nil)
        #expect(split?.reason.contains("8s") == true)

        let stand = ChartCellExplainer.explain(category: .hard, row: "16", dealerCol: "6",
                                               numDecks: 6, dealerHitsSoft17: false)
        #expect(stand?.playName == "Stand")
    }

    @Test func explanationFollowsTheDealerRule() {
        // Hard 11 against an ace: hit when the dealer stands on soft 17, double when he hits.
        let s17 = ChartCellExplainer.explain(category: .hard, row: "11", dealerCol: "A",
                                             numDecks: 6, dealerHitsSoft17: false)
        let h17 = ChartCellExplainer.explain(category: .hard, row: "11", dealerCol: "A",
                                             numDecks: 6, dealerHitsSoft17: true)
        #expect(s17?.code == "H")
        #expect(h17?.code == "D")
    }

    @Test func unknownCellsHaveNoExplanation() {
        #expect(ChartCellExplainer.explain(category: .hard, row: "4", dealerCol: "6",
                                           numDecks: 6, dealerHitsSoft17: false) == nil)
        #expect(ChartCellExplainer.explain(category: .pair, row: "11", dealerCol: "6",
                                           numDecks: 6, dealerHitsSoft17: false) == nil)
    }

    // MARK: My accuracy levels

    @Test func levelsFollowTheBands() {
        #expect(ChartAccuracy.level(for: nil) == .unpracticed)
        #expect(ChartAccuracy.level(for: SpotStat(correct: 0, total: 0)) == .unpracticed)
        #expect(ChartAccuracy.level(for: SpotStat(correct: 9, total: 10)) == .solid)
        #expect(ChartAccuracy.level(for: SpotStat(correct: 17, total: 20)) == .solid)   // exactly 85%
        #expect(ChartAccuracy.level(for: SpotStat(correct: 7, total: 10)) == .working)
        #expect(ChartAccuracy.level(for: SpotStat(correct: 3, total: 5)) == .working)   // exactly 60%
        #expect(ChartAccuracy.level(for: SpotStat(correct: 5, total: 10)) == .leak)
    }

    @Test func oneOrTwoTriesNeverCountAsSolidOrLeak() {
        #expect(ChartAccuracy.level(for: SpotStat(correct: 1, total: 1)) == .early)
        #expect(ChartAccuracy.level(for: SpotStat(correct: 0, total: 2)) == .early)
        #expect(ChartAccuracy.level(for: SpotStat(correct: 3, total: 3)) == .solid)
    }

    @Test func percentOnlyReadsHundredOrZeroWhenItIsExact() {
        #expect(ChartAccuracy.percent(for: SpotStat(correct: 199, total: 200)) == 99)
        #expect(ChartAccuracy.percent(for: SpotStat(correct: 1, total: 200)) == 1)
        #expect(ChartAccuracy.percent(for: SpotStat(correct: 200, total: 200)) == 100)
        #expect(ChartAccuracy.percent(for: SpotStat(correct: 0, total: 4)) == 0)
        #expect(ChartAccuracy.percent(for: SpotStat(correct: 2, total: 3)) == 67)
    }

    // MARK: Which Play decisions count toward a cell

    private func key(_ cards: [Card], vs up: Rank, canDouble: Bool = true, canSplit: Bool = true,
                     h17: Bool = false, decks: Int = 6) -> String? {
        SpotAttribution.key(cards: cards, dealerUp: up, canDouble: canDouble, canSplit: canSplit,
                            dealerHitsSoft17: h17, numDecks: decks)
    }

    @Test func ordinaryHandsCountTowardTheirCell() {
        #expect(key(Self.hand(.five, .six), vs: .six) == "H11v6")
        #expect(key(Self.hand(.ace, .seven), vs: .nine) == "S18v9")
        #expect(key(Self.hand(.eight, .eight), vs: .ten) == "P8v10")
        // A three card hard 14 against a 10 is still the "hard 14 vs 10" question.
        #expect(key(Self.hand(.two, .five, .seven), vs: .ten, canDouble: false) == "H14v10")
    }

    @Test func handsThatCannotDoubleDoNotCountOnDoubleCells() {
        // Three card hard 11 vs 6: "hit" is right, but the cell says double.
        #expect(key(Self.hand(.two, .four, .five), vs: .six, canDouble: false) == nil)
        // Hard 9 and 10 the same way.
        #expect(key(Self.hand(.two, .three, .four), vs: .five, canDouble: false) == nil)
        // Soft 18 vs 6 is "double, else stand" on the chart.
        #expect(key(Self.hand(.ace, .seven), vs: .six, canDouble: false) == nil)
        // Cells that never double are unaffected.
        #expect(key(Self.hand(.ten, .six), vs: .ten, canDouble: false) == "H16v10")
        #expect(key(Self.hand(.ace, .seven), vs: .ten, canDouble: false) == "S18v10")
    }

    @Test func unsplittablePairsDoNotCount() {
        #expect(key(Self.hand(.eight, .eight), vs: .ten, canSplit: false) == nil)
    }

    @Test func cellsTheTableRulesFlipDoNotCount() {
        // Hard 11 vs ace: hit on the printed chart, double with H17.
        #expect(key(Self.hand(.five, .six), vs: .ace, h17: true) == nil)
        #expect(key(Self.hand(.five, .six), vs: .ace, h17: false) == "H11vA")
        // Double deck changes hard 11 vs ace too (double against everything).
        #expect(key(Self.hand(.five, .six), vs: .ace, decks: 2) == nil)
    }
}
