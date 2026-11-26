import Testing
@testable import BlackjackTrainer

@MainActor
struct ProgressEmptyStateTests {
    @Test func aNewPlayerHasNoProgress() {
        let store = TestDefaults()
        #expect(Stats(defaults: store.defaults).hasNoProgress)
    }

    @Test func answeringDailyChallengeQuestionsCountsAsProgress() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        stats.recordChallengeAnswer(correct: true, spotKey: nil)
        #expect(!stats.hasNoProgress)
    }

    @Test func aFinishedDailyChallengeCountsAsProgress() {
        let store = TestDefaults()
        let stats = Stats(defaults: store.defaults)
        stats.recordChallengeResult(score: 7, total: 10, dateKey: "2026-11-26")
        #expect(!stats.hasNoProgress)
    }
}
