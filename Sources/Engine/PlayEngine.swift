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

@MainActor
@Observable
final class PlayEngine {
    // Settings (persisted across launches via UserDefaults)
    var numDecks = 6 { didSet { saveSettings() } }
    var dealerHitsSoft17 = false { didSet { saveSettings() } }
    var showCount = false { didSet { saveSettings() } }
    var showHandTotals = true { didSet { saveSettings() } }   // off = count your own hands, like a real table
    var betHints = false { didSet { saveSettings() } }
    var useDeviations = false { didSet { saveSettings() } }
    var soundOn = true { didSet { Sound.enabled = soundOn; saveSettings() } }
    var askCountChecks = false { didSet { saveSettings() } }
    var tableMinimum = 5.0 { didSet { saveSettings() } }
    var numHands = 1 {                               // spots played each round (face control)
        didSet {
            saveSettings()
            resizeSpots()
        }
    }

    // Session lifecycle — play happens in buy-in sessions: pick a stack, play
    // until you cash out or go broke, then start fresh at the buy-in screen.
    private(set) var sessionActive = false
    private(set) var sessionBuyIn = 0.0
    private(set) var sessionRounds = 0
    private(set) var sessionPeak = 0.0
    private(set) var sessionBiggestWin = 0.0
    private(set) var sessionBlackjacks = 0
    /// Receipt from the last completed session. Deliberately not persisted, so
    /// it only shows right after cashing out, not on every cold launch.
    private(set) var lastSummary: SessionSummary?

    // Mid-hand count check
    var countGuess = 0
    private(set) var countCheckActual = 0

    // Insurance side bet (offered when the dealer shows an ace)
    private(set) var insuranceBet = 0.0

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
    private let dealerResultPauseNanoseconds: UInt64 = 450_000_000

    #if DEBUG
    /// A deterministic hand used only by the UI regression test for the
    /// dealer-to-result transition: player 17, dealer 16 drawing and busting.
    private var settlementDelayTestDraws: [Card] =
        ProcessInfo.processInfo.arguments.contains("-uiTestDealerSettlementDelay")
        ? [
            Card(rank: .ten, suit: .spades),
            Card(rank: .ten, suit: .hearts),
            Card(rank: .seven, suit: .clubs),
            Card(rank: .six, suit: .diamonds),
            Card(rank: .ten, suit: .spades),
        ]
        : []

