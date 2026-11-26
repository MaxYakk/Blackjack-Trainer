import Foundation
import Testing
@testable import BlackjackTrainer

struct QuizReasonTests {
    private func reason(_ labels: String..., dealer: Rank) -> String {
        let hand = cards(labels[0], labels[1])
        let isPair = hand[0].rank.strategyKey == hand[1].rank.strategyKey
        return QuizReasons.explain(cards: hand, dealerUp: dealer, canSplit: isPair)
    }

    @Test func everyTwoCardHandGetsACleanReasonThatNamesTheRightMove() {
        let verb: [Action: String] = [.hit: "hit", .stand: "stand", .double: "double", .split: "split"]
        for a in Rank.allCases {
            for b in Rank.allCases {
                for dealer in Rank.allCases {
                    let hand = [Card(rank: a, suit: .spades), Card(rank: b, suit: .hearts)]
                    let isPair = a.strategyKey == b.strategyKey
                    let correct = BasicStrategy.correctAction(cards: hand, dealerUp: dealer,
                                                              canDouble: true, canSplit: isPair)
                    let text = QuizReasons.explain(cards: hand, dealerUp: dealer, canSplit: isPair)
                    #expect(!text.isEmpty)
                    #expect(text.count <= 120, "\(text)")
                    for dash in ["-", "\u{2013}", "\u{2014}", "\u{2212}"] {
                        #expect(!text.contains(dash), "\(text)")
                    }
                    #expect(text.lowercased().contains(verb[correct]!),
                            "\(a.rawValue),\(b.rawValue) vs \(dealer.rawValue) is \(correct): \(text)")
                }
            }
        }
    }

    @Test func keyReasonsAreAccurate() {
        #expect(reason("8s", "8h", dealer: .ten).contains("Always split 8s"))
        #expect(reason("As", "Ah", dealer: .six).contains("Always split aces"))
        #expect(reason("9s", "9h", dealer: .five).contains("Dealer 5 is weak"))
        #expect(reason("10s", "Kh", dealer: .six).contains("Stand on 20"))
        #expect(reason("10s", "3h", dealer: .six).contains("Dealer 6 busts often"))
        #expect(reason("10s", "6h", dealer: .ten).contains("Dealer 10 is strong"))
        #expect(reason("10s", "2h", dealer: .three).contains("busts a little less often"))
        #expect(reason("5s", "6h", dealer: .ten).contains("any 10 makes 21"))
        #expect(reason("5s", "6h", dealer: .ace).contains("dealer ace is too strong"))
        #expect(reason("As", "7h", dealer: .four).contains("protects you from busting"))
        #expect(reason("As", "7h", dealer: .nine).contains("soft 18 can't bust"))
        #expect(reason("As", "7h", dealer: .eight).contains("good enough to stand"))
    }

    @Test func everyDifficultyHasAOneLineSummary() {
        for difficulty in QuizDifficulty.allCases {
            #expect(!difficulty.summary.isEmpty)
            #expect(difficulty.summary.count <= 100, "\(difficulty.summary)")
        }
    }

    @Test @MainActor func answeringStoresTheReasonAndNextClearsIt() {
        let store = TestDefaults()
        let engine = QuizEngine(stats: Stats(defaults: store.defaults))
        #expect(engine.reason.isEmpty)
        engine.answer(.hit)
        #expect(!engine.reason.isEmpty)
        #expect(engine.answered)
        engine.next()
        #expect(engine.reason.isEmpty)
    }
}

