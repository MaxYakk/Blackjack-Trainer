import SwiftUI

/// The daily challenge: ten date-seeded spots, the same deal for everyone,
/// presented as a sheet from the Quiz tab.
///
/// Opening it after today's run is finished shows that result with an explicit
/// "Practice again" button; practice runs never change the recorded score.
struct DailyChallengeView: View {
    @Environment(Stats.self) private var stats
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var engine: DailyChallengeEngine?
    /// True while the sheet shows today's saved result instead of a run.
    @State private var showingSavedResult = false
    @State private var confirmLeave = false

    var body: some View {
        Group {
            if let engine {
                if showingSavedResult, let saved = stats.todayChallenge {
                    resultScreen(score: saved.score, total: saved.total, practice: false)
                } else if engine.finished {
                    resultScreen(score: engine.score, total: engine.spots.count, practice: engine.isReplay)
                } else {
                    challengeScreen(engine)
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
        // Attached to the sheet's outermost view so the scrim covers it all.
        .themedConfirm("Leave today's challenge?", isPresented: $confirmLeave,
                       message: "Your counted run for today is already started. If you leave now, the next time is practice and your score won't be saved.",
                       actions: [.destructive("Leave challenge") { dismiss() },
                                 .cancel("Keep playing")])
        // A started counted run is used up by leaving, so swiping down can't
        // skip the "Leave today's challenge?" question the X button asks.
        .interactiveDismissDisabled(engine.map(Self.leavingUsesUpRun) ?? false)
        .onAppear(perform: refreshForToday)
        // The sheet can stay open overnight (app in the background), and
        // onAppear doesn't run again then.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshForToday() }
        }
    }

    /// Deals today's challenge when there is no run yet or the open one is
    /// from an earlier day, so a stale run can't record under yesterday's date
    /// or stay practice (or counted) on the wrong day.
    private func refreshForToday() {
        guard engine?.dateKey != stats.todayDateKey else { return }
        engine = DailyChallengeEngine(stats: stats, dateKey: stats.todayDateKey)
        showingSavedResult = stats.todayChallenge != nil
    }

    /// A fresh run of today's hands. Today's counted run is already used, so
    /// this one is practice and records nothing.
    private func startPractice() {
        Motion.perform(.standard, reduceMotion: reduceMotion) {
            engine = DailyChallengeEngine(stats: stats, dateKey: stats.todayDateKey)
            showingSavedResult = false
        }
    }

    /// Leaving a counted run partway uses it up, so ask first.
    private func requestClose(_ engine: DailyChallengeEngine) {
        if Self.leavingUsesUpRun(engine) {
            confirmLeave = true
        } else {
            dismiss()
        }
    }

    /// True while leaving would throw away a started counted run. Once the
    /// last hand is answered the score is already saved, so leaving is free.
    private static func leavingUsesUpRun(_ engine: DailyChallengeEngine) -> Bool {
        let lastAnswered = engine.answered && engine.index + 1 >= engine.spots.count
        return !engine.isReplay && !engine.finished && !lastAnswered
            && (engine.index > 0 || engine.answered)
    }

    // MARK: Run

    private func challengeScreen(_ engine: DailyChallengeEngine) -> some View {
        VStack(spacing: 0) {
            header(engine)

            ScrollView {
                VStack(spacing: Space.md) {
                    if engine.isReplay { practiceNote(engine) }
                    if let spot = engine.current {
                        DrillHandTable(dealerUp: Card(rank: spot.dealerRank, suit: .clubs),
                                       player: spot.cards,
                                       handText: engine.handText)
                        DrillFeedback(message: engine.feedback.isEmpty ? nil : engine.feedback,
                                      good: engine.feedbackGood,
                                      reason: engine.answered ? reason(for: spot) : "")
                    }
                }
                .padding(.horizontal, Space.md)
                .padding(.bottom, Space.md)
            }

            Group {
                if engine.answered {
                    PrimaryButton(engine.index + 1 >= engine.spots.count ? "See results" : "Next") {
                        refreshForToday()
                        engine.next()   // ignored if the run just went stale
                    }
                } else if let spot = engine.current {
                    DecisionPad(canSplit: spot.isPair) { action in
                        refreshForToday()
                        engine.answer(action)   // ignored if the run just went stale
                    }
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.sm)
            .padding(.bottom, Space.md)
        }
    }

    private func header(_ engine: DailyChallengeEngine) -> some View {
        VStack(spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                Text(engine.isReplay ? "Daily Challenge: Practice" : "Daily Challenge")
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(engine.index + 1) / \(engine.spots.count)")
                    .font(.numberInline)
                    .foregroundStyle(.accent)
                    .accessibilityLabel("Hand \(engine.index + 1) of \(engine.spots.count)")
                closeButton { requestClose(engine) }
            }
            ProgressBar(value: Double(engine.index) / Double(max(engine.spots.count, 1)),
                        label: "Challenge progress")
        }
        .padding(.leading, Space.md)
        .padding(.trailing, Space.xs)
        .padding(.top, Space.xs)
        .padding(.bottom, Space.sm)
    }

    private func closeButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.heading)
                .foregroundStyle(.textSecondary)
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Close")
        .accessibilityIdentifier("dailyChallengeClose")
    }

    /// Why today's run is practice, in plain words.
    private func practiceNote(_ engine: DailyChallengeEngine) -> some View {
        Text(engine.isRestartOfUnfinishedRun
             ? "Today's counted run was already started, so this one is practice. Your saved stats won't change."
             : "You've already played today's challenge, so this one is practice. Your saved score won't change.")
            .font(.detail)
            .foregroundStyle(.textSecondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel(.subtle, padding: Space.sm)
    }

    private func reason(for spot: CatalogSpot) -> String {
        QuizReasons.explain(cards: spot.cards, dealerUp: spot.dealerRank, canSplit: spot.isPair)
    }

    // MARK: Result

    private func resultScreen(score: Int, total: Int, practice: Bool) -> some View {
        VStack(spacing: Space.md) {
            HStack {
                Spacer()
                closeButton { dismiss() }
            }
            .padding(.trailing, Space.xs)
            Spacer(minLength: 0)
            Image(systemName: score >= total - 2 ? "trophy.fill" : "checkmark.seal.fill")
                .scaledFont(size: 52, weight: .regular, relativeTo: .largeTitle, maxSize: 90)
                .foregroundStyle(.accent)
                .accessibilityHidden(true)
            Text(practice ? "Practice score" : "Today's score")
                .font(.detail)
                .foregroundStyle(.textSecondary)
            Text("\(score) / \(total)")
                .font(.numberHero)
                .foregroundStyle(.textPrimary)
                .accessibilityLabel("\(score) out of \(total)")
            Text(resultCopy(score: score, total: total))
                .font(.bodyText)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
            Text(practice
                 ? "Practice run: today's recorded score and stats are unchanged."
                 : "Same ten hands for everyone today. Come back tomorrow for a new deal.")
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
            Spacer(minLength: 0)
            VStack(spacing: Space.xs) {
                PrimaryButton("Done") { dismiss() }
                SecondaryButton("Practice again", systemImage: "arrow.clockwise") { startPractice() }
                    .accessibilityHint("Replays today's ten hands. Nothing is recorded.")
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.md)
        }
    }

    private func resultCopy(score: Int, total: Int) -> String {
        switch score {
        case total: return "Perfect. That's how the chart is supposed to be played."
        case (total - 2)...: return "Strong. The misses are already in your leaks list."
        case (total / 2)...: return "Decent. Check Progress to see which spots got you."
        default: return "Rough deal. Review missed hands in the Quiz will drill exactly these."
        }
    }
}
