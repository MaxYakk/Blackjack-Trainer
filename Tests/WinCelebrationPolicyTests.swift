import Foundation

@main
struct WinCelebrationPolicyTests {
    static func main() {
        precondition(!WinCelebrationPolicy.showsConfetti(hasBlackjack: false, reduceMotion: false),
                     "ordinary wins should not launch confetti")
        precondition(WinCelebrationPolicy.showsConfetti(hasBlackjack: true, reduceMotion: false),
                     "blackjack should retain the special celebration")
        precondition(!WinCelebrationPolicy.showsConfetti(hasBlackjack: true, reduceMotion: true),
                     "Reduce Motion should suppress confetti")
        precondition(!WinCelebrationPolicy.countsUpAmount,
                     "the final win amount should appear immediately")
        precondition(WinCelebrationPolicy.bannerDelayNanoseconds == 250_000_000,
                     "the win banner should wait 0.25 seconds after settlement")

        print("WinCelebrationPolicyTests passed")
    }
}
