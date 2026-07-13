import Foundation

enum Suit: String, CaseIterable, Codable {
    case spades = "♠"
    case hearts = "♥"
    case diamonds = "♦"
    case clubs = "♣"

    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum Rank: String, CaseIterable, Codable {
    case two = "2", three = "3", four = "4", five = "5", six = "6"
    case seven = "7", eight = "8", nine = "9", ten = "10"
    case jack = "J", queen = "Q", king = "K", ace = "A"

    /// Blackjack value; ace counts as 11 here and is reduced later when busting.
    var value: Int {
        switch self {
        case .ace: return 11
        case .ten, .jack, .queen, .king: return 10
        default: return Int(rawValue) ?? 0
        }
    }

    /// Normalized label used by the strategy tables (all 10-value cards become "10").
    var strategyKey: String {
        switch self {
        case .ten, .jack, .queen, .king: return "10"
        default: return rawValue
        }
    }

    /// Hi-Lo running-count contribution.
    var hiLo: Int {
        switch self {
        case .two, .three, .four, .five, .six: return 1
        case .seven, .eight, .nine: return 0
        default: return -1
        }
    }
}

struct Card: Identifiable, Equatable, Codable {
    let id: UUID
    let rank: Rank
    let suit: Suit

    init(rank: Rank, suit: Suit) {
        self.id = UUID()
        self.rank = rank
        self.suit = suit
    }

    var label: String { rank.rawValue + suit.rawValue }
}

struct HandValue {
    let total: Int
    let soft: Bool
}

/// Best value of a set of cards, reducing aces from 11 to 1 as needed.
func evaluate(_ cards: [Card]) -> HandValue {
    var total = 0
    var aces = 0
    for c in cards {
        total += c.rank.value
        if c.rank == .ace { aces += 1 }
    }
    while total > 21 && aces > 0 {
        total -= 10
        aces -= 1
    }
    return HandValue(total: total, soft: aces > 0)
}

struct Shoe {
    private(set) var cards: [Card] = []
    private(set) var index = 0
    let numDecks: Int

    init(numDecks: Int) {
        self.numDecks = numDecks
        reshuffle()
    }

    mutating func reshuffle() {
        var built: [Card] = []
        built.reserveCapacity(numDecks * 52)
        for _ in 0..<numDecks {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    built.append(Card(rank: rank, suit: suit))
                }
            }
        }
        built.shuffle()
        cards = built
        index = 0
    }

    var cardsRemaining: Int { cards.count - index }
    var decksRemaining: Double { max(Double(cardsRemaining) / 52.0, 0.25) }
    var needsReshuffle: Bool { cardsRemaining < Int(Double(numDecks * 52) * 0.25) }

    mutating func draw() -> Card {
        if index >= cards.count { reshuffle() }
        let card = cards[index]
        index += 1
        return card
    }
}
