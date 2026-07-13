import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

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
    case countCheck  // "what's the running count?" before acting
    case playing     // player acting
    case dealer      // dealer drawing
    case done        // round settled
}

struct PlayerHand: Identifiable {
    let id = UUID()
    var cards: [Card] = []
    var bet: Double = 0
    var done = false
    var busted = false
    var isDoubled = false
    var fromSplit = false
    var fromSplitAces = false
    var result: HandResult?

    var value: HandValue { evaluate(cards) }
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

@MainActor
@Observable
final class PlayEngine {
    // Settings (persisted across launches via UserDefaults)
    var numDecks = 6 { didSet { saveSettings() } }
    var dealerHitsSoft17 = false { didSet { saveSettings() } }
    var showCount = false { didSet { saveSettings() } }
    var betHints = false { didSet { saveSettings() } }
    var useDeviations = false { didSet { saveSettings() } }
    var soundOn = true { didSet { Sound.enabled = soundOn; saveSettings() } }
    var askCountChecks = false { didSet { saveSettings() } }
    var tableMinimum = 1.0 { didSet { saveSettings() } }
    var numHands = 1 {                               // spots played each round (face control)
        didSet {
            saveSettings()
            resizeSpots()
        }
    }

    // Mid-hand count check
    var countGuess = 0
    private(set) var countCheckActual = 0

    // Table state
    private(set) var dealer: [Card] = []
    private(set) var dealerHoleHidden = true
    private(set) var hands: [PlayerHand] = []
    private(set) var currentIndex = 0
    private(set) var phase: GamePhase = .betting

    private(set) var feedbackText = ""
    private(set) var feedbackGood = false
    private(set) var betAdviceText = ""
    private(set) var betAdviceGood = true

    // Betting — one wager per spot, independently adjustable.
    private(set) var spotBets: [Double] = [0]
    var activeSpot = 0
    private(set) var lastSpotBets: [Double] = []
    private(set) var lastRoundNet = 0.0

    /// Convenience accessor for the currently-selected spot's wager (used by single-spot UI/tests).
    var currentBet: Double { spotBets.indices.contains(activeSpot) ? spotBets[activeSpot] : 0 }
    var lastBet: Double { lastSpotBets.first ?? 0 }

    // Counting
    private(set) var runningCount = 0
    private let betSpreadCap = 6

    private var shoe = Shoe(numDecks: 6)
    private var pendingHoleCard: Card?
    private let stats: Stats

    private var settingsLoaded = false

    init(stats: Stats) {
        self.stats = stats
        loadSettings()
        Sound.enabled = soundOn
        settingsLoaded = true
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        guard d.object(forKey: "pe_saved") != nil else { return }  // keep defaults on first ever launch
        numDecks = d.integer(forKey: "pe_numDecks")
        dealerHitsSoft17 = d.bool(forKey: "pe_h17")
        showCount = d.bool(forKey: "pe_showCount")
        betHints = d.bool(forKey: "pe_betHints")
        useDeviations = d.bool(forKey: "pe_deviations")
        soundOn = d.bool(forKey: "pe_sound")
        askCountChecks = d.bool(forKey: "pe_countChecks")
        tableMinimum = d.double(forKey: "pe_tableMin")
        numHands = min(2, max(1, d.integer(forKey: "pe_numHands")))
    }

    private func saveSettings() {
        guard settingsLoaded else { return }   // don't write while loading
        let d = UserDefaults.standard
        d.set(true, forKey: "pe_saved")
        d.set(numDecks, forKey: "pe_numDecks")
        d.set(dealerHitsSoft17, forKey: "pe_h17")
        d.set(showCount, forKey: "pe_showCount")
        d.set(betHints, forKey: "pe_betHints")
        d.set(useDeviations, forKey: "pe_deviations")
        d.set(soundOn, forKey: "pe_sound")
        d.set(askCountChecks, forKey: "pe_countChecks")
        d.set(tableMinimum, forKey: "pe_tableMin")
        d.set(numHands, forKey: "pe_numHands")
    }

