import Foundation
@testable import BlackjackTrainer

/// A throwaway UserDefaults domain per test, so tests never share saved
/// state with each other or with the app.
final class TestDefaults {
    let suiteName = "BlackjackTrainerTests.\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

/// Builds cards from short labels like "10s", "Ah", "7c".
func cards(_ labels: String...) -> [Card] {
    labels.map { label in
        let suitChar = label.last!
        let rankText = String(label.dropLast())
        let suit: Suit = switch suitChar {
        case "s": .spades
        case "h": .hearts
        case "d": .diamonds
        default: .clubs
        }
        return Card(rank: Rank(rawValue: rankText)!, suit: suit)
    }
}

/// Hi-Lo total of a set of cards.
func hiLoSum(_ cards: some Sequence<Card>) -> Int {
    cards.reduce(0) { $0 + $1.rank.hiLo }
}

extension Shoe {
    /// The cards not yet dealt.
    var undealt: ArraySlice<Card> { cards[index...] }
}

@MainActor
func waitUntil(_ condition: () -> Bool) async {
    for _ in 0..<2000 {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }
}

/// A play table on its own defaults, sounds off, animations instant.
@MainActor
func makeTable(_ store: TestDefaults, buyIn: Double = 500, minimum: Double = 5, hands: Int = 1)
    -> (Stats, PlayEngine) {
    let stats = Stats(defaults: store.defaults)
    let engine = PlayEngine(stats: stats, defaults: store.defaults)
    engine.soundOn = false
    engine.pacing = .instant
    engine.startSession(buyIn: buyIn, minimum: minimum, hands: hands)
    return (stats, engine)
}

/// Bets `amount` on every spot.
@MainActor
func betEverySpot(_ engine: PlayEngine, _ amount: Double) {
    for spot in 0..<engine.numHands {
        engine.selectSpot(spot)
        engine.addChip(amount)
    }
}

/// Deals and waits until the player has something to do or the round is over.
@MainActor
func dealAndWait(_ engine: PlayEngine) async {
    engine.deal()
    await waitUntil { engine.phase != .dealing }
}

/// Stands every hand (declining insurance) and waits for settlement.
@MainActor
func standOut(_ engine: PlayEngine) async {
    if engine.phase == .insurance { engine.answerInsurance(take: false) }
    if engine.phase == .countCheck { engine.submitCountCheck() }
    while engine.phase == .playing { engine.stand() }
    await waitUntil { engine.phase == .done }
}
