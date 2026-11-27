import Foundation

/// Picks which chip denominations sit in the tray. The table minimum sets
/// the smallest chip and the starting chips set the largest, so a 25-chip
/// table never shows a 5 chip and a 500-chip stack never shows a 5,000 one.
enum ChipSizing {
    /// The most practice chips a session can start with, whether picked from
    /// the ladder or typed in.
    static let maxStartingChips = 10_000.0

    /// The preset steps for starting chips, low to high, ending at the cap.
    static let startingChipOptions: [Double] = [25, 50, 100, 250, 500, 1000, 2000, 5000, 10_000]

    /// Every minimum a table can be set to, low to high. Kept to whole values
    /// (and whole thousands) only — `label` renders anything ≥ 1,000 as
    /// "XK", and a value like 2500 rounds to a "3K" label that doesn't
    /// match the actual amount. The top option is a fifth of the starting
    /// chips cap, so every minimum leaves room for several bets.
    static let minimumOptions: [Double] = [0.10, 1, 5, 10, 25, 50, 100, 250, 500, 1000, 2000]

    /// Every chip value the tray can draw from, low to high. Each one has its
    /// own color in `ChipStyle`.
    static let ladder: [Double] = [
        0.10, 0.25, 1, 5, 10, 25, 50, 100, 250, 500,
        1000, 2000, 5000, 10000, 25000, 50000, 100000,
    ]

    /// The classic chip progression. When several chips could fill a gap
    /// in the tray, these win over the in-between values (10, 50, 250, ...).
    private static let primary: Set<Double> = [1, 5, 25, 100, 500, 1000, 5000, 25000, 100000]

    /// The largest chip has to fit into the starting chips at least this many times.
    static let buyInToTopChipRatio = 4.0

    /// Up to five chips: the smallest is always the table minimum, the
    /// largest is the biggest ladder chip that fits into the starting chips four
    /// times, and up to three ladder chips sit in between, spread evenly on
    /// a log scale. A narrow range just shows fewer chips. 100 starting chips
    /// at a 25 minimum gets a single 25 chip, since that's the only bet
    /// size that table plays in.
    static func denominations(buyIn: Double, tableMinimum: Double) -> [Double] {
        let low = tableMinimum
        let cap = buyIn / buyInToTopChipRatio + 0.001
        guard let high = ladder.last(where: { $0 > low + 0.001 && $0 <= cap }) else { return [low] }

        let between = ladder.filter { $0 > low + 0.001 && $0 < high - 0.001 }
        if between.count <= 3 { return [low] + between + [high] }

        let logLow = log(low), logHigh = log(high)
        var picked: [Double] = []
        for t in [0.25, 0.5, 0.75] {
            let target = logLow + (logHigh - logLow) * t
            let best = between
                .filter { !picked.contains($0) }
                .min { distance($0, to: target) < distance($1, to: target) }
            if let best { picked.append(best) }
        }
        return [low] + picked.sorted() + [high]
    }

    private static func distance(_ chip: Double, to target: Double) -> Double {
        abs(log(chip) - target) * (primary.contains(chip) ? 1 : 1.35)
    }

    /// A compact "X" / "0.10" / "XK" label for a minimum or starting amount.
    static func label(_ value: Double) -> String {
        if value < 1 { return String(format: "%.2f", value) }
        if value >= 1000 { return "\(Int((value / 1000).rounded()))K" }
        return "\(Int(value))"
    }
}
