import Foundation

/// One trophy: what it's for, how rare it is, and how close the player is.
struct Achievement: Identifiable {
    enum Tier: Int, Comparable {
        case bronze, silver, gold

        var name: String {
            switch self {
            case .bronze: return "Bronze"
            case .silver: return "Silver"
            case .gold: return "Gold"
            }
        }

        static func < (l: Tier, r: Tier) -> Bool { l.rawValue < r.rawValue }
    }

    let id: String
    let icon: String        // SF Symbol
    let title: String
    let detail: String
    let tier: Tier
    let category: String
    let progress: Double    // 0...1; 1 == unlocked
    let progressText: String

    var unlocked: Bool { progress >= 1 }
}

/// Computes the full trophy list from plain inputs (no Observation/UIKit,
/// so it compiles into the standalone test harness).
enum Achievements {
    struct Inputs {
        var decisions = 0            // play + quiz combined
        var decisionsCorrect = 0
        var decisionsClose = 0       // close calls (yellow), half credit
        var spotsPracticed = 0
        var masteredSpots = 0        // 90%+ accuracy over 5+ attempts
        var quizBestStreak = 0
        var handsPlayed = 0
        var blackjacks = 0
        var bestSessionNet: Double = 0   // most chips above the starting chips, best session ever
        var bestDrillStreak = 0
        var countChecksCorrect = 0
        var betDecisions = 0
        var betCorrect = 0
        var betClose = 0
        var challengesPlayed = 0
        var perfectChallenges = 0
        var longestDailyStreak = 0
    }

    // MARK: - What the Progress tab shows

    /// The few trophies worth a spot on Progress: the ones closest to
    /// unlocking, and the ones earned recently. The full list stays one tap away.
    struct Spotlight {
        let next: [Achievement]
        let recent: [Achievement]
    }

    /// Next up: the locked trophies with the most progress (easier tiers
    /// first on a tie, then list order), at most `nextCount`. Recently earned:
    /// trophies first seen unlocked on or after `since` ("yyyy-MM-dd"), newest
    /// first, at most `recentCount`. A date of "" means "earned before dates
    /// were tracked" and never counts as recent.
    static func spotlight(
        all: [Achievement], dates: [String: String], since: String,
        nextCount: Int = 2, recentCount: Int = 2
    ) -> Spotlight {
        let order = Dictionary(uniqueKeysWithValues: all.enumerated().map { ($1.id, $0) })
        let next = all.filter { !$0.unlocked }
            .sorted {
                if $0.progress != $1.progress { return $0.progress > $1.progress }
                if $0.tier != $1.tier { return $0.tier < $1.tier }
                return (order[$0.id] ?? 0) < (order[$1.id] ?? 0)
            }
            .prefix(nextCount)
        let recent = all.filter { item in
            guard item.unlocked, let day = dates[item.id], !day.isEmpty else { return false }
            return day >= since
        }
        .sorted {
            let a = dates[$0.id] ?? "", b = dates[$1.id] ?? ""
            if a != b { return a > b }
            if $0.tier != $1.tier { return $0.tier > $1.tier }
            return $0.id < $1.id
        }
        .prefix(recentCount)
        return Spotlight(next: Array(next), recent: Array(recent))
    }

    /// Records the day each trophy was first seen unlocked. The first time
    /// this runs (`seeded` false) every trophy already unlocked is stamped ""
    /// (earned before tracking), so an upgrade doesn't flood "recently earned".
    /// Dates are never removed.
    static func updatedDates(
        existing: [String: String], seeded: Bool, unlocked: [String], today: String
    ) -> (dates: [String: String], seeded: Bool) {
        var dates = existing
        for id in unlocked where dates[id] == nil {
            dates[id] = seeded ? today : ""
        }
        return (dates, true)
    }

    static let categories = ["Strategy", "Table Play", "Card Counting", "Dedication"]

