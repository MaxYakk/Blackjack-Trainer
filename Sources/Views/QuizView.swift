import SwiftUI

struct QuizView: View {
    @Environment(Stats.self) private var stats
    @State private var engine: QuizEngine?
    /// Mirrors the engine's saved difficulty so a mode chosen elsewhere
    /// (Progress "Drill these in Smart mode") applies when the tab opens.
    @AppStorage(QuizEngine.difficultyKey) private var storedDifficulty = QuizDifficulty.normal.rawValue

    var body: some View {
        Group {
            if let engine {
                QuizContent(engine: engine)
            } else {
                Color.clear
            }
        }
        .onAppear { if engine == nil { engine = QuizEngine(stats: stats) } }
        .onChange(of: storedDifficulty) { _, raw in
            guard let engine, let mode = QuizDifficulty(rawValue: raw), engine.difficulty != mode else { return }
            engine.difficulty = mode
        }
    }
}

private struct QuizContent: View {
    @Bindable var engine: QuizEngine
    @Environment(Stats.self) private var stats
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showChallenge = false
    /// Moves on by itself shortly after a correct answer. Off by default so
    /// the "why" line stays readable; the player turns it on when they want pace.
    @AppStorage("quiz_autoAdvance") private var autoAdvance = false

    private static let autoAdvanceDelay: Duration = .milliseconds(600)

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Quiz")
            // Content scrolls; the decision pad stays pinned at the bottom so
            // the buttons can never be pushed off a small screen.
            ScrollView {
                VStack(spacing: Space.md) {
                    challengeCard
                    scoreTiles
                    difficultyPicker
                    if let up = engine.dealerUp {
                        DrillHandTable(dealerUp: up, player: engine.player, handText: engine.handText)
                    }
                    DrillFeedback(message: engine.feedback.isEmpty ? nil : engine.feedback,
                                  good: engine.feedbackGood,
                                  reason: engine.reason)
                    autoAdvanceToggle
                }
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.md)
            }
            bottomBar
        }
        .background(Color.bg.ignoresSafeArea())
        // Correct answers can move on by themselves; cancelled automatically
        // when the player taps Next first (`answered` flips back to false).
        .task(id: engine.answered) {
            guard engine.answered, engine.feedbackGood, autoAdvance,
                  !UIAccessibility.isVoiceOverRunning else { return }
            try? await Task.sleep(for: Self.autoAdvanceDelay)
            guard !Task.isCancelled else { return }
            Motion.perform(.quick, reduceMotion: reduceMotion) { engine.next() }
        }
    }

    // MARK: Sections

    private var challengeCard: some View {
        Button {
            showChallenge = true
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(.accent)
                    .accessibilityHidden(true)
                Text("Daily Challenge")
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                Spacer()
                if let result = stats.todayChallenge {
                    Text("\(result.score)/\(result.total)")
                        .font(.numberInline)
                        .foregroundStyle(.positive)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.captionText)
                        .foregroundStyle(.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: Metrics.minTapTarget - 2 * Space.sm)
            .panel(padding: Space.sm)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(stats.todayChallenge == nil ? Color.accent : Color.clear,
                                  lineWidth: Metrics.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(stats.todayChallenge.map { "Scored \($0.score) of \($0.total) today" }
                            ?? "Not played today")
        .sheet(isPresented: $showChallenge) {
            DailyChallengeView()
                .environment(stats)
        }
    }

    private var scoreTiles: some View {
        HStack(spacing: Space.xs) {
            StatTile(label: "Streak", value: "\(engine.streak)", tint: .warm)
            StatTile(label: "Best", value: "\(stats.data.quizBestStreak)")
            StatTile(label: "Accuracy",
                     value: stats.data.quizTotal == 0 ? "N/A" : "\(Int(stats.quizAccuracy * 100))%")
        }
    }

    private var difficultyPicker: some View {
        VStack(spacing: Space.xs) {
            Picker("Difficulty", selection: $engine.difficulty) {
                ForEach(QuizDifficulty.allCases) { d in Text(d.rawValue).tag(d) }
            }
            .pickerStyle(.segmented)
            Text(engine.difficulty.summary)
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    private var autoAdvanceToggle: some View {
        Toggle(isOn: $autoAdvance) {
            Text("Move on after a correct answer")
                .font(.detail)
                .foregroundStyle(.textSecondary)
        }
        .tint(.accent)
    }

    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if engine.answered {
                PrimaryButton("Next") { engine.next() }
                    .transition(Motion.slide(reduceMotion))
            } else {
                DecisionPad(canSplit: engine.canSplit) { engine.answer($0) }
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xs)
        .frame(maxWidth: .infinity)
        .background(Color.bg)
        .motion(.quick, value: engine.answered)
    }
}
