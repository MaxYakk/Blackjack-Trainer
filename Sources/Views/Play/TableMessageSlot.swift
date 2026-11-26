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

/// The fixed-height slot that shows a `TableMessage` in a compact bubble.
///
/// The bubble is a single short line or two (footnote size, 36pt tall). When
/// there is more to read (long bet advice, or move feedback and bet advice
/// together) a chevron appears and tapping the bubble opens the full text in
/// place: the bubble grows downward over the table, never past the top of the
/// screen, and tapping again (or the next phase) closes it.
struct TableMessageSlot: View {
    let engine: PlayEngine
    let refundedChips: Double

    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var slotHeight: CGFloat = 36

    /// Longer than this and the two-line bubble would clip it.
    private static let longMessage = 70

    private var message: TableMessage? {
        TableMessage.current(engine: engine, refundedChips: refundedChips)
    }

    /// Full text worth expanding: bet advice and move feedback after the deal,
    /// only while the bubble is showing one of them (not a prompt or a note).
    private var details: [(title: String, text: String)] {
        guard engine.phase != .betting,
              let id = message?.identifier, id == "moveFeedback" || id == "betAdvice"
        else { return [] }
        var rows: [(String, String)] = []
        if !engine.feedbackText.isEmpty { rows.append(("Your move", engine.feedbackText)) }
        if !engine.betAdviceText.isEmpty { rows.append(("Your bet", engine.betAdviceText)) }
        return rows
    }

    private var canExpand: Bool {
        details.count > 1 || (message?.text.count ?? 0) > Self.longMessage
    }

    var body: some View {
        let message = message
        // The slot keeps one height; the expanded bubble overlays what is below.
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: slotHeight)
            .overlay(alignment: .top) {
                if let message {
                    bubble(message)
                }
            }
            .zIndex(expanded ? 1 : 0)
            .onChange(of: canExpand) { _, can in
                if !can { expanded = false }
            }
            .onChange(of: message?.text) { _, newText in
                expanded = false
                guard let newText, let current = self.message, current.announces else { return }
                AccessibilityNotification.Announcement(spoken(newText, kind: current.kind)).post()
            }
    }

    private func bubble(_ message: TableMessage) -> some View {
        let showAll = expanded && canExpand
        return Button {
            guard canExpand else { return }
            Motion.perform(.standard, reduceMotion: reduceMotion) { expanded.toggle() }
        } label: {
            HStack(alignment: showAll ? .top : .center, spacing: Space.xs) {
                Image(systemName: message.kind.symbol)
                    .font(.detail)
                    .foregroundStyle(message.kind.tint)
                    .accessibilityHidden(true)
                if showAll {
                    expandedText(message)
                } else {
                    Text(message.text)
                        .font(.detail.weight(.semibold))
                        .foregroundStyle(message.kind == .info ? Color.textPrimary : message.kind.tint)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                }
                if canExpand {
                    Image(systemName: showAll ? "chevron.up" : "chevron.down")
                        .font(.fine.weight(.semibold))
                        .foregroundStyle(.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.sm)
            .padding(.vertical, showAll ? Space.xs : 0)
            .frame(minHeight: slotHeight)
            .frame(maxWidth: showAll ? .infinity : nil)
            // Expanded, the bubble takes the height its text needs. Without
            // this it is squeezed to the 36pt slot, so the text spills out
            // above and below the colored background (over the dealer's cards).
            .fixedSize(horizontal: false, vertical: showAll)
            .background(message.kind.fill,
                        in: RoundedRectangle(cornerRadius: showAll ? Radius.medium : slotHeight / 2,
                                             style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canExpand)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(showAll ? fullText(message) : message.text, kind: message.kind))
        .accessibilityHint(canExpand ? (showAll ? "Double tap to show less" : "Double tap to read it all") : "")
        .accessibilityAddTraits(canExpand ? .isButton : [])
        .accessibilityIdentifier(message.identifier ?? "tableMessage")
    }

    /// Each part on its own line with a small label, when there are two.
    @ViewBuilder
    private func expandedText(_ message: TableMessage) -> some View {
        let rows = details.isEmpty ? [("", message.text)] : details.map { ($0.title, $0.text) }
        VStack(alignment: .leading, spacing: Space.xxs) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 0) {
                    if rows.count > 1 && !row.0.isEmpty {
                        Text(row.0)
                            .font(.overline)
                            .foregroundStyle(.textSecondary)
                    }
                    Text(row.1)
                        .font(.detail.weight(.semibold))
                        .foregroundStyle(message.kind == .info ? Color.textPrimary : message.kind.tint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fullText(_ message: TableMessage) -> String {
        details.isEmpty ? message.text : details.map(\.text).joined(separator: " ")
    }

    private func spoken(_ text: String, kind: FeedbackPill.Kind) -> String {
        let prefix = kind.spokenPrefix
        return prefix.isEmpty || text.localizedCaseInsensitiveContains(prefix) ? text : "\(prefix). \(text)"
    }
}
