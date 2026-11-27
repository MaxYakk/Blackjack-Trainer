import Foundation

/// Keeps ordinary wins restrained while preserving a special moment for a
/// natural blackjack.
enum WinCelebrationPolicy {
    static let countsUpAmount = false
    static let bannerDelayNanoseconds: UInt64 = 100_000_000

    static func showsConfetti(hasBlackjack: Bool, reduceMotion: Bool) -> Bool {
        hasBlackjack && !reduceMotion
    }
}
