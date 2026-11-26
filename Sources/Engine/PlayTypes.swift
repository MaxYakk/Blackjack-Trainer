import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Value types shared by the play table (moved out of PlayEngine.swift as-is).

enum HandResult: String, Equatable {
    case win = "Win"
    case lose = "Lose"
    case push = "Push"
    case bust = "Bust"
    case blackjack = "Blackjack!"
    case dealerBlackjack = "Dealer BJ"
}

enum GamePhase {
    case betting     // choosing chips
    case dealing     // cards being dealt (animated)
    case insurance   // dealer shows an ace: take insurance?
    case countCheck  // "what's the running count?" before acting
    case playing     // player acting
    case dealer      // dealer drawing
    case done        // round settled
}

/// Receipt for a completed table session, shown on the buy-in screen.
struct SessionSummary: Equatable {
    let buyIn: Double
    let cashedOut: Double
    let rounds: Int
    let peak: Double
    let biggestWin: Double
    let blackjacks: Int
    let busted: Bool

    var net: Double { cashedOut - buyIn }
}

struct PlayerHand: Identifiable {
    let id = UUID()
    var cards: [Card] = []
    var bet: Double = 0
    /// Which betting spot this hand came from — split hands inherit it, so
    /// the resplit cap can be enforced per spot rather than table-wide.
    var spotIndex = 0
    var done = false
    var busted = false
    var isDoubled = false
    var fromSplit = false
    var fromSplitAces = false
    var result: HandResult?

    var value: HandValue { evaluate(cards) }

    /// A natural: 21 on the first two cards of an original (unsplit) hand.
    var isBlackjack: Bool { cards.count == 2 && !fromSplit && evaluate(cards).total == 21 }
}

enum Haptics {
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
    static func notify(_ type: Int) {
        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        switch type {
        case 1: gen.notificationOccurred(.success)
        case -1: gen.notificationOccurred(.error)
        default: gen.notificationOccurred(.warning)
        }
        #endif
    }
}

/// The play session's saved keys (buy-in, rounds, peak...). Kept apart from
/// `StatsData` historically; `Stats.resetAll()` clears them so a reset also
/// ends the session.
enum PlaySessionStore {
    static let activeKey = "pe_sessionActive"
    static let buyInKey = "pe_sessionBuyIn"
    static let roundsKey = "pe_sessionRounds"
    static let peakKey = "pe_sessionPeak"
    static let biggestWinKey = "pe_sessionBiggestWin"
    static let blackjacksKey = "pe_sessionBlackjacks"

    static let allKeys = [activeKey, buyInKey, roundsKey, peakKey, biggestWinKey, blackjacksKey]

    static func clear(in defaults: UserDefaults) {
        for key in allKeys { defaults.removeObject(forKey: key) }
    }
}
