import Foundation
import Observation
import os

/// One day's aggregated strategy performance, used for the progress chart.
struct DayStat: Codable, Identifiable {
    var date: String   // "yyyy-MM-dd"
    var strategyCorrect: Int
    var strategyTotal: Int
    /// Close calls (yellow): half credit. Missing in older saves, so 0.
    var strategyClose = 0

    var id: String { date }
    var accuracy: Double {
        Accuracy.fraction(correct: strategyCorrect, close: strategyClose, total: strategyTotal) ?? 0
    }
}

extension DayStat {
    private enum CodingKeys: String, CodingKey { case date, strategyCorrect, strategyTotal, strategyClose }

    /// Field by field, so one damaged value can't drop the whole day.
    /// (A missing date is repaired from its dictionary key on load.)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = c.tolerant(String.self, forKey: .date) ?? ""
        strategyTotal = max(0, c.tolerant(Int.self, forKey: .strategyTotal) ?? 0)
        strategyCorrect = min(strategyTotal, max(0, c.tolerant(Int.self, forKey: .strategyCorrect) ?? 0))
        strategyClose = min(strategyTotal - strategyCorrect,
                            max(0, c.tolerant(Int.self, forKey: .strategyClose) ?? 0))
    }
}

/// One day's daily-challenge outcome.
struct ChallengeResult: Codable {
    /// Hands played exactly right (green).
    var score: Int
    var total: Int
    /// Close calls (yellow), worth half a point. Missing in older saves, so 0.
    var close = 0

    /// Green hands plus half a point per close call.
    var points: Double { Double(score) + 0.5 * Double(close) }
    var isPerfect: Bool { total > 0 && score == total }

    /// "8" or "8½".
    var pointsText: String {
        let whole = Int(points.rounded(.down))
        return points > Double(whole) ? "\(whole)½" : "\(whole)"
    }

    /// "8" or "8 and a half", for VoiceOver.
    var pointsSpoken: String {
        let whole = Int(points.rounded(.down))
        return points > Double(whole) ? "\(whole) and a half" : "\(whole)"
    }
}

extension ChallengeResult {
    private enum CodingKeys: String, CodingKey { case score, total, close }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = max(0, c.tolerant(Int.self, forKey: .total) ?? 0)
        score = min(total, max(0, c.tolerant(Int.self, forKey: .score) ?? 0))
        close = min(total - score, max(0, c.tolerant(Int.self, forKey: .close) ?? 0))
    }
}

struct StatsData: Codable {
    /// Bumped whenever the saved shape changes meaningfully. Saves written
    /// before versioning existed read as version 1.
    static let currentSchemaVersion = 2
    var schemaVersion = StatsData.currentSchemaVersion

    var strategyCorrect = 0
    var strategyTotal = 0
    /// Close calls (yellow) in Play: half credit in accuracy. Saves written
    /// before three-tier grading have none, which reads as 0.
    var strategyClose = 0

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
    /// Bets graded yellow ("a bit risky", one unit off the count): half credit.
    var betClose = 0

    // Chips on the felt in a round that hasn't settled yet. Saved in the same
    // blob as the bankroll so the two can never disagree; if the app closes
    // mid-hand, the next launch hands these chips back.
    var inPlayWager: Double = 0

    // The most any single session has ever been up over its buy-in. Feeds the
    // bankroll achievements — the live bankroll can't, because buying in big
    // would unlock them instantly and the next buy-in would un-earn them.
    var bestSessionNet: Double = 0

    // Rapid-fire strategy quiz
    var quizTotal = 0
    var quizCorrect = 0
    var quizClose = 0
    var quizBestStreak = 0

    // Counted Daily Challenge answers (the day's first run only; practice
    // replays never count). Part of overall strategy accuracy.
    var challengeAnswersTotal = 0
    var challengeAnswersCorrect = 0
    var challengeAnswersClose = 0

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

    // Right answers in a row per spot since its last miss (capped), keyed by
    // SpotID. Two in a row clears a missed hand from the quiz's review list.
    var spotStreaks: [String: Int] = [:]

    // The day each trophy was first seen unlocked ("yyyy-MM-dd"; "" for
    // trophies earned before dates were tracked). Feeds "recently earned".
    var achievementDates: [String: String] = [:]
    var achievementsSeeded = false

    // Graded decisions per day needed to keep the daily streak alive.
    var dailyGoal = 20