    // MARK: - Derived

    var bankroll: Double { stats.data.bankroll }

    var currentHand: PlayerHand? {
        guard phase == .playing, hands.indices.contains(currentIndex) else { return nil }
        return hands[currentIndex]
    }

    var decksRemaining: Double { shoe.decksRemaining }

    var trueCount: Double {
        (Double(runningCount) / decksRemaining * 2).rounded() / 2
    }

    /// Simplified Hi-Lo bet ramp: bet the true count in units (min 1), capped by the spread.
    var recommendedUnits: Int {
        let tc = trueCount
        if tc < 2 { return 1 }
        return min(Int(tc.rounded(.down)), betSpreadCap)
    }

    var recommendedBet: Double { Double(recommendedUnits) * tableMinimum }

    var dealerUpValue: Int {
        guard let first = dealer.first else { return 0 }
        return evaluate([first]).total
    }

    /// Total amount put on the table this round (sum of each spot's independent wager).
    var totalWager: Double { spotBets.reduce(0, +) }

    var canDeal: Bool {
        phase == .betting
            && spotBets.allSatisfy { $0 >= tableMinimum }
            && totalWager <= bankroll + 0.001
    }

    var canHitOrStand: Bool { phase == .playing }

    func canDouble(_ h: PlayerHand) -> Bool {
        h.cards.count == 2 && !h.fromSplitAces && bankroll >= h.bet
    }

    func canSplit(_ h: PlayerHand) -> Bool {
        guard h.cards.count == 2, bankroll >= h.bet else { return false }
        return h.cards[0].rank.strategyKey == h.cards[1].rank.strategyKey && hands.count < numHands + 3
    }

    // MARK: - Betting phase

    /// Keeps `spotBets` sized to `numHands`, preserving existing wagers when possible.
    private func resizeSpots() {
        if spotBets.count < numHands {
            spotBets.append(contentsOf: repeatElement(0, count: numHands - spotBets.count))
        } else if spotBets.count > numHands {
            spotBets.removeLast(spotBets.count - numHands)
        }
        activeSpot = min(activeSpot, numHands - 1)
    }

    /// Whether adding this chip to the active spot keeps the total wager within the bankroll.
    func canAddChip(_ amount: Double) -> Bool {
        totalWager + amount <= bankroll + 0.001
    }

    func addChip(_ amount: Double) {
        guard phase == .betting, spotBets.indices.contains(activeSpot), canAddChip(amount) else { return }
        spotBets[activeSpot] = ((spotBets[activeSpot] + amount) * 100).rounded() / 100
        Haptics.tap()
        Sound.play(.chip)
    }

    func selectSpot(_ index: Int) {
        guard phase == .betting, spotBets.indices.contains(index) else { return }
        activeSpot = index
    }

    func clearBet() {
        guard phase == .betting, spotBets.indices.contains(activeSpot) else { return }
        spotBets[activeSpot] = 0
    }

    /// Scales last round's per-spot wagers by `multiplier`, dropping the largest
    /// spots first if the total would exceed the bankroll.
    private func scaledLastBets(multiplier: Double) -> [Double] {
        var bets = (0..<numHands).map { lastSpotBets[$0 % lastSpotBets.count] * multiplier }
        var total = bets.reduce(0, +)
        while total > bankroll, let maxIdx = bets.indices.max(by: { bets[$0] < bets[$1] }), bets[maxIdx] > 0 {
            bets[maxIdx] = 0
            total = bets.reduce(0, +)
        }
        return bets
    }

    func repeatBet() {
        guard phase == .betting, !lastSpotBets.isEmpty else { return }
        spotBets = scaledLastBets(multiplier: 1)
    }

