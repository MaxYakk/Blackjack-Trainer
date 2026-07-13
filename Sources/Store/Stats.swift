import Foundation
import Observation

/// One day's aggregated strategy performance, used for the progress chart.
struct DayStat: Codable, Identifiable {
    var date: String   // "yyyy-MM-dd"
    var strategyCorrect: Int
    var strategyTotal: Int

    var id: String { date }
    var accuracy: Double { strategyTotal == 0 ? 0 : Double(strategyCorrect) / Double(strategyTotal) }
}

struct StatsData: Codable {
    var strategyCorrect = 0
    var strategyTotal = 0

    var handsPlayed = 0
    var handsWon = 0
    var handsLost = 0
    var handsPushed = 0
    var blackjacks = 0

    var drillsCompleted = 0
    var drillsCorrect = 0
    var bestStreak = 0
    var currentStreak = 0

    // Betting practice (play money)
    var bankroll: Double = 1000
    var betDecisions = 0
    var betCorrect = 0

    // Rapid-fire strategy quiz
    var quizTotal = 0
    var quizCorrect = 0
    var quizBestStreak = 0

    // Mid-session "what's the count?" checks
    var countChecks = 0
    var countChecksCorrect = 0

    // Bankroll curve (one point per settled round, capped)
    var bankrollHistory: [Double] = []

    var days: [String: DayStat] = [:]
}

// Tolerant decoding: any key missing from older saved data falls back to its default,
// so adding new fields never wipes a user's existing progress on upgrade.
// (Declared in an extension so the memberwise / no-argument initializers are preserved.)
extension StatsData {
    enum CodingKeys: String, CodingKey {
        case strategyCorrect, strategyTotal
        case handsPlayed, handsWon, handsLost, handsPushed, blackjacks
        case drillsCompleted, drillsCorrect, bestStreak, currentStreak
        case bankroll, betDecisions, betCorrect
        case quizTotal, quizCorrect, quizBestStreak
        case countChecks, countChecksCorrect
        case bankrollHistory
        case days
    }

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        strategyCorrect = try c.decodeIfPresent(Int.self, forKey: .strategyCorrect) ?? strategyCorrect
        strategyTotal   = try c.decodeIfPresent(Int.self, forKey: .strategyTotal) ?? strategyTotal
        handsPlayed     = try c.decodeIfPresent(Int.self, forKey: .handsPlayed) ?? handsPlayed
        handsWon        = try c.decodeIfPresent(Int.self, forKey: .handsWon) ?? handsWon
        handsLost       = try c.decodeIfPresent(Int.self, forKey: .handsLost) ?? handsLost
        handsPushed     = try c.decodeIfPresent(Int.self, forKey: .handsPushed) ?? handsPushed
        blackjacks      = try c.decodeIfPresent(Int.self, forKey: .blackjacks) ?? blackjacks
        drillsCompleted = try c.decodeIfPresent(Int.self, forKey: .drillsCompleted) ?? drillsCompleted
        drillsCorrect   = try c.decodeIfPresent(Int.self, forKey: .drillsCorrect) ?? drillsCorrect
        bestStreak      = try c.decodeIfPresent(Int.self, forKey: .bestStreak) ?? bestStreak
        currentStreak   = try c.decodeIfPresent(Int.self, forKey: .currentStreak) ?? currentStreak
        bankroll        = try c.decodeIfPresent(Double.self, forKey: .bankroll) ?? bankroll
        betDecisions    = try c.decodeIfPresent(Int.self, forKey: .betDecisions) ?? betDecisions
        betCorrect      = try c.decodeIfPresent(Int.self, forKey: .betCorrect) ?? betCorrect
        quizTotal       = try c.decodeIfPresent(Int.self, forKey: .quizTotal) ?? quizTotal
        quizCorrect     = try c.decodeIfPresent(Int.self, forKey: .quizCorrect) ?? quizCorrect
        quizBestStreak  = try c.decodeIfPresent(Int.self, forKey: .quizBestStreak) ?? quizBestStreak
        countChecks     = try c.decodeIfPresent(Int.self, forKey: .countChecks) ?? countChecks
        countChecksCorrect = try c.decodeIfPresent(Int.self, forKey: .countChecksCorrect) ?? countChecksCorrect
        bankrollHistory = try c.decodeIfPresent([Double].self, forKey: .bankrollHistory) ?? bankrollHistory
        days            = try c.decodeIfPresent([String: DayStat].self, forKey: .days) ?? days
    }
}

