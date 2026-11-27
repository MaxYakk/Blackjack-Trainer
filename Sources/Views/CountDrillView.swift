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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isCurrentTab) private var isCurrentTab
    @State private var guess = 0
    @State private var confirmRestart = false
    @AppStorage("cd_showTips") private var showTips = true
    @ScaledMetric(relativeTo: .body) private var stageHeight: CGFloat = 150

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Count Drill")
            ScrollView {
                VStack(spacing: Space.md) {
                    stage
                    if engine.phase == .guessing || engine.phase == .revealed {
                        answerCard
                    }
                    CountDrillSettingsPanel(engine: engine, showTips: $showTips)
                    if showTips {
                        hiloReference
                        explainer
                    }
                }
                .padding(Space.md)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        // Tab views stay alive: don't keep dealing (or announcing) off-screen.
        .onChange(of: isCurrentTab) { _, current in
            if !current, engine.isActive { engine.reset() }
        }
        .onDisappear {
            if engine.isActive { engine.reset() }
        }
        .onChange(of: engine.phase) { _, phase in
            if phase == .guessing {
                AccessibilityNotification.Announcement("Cards done. What's the count?").post()
            }
        }
        .themedConfirm("Restart this drill?", isPresented: $confirmRestart,
                       message: "You've seen every card. Restarting throws this drill away without a score.",
                       actions: [.destructive("Restart drill") { restart() },
                                 .cancel("Keep going")])
    }

    // MARK: Stage

    private var stage: some View {
        VStack(spacing: Space.sm) {
            stageContent
                .frame(maxWidth: .infinity, minHeight: stageHeight)

            if engine.phase == .running {
                VStack(spacing: Space.xs) {
                    Text("Card \(engine.dealtCount)/\(engine.totalCards)")
                        .font(.numberInline)
                        .foregroundStyle(.textSecondary)
                    ProgressBar(value: engine.totalCards == 0 ? 0 : Double(engine.dealtCount) / Double(engine.totalCards),
                                label: "Cards dealt")
                }
            }

            if engine.showHint && engine.phase == .running {
                Text("Running \(signed(engine.runningCount))  \u{2022}  \(engine.decksRemaining, specifier: "%.1f") left  \u{2022}  True \(engine.trueCount, specifier: "%+.1f")")
                    .font(.captionText)
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .background(Color.surfaceRaised, in: Capsule())
            }

            control
        }
        .frame(maxWidth: .infinity)
        .panel()
    }

    @ViewBuilder
    private var stageContent: some View {
        switch engine.phase {
        case .idle:
            VStack(spacing: Space.sm) {
                CardView(card: nil, size: 2.0, scalesWithText: true)
                Text("Cards flash one at a time. Keep a Hi Lo running count in your head.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        case .running:
            // A new identity per card, so even a repeat of the same card
            // visibly pops in (a quick fade with Reduce Motion).
            ZStack {
                if let card = engine.currentCard {
                    CardView(card: card, size: 2.0, scalesWithText: true)
                        .id(engine.dealtCount)
                        .transition(Motion.pop(reduceMotion))
                }
            }
            .animation(Motion.standard.resolved(reduceMotion), value: engine.dealtCount)
        case .guessing:
            VStack(spacing: Space.sm) {
                CardView(card: nil, faceDown: true, size: 1.6, scalesWithText: true)
                Text("What's the count?")
                    .font(.sectionTitle)
                    .foregroundStyle(.textPrimary)
                Text("All \(engine.totalCards) cards are done. Enter your running count below.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        case .revealed:
            let right = engine.lastGuessCorrect == true
            VStack(spacing: Space.xs) {
                Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .scaledFont(size: 56, weight: .regular, relativeTo: .largeTitle, maxSize: 90)
                    .foregroundStyle(right ? Color.positive : Color.negative)
                    .accessibilityHidden(true)
                Text("Running count")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
                Text(signed(engine.runningCount))
                    .font(.numberHero)
                    .foregroundStyle(.textPrimary)
            }
        }
    }

    // MARK: Control button

    private var controlTitle: String {
        switch engine.phase {
        case .idle: return "Start Drill"
        case .running, .guessing: return "Restart Drill"
        case .revealed: return "Next Drill"
        }
    }

    @ViewBuilder
    private var control: some View {
        let button = Button(controlTitle) { controlTapped() }
            .accessibilityIdentifier("countDrillControl")
        if engine.phase == .running || engine.phase == .guessing {
            button.buttonStyle(.secondaryCompact)
        } else {
            button.buttonStyle(.primary)
        }
    }

    private func controlTapped() {
        switch engine.phase {
        case .guessing:
            // The whole sequence has been watched; make sure it isn't a stray tap.
            confirmRestart = true
        case .running:
            // Losing count mid run is the normal reason to restart: no friction.
            restart()
        case .idle:
            beginDrill()
        case .revealed:
            beginDrill()
        }
    }

    private func beginDrill() {
        guess = 0
        engine.start()
    }

    private func restart() {
        guess = 0
        engine.reset()
    }

    // MARK: Answer

    private var answerCard: some View {
        VStack(spacing: Space.sm) {
            Text(engine.phase == .guessing ? "Your running count" : "Your guess")
                .font(.heading)
                .foregroundStyle(.textPrimary)
            CountGuessControl(guess: $guess, range: engine.guessRange,
                              enabled: engine.phase == .guessing)

            if engine.phase == .guessing {
                PrimaryButton("Submit") { engine.submitGuess(guess) }
            }

            if engine.phase == .revealed, let correct = engine.lastGuessCorrect {
                FeedbackPill(correct
                             ? "Correct! The running count was \(signed(engine.runningCount))."
                             : "Not quite. It was \(signed(engine.runningCount)), you said \(signed(engine.lastGuess ?? guess)).",
                             kind: correct ? .correct : .incorrect)
                Text(String(format: "True count %+.1f with %.1f decks remaining.",
                            engine.trueCount, engine.decksRemaining))
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .panel()
    }

    // MARK: Reference

    private var hiloReference: some View {
        HStack(spacing: Space.sm) {
            Text("Hi Lo:")
            Text("2-6 = +1").foregroundStyle(.positive)
            Text("7-9 = 0").foregroundStyle(.textSecondary)
            Text("10-A = -1").foregroundStyle(.negative)
        }
        .font(.captionText)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var explainer: some View {
        Panel(spacing: Space.xs) {
            Text("Tips: running to true count")
                .font(.heading)
                .foregroundStyle(.accent)
            Text("True count = running count ÷ decks left")
                .font(.detail.weight(.bold))
                .foregroundStyle(.textPrimary)
                .padding(Space.xs)
                .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            tip("Guess the decks left by eye, to the nearest half deck.")
            tip("Example: +6 with 3 decks left is a true count of +2.")
            tip("Bet and change plays by the true count, not the running count.")
        }
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            Text("•")
                .foregroundStyle(.accent)
                .accessibilityHidden(true)
            Text(text)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.detail)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}
