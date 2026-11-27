import Foundation

/// Lifetime accuracy for one strategy spot (see SpotID for the key format).
struct SpotStat: Codable {
    var correct = 0
    var total = 0
    /// Close calls (yellow): half credit. Older saves have none.
    var close = 0

    var accuracy: Double { Accuracy.fraction(correct: correct, close: close, total: total) ?? 0 }
}

/// Accuracy with half credit for a close call (yellow).
enum Accuracy {
    /// (green + ½ yellow) ÷ total, or nil when nothing was graded.
    static func fraction(correct: Int, close: Int = 0, total: Int) -> Double? {
        guard total > 0 else { return nil }
        let credit = Double(correct) + 0.5 * Double(close)
        return min(1, max(0, credit / Double(total)))
    }
}

struct RecurringMistake: Identifiable {
    let key: String
    let stat: SpotStat
    let commonChoice: String
    let choiceCount: Int
    let mistakeCount: Int

    var id: String { key }
}

/// One missed hand waiting in the quiz's review list.
struct ReviewCandidate: Identifiable {
    let key: String
    let mistakeCount: Int
    let stat: SpotStat

    var id: String { key }
}

/// Pure calculations behind the personalization features: leak ranking,
/// smart-quiz dealing weights, and the daily-goal streak. Kept free of
/// Observation/UserDefaults so they compile into the standalone test harness.
enum ProgressMetrics {
    /// Repeated wrong plays worth an explicit review. A single slip is kept
    /// out of the queue; the review is for patterns with enough evidence to
    /// be useful rather than noisy.
    static func recurringMistakes(
        in spots: [String: SpotStat],
        choices: [String: [String: Int]],
        minAttempts: Int = 3,
        minMistakes: Int = 2,
        masteredAt: Double = 0.9,
        limit: Int = 5
    ) -> [RecurringMistake] {
        choices.compactMap { key, wrongChoices in
            guard let stat = spots[key],
                  stat.total >= minAttempts,
                  stat.accuracy < masteredAt else { return nil }
            let mistakeCount = wrongChoices.values.reduce(0, +)
            guard mistakeCount >= minMistakes,
                  let common = wrongChoices.sorted(by: {
                      $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value
                  }).first else { return nil }
            return RecurringMistake(
                key: key,
                stat: stat,
                commonChoice: common.key,
                choiceCount: common.value,
                mistakeCount: mistakeCount
            )
        }
        .sorted {
            if $0.mistakeCount != $1.mistakeCount { return $0.mistakeCount > $1.mistakeCount }
            if $0.stat.accuracy != $1.stat.accuracy { return $0.stat.accuracy < $1.stat.accuracy }
            if $0.stat.total != $1.stat.total { return $0.stat.total > $1.stat.total }
            return $0.key < $1.key
        }
        .prefix(limit)
        .map { $0 }
    }

    /// Right answers in a row that clear a missed hand from review.
    static let reviewClearStreak = 2

    /// The hands a player has missed and not yet fixed, most missed first. A
    /// hand is in the list while it has at least one saved mistake and fewer
    /// than `reviewClearStreak` right answers in a row since the last miss
    /// (the streak resets on every miss, wherever it happened). Ties go to the
    /// lower accuracy, then the key, so the order is stable.
    static func reviewQueue(
        spots: [String: SpotStat],
        choices: [String: [String: Int]],
        streaks: [String: Int]
    ) -> [ReviewCandidate] {
        choices.compactMap { key, wrong -> ReviewCandidate? in
            let missed = wrong.values.reduce(0, +)
            guard missed > 0,
                  (streaks[key] ?? 0) < reviewClearStreak,
                  SpotCatalog.spot(forKey: key) != nil else { return nil }
            return ReviewCandidate(key: key, mistakeCount: missed, stat: spots[key] ?? SpotStat())
        }
        .sorted {
            if $0.mistakeCount != $1.mistakeCount { return $0.mistakeCount > $1.mistakeCount }
            if $0.stat.accuracy != $1.stat.accuracy { return $0.stat.accuracy < $1.stat.accuracy }
            return $0.key < $1.key
        }
    }

