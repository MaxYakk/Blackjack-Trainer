import Testing
@testable import BlackjackTrainer

// The owner dislikes the old sounds, the losing buzz most of all: a loss and a
// push are silent, and the on/off switch still silences everything.
//
// Compile alongside: Sources/Engine

struct PlaySoundTests {
    @Test func lossAndPushAreSilent() {
        #expect(!Sound.Cue.lose.isAudible)
        #expect(!Sound.Cue.push.isAudible)
    }

    @Test func cardChipAndWinStayAudible() {
        #expect(Sound.Cue.card.isAudible)
        #expect(Sound.Cue.chip.isAudible)
        #expect(Sound.Cue.win.isAudible)
    }

    @Test func playingWhileSwitchedOffDoesNothing() {
        let was = Sound.enabled
        defer { Sound.enabled = was }
        Sound.enabled = false
        Sound.play(.win)   // must not crash or play
        #expect(Sound.enabled == false)
    }
}
