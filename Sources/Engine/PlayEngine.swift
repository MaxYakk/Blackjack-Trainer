import Foundation
import Observation

@MainActor
@Observable
final class PlayEngine {
    /// Valid table shapes. Saved values outside these are pulled back in on
    /// load, and settings are clamped when changed.
    static let allowedDeckCounts = [2, 4, 6, 8]
    static let defaultDeckCount = 6
    static let spotRange = 1...3
    static let defaultTableMinimum = 5.0

    // Settings (persisted across launches via UserDefaults)
    var numDecks = 6 {
        didSet {
            let clamped = Self.clampDecks(numDecks)
            if clamped != numDecks { numDecks = clamped }   // re-entry doesn't re-fire didSet
            saveSettings()
            // Between rounds a new deck count takes effect now; mid-round it
            // waits for the round to finish (see reshuffleIfNeededBetweenRounds).
            if settingsLoaded && phase == .betting { reshuffleIfNeededBetweenRounds() }
        }
    }
    var dealerHitsSoft17 = false { didSet { saveSettings() } }
    var showCount = false { didSet { saveSettings() } }
    var showHandTotals = true { didSet { saveSettings() } }   // off = count your own hands, like a real table
    var betHints = false { didSet { saveSettings() } }
    var useDeviations = false { didSet { saveSettings() } }
    var soundOn = true { didSet { Sound.enabled = soundOn; saveSettings() } }
    var askCountChecks = false { didSet { saveSettings() } }
    var tableMinimum = PlayEngine.defaultTableMinimum {
        didSet {
            if !(tableMinimum.isFinite && tableMinimum > 0) { tableMinimum = Self.defaultTableMinimum }
            saveSettings()
        }
    }
    var numHands = 1 {                               // spots played each round (face control)
        didSet {
            let clamped = min(Self.spotRange.upperBound, max(Self.spotRange.lowerBound, numHands))
            if clamped != numHands { numHands = clamped }
            saveSettings()
            resizeSpots()
            // More spots need more cards behind the cut card.
            if settingsLoaded && phase == .betting { reshuffleIfNeededBetweenRounds() }
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

    /// True when the shoe was shuffled after the last round (cut card reached
    /// or deck count changed), so this round's bets start from a count of 0.
    /// Cleared when the next round is dealt. For a "Shuffling" notice.
    private(set) var shuffledForNextRound = false
    /// True if the shoe ran dry during the current round and the discards
    /// were reshuffled to finish it (very rare; the cut card reserves room
    /// for a heavy round). The count then restarts from the cards on the table.
    private(set) var shuffledMidRound = false

    private(set) var shoe = Shoe(numDecks: 6)
    private var pendingHoleCard: Card?
    private let stats: Stats
    private let defaults: UserDefaults

    /// Animation timing. Tests use `.instant` so rounds finish immediately.
    struct Pacing {
        var cardNanoseconds: UInt64 = 260_000_000
        var dealerDrawNanoseconds: UInt64 = 330_000_000
        var dealerResultNanoseconds: UInt64 = 450_000_000

        static let standard = Pacing()
        static let instant = Pacing(cardNanoseconds: 0, dealerDrawNanoseconds: 0, dealerResultNanoseconds: 0)
    }
    var pacing = Pacing.standard

    /// Bumped whenever a round is abandoned or replaced, so animation tasks
    /// still in flight from the old round stop instead of touching the new one.
    private var roundToken = 0

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

    init(stats: Stats, defaults: UserDefaults = .standard) {
        self.stats = stats
        self.defaults = defaults
        loadSettings()
        loadSession()
        shoe = Shoe(numDecks: numDecks)
        Sound.enabled = soundOn
        settingsLoaded = true
        stats.onReset { [weak self] in self?.endSessionAfterProgressReset() }
    }

    /// Session state loads unconditionally (unlike settings): every key
    /// defaults to zero/false, which is exactly the "no session" state.
    private func loadSession() {
        let d = defaults
        sessionActive = d.bool(forKey: PlaySessionStore.activeKey)
        sessionBuyIn = d.double(forKey: PlaySessionStore.buyInKey)
        sessionRounds = d.integer(forKey: PlaySessionStore.roundsKey)
        sessionPeak = d.double(forKey: PlaySessionStore.peakKey)
        sessionBiggestWin = d.double(forKey: PlaySessionStore.biggestWinKey)
        sessionBlackjacks = d.integer(forKey: PlaySessionStore.blackjacksKey)
        // A session with no real buy-in can't be scored; treat it as none.
        if sessionActive && !(sessionBuyIn.isFinite && sessionBuyIn > 0) {
            sessionActive = false
        }
    }

    private func saveSession() {
        let d = defaults
        d.set(sessionActive, forKey: PlaySessionStore.activeKey)
        d.set(sessionBuyIn, forKey: PlaySessionStore.buyInKey)
        d.set(sessionRounds, forKey: PlaySessionStore.roundsKey)
        d.set(sessionPeak, forKey: PlaySessionStore.peakKey)
        d.set(sessionBiggestWin, forKey: PlaySessionStore.biggestWinKey)
        d.set(sessionBlackjacks, forKey: PlaySessionStore.blackjacksKey)
    }

    /// Keeps the deck count to a shoe the table offers: a single deck
    /// becomes double deck (the nearest offered), anything else invalid
    /// goes back to the 6-deck default.
    static func clampDecks(_ n: Int) -> Int {
        if allowedDeckCounts.contains(n) { return n }
        return n == 1 ? 2 : defaultDeckCount
    }

    private func loadSettings() {
        let d = defaults
        guard d.object(forKey: "pe_saved") != nil else { return }  // keep defaults on first ever launch
        numDecks = Self.clampDecks(d.integer(forKey: "pe_numDecks"))
        dealerHitsSoft17 = d.bool(forKey: "pe_h17")
        showCount = d.bool(forKey: "pe_showCount")
        showHandTotals = d.object(forKey: "pe_showHandTotals") as? Bool ?? true
        betHints = d.bool(forKey: "pe_betHints")
        useDeviations = d.bool(forKey: "pe_deviations")
        soundOn = d.bool(forKey: "pe_sound")
        askCountChecks = d.bool(forKey: "pe_countChecks")
        let savedMinimum = d.double(forKey: "pe_tableMin")
        tableMinimum = savedMinimum.isFinite && savedMinimum > 0 ? savedMinimum : Self.defaultTableMinimum
        numHands = min(Self.spotRange.upperBound, max(Self.spotRange.lowerBound, d.integer(forKey: "pe_numHands")))
    }

    private func saveSettings() {
        guard settingsLoaded else { return }   // don't write while loading
        let d = defaults
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
        numHands = hands   // clamped by its didSet
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
        tableMinimum = Self.defaultTableMinimum
        newRound()
        saveSession()
    }

    /// Progress was reset: the old buy-in no longer matches the fresh stack,
    /// so end the session with no receipt and drop any round in progress
    /// (its chips went with the old stack).
    private func endSessionAfterProgressReset() {
        sessionActive = false
        sessionBuyIn = 0
        sessionRounds = 0
        sessionPeak = 0
        sessionBiggestWin = 0
        sessionBlackjacks = 0
        lastSummary = nil
        lastSpotBets = []
        lastRoundNet = 0
        tableMinimum = Self.defaultTableMinimum
        stats.abandonWager()
        newRound()
        PlaySessionStore.clear(in: defaults)
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
        roundToken += 1      // any animation still running belongs to the old round
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
        shuffledMidRound = false
        // Normally already done when the last round settled; this catches a
        // deck-count change or a round that was abandoned instead.
        reshuffleIfNeededBetweenRounds()
    }

    // MARK: - Shoe

    /// Cards this table shape should keep behind the cut card.
    private var roundReserve: Int { Shoe.heavyRoundCards(spots: numHands) }

    /// The between-rounds shuffle: when the cut card has come out (or the deck
    /// count changed), shuffle BEFORE the next bets, like a real dealer, so
    /// the player bets knowing the count restarted at 0.
    private func reshuffleIfNeededBetweenRounds() {
        if shoe.numDecks != numDecks {
            shoe = Shoe(numDecks: numDecks)
        } else if shoe.needsReshuffle(reserving: roundReserve) {
            shoe.reshuffle()
        } else {
            return
        }
        runningCount = 0
        shuffledForNextRound = true
    }

    /// Swaps in a specific shoe and starts its count at 0. Tests use it to
    /// stack exact hands; call it between rounds.
    func installShoe(_ newShoe: Shoe) {
        shoe = newShoe
        runningCount = 0
    }

    /// The shoe ran dry mid-round. Shuffle the discards (every card not on
    /// the table) and keep dealing. The count restarts from the cards still
    /// on the table, because they're the only ones missing from the new
    /// shoe; the hole card joins the count when it's flipped, as usual.
    private func reshuffleDiscardsMidRound() {
        let onTable = hands.flatMap(\.cards) + dealer
        shoe.reshuffle(excluding: onTable)
        runningCount = onTable
            .filter { $0.id != pendingHoleCard?.id }
            .reduce(0) { $0 + $1.rank.hiLo }
        shuffledMidRound = true
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
        if shoe.cardsRemaining <= 0 { reshuffleDiscardsMidRound() }
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
        if shoe.cardsRemaining <= 0 { reshuffleDiscardsMidRound() }
        return shoe.draw()
    }

    private func revealHole() {
        guard let card = pendingHoleCard else { return }
        runningCount += card.rank.hiLo
        pendingHoleCard = nil
    }

    private func pause() async {
        try? await Task.sleep(nanoseconds: pacing.cardNanoseconds)
    }

    private func cardTick() {
        Haptics.tap()
        Sound.play(.card)
    }

    // MARK: - Round flow

    func deal() {
        guard canDeal else { return }

        // No shuffle here: it happens between rounds, before betting, so the
        // bet is graded against the same count the player saw.
        // Grade the bet against the count BEFORE any new cards come out.
        evaluateBet()

        lastSpotBets = spotBets
        shuffledForNextRound = false
        shuffledMidRound = false
        stats.placeWager(totalWager)   // each spot's own wager, tracked until settled

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
        let token = roundToken

        Task { @MainActor in
            // Each step re-checks the round: a progress reset can abandon it mid-deal.
            // First card to each spot, then the dealer's up-card...
            for i in hands.indices {
                guard token == roundToken else { return }
                hands[i].cards.append(draw()); cardTick(); await pause()
            }
            guard token == roundToken else { return }
            dealer.append(draw()); cardTick(); await pause()                    // up-card (counted)
            // ...second card to each spot, then the dealer's hole card.
            for i in hands.indices {
                guard token == roundToken else { return }
                hands[i].cards.append(draw()); cardTick(); await pause()
            }
            guard token == roundToken else { return }
            let hole = drawUncounted(); dealer.append(hole); pendingHoleCard = hole; cardTick(); await pause()
            guard token == roundToken else { return }

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
            stats.placeWager(insuranceBet)
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
        // (3+ units already grades as too high, so this covers the 2-unit bet.)
        let bigAtLowCount = correct && tc < 2 && averageSpotBet > tableMinimum + 0.001
        // The count wants more than the stack should carry.
        let stackLimited = countUnits > rec
        // Too high can mean too much for the stack, or too much for the count.
        let overStack = BetSizingEvaluator.exceedsStack(
            spotBet: averageSpotBet, tableMinimum: tableMinimum,
            bankroll: bankroll, spreadCap: betSpreadCap)
        stats.recordBet(correct: correct)
        // The terse mode never hints at the count, so it only grades.
        betAdviceGood = correct && !(bigAtLowCount && betHints)

        if betHints {
            // Full coaching: reveals the count and the suggested bet.
            let tcStr = String(format: "%+.1f", tc)
            switch verdict {
            case .tooHigh:
                betAdviceText = overStack
                    ? "Too big for your chip count. With \(Money.chips(bankroll)), keep each bet at \(money(cap)) or less."
                    : "Too big for the count. The true count is \(tcStr), so bet about \(rec) unit\(rec == 1 ? "" : "s") (\(money(recommendedBet)))."
            case .tooLow:
                betAdviceText = stackLimited
                    ? "The true count is \(tcStr). Bet more, up to \(money(recommendedBet)), the most your chips should cover."
                    : "The true count is \(tcStr). Bet more, about \(rec) units (\(money(recommendedBet)))."
            case .acceptable:
                if bigAtLowCount {
                    betAdviceText = "Your chips can cover it, but with a true count of \(tcStr) the minimum (\(money(tableMinimum))) is the sharper bet."
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
                betAdviceText = overStack ? "Too much for your chip count." : "Too big for the count."
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
            dealerHitsSoft17: dealerHitsSoft17,
            numDecks: numDecks
        )

        // Spot identity must come from the hand's SHAPE, not split legality —
        // canSplit(h) also checks bankroll and the resplit cap, and letting
        // those reclassify 8,8 as "hard 16" would corrupt the pair stats that
        // the heatmap, leaks list, and Smart quiz are built on. When a pair
        // can't legally be split, the graded question isn't the chart's pair
        // cell at all, so it stays out of spot stats entirely (spotKey nil).
        let isPairShape = h.cards.count == 2
            && h.cards[0].rank.strategyKey == h.cards[1].rank.strategyKey
        // The chart (and every spot stat built on it) is the 4–8 deck S17
        // chart. In the cells H17 or double deck flips, the graded play no
        // longer matches the chart cell,
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
                dealerHitsSoft17: dealerHitsSoft17, numDecks: numDecks
            )
            // Same inputs as grading, so the note names the play that was graded
            // (8,8 vs 10 is a split, not "16 vs 10"; H17 and double deck use their indices).
            let dev = Deviations.matching(cards: h.cards, dealerUp: dealerUpRank(),
                                          canSplit: canSplit(h), dealerHitsSoft17: dealerHitsSoft17,
                                          numDecks: numDecks)
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
        stats.placeWager(hands[currentIndex].bet)   // matching wager
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
        stats.placeWager(newHand.bet)                    // second wager

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
            return
        }
        // A split hand that reaches 21 has nothing left to decide: stand it,
        // just like a hit that lands on 21. (Not a blackjack — it's from a split.)
        for i in [currentIndex, currentIndex + 1] where evaluate(hands[i].cards).total == 21 {
            hands[i].done = true
        }
        if hands[currentIndex].done { advance() }
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
        let token = roundToken
        Task { @MainActor in
            while true {
                let hv = evaluate(dealer)
                let mustHit = hv.total < 17 || (hv.total == 17 && hv.soft && dealerHitsSoft17)
                if !mustHit { break }
                #if DEBUG
                let drawDelay: UInt64 = isSettlementDelayUITest ? 100_000_000 : pacing.dealerDrawNanoseconds
                #else
                let drawDelay: UInt64 = pacing.dealerDrawNanoseconds
                #endif
                try? await Task.sleep(nanoseconds: drawDelay)
                guard token == roundToken else { return }
                dealer.append(draw())
                cardTick()
            }
            finishRoundAfterDealerPause()
        }
    }

    /// Leaves the dealer's completed hand unobstructed long enough for the
    /// final card or hole-card flip to finish before any result effects begin.
    private func finishRoundAfterDealerPause() {
        let token = roundToken
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: pacing.dealerResultNanoseconds)
            guard token == roundToken, phase == .dealer || phase == .dealing else { return }
            finishRound()
        }
    }

    private func finishRound() {
        dealerHoleHidden = false
        revealHole()
        let dv = evaluate(dealer)
        let dealerBJ = dv.total == 21 && dealer.count == 2
        var net = 0.0
        var payout = 0.0

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
            payout += ret
            net += ret - wagered
        }

        // Insurance settles against the dealer's hand: 2 to 1 on a dealer
        // natural, lost otherwise. The premium already left the bankroll when
        // it was taken.
        if insuranceBet > 0 {
            if dealerBJ {
                payout += insuranceBet * 3   // stake back + 2 to 1
                net += insuranceBet * 2
            } else {
                net -= insuranceBet
            }
        }

        // One step: pay out and clear the chips on the felt together, so a
        // closed app can never both pay a round and refund it.
        stats.settleRound(payout: payout)
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
        // Session counters save immediately; write the settled chips now too
        // so a hard kill can't leave them a round behind.
        stats.flush()
        // Cut card reached? Shuffle now, before the next bets (and before a
        // Rebet), so the next round's bet is graded on the count you see.
        reshuffleIfNeededBetweenRounds()

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
