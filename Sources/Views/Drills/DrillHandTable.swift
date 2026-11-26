import SwiftUI

// MARK: - Hand table for the quiz drills
//
// The dealer's up card on the left, the player's hand on the right, in one
// panel, so the whole question fits above the decision pad on a small phone.
// Used by the Quiz and the Daily Challenge.

struct DrillHandTable: View {
    let dealerUp: Card
    let player: [Card]
    let handText: String

    var body: some View {
        HStack(alignment: .top, spacing: Space.md) {
            VStack(spacing: Space.xs) {
                Text("Dealer shows")
                    .font(.captionText)
                    .foregroundStyle(.textSecondary)
                CardView(card: dealerUp, size: 1.3, scalesWithText: true)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: Space.xs) {
                Text(handText)
                    .font(.heading)
                    .foregroundStyle(.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel("Your hand: \(handText)")
                HStack(spacing: Space.xs) {
                    ForEach(player) { CardView(card: $0, size: 1.3, scalesWithText: true) }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .panel()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Feedback block

/// The result pill plus one sentence on why that play is right. Always takes
/// the same height (even when empty) so the pad underneath never jumps.
struct DrillFeedback: View {
    let message: String?
    let good: Bool
    let reason: String

    @ScaledMetric(relativeTo: .footnote) private var reasonHeight: CGFloat = 40

    var body: some View {
        VStack(spacing: Space.xs) {
            FeedbackPill(message, kind: good ? .correct : .incorrect, announces: false)
            Text(message == nil ? "" : reason)
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: reasonHeight, alignment: .top)
                .fixedSize(horizontal: false, vertical: true)
        }
        // One announcement with the reason included, instead of the pill's own.
        .onChange(of: message) { _, newValue in
            guard let newValue else { return }
            let prefix = good ? "Correct. " : "Incorrect. "
            let spoken = newValue.localizedCaseInsensitiveContains(prefix.dropLast(2))
                ? newValue : prefix + newValue
            AccessibilityNotification.Announcement("\(spoken). \(reason)").post()
        }
    }
}
