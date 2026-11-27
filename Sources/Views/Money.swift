import Foundation

/// The one-line reminder shown on onboarding and session setup.
enum PracticeNotice {
    static let line = "Play money only. No real money, no prizes."
}

/// Dollar formatting shared by every play-money amount in the app.
///
/// Amounts read like money ("$1,250", "$7.50") so the app feels like a real
/// table, but nothing here is real: there is no buying, no cash-out and no
/// prizes, and `PracticeNotice.line` says so on setup and onboarding.
///
/// Sign convention (the same everywhere): a positive amount has no sign
/// ("$25"); `signed` adds "+" for gains ("+$25") and a true minus for losses
/// ("\u{2212}$25"); a loss passed to `string` reads "\u{2212}$25" too. Zero
/// never has a sign ("$0").
///
/// Kept free of SwiftUI so `scripts/logic-tests.sh` can compile it on macOS
/// alongside Engine/ and Store/.
enum Money {
    /// The minus sign used for losses: a real minus, not a hyphen.
    static let minus = "\u{2212}"

    /// Whole dollars show no decimals ("$1,250"); a fraction always shows two
    /// ("$7.50"), the way a 3:2 blackjack on an odd bet pays.
    private static func formatted(_ magnitude: Double) -> String {
        let isWhole = abs(magnitude - magnitude.rounded()) < 0.005
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = isWhole ? 0 : 2
        f.maximumFractionDigits = isWhole ? 0 : 2
        return f.string(from: NSNumber(value: magnitude)) ?? String(format: isWhole ? "%.0f" : "%.2f", magnitude)
    }

    /// "$1,234", "$7.50", or "\u{2212}$25" for a negative amount.
    static func string(_ value: Double) -> String {
        if value < -0.005 { return minus + "$" + formatted(-value) }
        return "$" + formatted(abs(value))
    }

    /// "$1,234" with no fraction, for summary tiles and chart axes.
    static func wholeString(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let body = f.string(from: NSNumber(value: abs(value))) ?? String(format: "%.0f", abs(value))
        return (value < -0.5 ? minus : "") + "$" + body
    }

    /// Same as `string`. Kept so older call sites read "chips" without adding
    /// the word: amounts are just "$1,234".
    static func chips(_ value: Double) -> String { string(value) }

    /// "+$50" / "\u{2212}$50" (zero has no sign).
    static func signedChips(_ value: Double) -> String { signed(value) }

    /// "+$50" / "\u{2212}$50" (zero has no sign).
    static func signed(_ value: Double) -> String {
        if value > 0.005 { return "+" + string(value) }
        if value < -0.005 { return string(value) }
        return string(0)
    }
}
