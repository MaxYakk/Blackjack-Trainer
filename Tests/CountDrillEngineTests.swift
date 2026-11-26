import Foundation
import Testing
@testable import BlackjackTrainer

@MainActor
struct CountDrillEngineTests {
    private func makeEngine(_ store: TestDefaults) -> CountDrillEngine {
        CountDrillEngine(stats: Stats(defaults: store.defaults), defaults: store.defaults)
    }

    @Test func deckOptionsMatchThePlayTable() {
        #expect(CountDrillEngine.allowedDeckCounts == PlayEngine.allowedDeckCounts)
        #expect(CountDrillEngine.defaultDeckCount == PlayEngine.defaultDeckCount)
    }

    @Test func freshEngineUsesSixDecksAndNoTrainingWheels() {
        let engine = makeEngine(TestDefaults())
        #expect(engine.numDecks == 6)
        #expect(engine.showHint == false)
    }

    @Test func savedRetiredDeckCountsMoveToOfferedOnes() {
        let one = TestDefaults()
        one.defaults.set(true, forKey: "cd_saved")
        one.defaults.set(1, forKey: "cd_numDecks")
        one.defaults.set(20, forKey: "cd_cards")
        #expect(makeEngine(one).numDecks == 2)

        let five = TestDefaults()
        five.defaults.set(true, forKey: "cd_saved")
        five.defaults.set(5, forKey: "cd_numDecks")
        five.defaults.set(20, forKey: "cd_cards")
        #expect(makeEngine(five).numDecks == 6)
    }

    @Test func settingAnUnofferedDeckCountIsClamped() {
        let engine = makeEngine(TestDefaults())
        engine.numDecks = 5
        #expect(engine.numDecks == 6)
        engine.numDecks = 1
        #expect(engine.numDecks == 2)
        engine.numDecks = 8
        #expect(engine.numDecks == 8)
    }

    @Test func guessRangeFollowsDrillLength() {
        let engine = makeEngine(TestDefaults())
        engine.cardsPerDrill = 20
        #expect(engine.guessRange == -20...20)
        #expect(engine.clampedGuess(35) == 20)
        #expect(engine.clampedGuess(-35) == -20)
        #expect(engine.clampedGuess(7) == 7)
    }

    @Test func submittedGuessIsRememberedUntilTheNextDrill() async {
        let engine = makeEngine(TestDefaults())
        engine.cardsPerDrill = 10
        engine.speedSeconds = 0.001
        #expect(engine.lastGuessCorrect == nil)
        engine.start()
        #expect(engine.isActive)
        await waitUntil { engine.phase == .guessing }
        #expect(engine.isActive)
        #expect(engine.lastGuessCorrect == nil, "nothing is judged before the player submits")

        let wrong = engine.submitGuess(engine.runningCount + 1)
        #expect(!wrong)
        #expect(engine.lastGuessCorrect == false)
        #expect(engine.lastGuess == engine.runningCount + 1)
        #expect(!engine.isActive)

        engine.reset()
        #expect(engine.lastGuess == nil && engine.lastGuessCorrect == nil)
    }
}
