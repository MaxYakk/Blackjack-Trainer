import Foundation

/// Deterministic RNG (SplitMix64) so a given seed always deals the same
/// spots — the whole point of a shared daily challenge.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Pure dealing logic for the daily challenge: the date picks the hands.
enum DailyChallengeDeal {
    static let handCount = 10

    /// Stable FNV-1a hash of the date key — Swift's `hashValue` is randomized
    /// per launch and can't seed a shared daily deal.
    static func seed(for dateKey: String) -> UInt64 {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in dateKey.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001B3
        }
        return hash
    }

    /// The day's ten spots: same date key, same spots, every launch.
    static func spots(for dateKey: String) -> [CatalogSpot] {
        var rng = SeededGenerator(seed: seed(for: dateKey))
        return Array(SpotCatalog.all.shuffled(using: &rng).prefix(handCount))
    }
}