    // Daily-challenge results, keyed "yyyy-MM-dd".
    var challenges: [String: ChallengeResult] = [:]

    // Days whose counted challenge run was started but never finished. A
    // restarted run on one of these days is practice, so quitting halfway
    // can't buy a second "first" run with known answers.
    var challengesStarted: Set<String> = []
}

// Tolerant decoding: any key missing from older saved data — or holding a value
// that can't be read — falls back to its default on its own, so adding fields
// or one damaged value never wipes a user's existing progress.
// (Declared in an extension so the memberwise / no-argument initializers are preserved.)
extension StatsData {
    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case strategyCorrect, strategyTotal, strategyClose
        case handsPlayed, handsWon, handsLost, handsPushed, blackjacks
        case drillsCompleted, drillsCorrect, bestStreak, currentStreak
        case bankroll, betDecisions, betCorrect, betClose, inPlayWager, bestSessionNet
        case quizTotal, quizCorrect, quizClose, quizBestStreak
        case challengeAnswersTotal, challengeAnswersCorrect, challengeAnswersClose
        case countChecks, countChecksCorrect
        case bankrollHistory
        case days
        case spots
        case mistakeChoices
        case spotStreaks
        case achievementDates, achievementsSeeded
        case dailyGoal
        case challenges
        case challengesStarted
    }

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion   = c.tolerant(Int.self, forKey: .schemaVersion) ?? 1
        strategyCorrect = c.tolerant(Int.self, forKey: .strategyCorrect) ?? strategyCorrect
        strategyTotal   = c.tolerant(Int.self, forKey: .strategyTotal) ?? strategyTotal
        strategyClose   = max(0, c.tolerant(Int.self, forKey: .strategyClose) ?? 0)
        handsPlayed     = c.tolerant(Int.self, forKey: .handsPlayed) ?? handsPlayed
        handsWon        = c.tolerant(Int.self, forKey: .handsWon) ?? handsWon
        handsLost       = c.tolerant(Int.self, forKey: .handsLost) ?? handsLost
        handsPushed     = c.tolerant(Int.self, forKey: .handsPushed) ?? handsPushed
        blackjacks      = c.tolerant(Int.self, forKey: .blackjacks) ?? blackjacks
        drillsCompleted = c.tolerant(Int.self, forKey: .drillsCompleted) ?? drillsCompleted
        drillsCorrect   = c.tolerant(Int.self, forKey: .drillsCorrect) ?? drillsCorrect
        bestStreak      = c.tolerant(Int.self, forKey: .bestStreak) ?? bestStreak
        currentStreak   = c.tolerant(Int.self, forKey: .currentStreak) ?? currentStreak
        bankroll        = Self.finite(c.tolerant(Double.self, forKey: .bankroll)) ?? bankroll
        betDecisions    = c.tolerant(Int.self, forKey: .betDecisions) ?? betDecisions
        betCorrect      = c.tolerant(Int.self, forKey: .betCorrect) ?? betCorrect
        betClose        = max(0, c.tolerant(Int.self, forKey: .betClose) ?? 0)
        inPlayWager     = max(0, Self.finite(c.tolerant(Double.self, forKey: .inPlayWager)) ?? 0)
        bestSessionNet  = Self.finite(c.tolerant(Double.self, forKey: .bestSessionNet)) ?? bestSessionNet
        quizTotal       = c.tolerant(Int.self, forKey: .quizTotal) ?? quizTotal
        quizCorrect     = c.tolerant(Int.self, forKey: .quizCorrect) ?? quizCorrect
        quizClose       = max(0, c.tolerant(Int.self, forKey: .quizClose) ?? 0)
        quizBestStreak  = c.tolerant(Int.self, forKey: .quizBestStreak) ?? quizBestStreak
        countChecks     = c.tolerant(Int.self, forKey: .countChecks) ?? countChecks
        countChecksCorrect = c.tolerant(Int.self, forKey: .countChecksCorrect) ?? countChecksCorrect
        bankrollHistory = (c.lossyArray(Double.self, forKey: .bankrollHistory) ?? bankrollHistory)
            .filter(\.isFinite)
        if let loadedDays = c.lossyDictionary(DayStat.self, forKey: .days) {
            days = Dictionary(uniqueKeysWithValues: loadedDays.map { key, day in
                var repaired = day
                if repaired.date.isEmpty { repaired.date = key }
                return (key, repaired)
            })
        }
        spots = c.lossyDictionary(TolerantSpotStat.self, forKey: .spots)?.mapValues(\.value) ?? spots
        mistakeChoices = c.lossyDictionary(TolerantIntMap.self, forKey: .mistakeChoices)?
            .mapValues(\.value) ?? mistakeChoices
        spotStreaks = (c.lossyDictionary(Int.self, forKey: .spotStreaks) ?? [:])
            .mapValues { max(0, $0) }
        achievementDates = c.lossyDictionary(String.self, forKey: .achievementDates) ?? [:]
        achievementsSeeded = c.tolerant(Bool.self, forKey: .achievementsSeeded) ?? false
        let goal = c.tolerant(Int.self, forKey: .dailyGoal) ?? dailyGoal
        dailyGoal       = goal > 0 ? goal : StatsData().dailyGoal
        challenges      = c.lossyDictionary(ChallengeResult.self, forKey: .challenges) ?? challenges
        challengesStarted = Set(c.lossyArray(String.self, forKey: .challengesStarted) ?? [])
        if let total = c.tolerant(Int.self, forKey: .challengeAnswersTotal) {
            challengeAnswersTotal = max(0, total)
            challengeAnswersCorrect = min(challengeAnswersTotal,
                                          max(0, c.tolerant(Int.self, forKey: .challengeAnswersCorrect) ?? 0))
            challengeAnswersClose = min(challengeAnswersTotal - challengeAnswersCorrect,
                                        max(0, c.tolerant(Int.self, forKey: .challengeAnswersClose) ?? 0))
        } else {
            // Saved before these were tracked: start from the finished
            // challenges, so earlier counted runs aren't lost from accuracy.
            let finished = challenges.values.filter { $0.total > 0 }
            challengeAnswersTotal = finished.reduce(0) { $0 + $1.total }
            challengeAnswersCorrect = finished.reduce(0) { $0 + min(max($1.score, 0), $1.total) }
            challengeAnswersClose = finished.reduce(0) {
                $0 + min(max($1.close, 0), max($1.total - max($1.score, 0), 0))
            }
        }
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }
}