@Observable
final class Stats {
    private let key = "blackjack_stats_v1"

    var data: StatsData {
        didSet { save() }
    }

    init() {
        if let stored = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StatsData.self, from: stored) {
            data = decoded
        } else {
            data = StatsData()
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    // MARK: - Derived values

    var strategyAccuracy: Double {
        data.strategyTotal == 0 ? 0 : Double(data.strategyCorrect) / Double(data.strategyTotal)
    }

    var drillAccuracy: Double {
        data.drillsCompleted == 0 ? 0 : Double(data.drillsCorrect) / Double(data.drillsCompleted)
    }

    var betAccuracy: Double {
        data.betDecisions == 0 ? 0 : Double(data.betCorrect) / Double(data.betDecisions)
    }

    func recordBet(correct: Bool) {
        data.betDecisions += 1
        if correct { data.betCorrect += 1 }
    }

    func adjustBankroll(_ delta: Double) {
        data.bankroll += delta
    }

    func resetBankroll() {
        data.bankroll = 1000
    }

    var recentDays: [DayStat] {
        data.days.values.sorted { $0.date < $1.date }.suffix(30).map { $0 }
    }

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: - Recording

    func recordDecision(correct: Bool) {
        data.strategyTotal += 1
        if correct { data.strategyCorrect += 1 }

        let k = todayKey()
        var day = data.days[k] ?? DayStat(date: k, strategyCorrect: 0, strategyTotal: 0)
        day.strategyTotal += 1
        if correct { day.strategyCorrect += 1 }
        data.days[k] = day
    }

    func recordHandResult(_ result: HandResult) {
        data.handsPlayed += 1
        switch result {
        case .win, .blackjack:
            data.handsWon += 1
            if result == .blackjack { data.blackjacks += 1 }
        case .lose, .dealerBlackjack, .bust:
            data.handsLost += 1
        case .push:
            data.handsPushed += 1
        }
    }

    func recordDrill(correct: Bool) {
        data.drillsCompleted += 1
        if correct {
            data.drillsCorrect += 1
            data.currentStreak += 1
            data.bestStreak = max(data.bestStreak, data.currentStreak)
        } else {
            data.currentStreak = 0
        }
    }

    // MARK: - Strategy quiz

    var quizAccuracy: Double {
        data.quizTotal == 0 ? 0 : Double(data.quizCorrect) / Double(data.quizTotal)
    }

    func recordQuiz(correct: Bool, streak: Int) {
        data.quizTotal += 1
        if correct { data.quizCorrect += 1 }
        data.quizBestStreak = max(data.quizBestStreak, streak)
    }

    // MARK: - Mid-hand count checks

    var countCheckAccuracy: Double {
        data.countChecks == 0 ? 0 : Double(data.countChecksCorrect) / Double(data.countChecks)
    }

    func recordCountCheck(correct: Bool) {
        data.countChecks += 1
        if correct { data.countChecksCorrect += 1 }
    }

    // MARK: - Bankroll curve

    func pushBankrollPoint() {
        data.bankrollHistory.append(data.bankroll)
        if data.bankrollHistory.count > 200 {
            data.bankrollHistory.removeFirst(data.bankrollHistory.count - 200)
        }
    }

    func resetAll() {
        data = StatsData()
    }
}