struct ChartLookupTests {
    /// A hand that BasicStrategy classes as the given chart row.
    private func hand(_ category: ChartLookup.Category, row: String) -> [Card] {
        switch category {
        case .hard:
            let total = Int(row)!
            let pairs: [Int: (Rank, Rank)] = [
                5: (.two, .three), 6: (.two, .four), 7: (.two, .five), 8: (.three, .five),
                9: (.four, .five), 10: (.four, .six), 11: (.five, .six), 12: (.ten, .two),
                13: (.ten, .three), 14: (.ten, .four), 15: (.ten, .five), 16: (.ten, .six),
                17: (.ten, .seven),
            ]
            let p = pairs[total]!
            return [Card(rank: p.0, suit: .spades), Card(rank: p.1, suit: .hearts)]
        case .soft:
            let other = Rank.allCases.first { $0.value == Int(row)! - 11 }!
            return [Card(rank: .ace, suit: .spades), Card(rank: other, suit: .hearts)]
        case .pair:
            let rank = Rank.allCases.first { $0.strategyKey == row }!
            return [Card(rank: rank, suit: .spades), Card(rank: rank, suit: .hearts)]
        }
    }

    private func action(for code: String) -> Action {
        switch code {
        case "H": return .hit
        case "S": return .stand
        case "D", "Ds": return .double
        default: return .split
        }
    }

    @Test func everyChartCellMatchesWhatTheGameGrades() {
        let hardRows = (5...17).map(String.init)
        let softRows = (13...20).map(String.init)
        let pairRows = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "A"]
        let rankFor: [String: Rank] = ["2": .two, "3": .three, "4": .four, "5": .five, "6": .six,
                                       "7": .seven, "8": .eight, "9": .nine, "10": .ten, "A": .ace]
        for decks in [2, 4, 6, 8] {
            for h17 in [false, true] {
                for (category, rows) in [(ChartLookup.Category.hard, hardRows),
                                         (.soft, softRows), (.pair, pairRows)] {
                    for row in rows {
                        for col in BasicStrategy.dealerCols {
                            let code = ChartLookup.code(category: category, row: row, dealerCol: col,
                                                        numDecks: decks, dealerHitsSoft17: h17)
                            #expect(code != nil)
                            guard let code else { continue }
                            // Soft 12 does not exist here, so skip the "A,A" soft row.
                            let cards = hand(category, row: row)
                            let graded = BasicStrategy.correctAction(
                                cards: cards, dealerUp: rankFor[col]!, canDouble: true,
                                canSplit: category == .pair,
                                dealerHitsSoft17: h17, numDecks: decks)
                            #expect(graded == action(for: code),
                                    "\(category) \(row) vs \(col), \(decks) decks, h17 \(h17): chart \(code), graded \(graded)")
                        }
                    }
                }
            }
        }
    }

    @Test func h17ChangesShowOnlyWhenTheDealerHitsSoft17() {
        let s17 = ChartLookup.code(category: .hard, row: "11", dealerCol: "A", numDecks: 6, dealerHitsSoft17: false)
        let h17 = ChartLookup.code(category: .hard, row: "11", dealerCol: "A", numDecks: 6, dealerHitsSoft17: true)
        #expect(s17 == "H" && h17 == "D")
        let softS17 = ChartLookup.code(category: .soft, row: "18", dealerCol: "2", numDecks: 6, dealerHitsSoft17: false)
        let softH17 = ChartLookup.code(category: .soft, row: "18", dealerCol: "2", numDecks: 6, dealerHitsSoft17: true)
        #expect(softS17 == "S" && softH17 == "Ds")
    }

    @Test func doubleDeckUsesItsOwnChart() {
        #expect(ChartLookup.code(category: .hard, row: "9", dealerCol: "2", numDecks: 2, dealerHitsSoft17: false) == "D")
        #expect(ChartLookup.code(category: .hard, row: "9", dealerCol: "2", numDecks: 6, dealerHitsSoft17: false) == "H")
        #expect(ChartLookup.code(category: .hard, row: "11", dealerCol: "A", numDecks: 2, dealerHitsSoft17: false) == "D")
    }

    @Test func unknownCellsReturnNil() {
        #expect(ChartLookup.code(category: .hard, row: "99", dealerCol: "2", numDecks: 6, dealerHitsSoft17: false) == nil)
        #expect(ChartLookup.code(category: .hard, row: "10", dealerCol: "Z", numDecks: 6, dealerHitsSoft17: false) == nil)
    }
}
