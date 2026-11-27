import Foundation
import Observation

enum DrillPhase {
    case idle, running, guessing, revealed
}

@MainActor
@Observable
final class CountDrillEngine {
    /// Shoe sizes the drill offers: the same ones the Play table offers.
    static let allowedDeckCounts = [2, 4, 6, 8]
    static let defaultDeckCount = 6

    /// Keeps a saved deck count to one the drill offers: the old 1 deck
    /// option becomes 2, anything else invalid (such as the old 5) goes to 6.
    static func clampDecks(_ n: Int) -> Int {
        if allowedDeckCounts.contains(n) { return n }
        return n == 1 ? 2 : defaultDeckCount
    }

    // Settings (persisted across launches)
    var numDecks = 6 {
        didSet {
            let clamped = Self.clampDecks(numDecks)
            if clamped != numDecks { numDecks = clamped }   // re-entry doesn't re-fire didSet
            saveSettings()
        }
    }
    var cardsPerDrill = 20 { didSet { saveSettings() } }
    var speedSeconds = 1.0 { didSet { saveSettings() } }
    var showHint = false { didSet { saveSettings() } }

    private(set) var phase: DrillPhase = .idle
    private(set) var currentCard: Card?
    private(set) var dealtCount = 0
    private(set) var runningCount = 0
    /// What the player guessed and whether it was right (nil until they submit).
    private(set) var lastGuess: Int?
    private(set) var lastGuessCorrect: Bool?

    /// Shoe size of the drill in progress, so settings changed afterwards
    /// (they apply to the next drill) can't rewrite a shown result.
    private var drillDecks = 6
    private var sequence: [Card] = []
    private var task: Task<Void, Never>?
    private let stats: Stats
    private let defaults: UserDefaults

    private var settingsLoaded = false

    init(stats: Stats, defaults: UserDefaults = .standard) {
        self.stats = stats
        self.defaults = defaults
        loadSettings()
        settingsLoaded = true
    }

    private func loadSettings() {
        let d = defaults
        guard d.object(forKey: "cd_saved") != nil else { return }
        numDecks = Self.clampDecks(d.integer(forKey: "cd_numDecks"))
        cardsPerDrill = d.integer(forKey: "cd_cards")
        speedSeconds = d.double(forKey: "cd_speed")
        showHint = d.bool(forKey: "cd_hint")
    }

    private func saveSettings() {
        guard settingsLoaded else { return }
        let d = defaults
        d.set(true, forKey: "cd_saved")
        d.set(numDecks, forKey: "cd_numDecks")
        d.set(cardsPerDrill, forKey: "cd_cards")
        d.set(speedSeconds, forKey: "cd_speed")
        d.set(showHint, forKey: "cd_hint")
    }

    var totalCards: Int { sequence.count }

    /// True while a drill is under way (cards dealing or waiting for a guess),
    /// when the settings must not change.
    var isActive: Bool { phase == .running || phase == .guessing }

    /// The most the running count can move in one drill.
    var guessRange: ClosedRange<Int> { -cardsPerDrill...cardsPerDrill }

    /// `value` pulled back into `guessRange`.
    func clampedGuess(_ value: Int) -> Int {
        min(max(value, guessRange.lowerBound), guessRange.upperBound)
    }

    // Floor at a quarter deck (matching Shoe.decksRemaining) so the true-count
    // division never blows up. The old floor of one full deck's fraction pinned
    // a 1-deck drill at 1.0 for its whole run, making true count == running count.
    var decksRemaining: Double {
        max((Double(drillDecks * 52) - Double(dealtCount)) / 52.0, 0.25)
    }

    var trueCount: Double {
        (Double(runningCount) / decksRemaining * 2).rounded() / 2
    }

    func start() {
        task?.cancel()
        drillDecks = numDecks
        var shoe = Shoe(numDecks: drillDecks)
        sequence = (0..<cardsPerDrill).map { _ in shoe.draw() }
        dealtCount = 0
        runningCount = 0
        lastGuess = nil
        lastGuessCorrect = nil
        currentCard = nil
        phase = .running

        task = Task { @MainActor in
            for card in sequence {
                if Task.isCancelled { return }
                currentCard = card
                runningCount += card.rank.hiLo
                dealtCount += 1
                try? await Task.sleep(nanoseconds: UInt64(speedSeconds * 1_000_000_000))
            }
            if !Task.isCancelled {
                currentCard = nil
                phase = .guessing
            }
        }
    }

    /// Returns whether the guess was correct.
    @discardableResult
    func submitGuess(_ guess: Int) -> Bool {
        let correct = guess == runningCount
        stats.recordDrill(correct: correct)
        lastGuess = guess
        lastGuessCorrect = correct
        phase = .revealed
        return correct
    }

    func reset() {
        task?.cancel()
        phase = .idle
        currentCard = nil
        dealtCount = 0
        runningCount = 0
        lastGuess = nil
        lastGuessCorrect = nil
    }
}
