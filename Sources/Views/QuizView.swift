import SwiftUI

struct QuizView: View {
    @Environment(Stats.self) private var stats
    @State private var engine: QuizEngine?

    var body: some View {
        Group {
            if let engine {
                QuizContent(engine: engine)
            } else {
                Color.clear
            }
        }
        .onAppear { if engine == nil { engine = QuizEngine(stats: stats) } }
    }
}

private struct QuizContent: View {
    @Bindable var engine: QuizEngine
    @Environment(Stats.self) private var stats
    @State private var showChallenge = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader("Quiz")
            // Scrollable so the challenge card (or any future banner) never
            // pushes the Hit/Stand/Double/Split buttons off the bottom of
            // the screen — a fixed VStack with Spacers silently clipped them.
            ScrollView {
                VStack(spacing: 18) {
                    challengeCard
                    scoreBar
                    difficultyPicker

                    // Dealer up card
                    VStack(spacing: 6) {
                        Text("Dealer shows").font(.caption).foregroundStyle(.secondary)
                        if let up = engine.dealerUp { CardView(card: up, size: 1.4) }
                    }

                    // Player hand
                    VStack(spacing: 6) {
                        Text(engine.handText).font(.headline).foregroundStyle(Theme.accent)
                        HStack(spacing: 8) {
                            ForEach(engine.player) { CardView(card: $0, size: 1.4) }
                        }
                    }

                    // Feedback
                    Text(engine.feedback)
                        .font(.headline)
                        .foregroundStyle(engine.feedbackGood ? Theme.good : Theme.bad)
                        .frame(height: 26)

                    if engine.answered {
                        Button {
                            engine.next()
                        } label: {
                            Text("Next")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.black)
                        }
                        .padding(.horizontal)
                    } else {
                        actionGrid
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.feltDark.ignoresSafeArea())
    }

    private var challengeCard: some View {
        Button {
            showChallenge = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                Text("Daily Challenge")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                if let result = stats.todayChallenge {
                    Text("\(result.score)/\(result.total)")
                        .font(.headline)
                        .foregroundStyle(Theme.good)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.accent.opacity(stats.todayChallenge == nil ? 0.4 : 0), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showChallenge) {
            DailyChallengeView()
                .environment(stats)
        }
    }

    private var scoreBar: some View {
        HStack {
            pill("Streak", "\(engine.streak)")
            pill("Best", "\(stats.data.quizBestStreak)")
            pill("Accuracy", stats.data.quizTotal == 0 ? "N/A" : "\(Int(stats.quizAccuracy * 100))%")
        }
    }

    private var difficultyPicker: some View {
        VStack(spacing: 4) {
            Picker("Difficulty", selection: $engine.difficulty) {
                ForEach(QuizDifficulty.allCases) { d in Text(d.rawValue).tag(d) }
            }
            .pickerStyle(.segmented)
            if engine.difficulty == .hard {
                Text("Practice the tricky hands: hard totals, soft doubles, and pairs that often cause mistakes.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if engine.difficulty == .smart {
                Text("Trains YOUR game: deals the spots you miss most, plus ones you haven't practiced yet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func pill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundStyle(Theme.accent)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
    }

    private var actionGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                quizButton("Hit") { engine.answer(.hit) }
                quizButton("Stand") { engine.answer(.stand) }
            }
            HStack(spacing: 10) {
                quizButton("Double") { engine.answer(.double) }
                quizButton("Split", enabled: engine.canSplit) { engine.answer(.split) }
            }
        }
        .padding(.horizontal)
    }

    private func quizButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enabled ? Theme.felt : Color.gray.opacity(0.25),
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(enabled ? .white : .gray)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.white.opacity(enabled ? 0.15 : 0), lineWidth: 1))
        }
        .disabled(!enabled)
    }
}
