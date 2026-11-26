import SwiftUI

/// The lobby shown when no practice session is running: pick the starting
/// chips, the table minimum, how many hands to play and the table rules,
/// then start. Also shows the summary of the session that just ended, and a
/// "learn the basics" shortcut for players who have never played a hand.
struct SessionSetupView: View {
    @Bindable var engine: PlayEngine
    @Environment(Stats.self) private var stats

    @State private var buyIn: Double = 100
    @State private var minimum: Double = 5
    @State private var editing: AmountField?
    @State private var draft = ""
    @State private var hands = 1
    @State private var setupLoaded = false
    @State private var showTutorial = false

    private let buyInOptions = ChipSizing.startingChipOptions
    private let maxAmount = ChipSizing.maxStartingChips

    private enum AmountField: String, Identifiable {
        case buyIn = "Starting chips", minimum = "Minimum bet"
        var id: String { rawValue }
    }

    private var canStart: Bool { buyIn >= minimum }
    private var isFirstRun: Bool { stats.data.handsPlayed == 0 && engine.lastSummary == nil }

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                PageHeader("Hit Me", titleFont: .sectionTitle)
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: Space.md) {
                            if let summary = engine.lastSummary {
                                SessionReceiptCard(summary: summary)
                            }
                            if isFirstRun {
                                learnBasicsCard
                            }
                            buyInSection
                            tableSection
                            startSection
                            Text("Play until you end the session or run out of chips.")
                                .font(.captionText)
                                .foregroundStyle(.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.lg)
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
        .fullScreenCover(isPresented: $showTutorial) {
            BeginnerBlackjackTutorial()
        }
        .onAppear {
            guard !setupLoaded else { return }
            setupLoaded = true
            hands = engine.numHands
        }
    }

    // MARK: - First run

    private var learnBasicsCard: some View {
        Button {
            showTutorial = true
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "graduationcap.fill")
                    .font(.heading)
                    .foregroundStyle(.accent)
                    .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                    .background(.positiveBg, in: Circle())
                VStack(alignment: .leading, spacing: Space.xxs / 2) {
                    Text("New to blackjack?")
                        .font(.heading)
                        .foregroundStyle(.textPrimary)
                    Text("Learn the basics in about a minute.")
                        .font(.detail)
                        .foregroundStyle(.textSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: Space.xs)
                Image(systemName: "chevron.right")
                    .font(.detail.weight(.semibold))
                    .foregroundStyle(.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .panel(.surface, padding: Space.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("New to blackjack? Learn the basics")
        .accessibilityHint("Opens a short tutorial")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("learnBasicsCard")
    }

    // MARK: - Starting chips

    private var buyInSection: some View {
        VStack(spacing: Space.sm) {
            sectionLabel("STARTING CHIPS")
            amountSelector(
                value: buyIn,
                field: .buyIn,
                ids: ("buyInDecrease", "buyInAmount", "buyInIncrease", "buyInEdit"),
                labels: ("Fewer starting chips", "More starting chips", "Type starting chips"),
                canDecrease: buyInOptions.contains { $0 < buyIn },
                canIncrease: buyInOptions.contains { $0 > buyIn },
                step: adjustBuyIn
            )
        }
        .panel()
    }

    // MARK: - Table

    private var tableSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            sectionLabel("TABLE")
            VStack(alignment: .leading, spacing: Space.xs) {
                rowTitle("Minimum bet")
                amountSelector(
                    value: minimum,
                    field: .minimum,
                    ids: ("minimumBetDecrease", "minimumBetAmount", "minimumBetIncrease", "minimumBetEdit"),
                    labels: ("Lower minimum bet", "Raise minimum bet", "Type minimum bet"),
                    canDecrease: ChipSizing.minimumOptions.contains { $0 < minimum },
                    canIncrease: ChipSizing.minimumOptions.contains { $0 > minimum },
                    step: adjustMinimum
                )
            }
            VStack(alignment: .leading, spacing: Space.xs) {
                rowTitle("Hands per round")
                Picker("Hands per round", selection: $hands) {
                    ForEach(PlayEngine.spotRange, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }
            HStack {
                rowTitle("Decks")
                Spacer()
                Picker("Decks", selection: $engine.numDecks) {
                    ForEach(PlayEngine.allowedDeckCounts, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.menu)
                .tint(.accent)
                .accessibilityIdentifier("buyInDeckPicker")
                .accessibilityValue("\(engine.numDecks)")
            }
            HStack {
                rowTitle("Dealer")
                Spacer()
                Picker("Dealer", selection: $engine.dealerHitsSoft17) {
                    Text("Stands soft 17").tag(false)
                    Text("Hits soft 17").tag(true)
                }
                .pickerStyle(.menu)
                .tint(.accent)
                .accessibilityIdentifier("buyInDealerPicker")
                .accessibilityValue(engine.dealerHitsSoft17 ? "Hits soft 17" : "Stands soft 17")
            }
        }
        .panel()
    }

    // MARK: - Start

    private var startSection: some View {
        VStack(spacing: Space.xs) {
            PrimaryButton("Start session", systemImage: "suit.club.fill") {
                engine.startSession(buyIn: buyIn, minimum: minimum, hands: hands)
            }
            .disabled(!canStart)
            .accessibilityHint(canStart ? "" : startBlockedReason)
            .accessibilityIdentifier("startSessionButton")

            if !canStart {
                Label(startBlockedReason, systemImage: "exclamationmark.circle.fill")
                    .font(.detail)
                    .foregroundStyle(.warning)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("startDisabledReason")
            }
            Text(PracticeNotice.line)
                .font(.captionText.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("practiceNotice")
        }
    }

    private var startBlockedReason: String {
        "Starting chips must cover at least one minimum bet of \(Money.string(minimum))."
    }

    // MARK: - Amount selector

    /// `< amount ✎ >`: arrows step through presets; the amount or the pencil
    /// opens a field to type any amount.
    private func amountSelector(
        value: Double,
        field: AmountField,
        ids: (decrease: String, amount: String, increase: String, edit: String),
        labels: (decrease: String, increase: String, edit: String),
        canDecrease: Bool,
        canIncrease: Bool,
        step: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: Space.sm) {
            arrowButton("chevron.left", label: labels.decrease, id: ids.decrease,
                        disabled: !canDecrease) { step(-1) }
            HStack(spacing: Space.xs) {
                Text(Money.string(value))
                    .font(.numberHero)
                    .foregroundStyle(.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .onTapGesture { beginEditing(field) }
                    .accessibilityIdentifier(ids.amount)
                    .accessibilityHint("Double tap to type an amount")
                Button {
                    beginEditing(field)
                } label: {
                    Image(systemName: "pencil")
                        .font(.heading)
                        .foregroundStyle(.textSecondary)
                        .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                        .background(.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(labels.edit)
                .accessibilityIdentifier(ids.edit)
            }
            .frame(maxWidth: .infinity)
            arrowButton("chevron.right", label: labels.increase, id: ids.increase,
                        disabled: !canIncrease) { step(1) }
        }
        .padding(Space.xs)
        .background(.surfaceSubtle, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    private func arrowButton(_ systemImage: String, label: String, id: String,
                             disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.heading)
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .foregroundStyle(disabled ? Color.disabledText : Color.accent)
                .background(disabled ? Color.disabledFill : Color.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.overline)
            .tracking(1.6)
            .foregroundStyle(.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private func rowTitle(_ text: String) -> some View {
        Text(text)
            .font(.calloutText.weight(.semibold))
            .foregroundStyle(.textPrimary)
    }

    // MARK: - Actions

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

    /// Next preset above/below `value`, so arrows still work after a typed amount.
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
}

/// The summary of the session that just ended.
private struct SessionReceiptCard: View {
    let summary: SessionSummary

    private var headline: String { summary.busted ? "OUT OF CHIPS" : "SESSION COMPLETE" }
    private var headlineColor: Color { summary.busted ? .negative : .accent }

    private var netLine: String {
        if summary.net > 0.005 { return "Up \(Money.chips(summary.net))" }
        if summary.net < -0.005 { return "Down \(Money.chips(-summary.net))" }
        return "Finished even"
    }
    private var netColor: Color {
        if summary.net > 0.005 { return .positive }
        if summary.net < -0.005 { return .negative }
        return .textPrimary
    }

    private let columns = [GridItem(.flexible(), spacing: Space.xs), GridItem(.flexible(), spacing: Space.xs)]

    var body: some View {
        VStack(spacing: Space.sm) {
            VStack(spacing: Space.xxs) {
                Text(headline)
                    .font(.overline)
                    .tracking(1.6)
                    .foregroundStyle(headlineColor)
                Text(netLine)
                    .font(.numberHero)
                    .foregroundStyle(netColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("Started with \(Money.chips(summary.buyIn)), finished with \(Money.chips(summary.cashedOut))")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            LazyVGrid(columns: columns, spacing: Space.xs) {
                StatTile(label: summary.rounds == 1 ? "Round" : "Rounds",
                         value: "\(summary.rounds)", tint: .textPrimary)
                StatTile(label: "Best round", value: Money.string(summary.biggestWin), tint: .textPrimary)
                StatTile(label: "Peak chips", value: Money.string(summary.peak), tint: .textPrimary)
                StatTile(label: summary.blackjacks == 1 ? "Blackjack" : "Blackjacks",
                         value: "\(summary.blackjacks)", tint: .warm)
            }
        }
        .frame(maxWidth: .infinity)
        .panel()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sessionReceipt")
    }
}