    static func all(from i: Inputs) -> [Achievement] {
        // Close calls (yellow) count as half credit.
        let accuracy = Accuracy.fraction(correct: i.decisionsCorrect, close: i.decisionsClose,
                                         total: i.decisions) ?? 0
        let betAccuracy = Accuracy.fraction(correct: i.betCorrect, close: i.betClose,
                                            total: i.betDecisions) ?? 0

        return [
            // MARK: Strategy
            count("first-steps", "figure.walk", "First Steps",
                  "Make your first graded decision", .bronze, "Strategy",
                  current: i.decisions, target: 1),
            count("century", "100.circle.fill", "Century",
                  "Make 100 graded decisions", .silver, "Strategy",
                  current: i.decisions, target: 100),
            count("grinder", "flame.circle.fill", "Marathon",
                  "Make 1,000 graded decisions", .gold, "Strategy",
                  current: i.decisions, target: 1_000),
            gated("sharp", "scope", "Sharp",
                  "90% accuracy over 50+ decisions", .silver, "Strategy",
                  volume: i.decisions, volumeTarget: 50,
                  quality: accuracy, qualityTarget: 0.9),
            gated("surgeon", "cross.case.fill", "Surgeon",
                  "95% accuracy over 200+ decisions", .gold, "Strategy",
                  volume: i.decisions, volumeTarget: 200,
                  quality: accuracy, qualityTarget: 0.95),
            count("explorer", "map.fill", "Explorer",
                  "Practice 100 different chart spots", .silver, "Strategy",
                  current: i.spotsPracticed, target: 100),
            count("cartographer", "globe.americas.fill", "Cartographer",
                  "Practice 250 different chart spots", .gold, "Strategy",
                  current: i.spotsPracticed, target: 250),
            count("spot-master", "checkmark.seal.fill", "Spot Master",
                  "Master 10 spots (90%+ over 5+ tries)", .silver, "Strategy",
                  current: i.masteredSpots, target: 10),
            count("chart-master", "crown.fill", "Chart Master",
                  "Master 50 spots — the chart is yours", .gold, "Strategy",
                  current: i.masteredSpots, target: 50),
            count("flawless-10", "bolt.fill", "Flawless 10",
                  "10 quiz answers in a row", .silver, "Strategy",
                  current: i.quizBestStreak, target: 10),
            count("flawless-25", "bolt.shield.fill", "Flawless 25",
                  "25 quiz answers in a row", .gold, "Strategy",
                  current: i.quizBestStreak, target: 25),

            // MARK: Table Play
            count("first-hand", "suit.spade.fill", "First Hand",
                  "Play your first hand", .bronze, "Table Play",
                  current: i.handsPlayed, target: 1),
            count("regular-table", "table.furniture.fill", "Regular",
                  "Play 100 hands", .silver, "Table Play",
                  current: i.handsPlayed, target: 100),
            count("natural", "sparkles", "Natural",
                  "Land your first blackjack", .bronze, "Table Play",
                  current: i.blackjacks, target: 1),
            count("lucky-sevens", "7.circle.fill", "Seven Naturals",
                  "Land 7 blackjacks", .silver, "Table Play",
                  current: i.blackjacks, target: 7),
            chipGoal("high-roller", "arrow.up.right.circle.fill", "Hot Session",
                  "Climb 500 chips above your starting chips in one session", .silver, "Table Play",
                  current: i.bestSessionNet, target: 500),
            chipGoal("whale", "star.circle.fill", "Peak Session",
                  "Climb 1,500 chips above your starting chips in one session", .gold, "Table Play",
                  current: i.bestSessionNet, target: 1_500),

            // MARK: Card Counting
            count("counter", "eye.fill", "Counter",
                  "Nail 10 count drills in a row", .silver, "Card Counting",
                  current: i.bestDrillStreak, target: 10),
            count("eagle-eye", "eye.trianglebadge.exclamationmark.fill", "Eagle Eye",
                  "Nail 25 count drills in a row", .gold, "Card Counting",
                  current: i.bestDrillStreak, target: 25),
            count("sixth-sense", "brain.fill", "Sixth Sense",
                  "Answer 10 mid-hand count checks right", .silver, "Card Counting",
                  current: i.countChecksCorrect, target: 10),
            count("disciplined", "chart.bar.fill", "Disciplined",
                  "Grade 25 bets against the count", .bronze, "Card Counting",
                  current: i.betDecisions, target: 25),
            gated("bankroll-boss", "target", "Bet Master",
                  "85% bet accuracy over 40+ bets", .gold, "Card Counting",
                  volume: i.betDecisions, volumeTarget: 40,
                  quality: betAccuracy, qualityTarget: 0.85),

            // MARK: Dedication
            count("challenger", "calendar.badge.checkmark", "Challenger",
                  "Finish your first Daily Challenge", .bronze, "Dedication",
                  current: i.challengesPlayed, target: 1),
            count("challenge-vet", "calendar.circle.fill", "Challenge Veteran",
                  "Finish 10 Daily Challenges", .silver, "Dedication",
                  current: i.challengesPlayed, target: 10),
            count("perfect-day", "trophy.fill", "Perfect Day",
                  "Score 10/10 on a Daily Challenge", .gold, "Dedication",
                  current: i.perfectChallenges, target: 1),
            count("streak-3", "flame", "Warming Up",
                  "3-day goal streak", .bronze, "Dedication",
                  current: i.longestDailyStreak, target: 3),
            count("streak-7", "flame.fill", "On Fire",
                  "7-day goal streak", .silver, "Dedication",
                  current: i.longestDailyStreak, target: 7),
            count("streak-30", "flame.circle.fill", "Unstoppable",
                  "30-day goal streak", .gold, "Dedication",
                  current: i.longestDailyStreak, target: 30),
        ]
    }

