import SwiftUI

/// "Fix next": the plays the player misses most, each tappable, plus the two
/// actions that act on them (review the mistakes, drill them in the quiz).
struct ProgressFixNext: View {
    @Environment(Stats.self) private var stats
    @Environment(\.selectTab) private var selectTab
    @State private var review: ReviewSession?

    var body: some View {
        let leaks = stats.weakestSpots
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader("Fix next", subtitle: leaks.isEmpty ? nil : "The plays you miss most")
            if leaks.isEmpty {
                emptyPanel
            } else {
                leakList(leaks)
                actions
            }
        }
        .sheet(item: $review) { MistakeReviewView(session: $0) }
    }

    private var emptyPanel: some View {
        Panel(spacing: Space.xs) {
            Label("No weak spots yet", systemImage: "checkmark.circle")
                .font(.heading)
                .foregroundStyle(.textPrimary)
            Text("Answer a few more hands and quiz spots. The plays you miss most will show up here so you know exactly what to fix.")
                .font(.detail)
                .foregroundStyle(.textSecondary)
        }
    }

    private func leakList(_ leaks: [(key: String, stat: SpotStat)]) -> some View {
        let items = leaks.map {
            ReviewItem(key: $0.key, stat: $0.stat, choices: stats.data.mistakeChoices[$0.key])
        }
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                if offset > 0 { HairlineDivider() }
                LeakRow(item: item) {
                    review = ReviewSession(items: items, startIndex: offset)
                }
            }
        }
        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    @ViewBuilder
    private var actions: some View {
        PrimaryButton("Drill these in the Quiz", systemImage: "bolt.fill") {
            // The Quiz picks review (hands you've missed) or, with none
            // left, Smart (leans on the weak spots): see drillWeakSpots().
            UserDefaults.standard.set(true, forKey: QuizEngine.drillRequestKey)
            selectTab(.quiz)
        }
            .accessibilityHint("Opens the Quiz tab and deals the hands you miss most.")
            .accessibilityIdentifier("drillLeaksButton")
        let recurring = stats.recurringMistakes
        if !recurring.isEmpty {
            SecondaryButton("Review mistakes", systemImage: "arrow.triangle.2.circlepath") {
                review = ReviewSession(items: recurring.map(ReviewItem.init))
            }
            .accessibilityIdentifier("reviewMistakesButton")
        }
    }
}

private struct LeakRow: View {
    let item: ReviewItem
    let action: () -> Void

    var body: some View {
        let accuracy = Achievements.roundedPercent(item.stat.accuracy)
        let correctPlay = SpotID.correctActionName(item.key)
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Text("\(accuracy)%")
                    .font(.numberInline)
                    .foregroundStyle(item.stat.accuracy < 0.5 ? Color.negative : Color.warning)
                    .frame(minWidth: 52, alignment: .leading)
                VStack(alignment: .leading, spacing: Space.xxs / 2) {
                    Text(SpotID.displayName(item.key))
                        .font(.calloutText.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                    Text("\(item.stat.total) attempts")
                        .font(.captionText)
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: Space.xs)
                if let correctPlay {
                    Text(correctPlay)
                        .font(.calloutText.weight(.bold))
                        .foregroundStyle(.accent)
                }
                Image(systemName: "chevron.right")
                    .font(.captionText.weight(.semibold))
                    .foregroundStyle(.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(SpotID.displayName(item.key)), \(accuracy) percent correct over \(item.stat.total) attempts"
                            + (correctPlay.map { ", correct play \($0)" } ?? ""))
        .accessibilityHint("Shows this spot")
        .accessibilityAddTraits(.isButton)
    }
}
