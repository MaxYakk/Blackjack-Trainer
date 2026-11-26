import SwiftUI

/// The lobby shown when no practice session is running: pick the starting
/// chips, the table minimum, and how many hands to play, then start. Also
/// shows the summary of the session that just ended.
struct SessionSetupView: View {
    @Bindable var engine: PlayEngine

    @State private var buyIn: Double = 100
    @State private var minimum: Double = 5
    @State private var editing: AmountField?
    @State private var draft = ""
    @State private var hands = 1
    @State private var setupLoaded = false

    private let buyInOptions = ChipSizing.startingChipOptions

    private enum AmountField: String, Identifiable {
        case buyIn = "Starting chips", minimum = "Minimum bet"
        var id: String { rawValue }
    }

    private let maxAmount = ChipSizing.maxStartingChips

    private var canDecreaseBuyIn: Bool { buyInOptions.contains { $0 < buyIn } }
    private var canIncreaseBuyIn: Bool { buyInOptions.contains { $0 > buyIn } }
    private var canDecreaseMinimum: Bool { ChipSizing.minimumOptions.contains { $0 < minimum } }
    private var canIncreaseMinimum: Bool { ChipSizing.minimumOptions.contains { $0 > minimum } }

    var body: some View {
        ZStack {
            Color.bg
                .ignoresSafeArea()
            VStack(spacing: 0) {
                PageHeader("Hit Me", titleFont: .title3.weight(.bold))
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 18) {
                            if let summary = engine.lastSummary {
                                SessionReceiptCard(summary: summary)
                            }
                            buyInSection
                            tableSection
                            startButton
                            Text(PracticeNotice.line)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.textSecondary)
                                .accessibilityIdentifier("practiceNotice")
                            Text("Tap the starting chips or minimum bet to type your own amount.")
                                .font(.caption)
                                .foregroundStyle(Color.textTertiary)
                            Text("Play until you end the session or run out of chips.")
                                .font(.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 24)
                        .frame(minHeight: geometry.size.height)
                    }
                }
            }
        }
        .alert(editing?.rawValue ?? "", isPresented: Binding(
            get: { editing != nil },
            set: { if !$0 { editing = nil } }
        )) {
            TextField("Amount", text: $draft)
                .keyboardType(.decimalPad)
            Button("Set") { commitDraft() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Type an amount up to \(Money.string(maxAmount)).")
        }
        .onAppear {
            guard !setupLoaded else { return }
            setupLoaded = true
            hands = engine.numHands
        }
    }

    // MARK: - Starting chips

    private var buyInSection: some View {
        VStack(spacing: 14) {
            sectionLabel("STARTING CHIPS")
            HStack(spacing: 14) {
                selectorButton(
                    systemImage: "chevron.left",
                    accessibilityLabel: "Fewer starting chips",
                    accessibilityIdentifier: "buyInDecrease",
                    disabled: !canDecreaseBuyIn
                ) {
                    adjustBuyIn(by: -1)
                }

                Text(Money.string(buyIn))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEditing(.buyIn) }
                    .accessibilityIdentifier("buyInAmount")
                    .accessibilityHint("Double tap to type an amount")

                selectorButton(
                    systemImage: "chevron.right",
                    accessibilityLabel: "More starting chips",
                    accessibilityIdentifier: "buyInIncrease",
                    disabled: !canIncreaseBuyIn
                ) {
                    adjustBuyIn(by: 1)
                }
            }
            .padding(6)
            .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10).strokeBorder(Color.divider)
            }
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Color.divider)
        }
    }

    // MARK: - Table

    private var tableSection: some View {
        VStack(spacing: 14) {
            sectionLabel("TABLE")
            VStack(spacing: 10) {
                HStack {
                    Text("Minimum bet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }
                HStack(spacing: 14) {
                    selectorButton(
                        systemImage: "chevron.left",
                        accessibilityLabel: "Lower minimum bet",
                        accessibilityIdentifier: "minimumBetDecrease",
                        disabled: !canDecreaseMinimum
                    ) {
                        adjustMinimum(by: -1)
                    }

                    Text(Money.string(minimum))
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { beginEditing(.minimum) }
                        .accessibilityIdentifier("minimumBetAmount")
                        .accessibilityHint("Double tap to type an amount")

                    selectorButton(
                        systemImage: "chevron.right",
                        accessibilityLabel: "Raise minimum bet",
                        accessibilityIdentifier: "minimumBetIncrease",
                        disabled: !canIncreaseMinimum
                    ) {
                        adjustMinimum(by: 1)
                    }
                }
                .padding(6)
                .background(Color.surfaceSubtle, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).strokeBorder(Color.divider)
                }
            }
            VStack(spacing: 10) {
                HStack {
                    Text("Hands per round")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                }
                Picker("Hands per round", selection: $hands) {
                    ForEach(1...3, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }
            VStack(spacing: 10) {
                HStack {
                    Text("Decks")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Picker("Decks", selection: $engine.numDecks) {
                        ForEach(PlayEngine.allowedDeckCounts, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("buyInDeckPicker")
                    .accessibilityValue("\(engine.numDecks)")
                }
                HStack {
                    Text("Dealer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Picker("Dealer", selection: $engine.dealerHitsSoft17) {
                        Text("Stands soft 17").tag(false)
                        Text("Hits soft 17").tag(true)
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("buyInDealerPicker")
                    .accessibilityValue(engine.dealerHitsSoft17 ? "Hits soft 17" : "Stands soft 17")
                }
            }
        }
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).strokeBorder(Color.divider)
        }
    }

    private func adjustBuyIn(by offset: Int) {
        let next = stepped(buyIn, by: offset, in: buyInOptions)
        guard next != buyIn else { return }
        buyIn = next
        Haptics.tap()
        Sound.play(.chip)
    }

    private func adjustMinimum(by offset: Int) {
        let next = stepped(minimum, by: offset, in: ChipSizing.minimumOptions)
        guard next != minimum else { return }
        minimum = next
        Haptics.tap()
    }

    /// Next preset above/below `value`, so chevrons still work after a typed amount.
    private func stepped(_ value: Double, by offset: Int, in options: [Double]) -> Double {
        let sorted = options.sorted()
        if offset > 0 { return sorted.first { $0 > value } ?? value }
        return sorted.last { $0 < value } ?? value
    }

    private func beginEditing(_ field: AmountField) {
        let current = field == .buyIn ? buyIn : minimum
        draft = current.rounded() == current ? String(Int(current)) : String(format: "%.2f", current)
        editing = field
    }

    private func commitDraft() {
        defer { editing = nil }
        let cleaned = draft.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard let raw = Double(cleaned), raw.isFinite, raw > 0 else { return }
        let value = min((raw * 100).rounded() / 100, maxAmount)
        guard value >= 0.01 else { return }
        switch editing {
        case .buyIn: buyIn = value
        case .minimum: minimum = value
        case nil: break
        }
        Haptics.tap()
    }

    private func selectorButton(
        systemImage: String,
        accessibilityLabel: String,
        accessibilityIdentifier: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 44, height: 44)
                .foregroundStyle(disabled ? Color.disabledText : Theme.accent)
                .background(Color.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var startButton: some View {
        Button {
            engine.startSession(buyIn: buyIn, minimum: minimum, hands: hands)
        } label: {
            Label("Start session", systemImage: "suit.club.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    buyIn >= minimum ? Theme.accent : Color.disabledFill,
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(buyIn >= minimum ? Color.onAccent : Color.disabledText)
        }
        .disabled(buyIn < minimum)
        .accessibilityIdentifier("startSessionButton")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .tracking(2.2)
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

}

/// The summary of the session that just ended.
private struct SessionReceiptCard: View {
    let summary: SessionSummary

    private var headline: String { summary.busted ? "OUT OF CHIPS" : "SESSION COMPLETE" }
    private var headlineColor: Color { summary.busted ? Theme.bad : Theme.accent }

    private var netLine: String {
        if summary.net > 0.005 { return "Up \(Money.chips(summary.net))" }
        if summary.net < -0.005 { return "Down \(Money.chips(-summary.net))" }
        return "Finished even"
    }
    private var netColor: Color {
        if summary.net > 0.005 { return Theme.good }
        if summary.net < -0.005 { return Theme.bad }
        return .textPrimary
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(headline)
                .font(.caption.weight(.heavy))
                .tracking(2.4)
                .foregroundStyle(headlineColor)
            Text(netLine)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(netColor)
            Text("Started with \(Money.chips(summary.buyIn)), finished with \(Money.chips(summary.cashedOut))")
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
            HStack(spacing: 0) {
                receiptStat("\(summary.rounds)", summary.rounds == 1 ? "round" : "rounds")
                receiptDivider
                receiptStat(money(summary.biggestWin), "best round")
                receiptDivider
                receiptStat(money(summary.peak), "peak chips")
                if summary.blackjacks > 0 {
                    receiptDivider
                    receiptStat("\(summary.blackjacks)", summary.blackjacks == 1 ? "blackjack" : "blackjacks")
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(headlineColor.opacity(0.45), lineWidth: 1.2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sessionReceipt")
    }

    private var receiptDivider: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(width: 1, height: 26)
    }

    private func receiptStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.fine)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func money(_ value: Double) -> String { Money.string(value) }
}