/// One wrong play from the current app session, for the session report card.
struct SessionMistake: Identifiable {
    let id = UUID()
    let spotKey: String
    let chose: String
    let correctPlay: String
}

/// What happened when saved progress couldn't be read as-is on launch.
/// Transient: lets the UI explain it once, without persisting a flag.
enum StatsLoadIssue: Equatable {
    /// The saved progress couldn't be read. The original bytes were copied
    /// to `Stats.backupKey` before starting over, so nothing is destroyed.
    case unreadableSaveBackedUp
}

@MainActor
@Observable
final class Stats {
    static let storageKey = "blackjack_stats_v1"
    /// Raw copy of a save that couldn't be read, kept for recovery.
    static let backupKey = "blackjack_stats_v1_unreadable_backup"

    private let defaults: UserDefaults
    /// The day the screens last saw. "Today" readers touch this so a day
    /// rollover (see `refreshDay`) re-renders them.
    private(set) var dayStamp = ""
    private static let log = Logger(subsystem: "BlackjackTrainer", category: "Stats")

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
    /// Close calls (yellow) this app session: half credit.
    private(set) var sessionClose = 0
    private(set) var sessionMistakes: [SessionMistake] = []

    /// Set on launch if the saved progress couldn't be read (see StatsLoadIssue).
    private(set) var loadIssue: StatsLoadIssue?

    /// Chips returned on this launch from a round the app closed before it
    /// settled (0 if none). Transient, so the UI can mention it once.
    private(set) var refundedWagerOnLaunch = 0.0