    var canReplay: Bool {
        !lastSpotBets.isEmpty && lastSpotBets.reduce(0, +) > 0 && lastSpotBets.reduce(0, +) <= bankroll + 0.001
    }

    var canReplayDouble: Bool {
        !lastSpotBets.isEmpty && lastSpotBets.reduce(0, +) > 0 && lastSpotBets.reduce(0, +) * 2 <= bankroll + 0.001
    }

    /// Starts a new round with the same wager as last time and deals immediately.
    func replay() {
        guard phase == .done, canReplay else { return }
        newRound()
        spotBets = scaledLastBets(multiplier: 1)
        deal()
    }

    /// Starts a new round with double last round's wager and deals immediately.
    func replayDouble() {
        guard phase == .done, canReplayDouble else { return }
        newRound()
        spotBets = scaledLastBets(multiplier: 2)
        deal()
    }

    func newRound() {
        phase = .betting
        dealer = []
        hands = []
        dealerHoleHidden = true
        pendingHoleCard = nil
        feedbackText = ""
        betAdviceText = ""
        spotBets = Array(repeating: 0, count: numHands)
        activeSpot = 0
    }

    // MARK: - Drawing

    private func draw() -> Card {
        if shoe.index >= shoe.cards.count { runningCount = 0 }
        let card = shoe.draw()
        runningCount += card.rank.hiLo
        return card
    }

    private func drawUncounted() -> Card {
        if shoe.index >= shoe.cards.count { runningCount = 0 }
        return shoe.draw()
    }

    private func revealHole() {
        guard let card = pendingHoleCard else { return }
        runningCount += card.rank.hiLo
        pendingHoleCard = nil
    }

    private func pause() async {
        try? await Task.sleep(nanoseconds: 260_000_000)
    }

    private func cardTick() {
        Haptics.tap()
        Sound.play(.card)
    }

    // MARK: - Round flow

    func deal() {
        guard canDeal else { return }

        if shoe.numDecks != numDecks {
            shoe = Shoe(numDecks: numDecks)
            runningCount = 0
        } else if shoe.needsReshuffle {
            shoe.reshuffle()
            runningCount = 0
        }

        // Grade the bet against the count BEFORE any new cards come out.
        evaluateBet()

        lastSpotBets = spotBets
        stats.adjustBankroll(-totalWager)   // each spot's own wager

        dealer = []
        dealerHoleHidden = true
        pendingHoleCard = nil
        hands = spotBets.map { bet in
            var h = PlayerHand()
            h.bet = bet
            return h
        }
        currentIndex = 0
        feedbackText = ""
        lastRoundNet = 0
        phase = .dealing

        Task { @MainActor in
            // First card to each spot, then the dealer's up-card...
            for i in hands.indices { hands[i].cards.append(draw()); cardTick(); await pause() }
            dealer.append(draw()); cardTick(); await pause()                    // up-card (counted)
            // ...second card to each spot, then the dealer's hole card.
            for i in hands.indices { hands[i].cards.append(draw()); cardTick(); await pause() }
            let hole = drawUncounted(); dealer.append(hole); pendingHoleCard = hole; cardTick(); await pause()

            // Dealer natural ends the round for every spot.
            if evaluate(dealer).total == 21 {
                finishRound()
                return
            }
            // Any player natural auto-stands that spot.
            for i in hands.indices where evaluate(hands[i].cards).total == 21 {
                hands[i].done = true
            }
            // Optionally quiz the running count before the player acts (only if a spot still needs playing).
            let anyToPlay = hands.contains { !$0.done }
            if anyToPlay && askCountChecks && Int.random(in: 0..<100) < 40 {
                countCheckActual = runningCount
                countGuess = 0
                phase = .countCheck
            } else {
                goToHandOrDealer(from: 0)
            }
        }
    }

    func submitCountCheck() {
        guard phase == .countCheck else { return }
        let ok = countGuess == countCheckActual
        stats.recordCountCheck(correct: ok)
        feedbackGood = ok
        feedbackText = ok
            ? "Right — running count is \(countCheckActual)."
            : "Running count was \(countCheckActual) (you said \(countGuess))."
        goToHandOrDealer(from: 0)
    }