    // MARK: - Builders

    private static func count(
        _ id: String, _ icon: String, _ title: String, _ detail: String,
        _ tier: Achievement.Tier, _ category: String, current: Int, target: Int
    ) -> Achievement {
        Achievement(
            id: id, icon: icon, title: title, detail: detail, tier: tier, category: category,
            progress: min(Double(current) / Double(max(target, 1)), 1),
            progressText: "\(min(current, target))/\(target)"
        )
    }

    private static func chipGoal(
        _ id: String, _ icon: String, _ title: String, _ detail: String,
        _ tier: Achievement.Tier, _ category: String, current: Double, target: Double
    ) -> Achievement {
        Achievement(
            id: id, icon: icon, title: title, detail: detail, tier: tier, category: category,
            progress: min(current / max(target, 1), 1),
            progressText: "\(Int(max(min(current, target), 0)))/\(Int(target)) chips"
        )
    }

    /// Accuracy trophies need volume before quality means anything: progress
    /// climbs to 50% as the sample fills, then the accuracy itself carries
    /// the rest. Both parts full == unlocked.
    private static func gated(
        _ id: String, _ icon: String, _ title: String, _ detail: String,
        _ tier: Achievement.Tier, _ category: String,
        volume: Int, volumeTarget: Int, quality: Double, qualityTarget: Double
    ) -> Achievement {
        let volumePart = min(Double(volume) / Double(max(volumeTarget, 1)), 1)
        let qualityPart = min(quality / qualityTarget, 1)
        let done = volumePart >= 1 && qualityPart >= 1
        let text = volumePart < 1
            ? "\(volume)/\(volumeTarget) played"
            : "\(Int(quality * 100))%/\(Int(qualityTarget * 100))%"
        return Achievement(
            id: id, icon: icon, title: title, detail: detail, tier: tier, category: category,
            progress: done ? 1 : min(volumePart * 0.5 + qualityPart * 0.5, 0.99),
            progressText: text
        )
    }
}
