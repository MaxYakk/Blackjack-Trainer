import Foundation
import Observation

enum DrillPhase {
    case idle, running, guessing, revealed
}

@MainActor
@Observable
final class CountDrillEngine {
    // Settings (persisted across launches)
    var numDecks = 5 { didSet { saveSettings() } }
    var cardsPerDrill = 20 { didSet { saveSettings() } }
    var speedSeconds = 1.0 { didSet { saveSettings() } }
    var showHint = false { didSet { saveSettings() } }

    private(set) var phase: DrillPhase = .idle
    private(set) var currentCard: Card?
    private(set) var dealtCount = 0
    private(set) var runningCount = 0

    private var sequence: [Card] = []
    private var task: Task<Void, Never>?
    private let stats: Stats

    private var settingsLoaded = false

    init(stats: Stats) {
        self.stats = stats
        loadSettings()
        settingsLoaded = true
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        guard d.object(forKey: "cd_saved") != nil else { return }
        numDecks = d.integer(forKey: "cd_numDecks")
        cardsPerDrill = d.integer(forKey: "cd_cards")
        speedSeconds = d.double(forKey: "cd_speed")
        showHint = d.bool(forKey: "cd_hint")
    }

    private func saveSettings() {
        guard settingsLoaded else { return }
        let d = UserDefaults.standard
        d.set(true, forKey: "cd_saved")
        d.set(numDecks, forKey: "cd_numDecks")
        d.set(cardsPerDrill, forKey: "cd_cards")
        d.set(speedSeconds, forKey: "cd_speed")
        d.set(showHint, forKey: "cd_hint")
    }

    var totalCards: Int { sequence.count }

    var decksRemaining: Double {
        let shoeCards = Double(numDecks * 52)
        return max((shoeCards - Double(dealtCount)) / 52.0, 52.0 / shoeCards)
    }

    var trueCount: Double {
        (Double(runningCount) / decksRemaining * 2).rounded() / 2
    }

    func start() {
        task?.cancel()
        var shoe = Shoe(numDecks: numDecks)
        sequence = (0..<cardsPerDrill).map { _ in shoe.draw() }
        dealtCount = 0
        runningCount = 0
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
        phase = .revealed
        return correct
    }

    func reset() {
        task?.cancel()
        phase = .idle
        currentCard = nil
        dealtCount = 0
        runningCount = 0
    }
}
