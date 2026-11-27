import Foundation

/// Small formatting helpers shared by the Progress screens.
enum ProgressFormat {
    /// "82%", or nil when nothing has been recorded yet.
    static func percent(correct: Int, total: Int) -> String? {
        guard total > 0 else { return nil }
        return "\(Int((Double(correct) / Double(total) * 100).rounded()))%"
    }

    static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    /// Parses the store's "yyyy-MM-dd" day keys. Pinned locale and calendar,
    /// matching how the keys are written.
    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func date(fromDayKey key: String) -> Date? {
        dayParser.date(from: key)
    }
}

/// A day on the accuracy chart.
struct AccuracyPoint: Identifiable {
    let date: Date
    let percent: Double
    var id: Date { date }
}

/// Plain-language summaries of the charts, for VoiceOver.
enum TrendSummary {
    static func accuracy(_ points: [AccuracyPoint]) -> String {
        guard let first = points.first, let last = points.last, points.count > 1 else {
            return "Not enough days yet."
        }
        let delta = Int((last.percent - first.percent).rounded())
        let change: String
        if delta > 0 {
            change = "up \(delta) points since the first day"
        } else if delta < 0 {
            change = "down \(-delta) points since the first day"
        } else {
            change = "unchanged since the first day"
        }
        let low = Int((points.map(\.percent).min() ?? 0).rounded())
        let high = Int((points.map(\.percent).max() ?? 0).rounded())
        return "\(points.count) days. Latest \(Int(last.percent.rounded())) percent, \(change). Range \(low) to \(high) percent."
    }

    static func chips(_ history: [Double]) -> String {
        guard let first = history.first, let last = history.last, history.count > 1 else {
            return "Not enough hands yet."
        }
        let low = history.min() ?? last
        let high = history.max() ?? last
        return "\(history.count) hands. Started at \(Money.wholeString(first)), now \(Money.wholeString(last)). Low \(Money.wholeString(low)), high \(Money.wholeString(high))."
    }
}
