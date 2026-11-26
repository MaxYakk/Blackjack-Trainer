import Foundation
import Testing
@testable import BlackjackTrainer

/// Double-deck grading, checked cell by cell against the published charts
/// (wizardofodds.com/games/blackjack/strategy/2-decks/ and the
/// blackjackinfo.com strategy engine: 2 decks, DAS, no surrender; both agree).
struct DoubleDeckStrategyTests {
    private static let ups: [Rank] = [.two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .ace]

    /// Two-card hands for each chart row.
    private static let hardHands: [(String, Rank, Rank)] = [
        ("8", .five, .three), ("9", .five, .four), ("10", .six, .four), ("11", .six, .five),
        ("12", .ten, .two), ("13", .ten, .three), ("14", .ten, .four), ("15", .ten, .five),
        ("16", .ten, .six), ("17", .ten, .seven),
    ]

    private static let hardS17: [String: String] = [
        "8":  "H H H H H H H H H H",
        "9":  "D D D D D H H H H H",
        "10": "D D D D D D D D H H",
        "11": "D D D D D D D D D D",
        "12": "H H S S S H H H H H",
        "13": "S S S S S H H H H H",
        "14": "S S S S S H H H H H",
        "15": "S S S S S H H H H H",
        "16": "S S S S S H H H H H",
        "17": "S S S S S S S S S S",
    ]

    private static let softS17: [Rank: String] = [
        .two:   "H H H D D H H H H H",
        .three: "H H H D D H H H H H",
        .four:  "H H D D D H H H H H",
        .five:  "H H D D D H H H H H",
        .six:   "H D D D D H H H H H",
        .seven: "S Ds Ds Ds Ds S S H H H",
        .eight: "S S S S S S S S S S",
        .nine:  "S S S S S S S S S S",
    ]

    private static let softH17: [Rank: String] = softS17.merging([
        .three: "H H D D D H H H H H",
        .seven: "Ds Ds Ds Ds Ds S S H H H",
        .eight: "S S S S Ds S S S S S",
    ]) { _, h17 in h17 }

    /// Same under S17 and H17.
    private static let pairRows: [Rank: String] = [
        .two:   "P P P P P P H H H H",
        .three: "P P P P P P H H H H",
        .four:  "H H H P P H H H H H",
        .five:  "D D D D D D D D H H",
        .six:   "P P P P P P H H H H",
        .seven: "P P P P P P P H H H",
        .eight: "P P P P P P P P P P",
        .nine:  "P P P P P S P P S S",
        .ten:   "S S S S S S S S S S",
        .ace:   "P P P P P P P P P P",
    ]

    private static func action(_ code: Substring) -> Action {
        switch code {
        case "D", "Ds": return .double
        case "P": return .split
        case "S": return .stand
        default: return .hit
        }
    }

    private static func check(_ cards: [Card], row: String, h17: Bool, label: String) {
        let codes = row.split(separator: " ")
        for (up, code) in zip(ups, codes) {
            let got = BasicStrategy.correctAction(cards: cards, dealerUp: up, canDouble: true,
                                                  canSplit: true, dealerHitsSoft17: h17, numDecks: 2)
            #expect(got == action(code), "\(label) vs \(up.rawValue) (\(h17 ? "H17" : "S17")): got \(got)")
        }
    }

    @Test(arguments: [false, true])
    func everyCellMatchesThePublishedChart(h17: Bool) {
        for (label, a, b) in Self.hardHands {
            Self.check([Card(rank: a, suit: .spades), Card(rank: b, suit: .hearts)],
                       row: Self.hardS17[label] ?? "", h17: h17, label: "hard \(label)")
        }
        for (other, row) in h17 ? Self.softH17 : Self.softS17 {
            Self.check([Card(rank: .ace, suit: .spades), Card(rank: other, suit: .hearts)],
                       row: row, h17: h17, label: "A,\(other.rawValue)")
        }
        for (rank, row) in Self.pairRows {
            Self.check([Card(rank: rank, suit: .spades), Card(rank: rank, suit: .hearts)],
                       row: row, h17: h17, label: "\(rank.rawValue),\(rank.rawValue)")
        }
    }

    @Test func fourToEightDeckGamesKeepTheirChart() {
        let nine = [Card(rank: .five, suit: .spades), Card(rank: .four, suit: .hearts)]
        let sixes = [Card(rank: .six, suit: .spades), Card(rank: .six, suit: .hearts)]
        for decks in [4, 6, 8] {
            #expect(BasicStrategy.correctAction(cards: nine, dealerUp: .two, canDouble: true,
                                                canSplit: true, numDecks: decks) == .hit)
            #expect(BasicStrategy.correctAction(cards: sixes, dealerUp: .seven, canDouble: true,
                                                canSplit: true, numDecks: decks) == .hit)
        }
        #expect(BasicStrategy.correctAction(cards: nine, dealerUp: .two, canDouble: true,
                                            canSplit: true, numDecks: 2) == .double)
    }

    // MARK: Index plays in double deck

    private static func countPlay(_ a: Rank, _ b: Rank, vs up: Rank, tc: Double,
                                  h17: Bool = false) -> Action {
        Deviations.correctAction(cards: [Card(rank: a, suit: .spades), Card(rank: b, suit: .hearts)],
                                 dealerUp: up, trueCount: tc, canDouble: true, canSplit: true,
                                 dealerHitsSoft17: h17, numDecks: 2)
    }

    @Test func playsBasicStrategyAlreadyDoublesAreNotReversed() {
        // 11 vs A and 9 vs 2 are basic-strategy doubles in double deck.
        for tc in [-3.0, 0, 2] {
            #expect(Self.countPlay(.six, .five, vs: .ace, tc: tc) == .double)
            #expect(Self.countPlay(.six, .five, vs: .ace, tc: tc, h17: true) == .double)
            #expect(Self.countPlay(.five, .four, vs: .two, tc: tc) == .double)
        }
        #expect(Deviations.matching(cards: [Card(rank: .six, suit: .spades), Card(rank: .five, suit: .hearts)],
                                    dealerUp: .ace, numDecks: 2) == nil)
    }

    @Test func otherIndexPlaysStillApplyInDoubleDeck() {
        #expect(Self.countPlay(.ten, .six, vs: .ten, tc: 0) == .stand)
        #expect(Self.countPlay(.ten, .six, vs: .ten, tc: -1) == .hit)
        #expect(Self.countPlay(.ten, .king, vs: .six, tc: 4) == .split)
        #expect(Self.countPlay(.six, .four, vs: .ace, tc: 4) == .double)
        // 6,6 vs 7 splits in double deck; no count play overrides it.
        #expect(Self.countPlay(.six, .six, vs: .seven, tc: -5) == .split)
    }
}
