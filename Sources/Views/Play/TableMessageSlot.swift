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
            return TableMessage(text: "Your last hand was interrupted. \(Money.chips(refundedChips)) were returned.",
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

/// The fixed-height slot that shows a `TableMessage` in a `FeedbackPill`.
/// When there is more to read than fits (long bet advice, or both move
/// feedback and bet advice), tapping the pill opens the full text.
struct TableMessageSlot: View {
    let engine: PlayEngine
    let refundedChips: Double

    @State private var showDetails = false

    private var message: TableMessage? {
        TableMessage.current(engine: engine, refundedChips: refundedChips)
    }

    /// Full text worth expanding: bet advice and move feedback after the deal,
    /// only while the pill is showing one of them (not a prompt or a note).
    private var details: [(title: String, text: String)] {
        guard engine.phase != .betting,
              let id = message?.identifier, id == "moveFeedback" || id == "betAdvice"
        else { return [] }
        var rows: [(String, String)] = []
        if !engine.feedbackText.isEmpty { rows.append(("Your move", engine.feedbackText)) }
        if !engine.betAdviceText.isEmpty { rows.append(("Your bet", engine.betAdviceText)) }
        return rows
    }

    var body: some View {
        let message = message
        let expandable = !details.isEmpty
        // Same view structure whether or not it can expand, so the pill keeps
        // its identity and still announces each new message.
        HStack(spacing: Space.xxs) {
            FeedbackPill(message?.text, kind: message?.kind ?? .info,
                         announces: message?.announces ?? false)
            if expandable {
                Image(systemName: "chevron.down.circle")
                    .font(.calloutText)
                    .foregroundStyle(.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if expandable { showDetails = true } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(expandable ? .isButton : [])
        .accessibilityAction { if expandable { showDetails = true } }
        .accessibilityHint(expandable ? "Double tap to read the full feedback" : "")
        .accessibilityIdentifier(message?.identifier ?? "tableMessage")
        .popover(isPresented: $showDetails) {
            detailsView
                .presentationCompactAdaptation(.popover)
                .presentationBackground(Color.surfaceRaised)
        }
        .onChange(of: expandable) { _, canExpand in
            if !canExpand { showDetails = false }
        }
    }

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ForEach(details, id: \.title) { row in
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(row.title)
                        .font(.overline)
                        .foregroundStyle(.textSecondary)
                        .accessibilityAddTraits(.isHeader)
                    Text(row.text)
                        .font(.calloutText)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Space.md)
        .frame(width: 300, alignment: .leading)
    }
}
