import SwiftUI

// The control strip under the table for each non-playing phase — betting,
// insurance, count checks, and going broke — plus the shared button styles.
// Split out of PlayView so the table-layout file stays readable.

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

/// The betting-phase strip: spot count, chip tray, Clear/Repeat/Deal.
struct BettingControlsView: View {
    @Bindable var engine: PlayEngine

    var body: some View {
        VStack(spacing: 12) {
            // Number of spots to play this round
            HStack(spacing: 10) {
                Text("Hands")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
                Picker("Hands", selection: $engine.numHands) {
                    ForEach(1...3, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 120)
                if engine.numHands > 1 && engine.totalWager > 0 {
                    Spacer()
                    Text("Total \(Money.chips(engine.totalWager))")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            }
            if engine.numHands > 1 {
                Text("Tap a spot above, then tap chips to set its bet")
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
            }
            // Chip tray
            HStack(spacing: 10) {
                ForEach(Array(engine.chipDenominations.enumerated()), id: \.element) { idx, denom in
                    Button {
                        engine.addChip(denom)
                    } label: {
                        ChipView(value: denom, size: 54)
                            .opacity(engine.canAddChip(denom) ? 1 : 0.35)
                    }
                    .disabled(!engine.canAddChip(denom))
                    .accessibilityIdentifier("chip\(idx)")
                }
            }
            HStack(spacing: 10) {
                TableSecondaryButton(title: "Clear", enabled: engine.currentBet > 0) { engine.clearBet() }
                TableSecondaryButton(title: "Repeat", enabled: engine.canReplay) { engine.repeatBet() }
                Button {
                    engine.deal()
                } label: {
                    Text("Deal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(engine.canDeal ? Theme.accent : Color.disabledFill,
                                    in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(engine.canDeal ? Color.onAccent : Color.disabledText)
                }
                .disabled(!engine.canDeal)
            }
            Text("Table minimum \(Money.chips(engine.tableMinimum))")
                .font(.caption2)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}

/// The insurance offer shown when the dealer's up-card is an ace.
struct InsuranceControlsView: View {
    let engine: PlayEngine

    var body: some View {
        VStack(spacing: 12) {
            Text("Insurance?")
                .font(.headline)
                .foregroundStyle(.textPrimary)
            Text("The dealer shows an ace. Insurance costs \(Money.chips(engine.insuranceCost)) and pays 2 to 1 if the dealer has blackjack.")
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                TableActionButton(title: "No Insurance") { engine.answerInsurance(take: false) }
                    .accessibilityIdentifier("insuranceNo")
                TableActionButton(title: "Take Insurance") { engine.answerInsurance(take: true) }
                    .accessibilityIdentifier("insuranceYes")
            }
        }
        .padding()
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}

/// The mid-hand "what's the running count?" quiz.
struct CountCheckControlsView: View {
    @Bindable var engine: PlayEngine

    var body: some View {
        VStack(spacing: 12) {
            Text("What's the running count?")
                .font(.headline)
                .foregroundStyle(.textPrimary)
            Stepper(value: $engine.countGuess, in: -60...60) {
                HStack {
                    Text("Your count")
                    Spacer()
                    Text(engine.countGuess > 0 ? "+\(engine.countGuess)" : "\(engine.countGuess)")
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 4)
            Button {
                engine.submitCountCheck()
            } label: {
                Text("Submit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.onAccent)
            }
        }
        .padding()
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}

/// Out of chips: the round is over and the chips left can't cover another
/// table-minimum bet, so the only move left is a fresh session.
struct FeltedControlsView: View {
    let engine: PlayEngine

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                Text("OUT OF CHIPS")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(Theme.bad)
                Text("You're out of practice chips. Start a fresh session.")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.bad.opacity(0.5), lineWidth: 1.2)
            }
            Button {
                engine.cashOut()
            } label: {
                Label("New session", systemImage: "arrow.uturn.left.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 11))
                    .foregroundStyle(.onAccent)
            }
            .accessibilityIdentifier("newBuyInButton")
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
}
