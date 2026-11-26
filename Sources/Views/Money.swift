import Foundation

/// The one-line reminder shown on onboarding and session setup.
enum PracticeNotice {
    static let line = "Practice chips only. No real money, no prizes."
}

/// Comma-grouped practice-chip formatting shared by every chip amount in the
/// app. Chips have no money value, so there is no currency symbol: amounts are
/// plain numbers ("1,250"), and `chips` adds the word where a number would
/// otherwise stand alone ("1,250 chips").
///
/// Kept free of SwiftUI so `scripts/logic-tests.sh` can compile it on macOS
/// alongside Engine/ and Store/.
enum Money {
    /// Up to two decimals, none when the amount is whole. A 3:2 blackjack on an
    /// odd bet pays a fraction (a bet of 5 returns 7.5), so "7.5" shows as is.
    private static let amount: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    private static let whole: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    /// "1,234", or "1,234.5" / "0.25" when there is a fraction.
    static func string(_ value: Double) -> String {
        amount.string(from: NSNumber(value: value)) ?? String(format: "%g", value)
    }

    /// "1,234" with no fraction, for summary tiles.
    static func wholeString(_ value: Double) -> String {
        whole.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    /// "1,234 chips", or "1 chip" for exactly one.
    static func chips(_ value: Double) -> String {
        let text = string(value)
        return abs(value - 1) < 0.001 ? "\(text) chip" : "\(text) chips"
    }

    /// "+50 chips" / "-50 chips" (zero has no sign).
    static func signedChips(_ value: Double) -> String {
        if value > 0.005 { return "+" + chips(value) }
        if value < -0.005 { return "-" + chips(-value) }
        return chips(0)
    }
}
