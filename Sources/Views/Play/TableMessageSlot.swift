import SwiftUI

/// The one line of text the table shows between the dealer and the player:
/// move feedback, bet advice, prompts and table notes all share this single
/// fixed-height slot, so nothing stacks up or pushes the layout around.
struct TableMessage {
    let text: String
    let kind: FeedbackPill.Kind
    /// Prompts and grading are announced to VoiceOver; passive hints aren't.
    let announces: Bool
    let identifier: String?

    /// Picks the most useful message for the current moment.
    @MainActor
    static func current(engine: PlayEngine, refundedChips: Double) -> TableMessage? {
        let phase = engine.phase
        switch phase {
        case .countCheck:
            return TableMessage(text: "What's the running count?", kind: .info, announces: true, identifier: nil)
        case .insurance:
            return TableMessage(text: "Dealer shows an ace. Take insurance?", kind: .info, announces: true, identifier: nil)
        default:
            break
        }
        if !engine.feedbackText.isEmpty {
            return TableMessage(text: engine.feedbackText,
                                kind: engine.feedbackGood ? .correct : .incorrect,
                                announces: true, identifier: "moveFeedback")
        }
        if !engine.betAdviceText.isEmpty && phase != .betting {
            return TableMessage(text: engine.betAdviceText,
                                kind: engine.betAdviceGood ? .correct : .warning,
                                announces: true, identifier: "betAdvice")
        }
        if refundedChips > 0 && phase == .betting {
            return TableMessage(text: "Your last hand was interrupted. \(Money.string(refundedChips)) was returned.",
                                kind: .info, announces: true, identifier: "refundNote")
        }
        if engine.shuffledForNextRound || engine.shuffledMidRound {
            return TableMessage(text: "Shuffling a new shoe", kind: .info, announces: true, identifier: "shuffleNote")
        }
        if phase == .betting && !engine.isFelted {
            let hint = engine.numHands > 1
                ? "Tap a spot, then tap chips to set its bet."
                : "Tap chips to bet, then Deal."
            return TableMessage(text: hint, kind: .info, announces: false, identifier: "bettingHint")
        }
        return nil
    }
}

/// The fixed-height slot that shows a `TableMessage` as a one-line bubble.
///
/// Always a single line (the message copy is written short, and the text
/// shrinks a little before it would ever truncate), so the table never jumps
/// and there is nothing to expand. It sits a touch below the dealer's cards.
struct TableMessageSlot: View {
    let engine: PlayEngine
    let refundedChips: Double

    @ScaledMetric(relativeTo: .footnote) private var slotHeight: CGFloat = 36

    private var message: TableMessage? {
        TableMessage.current(engine: engine, refundedChips: refundedChips)
    }

    var body: some View {
        let message = message
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: slotHeight)
            .overlay {
                if let message {
                    bubble(message)
                }
            }
            // Breathing room under the dealer's cards.
            .padding(.top, Space.xs)
            .onChange(of: message?.text) { _, newText in
                guard let newText, let current = self.message, current.announces else { return }
                AccessibilityNotification.Announcement(spoken(newText, kind: current.kind)).post()
            }
    }

    private func bubble(_ message: TableMessage) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: message.kind.symbol)
                .font(.detail)
                .foregroundStyle(message.kind.tint)
                .accessibilityHidden(true)
            Text(message.text)
                .font(.detail.weight(.semibold))
                .foregroundStyle(message.kind == .info ? Color.textPrimary : message.kind.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, Space.sm)
        .frame(height: slotHeight)
        .background(message.kind.fill, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(message.text, kind: message.kind))
        .accessibilityIdentifier(message.identifier ?? "tableMessage")
    }

    private func spoken(_ text: String, kind: FeedbackPill.Kind) -> String {
        let prefix = kind.spokenPrefix
        return prefix.isEmpty || text.localizedCaseInsensitiveContains(prefix) ? text : "\(prefix). \(text)"
    }
}
