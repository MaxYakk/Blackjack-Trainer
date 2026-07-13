import SwiftUI

struct CountDrillView: View {
    @Environment(Stats.self) private var stats
    @State private var engine: CountDrillEngine?

    var body: some View {
        Group {
            if let engine {
                CountDrillContent(engine: engine)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if engine == nil { engine = CountDrillEngine(stats: stats) }
        }
    }
}

private struct CountDrillContent: View {
    @Bindable var engine: CountDrillEngine
    @Environment(Stats.self) private var stats
    @State private var guess = 0
    @State private var lastResultCorrect: Bool?
    @State private var showHints = true

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Count Drill")
            ScrollView {
                VStack(spacing: 16) {
                    settings
                    stage
                    if engine.phase == .guessing || engine.phase == .revealed {
                        answerCard
                    }
                    if showHints {
                        hiloReference
                        explainer
                    }
                }
                .padding()
            }
        }
        .background(Theme.feltDark.ignoresSafeArea())
    }

    private var settings: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Decks in shoe")
                Spacer()
                Picker("Decks", selection: $engine.numDecks) {
                    ForEach([1, 2, 4, 5, 6, 8], id: \.self) { Text("\($0)").tag($0) }
                }.pickerStyle(.menu)
            }
            HStack {
                Text("Cards")
                Spacer()
                Picker("Cards", selection: $engine.cardsPerDrill) {
                    ForEach([10, 20, 30, 52, 104], id: \.self) { Text("\($0)").tag($0) }
                }.pickerStyle(.menu)
            }
            HStack {
                Text("Speed")
                Spacer()
                Picker("Speed", selection: $engine.speedSeconds) {
                    Text("Extra Slow 2s").tag(2.0)
                    Text("Slow 1.5s").tag(1.5)
                    Text("Medium 1s").tag(1.0)
                    Text("Fast 0.6s").tag(0.6)
                    Text("Very Fast 0.35s").tag(0.35)
                }.pickerStyle(.menu)
            }
            Toggle("Show live count (hint)", isOn: $engine.showHint)
                .tint(Theme.accent)
            Toggle("Show Hi-Lo reference & tips", isOn: $showHints)
                .tint(Theme.accent)
        }
        .font(.subheadline)
        .padding()
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var stage: some View {
        VStack(spacing: 14) {
            ZStack {
                if engine.phase == .running, let card = engine.currentCard {
                    CardView(card: card, size: 2.0)
                } else if engine.phase == .guessing || engine.phase == .revealed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.good)
                } else {
                    Text("?")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(height: 150)

            if engine.phase == .running {
                Text("Card \(engine.dealtCount)/\(engine.totalCards)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if engine.showHint && engine.phase == .running {
                Text("Running \(signed(engine.runningCount))  •  \(engine.decksRemaining, specifier: "%.1f") left  •  True \(engine.trueCount, specifier: "%+.1f")")
                    .font(.caption)
                    .padding(6)
                    .background(Color.black.opacity(0.3), in: Capsule())
            }

            Button {
                lastResultCorrect = nil
                guess = 0
                engine.start()
            } label: {
                Text(engine.phase == .idle ? "Start Drill" : "Restart Drill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.black)
            }
            .disabled(engine.phase == .running)
            .opacity(engine.phase == .running ? 0.5 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.felt, in: RoundedRectangle(cornerRadius: 16))
    }

    private var answerCard: some View {
        VStack(spacing: 12) {
            Stepper(value: $guess, in: -50...50) {
                HStack {
                    Text("Your running count guess:")
                    Spacer()
                    Text(signed(guess)).fontWeight(.bold).foregroundStyle(Theme.accent)
                }
            }
            .disabled(engine.phase == .revealed)

            if engine.phase == .guessing {
                Button {
                    lastResultCorrect = engine.submitGuess(guess)
                } label: {
                    Text("Submit")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Theme.felt, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if engine.phase == .revealed, let correct = lastResultCorrect {
                Text(resultText(correct: correct))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(correct ? Theme.good : Theme.bad)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private func resultText(correct: Bool) -> String {
        let tc = engine.trueCount
        let base = correct
            ? "Correct! Running count was \(engine.runningCount)."
            : "Actual running count was \(engine.runningCount) (you guessed \(guess))."
        return base + String(format: " True count %+.1f with %.1f decks remaining.", tc, engine.decksRemaining)
    }

    private var hiloReference: some View {
        HStack(spacing: 14) {
            Text("Hi-Lo:")
            Text("2–6 = +1").foregroundStyle(Theme.good)
            Text("7–9 = 0").foregroundStyle(.secondary)
            Text("10–A = −1").foregroundStyle(Theme.bad)
        }
        .font(.caption)
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Counting a multi-deck shoe")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text("The running count means less on its own once several decks are in play. Convert it to a true count for your real edge:")
                .font(.caption)
            Text("True Count = Running Count ÷ Decks Remaining")
                .font(.caption.weight(.bold))
                .padding(8)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            Text("Estimate decks remaining by eye (nearest ½). Example: +6 running with 3 decks left in a 5-deck shoe → true count +2. Bet and deviate on the true count, not the raw running count.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}