    /// Called after `resetAll()`, so live engines (the play table) can drop
    /// state that no longer matches the wiped progress.
    private var resetHandlers: [@MainActor () -> Void] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
        var loaded = StatsData()
        if let stored = defaults.data(forKey: Self.storageKey) {
            do {
                loaded = try JSONDecoder().decode(StatsData.self, from: stored)
            } catch {
                // Never let the next save silently overwrite progress we
                // couldn't read: keep the raw bytes first. An earlier backup
                // is never replaced — it holds the oldest (likely fullest) copy.
                Self.log.error("Saved stats unreadable, backing up: \(String(describing: error), privacy: .public)")
                if defaults.data(forKey: Self.backupKey) == nil {
                    defaults.set(stored, forKey: Self.backupKey)
                }
                loadIssue = .unreadableSaveBackedUp
            }
        }
        // A wager still on the felt means the app closed mid-round. No
        // round can be in progress at launch, so hand the chips back.
        if loaded.inPlayWager > 0 {
            refundedWagerOnLaunch = loaded.inPlayWager
            loaded.bankroll += loaded.inPlayWager
            loaded.inPlayWager = 0
        }
        loaded.schemaVersion = StatsData.currentSchemaVersion
        data = loaded
        // First launch with trophy dates: stamp what is already earned as old.
        if !data.achievementsSeeded { syncAchievementDates() }
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
        do {
            let encoded = try JSONEncoder().encode(data)
            defaults.set(encoded, forKey: Self.storageKey)
        } catch {
            // Keep the last good save rather than writing something partial.
            Self.log.error("Could not save stats: \(String(describing: error), privacy: .public)")
        }
    }

    /// Registers work to run after progress is reset.
    func onReset(_ handler: @escaping @MainActor () -> Void) {
        resetHandlers.append(handler)
    }

    // MARK: - Derived values

    // Accuracy everywhere gives a close call (yellow) half credit.

    var strategyAccuracy: Double {
        Accuracy.fraction(correct: data.strategyCorrect, close: data.strategyClose,
                          total: data.strategyTotal) ?? 0
    }

    /// Session accuracy (the report card), half credit for close calls.
    var sessionAccuracy: Double? {
        Accuracy.fraction(correct: sessionCorrect, close: sessionClose, total: sessionDecisions)
    }

    var drillAccuracy: Double {
        data.drillsCompleted == 0 ? 0 : Double(data.drillsCorrect) / Double(data.drillsCompleted)
    }

    var betAccuracy: Double {
        Accuracy.fraction(correct: data.betCorrect, close: data.betClose, total: data.betDecisions) ?? 0
    }

    /// A yellow bet ("a bit risky", one unit off the count) is half credit.
    func recordBet(grade: Grade) {
        data.betDecisions += 1
        switch grade {
        case .correct: data.betCorrect += 1
        case .close: data.betClose += 1
        case .wrong: break
        }
        didRecord()
    }

    func recordBet(correct: Bool) { recordBet(grade: Grade(correct: correct)) }

    func adjustBankroll(_ delta: Double) {
        data.bankroll += delta
    }

    /// Moves chips from the stack onto the felt for the current round.
    /// They're tracked until `settleRound` so a closed app can refund them.
    func placeWager(_ amount: Double) {
        guard amount > 0 else { return }
        data.bankroll -= amount
        data.inPlayWager += amount
    }

    /// Pays out a settled round and clears the chips that were on the felt.
    func settleRound(payout: Double) {
        data.bankroll += payout
        data.inPlayWager = 0
    }

    /// Drops an unsettled round's chips without paying them back (used when
    /// a reset has already replaced the stack).
    func abandonWager() {
        data.inPlayWager = 0
    }

    /// Sets the table stack outright — used when a play session buys in.
    func setBankroll(_ amount: Double) {
        data.bankroll = amount
    }

    /// Records how far above its buy-in the current session has been; keeps
    /// the lifetime best. Called each time a round settles.
    func recordSessionProfit(_ net: Double) {
        data.bestSessionNet = max(data.bestSessionNet, net)
        didRecord()
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
    /// A close call (yellow) is half credit and still counts toward the daily goal.
    func recordDecision(grade: Grade, spotKey: String?) {
        data.strategyTotal += 1
        switch grade {
        case .correct: data.strategyCorrect += 1
        case .close: data.strategyClose += 1
        case .wrong: break
        }
        bumpDay(grade: grade)
        bumpSpot(spotKey, grade: grade)
        didRecord()
    }

    func recordDecision(correct: Bool, spotKey: String?) {
        recordDecision(grade: Grade(correct: correct), spotKey: spotKey)
    }

    private func bumpDay(grade: Grade) {
        let k = todayKey()
        var day = data.days[k] ?? DayStat(date: k, strategyCorrect: 0, strategyTotal: 0)
        day.strategyTotal += 1
        sessionDecisions += 1
        switch grade {
        case .correct:
            day.strategyCorrect += 1
            sessionCorrect += 1
        case .close:
            day.strategyClose += 1
            sessionClose += 1
        case .wrong:
            break
        }
        data.days[k] = day
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

    private func bumpSpot(_ key: String?, grade: Grade) {
        guard let key else { return }
        var spot = data.spots[key] ?? SpotStat()
        spot.total += 1
        // Only spots that were ever missed need a streak (it clears them from
        // the review list), which keeps this table small. A close call
        // neither clears a missed hand nor puts it back.
        switch grade {
        case .correct:
            spot.correct += 1
            if data.mistakeChoices[key] != nil || data.spotStreaks[key] != nil {
                data.spotStreaks[key] = min((data.spotStreaks[key] ?? 0) + 1, ProgressMetrics.reviewClearStreak)
            }
        case .close:
            spot.close += 1
        case .wrong:
            data.spotStreaks[key] = 0
        }
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

    /// Missed hands still to review, most missed first (see ProgressMetrics).
    var reviewQueue: [ReviewCandidate] {
        ProgressMetrics.reviewQueue(spots: data.spots, choices: data.mistakeChoices,
                                    streaks: data.spotStreaks)
    }

    /// Right answers in a row on this spot since it was last missed.
    func spotStreak(_ key: String) -> Int { data.spotStreaks[key] ?? 0 }

    /// Graded decisions (Play + quiz) made today, toward the daily goal.
    var todayDecisions: Int {
        _ = dayStamp
        return data.days[todayKey()]?.strategyTotal ?? 0
    }

    /// Consecutive days the daily goal was met (today's unfinished day
    /// doesn't break the run).
    var dailyStreak: Int {
        _ = dayStamp
        return ProgressMetrics.dailyStreak(
            dayTotals: data.days.mapValues(\.strategyTotal),
            goal: data.dailyGoal,
            today: Date()
        )
    }

    /// Strategy accuracy across graded play, the quiz and counted Daily
    /// Challenge answers, as one number (Progress, skill rating, trophies).
    var overallStrategyCorrect: Int {
        data.strategyCorrect + data.quizCorrect + data.challengeAnswersCorrect
    }
    var overallStrategyTotal: Int {
        data.strategyTotal + data.quizTotal + data.challengeAnswersTotal
    }
    /// Close calls (yellow) across the same three: half credit.
    var overallStrategyClose: Int {
        data.strategyClose + data.quizClose + data.challengeAnswersClose
    }

    /// Composite player level across strategy, coverage, counting, and betting.
    var skillRating: SkillRating {
        SkillRating.compute(from: SkillRating.Inputs(
            strategyCorrect: overallStrategyCorrect,
            strategyTotal: overallStrategyTotal,
            strategyClose: overallStrategyClose,
            spotsPracticed: data.spots.count,
            chartCells: SpotCatalog.chartCellCount,
            drillsCorrect: data.drillsCorrect,
            drillsCompleted: data.drillsCompleted,
            countChecksCorrect: data.countChecksCorrect,
            countChecks: data.countChecks,
            betCorrect: data.betCorrect,
            betDecisions: data.betDecisions,
            betClose: data.betClose
        ))
    }

    /// The full trophy list. A trophy never silently un-earns: anything with a
    /// stamped date stays unlocked even if live accuracy later dips.
    var achievements: [Achievement] {
        Achievements.keepingEarned(liveAchievements, dates: data.achievementDates)
    }

    /// Trophies judged against current data only (no memory of past unlocks).
    private var liveAchievements: [Achievement] {
        Achievements.all(from: Achievements.Inputs(
            decisions: overallStrategyTotal,
            decisionsCorrect: overallStrategyCorrect,
            decisionsClose: overallStrategyClose,
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
            betClose: data.betClose,
            challengesPlayed: data.challenges.count,
            perfectChallenges: data.challenges.values.filter(\.isPerfect).count,
            longestDailyStreak: ProgressMetrics.longestStreak(
                dayTotals: data.days.mapValues(\.strategyTotal), goal: data.dailyGoal)
        ))
    }

    /// Notes any newly unlocked trophy with today's date. Safe to call often;
    /// it only writes when something changed.
    func syncAchievementDates() {
        let result = Achievements.updatedDates(
            existing: data.achievementDates, seeded: data.achievementsSeeded,
            unlocked: liveAchievements.filter(\.unlocked).map(\.id), today: todayKey())
        guard result.dates != data.achievementDates || result.seeded != data.achievementsSeeded else { return }
        data.achievementDates = result.dates
        data.achievementsSeeded = result.seeded
    }

    /// Stamps newly earned trophies right when the progress that earned them
    /// is recorded, so the date is the real day and the trophy is kept.
    private func didRecord() { syncAchievementDates() }

    /// The day key `days` days before today, for "recent" cutoffs.
    func dayKey(daysAgo days: Int) -> String {
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return Self.dayFormatter.string(from: date)
    }

    // MARK: - Daily challenge

    /// Today's date key, shared with the daily challenge so "today" always
    /// means the same thing everywhere.
    var todayDateKey: String { todayKey() }

    var todayChallenge: ChallengeResult? {
        _ = dayStamp
        return data.challenges[todayKey()]
    }

    /// Call when the app becomes active or the clock/day changes, so
    /// "today" values on screen re-read instead of showing yesterday's.
    func refreshDay() {
        let key = todayKey()
        if key != dayStamp { dayStamp = key }
    }

    /// A counted challenge rep counts toward overall accuracy, day totals and
    /// spot accuracy like any other graded decision, without inflating quiz stats.
    func recordChallengeAnswer(grade: Grade, spotKey: String?) {
        data.challengeAnswersTotal += 1
        switch grade {
        case .correct: data.challengeAnswersCorrect += 1
        case .close: data.challengeAnswersClose += 1
        case .wrong: break
        }
        bumpDay(grade: grade)
        bumpSpot(spotKey, grade: grade)
        didRecord()
    }

    func recordChallengeAnswer(correct: Bool, spotKey: String?) {
        recordChallengeAnswer(grade: Grade(correct: correct), spotKey: spotKey)
    }

    /// Keep the best score if the challenge is somehow replayed the same day.
    /// `score` is the green hands; each close call adds half a point.
    func recordChallengeResult(score: Int, close: Int = 0, total: Int, dateKey: String) {
        let result = ChallengeResult(score: score, total: total, close: close)
        let existing = data.challenges[dateKey]
        if existing == nil || result.points > (existing?.points ?? 0) {
            data.challenges[dateKey] = result
        }
        data.challengesStarted.remove(dateKey)   // finished; the result now marks the day
        didRecord()
    }

    /// Marks the day's counted run as begun, so quitting and relaunching
    /// can't offer a fresh "first" run with answers already seen.
    func markChallengeStarted(dateKey: String) {
        data.challengesStarted.insert(dateKey)
    }

    /// True once the day's counted run has begun or finished; later runs are practice.
    func challengeRunUsed(dateKey: String) -> Bool {
        data.challenges[dateKey] != nil || data.challengesStarted.contains(dateKey)
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
        didRecord()
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
        didRecord()
    }

    // MARK: - Strategy quiz

    var quizAccuracy: Double {
        Accuracy.fraction(correct: data.quizCorrect, close: data.quizClose, total: data.quizTotal) ?? 0
    }

    /// Quiz answers count toward the same day totals and spot accuracy as
    /// Play decisions — a rep is a rep, wherever it happens.
    func recordQuiz(grade: Grade, streak: Int, spotKey: String?) {
        data.quizTotal += 1
        switch grade {
        case .correct: data.quizCorrect += 1
        case .close: data.quizClose += 1
        case .wrong: break
        }
        data.quizBestStreak = max(data.quizBestStreak, streak)
        bumpDay(grade: grade)
        bumpSpot(spotKey, grade: grade)
        didRecord()
    }

    func recordQuiz(correct: Bool, streak: Int, spotKey: String?) {
        recordQuiz(grade: Grade(correct: correct), streak: streak, spotKey: spotKey)
    }

    // MARK: - Mid-hand count checks

    var countCheckAccuracy: Double {
        data.countChecks == 0 ? 0 : Double(data.countChecksCorrect) / Double(data.countChecks)
    }

    func recordCountCheck(correct: Bool) {
        data.countChecks += 1
        if correct { data.countChecksCorrect += 1 }
        didRecord()
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
        data.achievementsSeeded = true   // nothing earned yet; new trophies get real dates
        sessionDecisions = 0
        sessionCorrect = 0
        sessionClose = 0
        sessionMistakes = []
        refundedWagerOnLaunch = 0
        // The play session's buy-in lives outside `data`. Leaving it would
        // compare the fresh 1,000 stack against the old buy-in and record
        // fake profit (and unlock bankroll trophies) on the next round.
        PlaySessionStore.clear(in: defaults)
        for handler in resetHandlers { handler() }
        flush()   // a reset should never sit in the debounce window
    }
}