    private var isSettlementDelayUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestDealerSettlementDelay")
    }
    #endif

    private var settingsLoaded = false

    init(stats: Stats) {
        self.stats = stats
        loadSettings()
        loadSession()
        Sound.enabled = soundOn
        settingsLoaded = true
    }

    /// Session state loads unconditionally (unlike settings): every key
    /// defaults to zero/false, which is exactly the "no session" state.
    private func loadSession() {
        let d = UserDefaults.standard
        sessionActive = d.bool(forKey: "pe_sessionActive")
        sessionBuyIn = d.double(forKey: "pe_sessionBuyIn")
        sessionRounds = d.integer(forKey: "pe_sessionRounds")
        sessionPeak = d.double(forKey: "pe_sessionPeak")
        sessionBiggestWin = d.double(forKey: "pe_sessionBiggestWin")
        sessionBlackjacks = d.integer(forKey: "pe_sessionBlackjacks")
    }

    private func saveSession() {
        let d = UserDefaults.standard
        d.set(sessionActive, forKey: "pe_sessionActive")
        d.set(sessionBuyIn, forKey: "pe_sessionBuyIn")
        d.set(sessionRounds, forKey: "pe_sessionRounds")
        d.set(sessionPeak, forKey: "pe_sessionPeak")
        d.set(sessionBiggestWin, forKey: "pe_sessionBiggestWin")
        d.set(sessionBlackjacks, forKey: "pe_sessionBlackjacks")
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        guard d.object(forKey: "pe_saved") != nil else { return }  // keep defaults on first ever launch
        numDecks = d.integer(forKey: "pe_numDecks")
        dealerHitsSoft17 = d.bool(forKey: "pe_h17")
        showCount = d.bool(forKey: "pe_showCount")
        showHandTotals = d.object(forKey: "pe_showHandTotals") as? Bool ?? true
        betHints = d.bool(forKey: "pe_betHints")
        useDeviations = d.bool(forKey: "pe_deviations")
        soundOn = d.bool(forKey: "pe_sound")
        askCountChecks = d.bool(forKey: "pe_countChecks")
        tableMinimum = d.double(forKey: "pe_tableMin")
        numHands = min(3, max(1, d.integer(forKey: "pe_numHands")))
    }

    private func saveSettings() {
        guard settingsLoaded else { return }   // don't write while loading
        let d = UserDefaults.standard
        d.set(true, forKey: "pe_saved")
        d.set(numDecks, forKey: "pe_numDecks")
        d.set(dealerHitsSoft17, forKey: "pe_h17")
        d.set(showCount, forKey: "pe_showCount")
        d.set(showHandTotals, forKey: "pe_showHandTotals")
        d.set(betHints, forKey: "pe_betHints")
        d.set(useDeviations, forKey: "pe_deviations")
        d.set(soundOn, forKey: "pe_sound")
        d.set(askCountChecks, forKey: "pe_countChecks")
        d.set(tableMinimum, forKey: "pe_tableMin")
        d.set(numHands, forKey: "pe_numHands")
    }

    // MARK: - Session lifecycle

    /// Profit or loss since sitting down.
    var sessionNet: Double { bankroll - sessionBuyIn }

    /// Broke: not enough chips left to place even a table-minimum bet.
    var isFelted: Bool { sessionActive && bankroll < tableMinimum - 0.001 }

    /// Walking away is only allowed between rounds, like a real table.
    var canCashOut: Bool { sessionActive && (phase == .betting || phase == .done) }

    /// Sits down with a fresh stack. `buyIn` must cover at least one
    /// table-minimum bet or the session refuses to start.
    func startSession(buyIn: Double, minimum: Double, hands: Int) {
        guard !sessionActive, buyIn >= minimum, minimum > 0 else { return }
        tableMinimum = minimum
        numHands = min(3, max(1, hands))
        stats.setBankroll(buyIn)
        sessionActive = true
        sessionBuyIn = buyIn
        sessionRounds = 0
        sessionPeak = buyIn
        sessionBiggestWin = 0
        sessionBlackjacks = 0
        lastSummary = nil
        newRound()
        saveSession()
    }

    /// Ends the session between rounds and writes the receipt.
    func cashOut() {
        guard canCashOut else { return }
        lastSummary = SessionSummary(
            buyIn: sessionBuyIn,
            cashedOut: bankroll,
            rounds: sessionRounds,
            peak: sessionPeak,
            biggestWin: sessionBiggestWin,
            blackjacks: sessionBlackjacks,
            busted: isFelted
        )
        sessionActive = false
        tableMinimum = 5
        newRound()
        saveSession()
    }

    // MARK: - Derived

    var bankroll: Double { stats.data.bankroll }

    /// The chip tray for the current session — always sized to the buy-in
    /// and table minimum rather than a fixed set (see ChipSizing).
    var chipDenominations: [Double] { ChipSizing.denominations(buyIn: sessionBuyIn, tableMinimum: tableMinimum) }

    var currentHand: PlayerHand? {
        guard phase == .playing, hands.indices.contains(currentIndex) else { return nil }
        return hands[currentIndex]
    }

    var decksRemaining: Double { shoe.decksRemaining }

    var trueCount: Double {
        (Double(runningCount) / decksRemaining * 2).rounded() / 2
    }

    /// Simplified Hi-Lo bet ramp: bet the true count in units (min 1), capped
    /// by the spread. Ignores the bankroll; see `recommendedUnits`.
    var countUnits: Int {
        let tc = trueCount
        if tc < 2 { return 1 }
        return min(Int(tc.rounded(.down)), betSpreadCap)
    }

    /// The most one spot should carry for the current stack (see BetSizingEvaluator).
    var maxComfortableBet: Double {
        BetSizingEvaluator.maxBet(bankroll: bankroll, tableMinimum: tableMinimum, spreadCap: betSpreadCap)
    }

    /// The count ramp trimmed to what the stack can carry.
    var recommendedUnits: Int {
        BetSizingEvaluator.recommendedUnits(countUnits: countUnits, maxBet: maxComfortableBet,
                                            tableMinimum: tableMinimum)
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
        // Resplit cap is per SPOT (four hands each, i.e. three splits), like a
        // real table — a shared cap would let one busy spot eat the others'
        // split allowance in a multi-hand round.
        let handsFromThisSpot = hands.filter { $0.spotIndex == h.spotIndex }.count
        return h.cards[0].rank.strategyKey == h.cards[1].rank.strategyKey && handsFromThisSpot < 4
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

    /// Last round's per-spot wagers scaled by `multiplier` and mapped onto the
    /// current spot count (cycling if the count grew since that round).
    private func projectedRepeatBets(multiplier: Double) -> [Double] {
        guard !lastSpotBets.isEmpty else { return [] }
        return (0..<numHands).map { lastSpotBets[$0 % lastSpotBets.count] * multiplier }
    }

    /// Scales last round's per-spot wagers by `multiplier`, dropping the largest
    /// spots first if the total would exceed the bankroll. (Safety net only —
    /// canReplay/canReplayDouble gate callers on the projected total.)
    private func scaledLastBets(multiplier: Double) -> [Double] {
        var bets = projectedRepeatBets(multiplier: multiplier)
        var total = bets.reduce(0, +)
        while total > bankroll, let maxIdx = bets.indices.max(by: { bets[$0] < bets[$1] }), bets[maxIdx] > 0 {
            bets[maxIdx] = 0
            total = bets.reduce(0, +)
        }
        return bets
    }

    func repeatBet() {
        guard phase == .betting, canReplay else { return }
        spotBets = scaledLastBets(multiplier: 1)
    }

    /// Whether last round's wagers fit the bankroll at the CURRENT spot count —
    /// checking only the stored bets would let a grown spot count (or a shrunk
    /// bankroll) zero out spots and leave an un-dealable round.
    var canReplay: Bool {
        let total = projectedRepeatBets(multiplier: 1).reduce(0, +)
        return total > 0 && total <= bankroll + 0.001
    }

    var canReplayDouble: Bool {
        let total = projectedRepeatBets(multiplier: 2).reduce(0, +)
        return total > 0 && total <= bankroll + 0.001
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
        insuranceBet = 0
        spotBets = Array(repeating: 0, count: numHands)
        activeSpot = 0
    }

    // MARK: - Drawing

    private func draw() -> Card {
        #if DEBUG
        if !settlementDelayTestDraws.isEmpty {
            let card = settlementDelayTestDraws.removeFirst()
            runningCount += card.rank.hiLo
            return card
        }
        #endif
        if shoe.index >= shoe.cards.count { runningCount = 0 }
        let card = shoe.draw()
        runningCount += card.rank.hiLo
        return card
    }

    private func drawUncounted() -> Card {
        #if DEBUG
        if !settlementDelayTestDraws.isEmpty {
            return settlementDelayTestDraws.removeFirst()
        }
        #endif
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
        insuranceBet = 0
        hands = spotBets.enumerated().map { idx, bet in
            var h = PlayerHand()
            h.bet = bet
            h.spotIndex = idx
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

            // Ace up: insurance is offered BEFORE the peek, like a real table.
            // Skipped when the bankroll can't cover the premium.
            if dealer[0].rank == .ace && bankroll + 0.001 >= insuranceCost {
                phase = .insurance
                return
            }
            continueRoundAfterDeal()
        }
    }

    /// Everything that happens between the last dealt card (or the insurance
    /// decision) and the first player action: peek for a dealer natural,
    /// auto-stand player naturals, and optionally quiz the running count.
    private func continueRoundAfterDeal() {
        // Dealer natural ends the round for every spot. Move to .dealer first:
        // arriving here from .insurance would otherwise trip the phase guard
        // in finishRoundAfterDealerPause and leave the round hanging (and the
        // insurance buttons answerable twice).
        if evaluate(dealer).total == 21 {
            phase = .dealer
            finishRoundAfterDealerPause()
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

    // MARK: - Insurance

    /// The premium: half the round's total wager, the standard maximum.
    var insuranceCost: Double { ((totalWager / 2) * 100).rounded() / 100 }

    /// Resolves the insurance offer. Graded like any other decision: without
    /// deviations the correct answer is always no (basic strategy never
    /// insures); with deviations it flips to yes at true count +3 or higher.
    /// Not a chart cell, so it stays out of spot stats.
    func answerInsurance(take: Bool) {
        guard phase == .insurance else { return }
        let shouldTake = useDeviations && trueCount >= Deviations.insuranceIndex
        let ok = take == shouldTake
        stats.recordDecision(correct: ok, spotKey: nil)
        feedbackGood = ok
        if useDeviations {
            if ok {
                feedbackText = shouldTake
                    ? "Right. The count is high enough to insure (true count +3 or more)."
                    : "Right. Only insure at a true count of +3 or higher."
            } else {
                feedbackText = shouldTake
                    ? "The count says take insurance here (true count +3 or higher)."
                    : "Insurance is only worth it at a true count of +3 or higher."
            }
        } else {
            feedbackText = ok
                ? "Right. Basic strategy never takes insurance."
                : "Not quite. Basic strategy never takes insurance."
        }
        if take {
            insuranceBet = insuranceCost
            stats.adjustBankroll(-insuranceBet)
        }
        continueRoundAfterDeal()
    }

    func submitCountCheck() {
        guard phase == .countCheck else { return }
        let ok = countGuess == countCheckActual
        stats.recordCountCheck(correct: ok)
        feedbackGood = ok
        feedbackText = ok
            ? "Right. The running count is \(countCheckActual)."
            : "Running count was \(countCheckActual) (you said \(countGuess))."
        goToHandOrDealer(from: 0)
    }

    private func evaluateBet() {
        let tc = trueCount
        let rec = recommendedUnits
        let cap = maxComfortableBet
        let averageSpotBet = totalWager / Double(numHands)
        let verdict = BetSizingEvaluator.verdict(
            spotBet: averageSpotBet,
            countUnits: countUnits,
            tableMinimum: tableMinimum,
            bankroll: bankroll,
            spreadCap: betSpreadCap
        )
        let correct = verdict == .acceptable
        // Allowed (the stack can take it) but a counter would still bet the
        // minimum here. Coached, not scored as a mistake.
        let bigAtLowCount = correct && tc < 2 && averageSpotBet > tableMinimum * 3 + 0.001
        // The count wants more than the stack should carry.
        let stackLimited = countUnits > rec
        stats.recordBet(correct: correct)
        // The terse mode never hints at the count, so it only grades.
        betAdviceGood = correct && !(bigAtLowCount && betHints)

        if betHints {
            // Full coaching: reveals the count and the suggested bet.
            let tcStr = String(format: "%+.1f", tc)
            switch verdict {
            case .tooHigh:
                betAdviceText = "Too big for your stack. With \(money(bankroll)), keep each bet at \(money(cap)) or less."
            case .tooLow:
                betAdviceText = stackLimited
                    ? "The true count is \(tcStr). Bet more, up to \(money(recommendedBet)), the most your stack should carry."
                    : "The true count is \(tcStr). Bet more, about \(rec) units (\(money(recommendedBet)))."
            case .acceptable:
                if bigAtLowCount {
                    betAdviceText = "Your stack can take it, but with a true count of \(tcStr) the minimum (\(money(tableMinimum))) is the sharper bet."
                } else if tc < 2 {
                    betAdviceText = "Good. The true count is \(tcStr). Keep the bet near the table minimum here."
                } else {
                    betAdviceText = "Nice bet. With a true count of \(tcStr), that is close enough to \(rec) units."
                }
            }
        } else {
            // Terse verdict only, never reveals the count.
            switch verdict {
            case .acceptable:
                betAdviceText = "Good bet."
            case .tooHigh:
                betAdviceText = "Too much for your stack."
            case .tooLow:
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
            canSplit: canSplit(h),
            dealerHitsSoft17: dealerHitsSoft17
        )

        // Spot identity must come from the hand's SHAPE, not split legality —
        // canSplit(h) also checks bankroll and the resplit cap, and letting
        // those reclassify 8,8 as "hard 16" would corrupt the pair stats that
        // the heatmap, leaks list, and Smart quiz are built on. When a pair
        // can't legally be split, the graded question isn't the chart's pair
        // cell at all, so it stays out of spot stats entirely (spotKey nil).
        let isPairShape = h.cards.count == 2
            && h.cards[0].rank.strategyKey == h.cards[1].rank.strategyKey
        // The chart (and every spot stat built on it) is S17. In the three
        // cells H17 flips, the graded play no longer matches the chart cell,
        // so those decisions stay out of spot stats — same reasoning as
        // count deviations below.
        let chartAction = BasicStrategy.correctAction(
            cards: h.cards,
            dealerUp: dealerUpRank(),
            canDouble: canDouble(h),
            canSplit: canSplit(h)
        )
        let spotKey: String? = (isPairShape && !canSplit(h)) || chartAction != basic
            ? nil
            : SpotID.key(cards: h.cards, dealerUp: dealerUpRank(), canSplit: canSplit(h))

        if useDeviations {
            // Grade against the count-aware play; teach the index when it differs.
            let correct = Deviations.correctAction(
                cards: h.cards, dealerUp: dealerUpRank(), trueCount: trueCount,
                canDouble: canDouble(h), canSplit: canSplit(h),
                dealerHitsSoft17: dealerHitsSoft17
            )
            let dev = Deviations.matching(cards: h.cards, dealerUp: dealerUpRank())
            let isIndexPlay = correct != basic
            let ok = action == correct
            // When the count overrides the chart, the result says nothing about
            // the player's basic strategy — keep it out of spot accuracy.
            stats.recordDecision(correct: ok, spotKey: isIndexPlay ? nil : spotKey)
            if !ok, !isIndexPlay, let spotKey {
                stats.logMistake(spotKey: spotKey, chose: action.name, correctPlay: correct.name)
            }
            feedbackGood = ok
            if ok && isIndexPlay {
                feedbackText = "Nice index play: \(dev?.note ?? "Deviation")."
            } else if ok {
                feedbackText = "Correct. \(correct.name)."
            } else if isIndexPlay {
                feedbackText = "Deviation: \(dev?.note ?? "index play") says \(correct.name) (you chose \(action.name))."
            } else {
                feedbackText = "Not quite. Basic strategy says \(correct.name) (you chose \(action.name))."
            }
            return
        }

        let ok = action == basic
        stats.recordDecision(correct: ok, spotKey: spotKey)
        if !ok, let spotKey {
            stats.logMistake(spotKey: spotKey, chose: action.name, correctPlay: basic.name)
        }
        feedbackGood = ok
        feedbackText = ok
            ? "Correct! Basic strategy says \(basic.name)."
            : "Not quite. Basic strategy says \(basic.name) (you chose \(action.name))."
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
            Haptics.notify(-1)
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
            Haptics.notify(-1)
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
        newHand.spotIndex = hands[currentIndex].spotIndex   // resplit cap is per spot
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
        // The dealer only draws while a live hand can still be outdrawn. If
        // every live spot is a natural, the round settles now — a natural can
        // only push against a dealer natural, which the peek already ruled out.
        let anyContest = hands.contains { !$0.busted && !$0.isBlackjack }
        phase = .dealer
        dealerHoleHidden = false
        revealHole()
        if !anyLive || !anyContest {
            finishRoundAfterDealerPause()
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
                #if DEBUG
                let drawDelay: UInt64 = isSettlementDelayUITest ? 100_000_000 : 330_000_000
                #else
                let drawDelay: UInt64 = 330_000_000
                #endif
                try? await Task.sleep(nanoseconds: drawDelay)
                dealer.append(draw())
                cardTick()
            }
            finishRoundAfterDealerPause()
        }
    }

    /// Leaves the dealer's completed hand unobstructed long enough for the
    /// final card or hole-card flip to finish before any result effects begin.
    private func finishRoundAfterDealerPause() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: dealerResultPauseNanoseconds)
            guard phase == .dealer || phase == .dealing else { return }
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
            let playerBJ = hands[i].isBlackjack
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

        // Insurance settles against the dealer's hand: 2 to 1 on a dealer
        // natural, lost otherwise. The premium already left the bankroll when
        // it was taken.
        if insuranceBet > 0 {
            if dealerBJ {
                stats.adjustBankroll(insuranceBet * 3)   // stake back + 2 to 1
                net += insuranceBet * 2
            } else {
                net -= insuranceBet
            }
        }

        lastRoundNet = net
        phase = .done
        stats.pushBankrollPoint()

        sessionRounds += 1
        sessionPeak = max(sessionPeak, bankroll)
        sessionBiggestWin = max(sessionBiggestWin, net)
        sessionBlackjacks += hands.filter { $0.result == .blackjack }.count
        // Durable profit metric for the bankroll achievements: how far above
        // the buy-in this session has ever been. Unlike the live bankroll, it
        // can't be inflated by a big buy-in or erased by the next session.
        stats.recordSessionProfit(sessionPeak - sessionBuyIn)
        saveSession()

        if net > 0 {
            Haptics.notify(1)
            Sound.play(.win)
        } else if net < 0 {
            Haptics.notify(-1)
            Sound.play(.lose)
        } else {
            Haptics.notify(0)
            Sound.play(.push)
        }
    }

    // MARK: - Formatting

    func money(_ v: Double) -> String { Money.string(v) }
}