    private func evaluateBet() {
        let tc = trueCount
        let rec = recommendedUnits
        let averageSpotBet = totalWager / Double(numHands)
        let betUnits = Int((averageSpotBet / tableMinimum).rounded())
        let correct: Bool
        if tc < 2 {
            correct = betUnits <= 1                       // bet the minimum when the count is neutral/negative
        } else {
            correct = abs(betUnits - rec) <= 1 && betUnits >= 2  // ramp up (within a unit) when the count is hot
        }
        stats.recordBet(correct: correct)
        betAdviceGood = correct

        if betHints {
            // Full coaching — reveals the count and the suggested bet.
            let tcStr = String(format: "%+.1f", tc)
            if tc < 2 {
                betAdviceText = correct
                    ? "Good — true count \(tcStr). Flat-bet the minimum here."
                    : "True count \(tcStr) is low — you should bet the table minimum (\(money(tableMinimum)))."
            } else {
                betAdviceText = correct
                    ? "Nice ramp — true count \(tcStr), about \(rec) units."
                    : "True count \(tcStr) is hot — bet more, about \(rec) units (\(money(recommendedBet)))."
            }
        } else {
            // Terse verdict only — never reveals the count.
            if correct {
                betAdviceText = "Good bet."
            } else if betUnits > rec {
                betAdviceText = "You bet too much."
            } else {
                betAdviceText = "You bet too little."
            }
        }
    }

    // MARK: - Player actions

    private func dealerUpRank() -> Rank { dealer[0].rank }

    private func judge(_ action: Action) {
        guard hands.indices.contains(currentIndex) else { return }
        let h = hands[currentIndex]
        let basic = BasicStrategy.correctAction(
            cards: h.cards,
            dealerUp: dealerUpRank(),
            canDouble: canDouble(h),
            canSplit: canSplit(h)
        )

        if useDeviations {
            // Grade against the count-aware play; teach the index when it differs.
            let correct = Deviations.correctAction(
                cards: h.cards, dealerUp: dealerUpRank(), trueCount: trueCount,
                canDouble: canDouble(h), canSplit: canSplit(h)
            )
            let dev = Deviations.matching(cards: h.cards, dealerUp: dealerUpRank())
            let isIndexPlay = correct != basic
            let ok = action == correct
            stats.recordDecision(correct: ok)
            feedbackGood = ok
            if ok && isIndexPlay {
                feedbackText = "Index play! \(dev?.note ?? "Deviation") — nice."
            } else if ok {
                feedbackText = "Correct — \(correct.name)."
            } else if isIndexPlay {
                feedbackText = "Deviation: \(dev?.note ?? "index play") says \(correct.name) (you chose \(action.name))."
            } else {
                feedbackText = "Not quite — basic strategy says \(correct.name) (you chose \(action.name))."
            }
            return
        }

        let ok = action == basic
        stats.recordDecision(correct: ok)
        feedbackGood = ok
        feedbackText = ok
            ? "Correct! Basic strategy says \(basic.name)."
            : "Not quite — basic strategy says \(basic.name) (you chose \(action.name))."
    }

    func hit() {
        guard phase == .playing else { return }
        judge(.hit)
        hands[currentIndex].cards.append(draw())
        cardTick()
        let total = evaluate(hands[currentIndex].cards).total
        if total > 21 {
            hands[currentIndex].done = true
            hands[currentIndex].busted = true
            advance()
        } else if total == 21 {
            hands[currentIndex].done = true
            advance()
        }
    }

    func stand() {
        guard phase == .playing else { return }
        judge(.stand)
        hands[currentIndex].done = true
        advance()
    }

