import SwiftUI

struct QuizView: View {
    @Environment(Stats.self) private var stats
    @State private var engine: QuizEngine?
    /// Mirrors the engine's saved difficulty so a mode chosen elsewhere
    /// (Progress "Drill these") applies when the tab opens.
    @AppStorage(QuizEngine.difficultyKey) private var storedDifficulty = QuizDifficulty.normal.rawValue
    /// Set by Progress "Drill these" to open straight into review.
    @AppStorage(QuizEngine.reviewRequestKey) private var reviewRequested = false

    var body: some View {
        Group {
            if let engine {
                QuizContent(engine: engine)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if engine == nil { engine = QuizEngine(stats: stats) }
            applyReviewRequest()
        }
        .onChange(of: reviewRequested) { _, _ in applyReviewRequest() }
        .onChange(of: storedDifficulty) { _, raw in
            guard let engine, let mode = QuizDifficulty(rawValue: raw), mode != .review,
                  engine.difficulty != mode else { return }
            engine.difficulty = mode
        }
    }

    private func applyReviewRequest() {
        guard reviewRequested, let engine else { return }
        reviewRequested = false
        if !engine.isReviewing { engine.startReview() }
    }
}

private struct QuizContent: View {
    @Bindable var engine: QuizEngine
    @Environment(Stats.self) private var stats
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showChallenge = false
    /// "Next hand on its own after a right answer": moves on by itself shortly after a
    /// correct answer. Off by default so the "why" line stays readable.
    @AppStorage("quiz_autoAdvance") private var autoAdvance = false

    private static let autoAdvanceDelay: Duration = .milliseconds(600)

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Quiz")
            // The settings scroll. The hand, the result and the decision pad
            // below are pinned, so the cards and Hit / Stand never move.
            ScrollView {
                VStack(spacing: Space.md) {
                    // What you pick before answering comes first (challenge, review,
                    // difficulty), so it is visible without scrolling; stats follow.
                    challengeCard
                    if engine.isReviewing {
                        reviewPanel
                    } else {
                        reviewEntry
                        difficultyPicker
                    }
                    scoreTiles
                    if !engine.reviewIsEmpty { autoAdvanceToggle }
                    if engine.reviewIsEmpty {
                        reviewEmptyState
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.md)
            }
            if let up = engine.dealerUp {
                VStack(spacing: Space.xs) {
                    DrillHandTable(dealerUp: up, player: engine.player, handText: engine.handText)
                    DrillFeedback(message: engine.feedback.isEmpty ? nil : engine.feedback,
                                  grade: engine.grade,
                                  reason: engine.reason)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.xs)
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
                    Text("\(result.pointsText)/\(result.total)")
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
        .accessibilityValue(stats.todayChallenge.map { "Scored \($0.pointsSpoken) of \($0.total) today" }
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
            SegmentedChoice(QuizDifficulty.pickerCases, selection: $engine.difficulty,
                            accessibilityLabel: "Difficulty")
            Text(engine.difficulty.summary)
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    /// Opens review mode: a row, not a fifth difficulty, because review is a
    /// list that empties rather than a way of dealing.
    private var reviewEntry: some View {
        let left = engine.reviewRemaining
        return Button {
            Motion.perform(.quick, reduceMotion: reduceMotion) { engine.startReview() }
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
                    .foregroundStyle(.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("Review missed hands")
                        .font(.heading)
                        .foregroundStyle(.textPrimary)
                    Text(left == 0 ? "Nothing to review right now" : "\(left) to go, most missed first")
                        .font(.detail)
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: Space.xs)
                Image(systemName: "chevron.right")
                    .font(.captionText)
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
            .contentShape(Rectangle())
            .panel(padding: Space.sm)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Review missed hands")
        .accessibilityValue(left == 0 ? "Nothing to review" : "\(left) to go")
        .accessibilityHint("Drills only the hands you have missed")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("reviewMissedHandsButton")
    }

    /// Shown instead of the difficulty picker while reviewing.
    private var reviewPanel: some View {
        let left = engine.reviewRemaining
        return Panel(spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text("Reviewing missed hands")
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: Space.xs)
                Text(left == 0 ? "All clear" : "\(left) left")
                    .font(.numberInline)
                    .foregroundStyle(left == 0 ? Color.positive : Color.accent)
            }
            Text(engine.difficulty.summary)
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Back to quiz", systemImage: "chevron.left", compact: true) {
                Motion.perform(.quick, reduceMotion: reduceMotion) { engine.endReview() }
            }
            .accessibilityIdentifier("endReviewButton")
        }
    }

    private var reviewEmptyState: some View {
        Panel(alignment: .center, spacing: Space.sm) {
            Image(systemName: "checkmark.circle")
                .scaledFont(size: 44, weight: .regular, relativeTo: .largeTitle, maxSize: 80)
                .foregroundStyle(.positive)
                .accessibilityHidden(true)
            Text("You're all caught up")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Hands you miss in Play, the Quiz or the Daily Challenge land here. Get one right twice in a row and it leaves the list.")
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var autoAdvanceToggle: some View {
        Toggle(isOn: $autoAdvance) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("Next hand on its own after a right answer")
                    .font(.calloutText)
                    .foregroundStyle(.textPrimary)
                Text("Moves on by itself after a correct answer. A wrong answer waits for you.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.themed)
        .panel(.subtle, padding: Space.sm)
        .accessibilityIdentifier("quizAutoNextToggle")
    }

    /// Hit / Stand / Double / Split, or Next after an answer. Next sits in
    /// the same space the pad uses, so the hand above never shifts.
    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if engine.reviewIsEmpty {
                EmptyView()
            } else {
                ZStack(alignment: .bottom) {
                    DecisionPad(canSplit: engine.canSplit) { _ in }
                        .hidden()
                    if engine.answered {
                        PrimaryButton("Next") { engine.next() }
                            .transition(Motion.slide(reduceMotion))
                    } else {
                        DecisionPad(canSplit: engine.canSplit) { engine.answer($0) }
                    }
                }
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
