import SwiftUI

/// Everything the table says about a settled round: the headline, the chip
/// change, one detail line, and the colors. Built once from the engine so the
/// result card, the win toast and the VoiceOver announcement all agree.
struct RoundOutcome {
    enum Kind { case blackjack, win, push, loss }

    let kind: Kind
    let net: Double
    let title: String
    let amountText: String
    let detail: String

    @MainActor
    init(engine: PlayEngine) {
        let hands = engine.hands
        let net = engine.lastRoundNet
        let blackjacks = hands.filter { $0.result == .blackjack }.count
        let winners = hands.filter { $0.result == .win || $0.result == .blackjack }.count
        let dealerTotal = evaluate(engine.dealer).total

        self.net = net
        if net > 0.005 {
            kind = blackjacks > 0 ? .blackjack : .win
            title = blackjacks > 0 ? "Blackjack" : "Win"
            amountText = Money.signedChips(net)
            if blackjacks == 1 {
                detail = "Blackjack pays 3 to 2."
            } else if blackjacks > 1 {
                detail = "\(blackjacks) blackjacks, paid 3 to 2."
            } else if dealerTotal > 21 {
                detail = "Dealer went over 21."
            } else if hands.count > 1 {
                detail = "\(winners) of \(hands.count) hands won."
            } else {
                detail = "You beat the dealer's \(dealerTotal)."
            }
        } else if net < -0.005 {
            kind = .loss
            // "Dealer wins" would be wrong in a mixed round where one hand won
            // but the round still lost chips overall.
            title = winners > 0 ? "Dealer ahead" : "Dealer wins"
            amountText = "Lost \(Money.chips(-net))"
            if winners > 0 {
                detail = "\(winners) of \(hands.count) hands won. Dealer made \(dealerTotal)."
            } else if hands.allSatisfy({ $0.result == .bust }) {
                detail = "You went over 21."
            } else if hands.contains(where: { $0.result == .dealerBlackjack }) {
                detail = "Dealer had blackjack."
            } else {
                detail = "Dealer made \(dealerTotal)."
            }
        } else {
            kind = .push
            title = "Push"
            amountText = "Bet returned"
            detail = "Dealer made \(dealerTotal). Bets push."
        }
    }

    /// Coral marks a natural so it reads differently from an ordinary mint win.
    var tint: Color {
        switch kind {
        case .blackjack: return .warm
        case .win: return .positive
        case .push: return .textSecondary
        case .loss: return .negative
        }
    }

    var tintBackground: Color {
        switch kind {
        case .blackjack: return .warmBg
        case .win: return .positiveBg
        case .push: return .surfaceRaised
        case .loss: return .negativeBg
        }
    }

    var symbol: String {
        switch kind {
        case .blackjack: return "suit.spade.fill"
        case .win: return "arrow.up.circle.fill"
        case .push: return "equal.circle.fill"
        case .loss: return "arrow.down.circle.fill"
        }
    }

    /// One sentence for VoiceOver when the round settles.
    var announcement: String { "\(title). \(amountText). \(detail)" }
}