    func double() {
        guard phase == .playing, canDouble(hands[currentIndex]) else { return }
        judge(.double)
        stats.adjustBankroll(-hands[currentIndex].bet)   // matching wager
        hands[currentIndex].bet *= 2
        hands[currentIndex].isDoubled = true
        hands[currentIndex].cards.append(draw())
        cardTick()
        hands[currentIndex].done = true
        if evaluate(hands[currentIndex].cards).total > 21 {
            hands[currentIndex].busted = true
        }
        advance()
    }

    func split() {
        guard phase == .playing, canSplit(hands[currentIndex]) else { return }
        judge(.split)
        let isAces = hands[currentIndex].cards[0].rank == .ace
        let movedCard = hands[currentIndex].cards.removeLast()

        var newHand = PlayerHand()
        newHand.cards = [movedCard]
        newHand.bet = hands[currentIndex].bet
        newHand.fromSplit = true
        newHand.fromSplitAces = isAces
        stats.adjustBankroll(-newHand.bet)               // second wager

        hands[currentIndex].fromSplit = true
        hands[currentIndex].fromSplitAces = isAces
        hands[currentIndex].cards.append(draw())
        newHand.cards.append(draw())
        hands.insert(newHand, at: currentIndex + 1)
        cardTick()

        if isAces {
            hands[currentIndex].done = true
            hands[currentIndex + 1].done = true
            advance()
        }
    }

    private func advance() {
        goToHandOrDealer(from: currentIndex + 1)
    }

    private func goToHandOrDealer(from startIndex: Int) {
        if let next = hands.indices.first(where: { $0 >= startIndex && !hands[$0].done }) {
            currentIndex = next
            phase = .playing        // may be entered from .dealing (deal) or .countCheck
            return
        }
        let anyLive = hands.contains { !$0.busted }
        phase = .dealer
        dealerHoleHidden = false
        revealHole()
        if !anyLive {
            finishRound()
            return
        }
        playDealer()
    }

    private func playDealer() {
        Task { @MainActor in
            while true {
                let hv = evaluate(dealer)
                let mustHit = hv.total < 17 || (hv.total == 17 && hv.soft && dealerHitsSoft17)
                if !mustHit { break }
                try? await Task.sleep(nanoseconds: 450_000_000)
                dealer.append(draw())
                cardTick()
            }
            finishRound()
        }
    }

    private func finishRound() {
        dealerHoleHidden = false
        revealHole()
        let dv = evaluate(dealer)
        let dealerBJ = dv.total == 21 && dealer.count == 2
        var net = 0.0

        for i in hands.indices {
            let pv = evaluate(hands[i].cards)
            let playerBJ = pv.total == 21 && hands[i].cards.count == 2 && !hands[i].fromSplit
            let result: HandResult
            if pv.total > 21 {
                result = .bust
            } else if playerBJ && dealerBJ {
                result = .push
            } else if playerBJ {
                result = .blackjack
            } else if dealerBJ {
                result = .dealerBlackjack
            } else if dv.total > 21 || pv.total > dv.total {
                result = .win
            } else if pv.total < dv.total {
                result = .lose
            } else {
                result = .push
            }
            hands[i].result = result
            stats.recordHandResult(result)

            let wagered = hands[i].bet
            let ret: Double
            switch result {
            case .blackjack: ret = wagered * 2.5
            case .win: ret = wagered * 2
            case .push: ret = wagered
            case .lose, .bust, .dealerBlackjack: ret = 0
            }
            stats.adjustBankroll(ret)
            net += ret - wagered
        }

        lastRoundNet = net
        phase = .done
        stats.pushBankrollPoint()
        // Feedback is haptic only — a buzz on a loss, a light tap on a win. No ringtone.
        if net > 0 { Haptics.notify(1) }
        else if net < 0 { Haptics.notify(-1) }
        else { Haptics.notify(0) }
    }

    // MARK: - Formatting

    func money(_ v: Double) -> String { String(format: "$%.2f", v) }
}
