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

/// One day's daily-challenge outcome.
struct ChallengeResult: Codable {
    var score: Int
    var total: Int
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

    // The most any single session has ever been up over its buy-in. Feeds the
    // bankroll achievements — the live bankroll can't, because buying in big
    // would unlock them instantly and the next buy-in would un-earn them.
    var bestSessionNet: Double = 0

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

    // Per-spot lifetime accuracy, keyed by SpotID (e.g. "H16v10").
    // Fed by both Play grading and the quiz; powers the heatmap,
    // the leaks list, and smart-quiz dealing.
    var spots: [String: SpotStat] = [:]

    // Wrong action frequency by spot, e.g. H16v10 -> Stand -> 4. Unlike the
    // transient session recap, this persists across play and quiz sessions.
    var mistakeChoices: [String: [String: Int]] = [:]

    // Graded decisions per day needed to keep the daily streak alive.
    var dailyGoal = 20

    // Daily-challenge results, keyed "yyyy-MM-dd".
    var challenges: [String: ChallengeResult] = [:]
}

// Tolerant decoding: any key missing from older saved data falls back to its default,
// so adding new fields never wipes a user's existing progress on upgrade.
// (Declared in an extension so the memberwise / no-argument initializers are preserved.)
extension StatsData {
    enum CodingKeys: String, CodingKey {
        case strategyCorrect, strategyTotal
        case handsPlayed, handsWon, handsLost, handsPushed, blackjacks
        case drillsCompleted, drillsCorrect, bestStreak, currentStreak
        case bankroll, betDecisions, betCorrect, bestSessionNet
        case quizTotal, quizCorrect, quizBestStreak
        case countChecks, countChecksCorrect
        case bankrollHistory
        case days
        case spots
        case mistakeChoices
        case dailyGoal
        case challenges
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
        bestSessionNet  = try c.decodeIfPresent(Double.self, forKey: .bestSessionNet) ?? bestSessionNet
        quizTotal       = try c.decodeIfPresent(Int.self, forKey: .quizTotal) ?? quizTotal
        quizCorrect     = try c.decodeIfPresent(Int.self, forKey: .quizCorrect) ?? quizCorrect
        quizBestStreak  = try c.decodeIfPresent(Int.self, forKey: .quizBestStreak) ?? quizBestStreak
        countChecks     = try c.decodeIfPresent(Int.self, forKey: .countChecks) ?? countChecks
        countChecksCorrect = try c.decodeIfPresent(Int.self, forKey: .countChecksCorrect) ?? countChecksCorrect
        bankrollHistory = try c.decodeIfPresent([Double].self, forKey: .bankrollHistory) ?? bankrollHistory
        days            = try c.decodeIfPresent([String: DayStat].self, forKey: .days) ?? days
        spots           = try c.decodeIfPresent([String: SpotStat].self, forKey: .spots) ?? spots
        mistakeChoices  = try c.decodeIfPresent([String: [String: Int]].self, forKey: .mistakeChoices) ?? mistakeChoices
        dailyGoal       = try c.decodeIfPresent(Int.self, forKey: .dailyGoal) ?? dailyGoal
        challenges      = try c.decodeIfPresent([String: ChallengeResult].self, forKey: .challenges) ?? challenges
    }
}

/// One wrong play from the current app session, for the session report card.
struct SessionMistake: Identifiable {
    let id = UUID()
    let spotKey: String
    let chose: String
    let correctPlay: String
}

@MainActor
@Observable
final class Stats {
    private let key = "blackjack_stats_v1"

    var data: StatsData {
        didSet { scheduleSave() }
    }

    // A single graded decision mutates `data` several times (totals, day
    // stats, spot stats), and each mutation used to re-encode the whole blob.
    // Coalesce: one encode shortly after the last mutation, plus an explicit
    // flush() when the app backgrounds or progress is reset.
    private var saveTask: Task<Void, Never>?

    // Transient per-launch session recap — deliberately not persisted.
    private(set) var sessionDecisions = 0
    private(set) var sessionCorrect = 0
    private(set) var sessionMistakes: [SessionMistake] = []

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestMistakeReview") {
            var seeded = StatsData()
            seeded.spots = [
                "H16v10": SpotStat(correct: 1, total: 6),
                "H12v3": SpotStat(correct: 2, total: 6),
            ]
            seeded.mistakeChoices = [
                "H16v10": ["Stand": 4, "Double": 1],
                "H12v3": ["Stand": 4],
            ]
            data = seeded
            return
        }
