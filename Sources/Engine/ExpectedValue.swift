import Foundation

/// Expected value of each play (Hit, Stand, Double, Split) for a hand against
/// a dealer up card, in units of the original bet (+1 = win one bet).
///
/// Infinite-deck approximation: every card has its natural probability
/// (1/13 each, 4/13 for ten-valued cards) no matter what has been dealt. It is
/// within a few hundredths of a bet of the exact 4–8 deck numbers, which is
/// all the green / yellow / red grading needs.
///
/// Rules (the ones the app deals): the dealer peeks, so every value against a
/// 10 or ace assumes the dealer does not have blackjack. Dealer stands or
/// hits soft 17. Double on any first two cards, double after split, split
/// aces get one card each (no resplit of aces), other pairs resplit up to
/// four hands, no surrender. A 21 after a split pays even money.
///
/// Validated against the Wizard of Odds infinite-deck table (see
/// ExpectedValueTests).
struct ExpectedValue: Sendable {
    /// The EV of each play for one decision. `nil` when the play isn't
    /// allowed (no double on three cards, no split on a non-pair).
    struct Plays: Equatable, Sendable {
        let stand: Double
        let hit: Double
        let double: Double?
        let split: Double?

        func value(of action: Action) -> Double? {
            switch action {
            case .stand: return stand
            case .hit: return hit
            case .double: return double
            case .split: return split
            }
        }

        /// The best allowed play and its EV.
        var best: (action: Action, ev: Double) {
            var top: (action: Action, ev: Double) = (.stand, stand)
            for (action, ev) in [(Action.hit, hit), (.double, double), (.split, split)] {
                if let ev, ev > top.ev + 1e-12 { top = (action, ev) }
            }
            return top
        }
    }

    let dealerHitsSoft17: Bool
    /// Most hands one spot may become by splitting (the table allows 4).
    /// `nil` = unlimited resplits (what the published infinite-deck table uses).
    let maxSplitHands: Int?

    /// Card values 2...10 and 11 (ace), with their infinite-deck odds.
    static let cardOdds: [(value: Int, p: Double)] =
        (2...9).map { ($0, 1.0 / 13) } + [(10, 4.0 / 13), (11, 1.0 / 13)]

    /// Dealer final totals, index 0...4 = 17...21, index 5 = bust.
    private let dealerOutcomes: [Int: [Double]]

    init(dealerHitsSoft17: Bool = false, maxSplitHands: Int? = 4) {
        self.dealerHitsSoft17 = dealerHitsSoft17
        self.maxSplitHands = maxSplitHands
        var outcomes: [Int: [Double]] = [:]
        for up in 2...11 {
            outcomes[up] = Self.dealerDistribution(up: up, hitsSoft17: dealerHitsSoft17)
        }
        dealerOutcomes = outcomes
    }

    // MARK: - Public lookups

    /// The EVs for a hand. `dealerUp` uses the card's blackjack value
    /// (2...10, ace = 11). `canSplit` only matters for a two-card pair.
    func plays(cards: [Card], dealerUp: Rank, canDouble: Bool, canSplit: Bool) -> Plays {
        let up = dealerUp.value
        let hv = evaluate(cards)
        let state = HandState(total: hv.total, soft: hv.soft)
        let isPair = cards.count == 2 && cards[0].rank.strategyKey == cards[1].rank.strategyKey
        let splitEV: Double? = (isPair && canSplit) ? split(pairValue: cards[0].rank.value, up: up) : nil
        return Plays(stand: stand(state, up: up),
                     hit: hit(state, up: up),
                     double: canDouble && cards.count == 2 ? double(state, up: up) : nil,
                     split: splitEV)
    }

    // MARK: - Hand states

    /// A hand's total and whether an ace is counted as 11.
    struct HandState: Hashable, Sendable {
        var total: Int
        var soft: Bool

        func adding(_ card: Int) -> HandState {
            var t = total + card
            var s = soft
            if card == 11 { s = true }
            if card == 11 && soft { t -= 10 }   // a second ace counts as 1
            if t > 21 && s { t -= 10; s = false }
            return HandState(total: t, soft: s)
        }

        var busted: Bool { total > 21 }
    }

    // MARK: - Dealer

