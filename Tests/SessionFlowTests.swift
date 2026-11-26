import Foundation

// Headless check of the play-session lifecycle: buy in, track the round,
// cash out with a receipt, and detect going broke.
//
// Compile alongside:
//   Sources/Engine/{PlayEngine,Cards,BasicStrategy,BetSizing,Sound,SpotID,SpotCatalog}.swift
//   Sources/Store/{Stats,ProgressMetrics,SkillRating,Achievements}.swift

@main
struct SessionFlowTests {
    static func main() {
        MainActor.assumeIsolated { run() }
    }

    @MainActor
    private static func run() {
        // Fresh defaults so a previous run's persisted session can't leak in.
        let d = UserDefaults.standard
        for key in ["pe_saved", "pe_sessionActive", "pe_sessionBuyIn", "pe_sessionRounds",
                    "pe_sessionPeak", "pe_sessionBiggestWin", "pe_sessionBlackjacks",
                    "blackjack_stats_v1"] {
            d.removeObject(forKey: key)
        }

        let stats = Stats()
        let engine = PlayEngine(stats: stats)
        precondition(!engine.sessionActive, "No session should exist on first launch")
        precondition(engine.tableMinimum == 5, "A fresh table should default to a $5 minimum")

        // Buying in seeds the stack and applies the chosen table shape.
        engine.startSession(buyIn: 500, minimum: 25, hands: 2)
        precondition(engine.sessionActive, "Session should start")
        precondition(engine.bankroll == 500, "Buy in should seed the stack, got \(engine.bankroll)")
        precondition(engine.tableMinimum == 25 && engine.numHands == 2, "Table shape should apply")
        precondition(engine.sessionNet == 0, "Fresh session should be even")
        precondition(engine.canCashOut, "Cash out must be available between rounds")
        precondition(!engine.isFelted, "A funded session is not felted")

        // Starting again mid-session must be refused.
        engine.startSession(buyIn: 9999, minimum: 1, hands: 1)
        precondition(engine.sessionBuyIn == 500, "A running session must not be replaced")

        // Cashing out writes the receipt and frees the table.
        engine.cashOut()
        precondition(!engine.sessionActive, "Cash out should end the session")
        precondition(engine.tableMinimum == 5, "The next table should reset to a $5 minimum")
        let receipt = engine.lastSummary
        precondition(receipt?.buyIn == 500 && receipt?.cashedOut == 500, "Receipt should record the money flow")
        precondition(receipt?.net == 0 && receipt?.busted == false, "Breaking even is not a bust")

        // Going broke: below one table-minimum bet reads as felted, and the
        // receipt marks the bust.
        engine.startSession(buyIn: 100, minimum: 5, hands: 1)
        stats.setBankroll(2)
        precondition(engine.isFelted, "A stack below the minimum bet is felted")
        engine.cashOut()
        precondition(engine.lastSummary?.busted == true, "The receipt should flag the bust")
        precondition(engine.lastSummary?.net == -98, "Net should reflect the loss, got \(engine.lastSummary?.net ?? .nan)")

        // A buy in that can't cover a single minimum bet is refused.
        engine.startSession(buyIn: 3, minimum: 5, hands: 1)
        precondition(!engine.sessionActive, "A buy in below the table minimum must be refused")

        print("SessionFlowTests passed")
    }
}