#endif
        if let stored = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StatsData.self, from: stored) {
            data = decoded
        } else {
            data = StatsData()
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    /// Writes any pending changes immediately. Called when the app
    /// backgrounds so a coalesced save can't be lost to a suspend/kill.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        save()
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

    /// Sets the table stack outright — used when a play session buys in.
    func setBankroll(_ amount: Double) {
        data.bankroll = amount
    }

    /// Records how far above its buy-in the current session has been; keeps
    /// the lifetime best. Called each time a round settles.
    func recordSessionProfit(_ net: Double) {
        data.bestSessionNet = max(data.bestSessionNet, net)
    }

    var recentDays: [DayStat] {
        data.days.values.sorted { $0.date < $1.date }.suffix(30).map { $0 }
    }

    // Locale and calendar are pinned: on a device using the Buddhist or
    // Japanese calendar, an unpinned "yyyy" produces a different year (e.g.
    // 2569), splitting the user's history — and the daily-challenge seed —
    // across incompatible keys whenever the region changes.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func todayKey() -> String {
        Self.dayFormatter.string(from: Date())
    }

    // MARK: - Recording

    /// spotKey is the SpotID for the graded hand; pass nil when the decision
    /// shouldn't feed spot accuracy (e.g. count-deviation spots, where the
    /// "correct" play differs from the basic-strategy chart).
    func recordDecision(correct: Bool, spotKey: String?) {
        data.strategyTotal += 1
        if correct { data.strategyCorrect += 1 }
        bumpDay(correct: correct)
        bumpSpot(spotKey, correct: correct)
    }

    private func bumpDay(correct: Bool) {
        let k = todayKey()
        var day = data.days[k] ?? DayStat(date: k, strategyCorrect: 0, strategyTotal: 0)
        day.strategyTotal += 1
        if correct { day.strategyCorrect += 1 }
        data.days[k] = day

        sessionDecisions += 1
        if correct { sessionCorrect += 1 }
    }

    /// Remember a wrong play for this session's report card (capped so a
    /// long session can't grow without bound).
    func logMistake(spotKey: String, chose: String, correctPlay: String) {
        sessionMistakes.append(SessionMistake(spotKey: spotKey, chose: chose, correctPlay: correctPlay))
        if sessionMistakes.count > 50 {
            sessionMistakes.removeFirst(sessionMistakes.count - 50)
        }
        var choices = data.mistakeChoices[spotKey] ?? [:]
        choices[chose, default: 0] += 1
        data.mistakeChoices[spotKey] = choices
    }

    private func bumpSpot(_ key: String?, correct: Bool) {
        guard let key else { return }
        var spot = data.spots[key] ?? SpotStat()
        spot.total += 1
        if correct { spot.correct += 1 }
        data.spots[key] = spot
    }

    // MARK: - Personalization

    /// Your worst spots (min attempts applied), worst first — the leaks list.
    var weakestSpots: [(key: String, stat: SpotStat)] {
        ProgressMetrics.weakestSpots(in: data.spots)
    }

    /// Persistent wrong-action patterns with enough evidence for review.
    var recurringMistakes: [RecurringMistake] {
        ProgressMetrics.recurringMistakes(in: data.spots, choices: data.mistakeChoices)
    }

    /// Graded decisions (Play + quiz) made today, toward the daily goal.
    var todayDecisions: Int {
        data.days[todayKey()]?.strategyTotal ?? 0
    }

    /// Consecutive days the daily goal was met (today's unfinished day
    /// doesn't break the run).
    var dailyStreak: Int {
        ProgressMetrics.dailyStreak(
            dayTotals: data.days.mapValues(\.strategyTotal),
            goal: data.dailyGoal,
            today: Date()
        )
    }

    /// Composite player level across strategy, coverage, counting, and betting.
    var skillRating: SkillRating {
        SkillRating.compute(from: SkillRating.Inputs(
            strategyCorrect: data.strategyCorrect + data.quizCorrect,
            strategyTotal: data.strategyTotal + data.quizTotal,
            spotsPracticed: data.spots.count,
            chartCells: SpotCatalog.chartCellCount,
            drillsCorrect: data.drillsCorrect,
            drillsCompleted: data.drillsCompleted,
            countChecksCorrect: data.countChecksCorrect,
            countChecks: data.countChecks,
            betCorrect: data.betCorrect,
            betDecisions: data.betDecisions
        ))
    }

    /// The full trophy list, live against current data.
    var achievements: [Achievement] {
        Achievements.all(from: Achievements.Inputs(
            decisions: data.strategyTotal + data.quizTotal,
            decisionsCorrect: data.strategyCorrect + data.quizCorrect,
            spotsPracticed: data.spots.count,
            masteredSpots: data.spots.values.filter { $0.total >= 5 && $0.accuracy >= 0.9 }.count,
            quizBestStreak: data.quizBestStreak,
            handsPlayed: data.handsPlayed,
            blackjacks: data.blackjacks,
            bestSessionNet: data.bestSessionNet,
            bestDrillStreak: data.bestStreak,
            countChecksCorrect: data.countChecksCorrect,
            betDecisions: data.betDecisions,
            betCorrect: data.betCorrect,
            challengesPlayed: data.challenges.count,
            perfectChallenges: data.challenges.values.filter { $0.total > 0 && $0.score == $0.total }.count,
            longestDailyStreak: ProgressMetrics.longestStreak(
                dayTotals: data.days.mapValues(\.strategyTotal), goal: data.dailyGoal)
        ))
    }

    // MARK: - Daily challenge

    /// Today's date key, shared with the daily challenge so "today" always
    /// means the same thing everywhere.
    var todayDateKey: String { todayKey() }

    var todayChallenge: ChallengeResult? { data.challenges[todayKey()] }

    /// A challenge rep counts toward day totals and spot accuracy like any
    /// other graded decision, without inflating quiz stats.
    func recordChallengeAnswer(correct: Bool, spotKey: String?) {
        bumpDay(correct: correct)
        bumpSpot(spotKey, correct: correct)
    }

    /// Keep the best score if the challenge is somehow replayed the same day.
    func recordChallengeResult(score: Int, total: Int, dateKey: String) {
        let existing = data.challenges[dateKey]
        if existing == nil || score > (existing?.score ?? 0) {
            data.challenges[dateKey] = ChallengeResult(score: score, total: total)
        }
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

    /// Quiz answers count toward the same day totals and spot accuracy as
    /// Play decisions — a rep is a rep, wherever it happens.
    func recordQuiz(correct: Bool, streak: Int, spotKey: String?) {
        data.quizTotal += 1
        if correct { data.quizCorrect += 1 }
        data.quizBestStreak = max(data.quizBestStreak, streak)
        bumpDay(correct: correct)
        bumpSpot(spotKey, correct: correct)
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
        sessionDecisions = 0
        sessionCorrect = 0
        sessionMistakes = []
        flush()   // a reset should never sit in the debounce window
    }
}