    /// Picks the next hand for a review pass: the most missed hand not yet
    /// shown this pass (and not the one just shown). When every hand has had
    /// its turn the pass starts over. Nil when the queue is empty.
    static func nextReviewKey(queue: [String], served: Set<String>, last: String?)
        -> (key: String, served: Set<String>)? {
        guard !queue.isEmpty else { return nil }
        var pass = served
        var pool = queue.filter { !pass.contains($0) && $0 != last }
        if pool.isEmpty {
            pass = []
            pool = queue.filter { $0 != last }
            if pool.isEmpty { pool = queue }   // a single hand left: it repeats
        }
        let pick = pool[0]
        pass.insert(pick)
        return (pick, pass)
    }

    /// Spots worth drilling: enough attempts to be signal, not yet mastered,
    /// worst accuracy first (more attempts breaks ties — stronger evidence).
    static func weakestSpots(
        in spots: [String: SpotStat],
        minAttempts: Int = 3,
        masteredAt: Double = 0.9,
        limit: Int = 5
    ) -> [(key: String, stat: SpotStat)] {
        spots
            .filter { $0.value.total >= minAttempts && $0.value.accuracy < masteredAt }
            .sorted {
                if $0.value.accuracy != $1.value.accuracy { return $0.value.accuracy < $1.value.accuracy }
                if $0.value.total != $1.value.total { return $0.value.total > $1.value.total }
                return $0.key < $1.key
            }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    /// Dealing weight for the smart quiz. Unseen spots get a strong pull so
    /// coverage grows, weak spots the strongest, and mastered spots stay in
    /// rotation but rare (so knowledge is still spot-checked over time).
    static func drillWeight(for stat: SpotStat?) -> Double {
        guard let stat, stat.total > 0 else { return 3 }
        if stat.accuracy >= 0.9 && stat.total >= 5 { return 0.5 }
        return 1 + 6 * (1 - stat.accuracy)
    }

    /// Formatter for the "yyyy-MM-dd" day keys. Locale and calendar are pinned
    /// so keys parse and render identically on every device — an unpinned
    /// formatter follows the device calendar (e.g. Buddhist year 2569), which
    /// would break streaks against keys written under a different region.
    private static func dayKeyFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    /// The longest goal-meeting run of consecutive days anywhere in history.
    /// Achievements use this instead of the live streak so a trophy, once
    /// earned, can never silently un-earn itself when a streak breaks.
    static func longestStreak(
        dayTotals: [String: Int],
        goal: Int,
        calendar: Calendar = .current
    ) -> Int {
        let f = dayKeyFormatter()

        let qualifying = dayTotals
            .filter { $0.value >= max(goal, 1) }
            .keys
            .compactMap { f.date(from: $0) }
            .sorted()

        var best = 0
        var run = 0
        var previous: Date?
        for day in qualifying {
            if let previous,
               let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// Consecutive days on which at least `goal` decisions were made, ending
    /// today — or ending yesterday when today's goal isn't met yet, so an
    /// unfinished day never reads as a broken streak. Keys are "yyyy-MM-dd".
    static func dailyStreak(
        dayTotals: [String: Int],
        goal: Int,
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let f = dayKeyFormatter()

        var day = today
        if (dayTotals[f.string(from: day)] ?? 0) < max(goal, 1) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while (dayTotals[f.string(from: day)] ?? 0) >= max(goal, 1) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}

extension Stats {
    /// True until the player has done anything that records progress: no
    /// graded plays, quiz answers, bets, count drills, count checks or daily
    /// challenge answers (those feed the day totals and spot accuracy).
    var hasNoProgress: Bool {
        data.strategyTotal == 0 && data.quizTotal == 0 && data.handsPlayed == 0
            && data.drillsCompleted == 0 && data.countChecks == 0 && data.betDecisions == 0
            && data.challenges.isEmpty && data.days.isEmpty && data.spots.isEmpty
    }
}
