import Foundation
import Testing
@testable import BlackjackTrainer

struct WinCelebrationPolicyTests {
    @Test static func runAll() {
        #expect(!WinCelebrationPolicy.showsConfetti(hasBlackjack: false, reduceMotion: false),
                     "ordinary wins should not launch confetti")
        #expect(WinCelebrationPolicy.showsConfetti(hasBlackjack: true, reduceMotion: false),
                     "blackjack should retain the special celebration")
        #expect(!WinCelebrationPolicy.showsConfetti(hasBlackjack: true, reduceMotion: true),
                     "Reduce Motion should suppress confetti")
        #expect(!WinCelebrationPolicy.countsUpAmount,
                     "the final win amount should appear immediately")
        #expect(WinCelebrationPolicy.bannerDelayNanoseconds == 100_000_000,
                     "the win banner should wait 0.1 seconds after settlement")
    }
}
