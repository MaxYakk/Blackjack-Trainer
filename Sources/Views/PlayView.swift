import SwiftUI

struct PlayView: View {
    @Environment(Stats.self) private var stats
    @State private var engine: PlayEngine?

    var body: some View {
        Group {
            if let engine {
                PlayContent(engine: engine)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if engine == nil { engine = PlayEngine(stats: stats) }
        }
    }
}

private struct PlayContent: View {
    @Bindable var engine: PlayEngine
    @Environment(Stats.self) private var stats
    @State private var showSettings = false

    private let chipDenoms: [Double] = [0.10, 1, 5, 25, 100]

    var body: some View {
        ZStack {
            feltBackground
            VStack(spacing: 0) {
                PageHeader("Blackjack") {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(Theme.accent)
                    }
                    .accessibilityIdentifier("settingsButton")
                }
                tableArea
                controlArea
                footer
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(engine: engine)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Background

    private var feltBackground: some View {
        LinearGradient(
            colors: [Theme.felt, Theme.feltDark],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Table

    private var tableArea: some View {
        VStack(spacing: 0) {
            // Dealer — sized to its own content, never forced into a fixed band,
            // so the count strip below it can't overlap the banner underneath.
            VStack(spacing: 8) {
                Text("Dealer \(dealerTotalText)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white.opacity(0.95))
                HStack(spacing: 8) {
                    ForEach(Array(engine.dealer.enumerated()), id: \.offset) { idx, card in
                        CardView(card: card, faceDown: engine.dealerHoleHidden && idx == 1, size: 1.35)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 3)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(minHeight: 95)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: engine.dealer.count)
                .animation(.easeInOut, value: engine.dealerHoleHidden)

                if engine.showCount && engine.phase != .betting {
                    countStrip.padding(.top, 2)
                }
            }
            .padding(.top, 12)

            bannerArea
                .padding(.top, 8)

            // Player hands / betting spots — fills every remaining pixel instead
            // of floating in a sea of empty felt.
            Group {
                if engine.hands.isEmpty {
                    bettingSpots
                } else {
                    handsFan
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
    }

    /// Arranges player hands in a deep arc that spans most of the felt's height —
    /// outer spots drop well below the middle one, like seats curling around a
    /// real table, with each hand's own two cards fanned instead of laid flat.
    @ViewBuilder
    private var handsFan: some View {
        GeometryReader { geo in
            let count = engine.hands.count
            let mid = Double(count - 1) / 2
            let arcDrop = min(geo.size.height * 0.22, 60)
            let columnSpacing: CGFloat = count >= 4 ? 8 : 16
            // Size cards from whichever dimension is tighter — width (so columns
            // can't clip off-screen on a resplit) or height (so a short screen
            // can't push the fan down into the buttons below) — so it always fits.
            let columnWidth = (geo.size.width - columnSpacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1))
            let widthCardSize = (columnWidth - 6) / 2 / 48
            let chromeHeight: CGFloat = 18 + 14 + 34 + 20   // label + card padding + chip stack + VStack spacing
            let heightBudget = geo.size.height - chromeHeight - arcDrop
            let heightCardSize = heightBudget / 68
            let cardSize: CGFloat = max(0.65, min(1.35, min(widthCardSize, heightCardSize)))
            let row = HStack(alignment: .top, spacing: columnSpacing) {
                ForEach(Array(engine.hands.enumerated()), id: \.element.id) { idx, hand in
                    handColumn(hand, index: idx, cardSize: cardSize)
                        .offset(y: count > 1 ? abs(Double(idx) - mid) / max(mid, 1) * arcDrop : 0)
                        .id(idx)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: count)

            Group {
                if count > 4 {
                    // A heavily resplit round can still grow taller than it is wide —
                    // let it scroll and keep the active hand in view.
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) { row }
                            .onChange(of: engine.currentIndex) { _, idx in
                                withAnimation { proxy.scrollTo(idx, anchor: .center) }
                            }
                    }
                } else {
                    row.frame(maxWidth: .infinity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    private var countStrip: some View {
        Text("Running \(signed(engine.runningCount))   •   \(engine.decksRemaining, specifier: "%.1f") decks   •   True \(engine.trueCount, specifier: "%+.1f")")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.black.opacity(0.28), in: Capsule())
    }

    private var bannerArea: some View {
        VStack(spacing: 6) {
            if !engine.feedbackText.isEmpty {
                Text(engine.feedbackText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(engine.feedbackGood ? Theme.mint : Theme.bad)
            }
            if !engine.betAdviceText.isEmpty && (engine.phase == .playing || engine.phase == .done || engine.phase == .dealing) {
                Text(engine.betAdviceText)
                    .font(.caption)
                    .foregroundStyle(engine.betAdviceGood ? Theme.mint.opacity(0.9) : Theme.accent)
            }
        }
        .multilineTextAlignment(.center)
        .frame(minHeight: 44)
        .padding(.vertical, 8)
        .animation(.easeInOut, value: engine.feedbackText)
    }

    /// One betting spot per hand, laid out in the same arc the dealt hands will
    /// use, so the transition from betting to playing doesn't jump around. Tap a
    /// spot to make it active, then tap chips to add to that spot specifically —
    /// each hand can carry its own wager.
    private var bettingSpots: some View {
        GeometryReader { geo in
            let count = engine.numHands
            let mid = Double(count - 1) / 2
            // Reserve room for the spot label, the "$0.00" amount, and the arc
            // drop itself, then size the circle from whatever height is actually
            // left — never a fixed size that can overflow into the controls below.
            let labelHeight: CGFloat = count > 1 ? 20 : 0
            let chromeHeight: CGFloat = labelHeight + 36 + 16
            let arcDrop = min(geo.size.height * 0.18, 40)
            let heightBudget = geo.size.height - chromeHeight - arcDrop
            let widthBudget = (geo.size.width - CGFloat(count - 1) * (count >= 3 ? 14 : 24)) / CGFloat(max(count, 1))
            let spotSize = max(60, min(count >= 3 ? 104 : 130, min(heightBudget, widthBudget)))
            HStack(alignment: .top, spacing: count >= 3 ? 14 : 24) {
                ForEach(0..<count, id: \.self) { idx in
                    bettingSpot(idx, size: spotSize)
                        .offset(y: count > 1 ? abs(Double(idx) - mid) / max(mid, 1) * arcDrop : 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: count)
        }
    }

    private func bettingSpot(_ index: Int, size: CGFloat) -> some View {
        let bet = engine.spotBets.indices.contains(index) ? engine.spotBets[index] : 0
        let isActive = engine.activeSpot == index
        return Button {
            engine.selectSpot(index)
        } label: {
            VStack(spacing: 8) {
                if engine.numHands > 1 {
                    Text("Spot \(index + 1)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isActive ? Theme.accent : .white.opacity(0.6))
                }
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: isActive ? 2.5 : 2, dash: bet > 0 ? [] : [7, 6]))
                        .foregroundStyle(isActive ? Theme.accent : .white.opacity(0.5))
                        .frame(width: size, height: size)
                    if bet > 0 {
                        ChipStack(amount: bet)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Tap chips\nto bet")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bet)
                Text(engine.money(bet))
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier(index == 0 ? "betAmount" : "betAmount\(index)")
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("spot\(index)")
    }

    private func handColumn(_ hand: PlayerHand, index: Int, cardSize: CGFloat) -> some View {
        let isActive = engine.phase == .playing && index == engine.currentIndex
        return VStack(spacing: 10) {
            Text(handLabel(hand))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(resultColor(hand))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("handTotal\(index)")
            HStack(spacing: 6) {
                ForEach(hand.cards) { card in
                    CardView(card: card, size: cardSize)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isActive ? Theme.accent : .clear, lineWidth: 2)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hand.cards.count)
            // chips riding under the hand
            ChipStack(amount: hand.bet, size: 34 * min(cardSize, 1))
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlArea: some View {
        switch engine.phase {
        case .betting:
            bettingControls
        case .dealing:
            Text("Dealing…")
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 20)
        case .countCheck:
            countCheckControls
        case .playing:
            actionControls
        case .dealer:
            Text("Dealer plays…")
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 20)
        case .done:
            doneControls
        }
    }

    private var bettingControls: some View {
        VStack(spacing: 12) {
            // Number of spots to play this round
            HStack(spacing: 10) {
                Text("Hands")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Picker("Hands", selection: $engine.numHands) {
                    ForEach(1...3, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
                if engine.numHands > 1 && engine.totalWager > 0 {
                    Spacer()
                    Text("Total \(engine.money(engine.totalWager))")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                }
            }
            if engine.numHands > 1 {
                Text("Tap a spot above, then tap chips to set its bet")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
            // Chip tray
            HStack(spacing: 10) {
                ForEach(Array(chipDenoms.enumerated()), id: \.element) { idx, denom in
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
                secondaryButton("Clear", enabled: engine.currentBet > 0) { engine.clearBet() }
                secondaryButton("Repeat", enabled: engine.lastBet > 0 && engine.lastBet <= engine.bankroll) { engine.repeatBet() }
                Button {
                    engine.deal()
                } label: {
                    Text("Deal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(engine.canDeal ? Theme.accent : Color.gray.opacity(0.4),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.black)
                }
                .disabled(!engine.canDeal)
            }
            Text("Table minimum \(engine.money(engine.tableMinimum))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private var countCheckControls: some View {
        VStack(spacing: 12) {
            Text("What's the running count?")
                .font(.headline)
                .foregroundStyle(.white)
            Stepper(value: $engine.countGuess, in: -60...60) {
                HStack {
                    Text("Your count")
                    Spacer()
                    Text(signed(engine.countGuess))
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
                    .foregroundStyle(.black)
            }
        }
        .padding()
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private var actionControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                actionButton("Hit", enabled: engine.canHitOrStand) { engine.hit() }
                actionButton("Stand", enabled: engine.canHitOrStand) { engine.stand() }
            }
            HStack(spacing: 10) {
                actionButton("Double", enabled: doubleEnabled) { engine.double() }
                actionButton("Split", enabled: splitEnabled) { engine.split() }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private var doneControls: some View {
        VStack(spacing: 10) {
            Text(roundSummary)
                .font(.headline)
                .foregroundStyle(engine.lastRoundNet > 0 ? Theme.mint : (engine.lastRoundNet < 0 ? Theme.bad : .white))
            Button {
                engine.newRound()
            } label: {
                Text("New Bet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.black)
            }
            HStack(spacing: 10) {
                secondaryButton("Replay", enabled: engine.canReplay) { engine.replay() }
                secondaryButton("Double & Replay", enabled: engine.canReplayDouble) { engine.replayDouble() }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private var roundSummary: String {
        if engine.lastRoundNet > 0 { return "You won \(engine.money(engine.lastRoundNet))" }
        if engine.lastRoundNet < 0 { return "You lost \(engine.money(-engine.lastRoundNet))" }
        return "Push"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            footerItem("BALANCE", engine.money(engine.bankroll), Theme.accent)
            Divider().frame(height: 30).overlay(.white.opacity(0.2))
            footerItem("LAST", engine.money(engine.lastRoundNet),
                       engine.lastRoundNet > 0 ? Theme.good : (engine.lastRoundNet < 0 ? Theme.bad : .white))
            Divider().frame(height: 30).overlay(.white.opacity(0.2))
            footerItem("TRUE COUNT", engine.showCount ? String(format: "%+.1f", engine.trueCount) : "—", .white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(.ultraThinMaterial)
    }

    private func footerItem(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Buttons

    private var doubleEnabled: Bool {
        guard let h = engine.currentHand else { return false }
        return engine.canDouble(h)
    }
    private var splitEnabled: Bool {
        guard let h = engine.currentHand else { return false }
        return engine.canSplit(h)
    }

    private func actionButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(enabled ? Theme.felt : Color.gray.opacity(0.25),
                            in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(enabled ? .white : .gray)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(enabled ? 0.18 : 0), lineWidth: 1)
                )
        }
        .disabled(!enabled)
    }

    private func secondaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(enabled ? .white : .white.opacity(0.35))
        }
        .disabled(!enabled)
    }

    // MARK: - Helpers

    private func handLabel(_ hand: PlayerHand) -> String {
        let v = hand.value
        var label = v.soft && v.total != 21 ? "soft \(v.total)" : "\(v.total)"
        if let r = hand.result { label += " · \(r.rawValue)" }
        return label
    }

    private func resultColor(_ hand: PlayerHand) -> Color {
        switch hand.result {
        case .win, .blackjack: return Theme.good
        case .lose, .bust, .dealerBlackjack: return Theme.bad
        default: return .white.opacity(0.9)
        }
    }

    private var dealerTotalText: String {
        guard !engine.dealer.isEmpty else { return "" }
        if engine.dealerHoleHidden { return "(\(engine.dealerUpValue))" }
        let v = evaluate(engine.dealer)
        return v.soft && v.total != 21 ? "(soft \(v.total))" : "(\(v.total))"
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}

// MARK: - Settings sheet

private struct SettingsSheet: View {
    @Bindable var engine: PlayEngine
    @Environment(Stats.self) private var stats
    @Environment(\.dismiss) private var dismiss
    @State private var showResetBankroll = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Table Rules") {
                    Picker("Decks", selection: $engine.numDecks) {
                        ForEach([1, 2, 4, 6, 8], id: \.self) { Text("\($0)").tag($0) }
                    }
                    Picker("Dealer", selection: $engine.dealerHitsSoft17) {
                        Text("Stands soft 17").tag(false)
                        Text("Hits soft 17").tag(true)
                    }
                    Picker("Table minimum", selection: $engine.tableMinimum) {
                        Text("$0.10").tag(0.10)
                        Text("$1").tag(1.0)
                        Text("$5").tag(5.0)
                        Text("$25").tag(25.0)
                    }
                }
                Section {
                    Toggle("Show running / true count", isOn: $engine.showCount)
                    Toggle("Betting hints", isOn: $engine.betHints)
                    Toggle("Ask the count mid-hand", isOn: $engine.askCountChecks)
                } header: {
                    Text("Counting")
                } footer: {
                    Text("With betting hints off, the app only tells you if you bet too much or too little — it won't reveal the count. \"Ask the count mid-hand\" occasionally quizzes your running count before you act.")
                }
                Section {
                    Toggle("Count deviations (Illustrious 18)", isOn: $engine.useDeviations)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Grades your plays against count-based index deviations — e.g. stand 16 vs 10 at true count 0+. See the full list on the Strategy tab.")
                }
                Section("Sound") {
                    Toggle("Sound effects", isOn: $engine.soundOn)
                }
                Section("Bankroll") {
                    HStack {
                        Text("Balance")
                        Spacer()
                        Text(engine.money(engine.bankroll)).foregroundStyle(.secondary)
                    }
                    Button("Reset bankroll to $1,000", role: .destructive) {
                        showResetBankroll = true
                    }
                }
                Section {
                    Text("Bet-sizing tip: keep bets at the table minimum when the true count is low, and ramp up (about one unit per point of true count) once it climbs to +2 or higher. The app grades each bet against the count.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Reset bankroll?", isPresented: $showResetBankroll, titleVisibility: .visible) {
                Button("Reset to $1,000", role: .destructive) { stats.resetBankroll() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}
