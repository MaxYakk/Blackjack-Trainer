import SwiftUI

// The control dock under the table. It keeps one height in every phase
// (two decision-button rows), so the table never jumps between betting,
// dealing, playing and the round result.

/// The fixed-height dock that swaps its contents by phase.
struct ControlDock: View {
    @Bindable var engine: PlayEngine

    /// Two 52pt button rows and the gap between them, growing with text size.
    @ScaledMetric(relativeTo: .headline) private var height: CGFloat =
        Metrics.buttonHeight * 2 + Space.sm

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: height, alignment: .bottom)
    }

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .betting:
            if engine.isFelted {
                FeltedControlsView(engine: engine)
            } else {
                BettingControlsView(engine: engine)
            }
        case .dealing:
            WaitingControlsView(status: "Dealing…")
        case .insurance:
            InsuranceControlsView(engine: engine)
        case .countCheck:
            CountCheckControlsView(engine: engine)
        case .playing:
            DecisionPad(
                canHit: engine.canHitOrStand,
                canStand: engine.canHitOrStand,
                canDouble: engine.currentHand.map { engine.canDouble($0) } ?? false,
                canSplit: engine.currentHand.map { engine.canSplit($0) } ?? false
            ) { action in
                switch action {
                case .hit: engine.hit()
                case .stand: engine.stand()
                case .double: engine.double()
                case .split: engine.split()
                }
            }
        case .dealer:
            WaitingControlsView(status: "Dealer plays…")
        case .done:
            if engine.isFelted {
                FeltedControlsView(engine: engine)
            } else {
                RoundDoneControlsView(engine: engine)
            }
        }
    }
}

/// A table choice tile (insurance Yes/No). Same look as the `DecisionPad` keys.
struct TableActionButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        DecisionButton(title: title, enabled: enabled, action: action)
    }
}

/// Low-emphasis button (Clear / Repeat): the shared compact secondary style.
struct TableSecondaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) { Text(title) }
            .buttonStyle(.secondaryCompact)
            .disabled(!enabled)
    }
}

/// Betting: the chip tray, then Clear / Repeat / Deal.
struct BettingControlsView: View {
    let engine: PlayEngine

    var body: some View {
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                ForEach(Array(engine.chipDenominations.enumerated()), id: \.element) { idx, denom in
                    let enabled = engine.canAddChip(denom)
                    Button {
                        engine.addChip(denom)
                    } label: {
                        ChipView(value: denom, size: 52)
                            .opacity(enabled ? 1 : 0.35)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
                    .disabled(!enabled)
                    .accessibilityLabel("Add a \(Money.string(denom)) chip")
                    .accessibilityIdentifier("chip\(idx)")
                }
            }
            HStack(spacing: Space.xs) {
                TableSecondaryButton(title: "Clear", enabled: engine.currentBet > 0) { engine.clearBet() }
                TableSecondaryButton(title: "Repeat", enabled: engine.canReplay) { engine.repeatBet() }
                Button("Deal") { engine.deal() }
                    .buttonStyle(.primaryCompact)
                    .disabled(!engine.canDeal)
            }
        }
    }
}

/// Dealing and the dealer's turn: the decision pad stays in place, dimmed,
/// under a small status label, so nothing moves when it's the player's turn.
struct WaitingControlsView: View {
    let status: String

    var body: some View {
        ZStack {
            DecisionPad(canHit: false, canStand: false, canDouble: false, canSplit: false) { _ in }
                // VoiceOver (and UI tests) see only the status while waiting.
                .accessibilityHidden(true)
            Text(status)
                .font(.buttonLabelSmall)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.xs)
                .background(.surface, in: Capsule())
                .overlay { Capsule().strokeBorder(Color.divider, lineWidth: Metrics.hairline) }
                .accessibilityIdentifier("dockStatus")
        }
    }
}

/// The insurance offer when the dealer's up-card is an ace. The question
/// itself sits in the table's message slot.
struct InsuranceControlsView: View {
    let engine: PlayEngine

    var body: some View {
        VStack(spacing: Space.sm) {
            Text("Costs \(Money.chips(engine.insuranceCost)). Pays 2 to 1 if the dealer has blackjack.")
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxHeight: .infinity)
            HStack(spacing: Space.sm) {
                TableActionButton(title: "No Insurance") { engine.answerInsurance(take: false) }
                    .accessibilityIdentifier("insuranceNo")
                TableActionButton(title: "Take Insurance") { engine.answerInsurance(take: true) }
                    .accessibilityIdentifier("insuranceYes")
            }
        }
    }
}

/// The mid-hand "what's the running count?" check. The question sits in the
/// table's message slot; the dock holds the fast count input and Submit.
struct CountCheckControlsView: View {
    @Bindable var engine: PlayEngine

    var body: some View {
        VStack(spacing: Space.sm) {
            CountStepper(value: $engine.countGuess, label: "Your running count")
            PrimaryButton("Submit") { engine.submitCountCheck() }
        }
    }
}

/// Round settled: a compact result card, then New Bet / Replay / Replay ×2.
struct RoundDoneControlsView: View {
    let engine: PlayEngine

    var body: some View {
        VStack(spacing: Space.sm) {
            RoundResultCard(outcome: RoundOutcome(engine: engine))
            HStack(spacing: Space.xs) {
                Button("New Bet") { engine.newRound() }
                    .buttonStyle(.secondaryCompact)
                    .accessibilityHint("Clears the table so you can choose a new bet")
                Button("Replay") { engine.replay() }
                    .buttonStyle(.primaryCompact)
                    .disabled(!engine.canReplay)
                    .accessibilityHint("Deals again with the same bet")
                Button("Replay ×2") { engine.replayDouble() }
                    .buttonStyle(.secondaryCompact)
                    .disabled(!engine.canReplayDouble)
                    .accessibilityLabel("Double bet and replay")
            }
        }
    }
}

/// The settled-round card: outcome and detail on the left, chips won or lost
/// on the right. Coral for a natural, mint for a win, red for a loss.
struct RoundResultCard: View {
    let outcome: RoundOutcome

    var body: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: outcome.symbol)
                .font(.heading)
                .foregroundStyle(outcome.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(outcome.title)
                    .font(.heading)
                    .foregroundStyle(outcome.tint)
                Text(outcome.detail)
                    .font(.captionText)
                    .foregroundStyle(.textSecondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            Spacer(minLength: Space.xs)
            Text(outcome.amountText)
                .font(.numberInline)
                .foregroundStyle(outcome.kind == .loss ? Color.negative : Color.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, Space.sm)
        .frame(maxHeight: .infinity)
        .background(outcome.tintBackground, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(outcome.announcement)
        .accessibilityIdentifier("roundResultCard")
    }
}

/// Out of chips: the chips left can't cover another table-minimum bet, so
/// the only move is a fresh session.
struct FeltedControlsView: View {
    let engine: PlayEngine

    var body: some View {
        VStack(spacing: Space.sm) {
            VStack(spacing: Space.xxs) {
                Text("Out of chips")
                    .font(.heading)
                    .foregroundStyle(.negative)
                Text("Start a fresh session to keep practicing.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.negativeBg, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .accessibilityElement(children: .combine)
            PrimaryButton("New session", systemImage: "arrow.uturn.left.circle.fill") { engine.cashOut() }
                .accessibilityIdentifier("newBuyInButton")
        }
    }
}