    /// Final-total odds for a dealer up card, given the dealer has already
    /// peeked and does NOT have blackjack.
    private static func dealerDistribution(up: Int, hitsSoft17: Bool) -> [Double] {
        var memo: [HandState: [Double]] = [:]
        func finish(_ s: HandState) -> [Double] {
            if s.busted { return [0, 0, 0, 0, 0, 1] }
            let stands = s.total > 17 || (s.total == 17 && !(s.soft && hitsSoft17))
            if stands {
                var out = [Double](repeating: 0, count: 6)
                out[s.total - 17] = 1
                return out
            }
            if let cached = memo[s] { return cached }
            var out = [Double](repeating: 0, count: 6)
            for (card, p) in cardOdds {
                let next = finish(s.adding(card))
                for i in 0..<6 { out[i] += p * next[i] }
            }
            memo[s] = out
            return out
        }
        let start = HandState(total: up, soft: up == 11)
        // Hole card odds, conditioned on no dealer blackjack.
        let excluded = up == 11 ? 10 : (up == 10 ? 11 : nil)
        let holeOdds = cardOdds.filter { $0.value != excluded }
        let mass = holeOdds.reduce(0) { $0 + $1.p }
        var out = [Double](repeating: 0, count: 6)
        for (card, p) in holeOdds {
            let next = finish(start.adding(card))
            for i in 0..<6 { out[i] += (p / mass) * next[i] }
        }
        return out
    }

    // MARK: - Player plays

    /// Standing on `s` (a bust loses).
    func stand(_ s: HandState, up: Int) -> Double {
        guard !s.busted, let dealer = dealerOutcomes[up] else { return -1 }
        var ev = dealer[5]   // dealer busts
        for (i, p) in dealer.prefix(5).enumerated() {
            let d = 17 + i
            if s.total > d { ev += p } else if s.total < d { ev -= p }
        }
        return ev
    }

    /// Taking one card, then playing on with the better of hit and stand.
    func hit(_ s: HandState, up: Int) -> Double {
        var memo: [HandState: Double] = [:]
        func best(_ s: HandState) -> Double {
            if s.busted { return -1 }
            if s.total == 21 { return stand(s, up: up) }
            if let cached = memo[s] { return cached }
            let value = max(stand(s, up: up), hitOnce(s))
            memo[s] = value
            return value
        }
        func hitOnce(_ s: HandState) -> Double {
            Self.cardOdds.reduce(0) { $0 + $1.p * best(s.adding($1.value)) }
        }
        return hitOnce(s)
    }

    /// Doubling: twice the bet, exactly one more card.
    func double(_ s: HandState, up: Int) -> Double {
        2 * Self.cardOdds.reduce(0) { $0 + $1.p * stand(s.adding($1.value), up: up) }
    }

    /// Best of stand / hit / double for a two-card hand (doubling allowed).
    private func bestTwoCard(_ s: HandState, up: Int) -> Double {
        max(stand(s, up: up), hit(s, up: up), double(s, up: up))
    }

    /// Splitting a pair of `pairValue` (2...11). Total EV over all hands it
    /// becomes, in units of the original bet.
    func split(pairValue r: Int, up: Int) -> Double {
        let start = HandState(total: r, soft: r == 11)
        if r == 11 {
            // Split aces: one card each, no resplit. A,10 is 21, not blackjack.
            let one = Self.cardOdds.reduce(0) { $0 + $1.p * stand(start.adding($1.value), up: up) }
            return 2 * one
        }
        let pRepeat = Self.cardOdds.first { $0.value == r }?.p ?? 0
        // EV of one split hand that drew a card other than its pair card.
        let otherDraws = Self.cardOdds.filter { $0.value != r }
            .reduce(0) { $0 + $1.p * bestTwoCard(start.adding($1.value), up: up) }
        // Played as a pair that isn't split again (e.g. 8,8 as hard 16).
        let stuckPair = bestTwoCard(start.adding(r), up: up)
        guard let cap = maxSplitHands else {
            // Unlimited resplits, taken only when they pay: per hand,
            // E = other + pRepeat * 2E when resplitting, else other + pRepeat * stuck.
            let resplitting = otherDraws / (1 - 2 * pRepeat)
            let keeping = otherDraws + pRepeat * stuckPair
            return 2 * (2 * resplitting > stuckPair ? max(resplitting, keeping) : keeping)
        }
        // pending: split hands still waiting for their second card;
        // hands: how many hands the spot has now.
        var memo: [Int: Double] = [:]
        func total(pending: Int, hands: Int) -> Double {
            if pending == 0 { return 0 }
            let key = pending * 100 + hands
            if let cached = memo[key] { return cached }
            var ev = otherDraws + (1 - pRepeat) * total(pending: pending - 1, hands: hands)
            let keep = stuckPair + total(pending: pending - 1, hands: hands)
            if hands < cap {
                // Resplit only when it beats keeping the pair.
                ev += pRepeat * max(total(pending: pending + 1, hands: hands + 1), keep)
            } else {
                ev += pRepeat * keep
            }
            memo[key] = ev
            return ev
        }
        return total(pending: 2, hands: 2)
    }
}
