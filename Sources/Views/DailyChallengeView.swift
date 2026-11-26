import SwiftUI

/// The daily challenge: ten date-seeded spots, the same deal for everyone,
/// presented as a sheet from the Quiz tab.
struct DailyChallengeView: View {
    @Environment(Stats.self) private var stats
    @Environment(\.dismiss) private var dismiss
    @State private var engine: DailyChallengeEngine?

    var body: some View {
        Group {
            if let engine {
                if engine.finished {
                    resultScreen(engine)
                } else {
                    challengeScreen(engine)
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.feltDark.ignoresSafeArea())
        .onAppear {
            // Also rebuilds when a kept-alive view reappears after midnight,
            // so a stale engine can't record under yesterday's key.
            if engine?.dateKey != stats.todayDateKey {
                engine = DailyChallengeEngine(stats: stats, dateKey: stats.todayDateKey)
            }
        }
    }

    private func challengeScreen(_ engine: DailyChallengeEngine) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(engine.isReplay ? "Daily Challenge · Practice" : "Daily Challenge")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("\(engine.index + 1) / \(engine.spots.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal)
            .padding(.top, 18)

            ProgressView(value: Double(engine.index), total: Double(engine.spots.count))
                .tint(Theme.accent)
                .padding(.horizontal)
                .padding(.bottom, 8)

            // Scrollable so the action buttons can never get pushed off the
            // bottom of the sheet, regardless of screen size or feedback length.
            ScrollView {
                VStack(spacing: 18) {
                    if let spot = engine.current {
                        VStack(spacing: 6) {
                            Text("Dealer shows").font(.caption).foregroundStyle(.textSecondary)
                            CardView(card: Card(rank: spot.dealerRank, suit: .clubs), size: 1.4)
                        }
                        VStack(spacing: 6) {
                            Text(engine.handText).font(.headline).foregroundStyle(Theme.accent)
                            HStack(spacing: 8) {
                                ForEach(spot.cards) { CardView(card: $0, size: 1.4) }
                            }
                        }
                    }

                    Text(engine.feedback)
                        .font(.headline)
                        .foregroundStyle(engine.feedbackGood ? Theme.mint : Theme.bad)
                        .frame(height: 26)

                    if engine.answered {
                        Button {
                            engine.next()
                        } label: {
                            Text(engine.index + 1 >= engine.spots.count ? "See results" : "Next")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.onAccent)
                        }
                        .padding(.horizontal)
                    } else if let spot = engine.current {
                        actionGrid(engine, canSplit: spot.isPair)
                    }
                }
                .padding(.vertical, 18)
            }
        }
    }

    private func resultScreen(_ engine: DailyChallengeEngine) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: engine.score >= 8 ? "trophy.fill" : "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent)
            Text("\(engine.score) / \(engine.spots.count)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.textPrimary)
            Text(resultCopy(score: engine.score, total: engine.spots.count))
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text(engine.isReplay
                 ? "Practice run — today's recorded score and stats are unchanged."
                 : "Same ten hands for everyone today — come back tomorrow for a new deal.")
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.onAccent)
            }
            .padding(.horizontal)
            .padding(.bottom, 18)
        }
    }

    private func resultCopy(score: Int, total: Int) -> String {
        switch score {
        case total: return "Perfect. That's how the chart is supposed to be played."
        case (total - 2)...: return "Strong. The misses are already in your leaks list."
        case (total / 2)...: return "Decent — check Progress to see which spots got you."
        default: return "Rough deal. Smart quiz mode will drill exactly these."
        }
    }

    private func actionGrid(_ engine: DailyChallengeEngine, canSplit: Bool) -> some View {
        DecisionPad(canSplit: canSplit) { engine.answer($0) }
            .padding(.horizontal)
    }
}
