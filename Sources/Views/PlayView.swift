import SwiftUI

struct PlayView: View {
    @Environment(Stats.self) private var stats
    @State private var engine: PlayEngine?
    /// Chips returned after an interrupted hand, shown once on the table.
    @State private var refundedChips = 0.0

    var body: some View {
        Group {
            if let engine {
                if engine.sessionActive {
                    PlayContent(engine: engine, refundedChips: $refundedChips)
                } else {
                    SessionSetupView(engine: engine)
                }
            } else {
                Color.clear
            }
        }
        .onAppear {
            if engine == nil {
                engine = PlayEngine(stats: stats)
                refundedChips = stats.refundedWagerOnLaunch
            }
        }
    }
}

private struct PlayContent: View {
    @Bindable var engine: PlayEngine
    @Binding var refundedChips: Double
    @Environment(Stats.self) private var stats
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSettings = false
    @State private var showBeginnerTutorial = false
    @State private var showEndSession = false

    // Round-result effects, triggered when the round settles.
    @State private var showWinOverlay = false
    @State private var confettiSeed = 0
    @State private var confettiActive = false
    @State private var lossFlash = false

    var body: some View {
        ZStack {
            feltBackground
            VStack(spacing: 0) {
                PageHeader("Hit Me", titleFont: .title3.weight(.bold)) { headerMenu }
                tableArea
                controlArea
                footer
            }
            effectsLayer
            endSessionOverlay
        }
        .animation(.easeOut(duration: 0.22), value: showEndSession)
        .sheet(isPresented: $showSettings) {
            SettingsSheet(engine: engine)
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showBeginnerTutorial) {
            BeginnerBlackjackTutorial()
        }
        .onChange(of: engine.phase) { _, phase in
            if phase != .betting { refundedChips = 0 }   // the returned-chips note shows once
            roundSettled(phase)
        }
    }

    /// A confirmation centered over the table, replacing the generic bottom
    /// action sheet the system default used to show.
    @ViewBuilder
    private var endSessionOverlay: some View {
        if showEndSession {
            Color.scrim
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { showEndSession = false }
            EndSessionConfirmCard(
                amount: Money.chips(engine.bankroll),
                onConfirm: {
                    engine.cashOut()
                    showEndSession = false
                },
                onCancel: { showEndSession = false }
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }

    /// Kicks off the win celebration or the loss flash when a round settles,
    /// and tears both down the moment the next round starts.
    private func roundSettled(_ phase: GamePhase) {
        guard phase == .done else {
            showWinOverlay = false
            confettiActive = false
            lossFlash = false
            return
        }
        if engine.lastRoundNet > 0 {
            let hasBlackjack = engine.hands.contains { $0.result == .blackjack }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: WinCelebrationPolicy.bannerDelayNanoseconds)
                guard engine.phase == .done, engine.lastRoundNet > 0 else { return }

                showWinOverlay = true
                confettiActive = WinCelebrationPolicy.showsConfetti(
                    hasBlackjack: hasBlackjack,
                    reduceMotion: reduceMotion
                )
                if confettiActive { confettiSeed += 1 }

                try? await Task.sleep(nanoseconds: 1_800_000_000)
                withAnimation(.easeOut(duration: 0.25)) {
                    showWinOverlay = false
                    confettiActive = false
                }
            }
        } else if engine.lastRoundNet < 0 {
            withAnimation(.easeIn(duration: 0.12)) { lossFlash = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                withAnimation(.easeOut(duration: 0.35)) { lossFlash = false }
            }
        }
    }

    /// Celebration and loss effects floating over the table. Everything here
    /// ignores touches so the controls stay usable mid-animation.
    @ViewBuilder
    private var effectsLayer: some View {
        if lossFlash {
            LossVignetteView().transition(.opacity)
        }
        if confettiActive {
            ConfettiBurstView(seed: confettiSeed)
        }
        if showWinOverlay {
            WinOverlayView(
                amount: engine.lastRoundNet,
                blackjack: engine.hands.contains { $0.result == .blackjack },
                detail: winDetail
            )
            .transition(.opacity)
        }
    }

    /// A single top-right menu button replaces three separate header pills —
    /// "How to Play", "End session", and "Table Options" together didn't fit
    /// next to the title without wrapping.
    private var headerMenu: some View {
        Menu {
            Button {
                showBeginnerTutorial = true
            } label: {
                Label("How to Play", systemImage: "questionmark.circle")
            }
            .accessibilityIdentifier("learnBlackjackHeaderButton")

            Button {
                showEndSession = true
            } label: {
                Label("End session", systemImage: "flag.checkered")
            }
            .disabled(!engine.canCashOut)
            .accessibilityIdentifier("cashOutButton")

            Button {
                showSettings = true
            } label: {
                Label("Table Options", systemImage: "slider.horizontal.3")
            }
            .accessibilityIdentifier("settingsButton")
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 46, height: 46)
                .background(Color.surface, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.divider)
                }
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("headerMenuButton")
    }

    // MARK: - Background

    private var feltBackground: some View {
        Color.bg
            .ignoresSafeArea()
    }

    // MARK: - Table

    private var tableArea: some View {
        VStack(spacing: 0) {
            // Dealer — sized to its own content, never forced into a fixed band,
            // so the count strip below it can't overlap the banner underneath.
            VStack(spacing: 8) {
                Text(engine.showHandTotals ? "Dealer \(dealerTotalText)" : "Dealer")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                HStack(spacing: 8) {
                    ForEach(Array(engine.dealer.enumerated()), id: \.offset) { idx, card in
                        Group {
                            if idx == 1 {
                                // The hole card turns over with a real flip.
                                HoleCardView(card: card, faceDown: engine.dealerHoleHidden, size: 1.35)
                            } else {
                                CardView(card: card, size: 1.35)
                            }
                        }
                        .shadow(color: .shadowColor, radius: 4, y: 3)
                        .transition(.dealtCard)
                        .accessibilityIdentifier("dealerCard\(idx)")
                    }
                }
                .frame(minHeight: 95)
                .animation(.spring(response: 0.4, dampingFraction: 0.78), value: engine.dealer.count)

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

    /// Arranges player hands in an arc so they never crowd the screen edges or
    /// bleed into the controls below.
    @ViewBuilder
    private var handsFan: some View {
        GeometryReader { geo in
            arcRow(geo: geo, count: engine.hands.count)
        }
    }

    private func arcRow(geo: GeometryProxy, count: Int) -> some View {
        let mid = Double(count - 1) / 2
        let arcDrop = min(geo.size.height * 0.22, 60)
        let columnSpacing: CGFloat = count >= 4 ? 8 : 16
        // Size cards from whichever dimension is tighter — width (so columns
        // can't clip off-screen on a resplit) or height (so a short screen
        // can't push the fan down into the buttons below) — so it always fits.
        let columnWidth = (geo.size.width - columnSpacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1))
        // Card size is picked for the common 2-card case; a floor keeps faces
        // readable even under a hard height/width squeeze. A hand that grows
        // past 2 cards (hits, resplits) does NOT shrink this further — instead
        // handColumn overlaps that hand's own cards to stay inside columnWidth,
        // so one busy hand in a multi-hand round can't push its neighbors off-screen.
        let cardRowHorizontalPadding: CGFloat = 14
        let widthCardSize = (columnWidth - cardRowHorizontalPadding - 6) / 2 / 48
        let chromeHeight: CGFloat = 18 + 14 + 34 + 20   // label + card padding + chip stack + VStack spacing
        let heightBudget = geo.size.height - chromeHeight - arcDrop
        let heightCardSize = heightBudget / 68
        let cardSize: CGFloat = max(0.65, min(1.35, min(widthCardSize, heightCardSize)))
        let row = HStack(alignment: .top, spacing: columnSpacing) {
            ForEach(Array(engine.hands.enumerated()), id: \.element.id) { idx, hand in
                handColumn(hand, index: idx, cardSize: cardSize, columnWidth: columnWidth)
                    .offset(y: count > 1 ? abs(Double(idx) - mid) / max(mid, 1) * arcDrop : 0)
                    .id(idx)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: count)

        return Group {
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
        // Top-aligned, not centered: arcDrop is already reserved out of heightBudget
        // above, so anchoring to the top keeps the dropped-down outer hands inside
        // this frame instead of bleeding past its (centered) bottom edge into the
        // control area below.
        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
    }

    private var countStrip: some View {
        Text("Running \(signed(engine.runningCount))   •   \(engine.decksRemaining, specifier: "%.1f") decks   •   True \(engine.trueCount, specifier: "%+.1f")")
            .font(.caption)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.surface, in: Capsule())
    }

    private var bannerArea: some View {
        VStack(spacing: 6) {
            if refundedChips > 0 && engine.phase == .betting {
                tableNote(
                    "Your last hand was interrupted; \(Money.chips(refundedChips)) were returned.",
                    identifier: "refundNote"
                )
            }
            if engine.shuffledForNextRound || engine.shuffledMidRound {
                tableNote("Shuffling a new shoe", identifier: "shuffleNote")
            }
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

    /// A small one-line notice on the table (shoe shuffles, returned chips).
    private func tableNote(_ text: String, identifier: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.surface, in: Capsule())
            .accessibilityIdentifier(identifier)
    }

    /// One betting spot per hand, laid out in the same arc the dealt hands will
    /// use, so the transition from betting to playing doesn't jump around. Tap a
    /// spot to make it active, then tap chips to add to that spot specifically —
    /// each hand can carry its own bet.
    private var bettingSpots: some View {
        GeometryReader { geo in
            arcRowSpots(geo: geo)
        }
    }

    private func arcRowSpots(geo: GeometryProxy) -> some View {
        let count = engine.numHands
        let mid = Double(count - 1) / 2
        // Reserve room for the spot label, the "Bet 0" amount, and the arc
        // drop itself, then size the circle from whatever height is actually
        // left — never a fixed size that can overflow into the controls below.
        let labelHeight: CGFloat = count > 1 ? 20 : 0
        let chromeHeight: CGFloat = labelHeight + 24 + 16
        let arcDrop = min(geo.size.height * 0.18, 40)
        let heightBudget = geo.size.height - chromeHeight - arcDrop
        let spotSpacing: CGFloat = count == 3 ? 16 : 24
        let widthBudget = (geo.size.width - CGFloat(count - 1) * spotSpacing) / CGFloat(max(count, 1))
        let spotSize = max(60, min(130, min(heightBudget, widthBudget)))
        return HStack(alignment: .top, spacing: spotSpacing) {
            ForEach(0..<count, id: \.self) { idx in
                bettingSpot(idx, size: spotSize)
                    .offset(y: count > 1 ? abs(Double(idx) - mid) / max(mid, 1) * arcDrop : 0)
            }
        }
        // Top-aligned so the arc-dropped spots stay inside this frame instead of
        // bleeding past a centered layout's bottom edge into the controls below.
        .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: count)
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
                        .foregroundStyle(isActive ? Theme.accent : Color.textTertiary)
                }
                ZStack {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: isActive ? 2.5 : 2, dash: bet > 0 ? [] : [7, 6]))
                        .foregroundStyle(isActive ? Theme.accent : Color.textTertiary)
                        .frame(width: size, height: size)
                    if bet > 0 {
                        ChipStack(amount: bet)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text("Tap chips\nto bet")
                            .font(.system(size: max(9, min(12, size * 0.11)), weight: .regular, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .allowsTightening(true)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.textTertiary)
                            .frame(width: max(36, size - 24), height: max(32, size - 24))
                            .accessibilityIdentifier("bettingInstruction\(index)")
                    }
                }
                .frame(width: size, height: size)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("bettingCircle\(index)")
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: bet)
                Text("Bet \(engine.money(bet))")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier(index == 0 ? "betAmount" : "betAmount\(index)")
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("spot\(index)")
        .accessibilityValue(isActive ? "active" : "inactive")
    }

    private func handColumn(_ hand: PlayerHand, index: Int, cardSize: CGFloat, columnWidth: CGFloat) -> some View {
        let isActive = engine.phase == .playing && index == engine.currentIndex
        // With the desired 6pt gap, a hand past 2 cards can outgrow its column
        // (narrow columns in a 2-3 hand round, plus hits/resplits). Rather than
        // shrinking the card size — which would shrink every other hand's cards
        // too — overlap this hand's own cards just enough to stay in-column.
        let n = hand.cards.count
        let cardWidth = 48 * cardSize
        let desiredSpacing: CGFloat = 6
        let availableCardWidth = max(columnWidth - 14, 0)
        let neededWidth = CGFloat(n) * cardWidth + CGFloat(max(n - 1, 0)) * desiredSpacing
        let cardSpacing: CGFloat = n > 1 && neededWidth > availableCardWidth
            ? (availableCardWidth - CGFloat(n) * cardWidth) / CGFloat(n - 1)
            : desiredSpacing
        let lost = hand.busted || hand.result == .lose || hand.result == .bust || hand.result == .dealerBlackjack
        return VStack(spacing: 10) {
            Text(handLabel(hand))
                .opacity(engine.showHandTotals ? 1 : 0)   // keep the slot so the layout doesn't shift
                .accessibilityHidden(!engine.showHandTotals)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(resultColor(hand))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityIdentifier("handTotal\(index)")
            HStack(spacing: cardSpacing) {
                ForEach(hand.cards) { card in
                    CardView(card: card, size: cardSize)
                        .shadow(color: .shadowColor, radius: 2, y: 2)
                        .transition(.dealtCard)
                }
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isActive ? Theme.accent : .clear, lineWidth: 2)
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: hand.cards.count)
            // A beaten hand fades under the table lights.
            .saturation(lost ? 0.55 : 1)
            .opacity(lost ? 0.75 : 1)
            .animation(.easeIn(duration: 0.3).delay(0.1), value: lost)
            // The result stamps onto the cards. A bust or a natural stamps the
            // moment it happens; everything else waits for the dealer.
            .overlay {
                if let result = hand.result ?? earlyResult(hand) {
                    ResultStamp(result: result, delay: hand.result == nil ? 0 : Double(index) * 0.06)
                }
            }
            // Chips riding under the hand: swept away on a loss, paid on a win.
            BetChipsView(hand: hand, settled: engine.phase == .done, size: 34 * min(cardSize, 1))
        }
        .frame(width: columnWidth)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playerHand\(index)")
        .accessibilityValue(isActive ? "active" : "inactive")
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlArea: some View {
        switch engine.phase {
        case .betting:
            if engine.isFelted {
                FeltedControlsView(engine: engine)
            } else {
                BettingControlsView(engine: engine)
            }
        case .dealing:
            Text("Dealing…")
                .foregroundStyle(Color.textSecondary)
                .padding(.vertical, 20)
        case .insurance:
            InsuranceControlsView(engine: engine)
        case .countCheck:
            CountCheckControlsView(engine: engine)
        case .playing:
            actionControls
        case .dealer:
            Text("Dealer plays…")
                .foregroundStyle(Color.textSecondary)
                .padding(.vertical, 20)
        case .done:
            doneControls
        }
    }

    private var actionControls: some View {
        DecisionPad(
            canHit: engine.canHitOrStand,
            canStand: engine.canHitOrStand,
            canDouble: doubleEnabled,
            canSplit: splitEnabled
        ) { action in
            switch action {
            case .hit: engine.hit()
            case .stand: engine.stand()
            case .double: engine.double()
            case .split: engine.split()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var doneControls: some View {
        if engine.isFelted {
            FeltedControlsView(engine: engine)
        } else {
            VStack(spacing: 12) {
                roundResultCard

                HStack(spacing: 10) {
                    doneActionButton(
                        "Replay",
                        systemImage: "arrow.clockwise",
                        primary: engine.canReplay,
                        enabled: engine.canReplay
                    ) { engine.replay() }
                    doneActionButton(
                        "Double & Replay",
                        systemImage: "2.circle.fill",
                        primary: false,
                        enabled: engine.canReplayDouble
                    ) { engine.replayDouble() }
                }

                Button {
                    engine.newRound()
                } label: {
                    Label("New Bet", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.textPrimary)
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 11))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(Color.divider)
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
            .animation(.spring(response: 0.48, dampingFraction: 0.72), value: engine.lastRoundNet)
        }
    }

    /// The settled-round plaque under the table: outcome word on the left,
    /// chips won or lost on the right, one detail line beneath.
    private var roundResultCard: some View {
        let net = engine.lastRoundNet
        let anyHandWon = engine.hands.contains { $0.result == .win || $0.result == .blackjack }
        // "DEALER WINS" would be a lie in a mixed multi-spot round where one
        // hand won but the round still lost money overall.
        let title = net > 0
            ? (engine.hands.contains { $0.result == .blackjack } ? "BLACKJACK" : "WIN")
            : (net < 0 ? (anyHandWon ? "DEALER AHEAD" : "DEALER WINS") : "PUSH")
        let titleColor: Color = net > 0 ? Theme.accent : (net < 0 ? Theme.bad : Color.textSecondary)
        let amountText = net > 0
            ? Money.signedChips(net)
            : (net < 0 ? "Lost \(Money.chips(-net))" : "Bet returned")
        let amountColor: Color = net > 0 ? .textPrimary : (net < 0 ? Theme.bad : .textPrimary)
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(titleColor)
                Spacer()
                Text(amountText)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
            }
            HStack {
                Text(net >= 0 && engine.lastRoundNet > 0 ? winDetail : settleDetail)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(titleColor.opacity(net == 0 ? 0.2 : 0.5), lineWidth: 1.2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roundResultCard")
    }

    /// Detail line for losses and pushes, anchored on what the dealer made.
    private var settleDetail: String {
        let dealerValue = evaluate(engine.dealer)
        if engine.lastRoundNet == 0 { return "Dealer made \(dealerValue.total). Bets push." }
        let winning = engine.hands.filter { $0.result == .win || $0.result == .blackjack }.count
        if winning > 0 {
            return "\(winning) of \(engine.hands.count) hands won. Dealer made \(dealerValue.total)."
        }
        if engine.hands.allSatisfy({ $0.result == .bust }) { return "You went over 21." }
        if engine.hands.contains(where: { $0.result == .dealerBlackjack }) { return "Dealer had blackjack." }
        return "Dealer made \(dealerValue.total)."
    }

    private var winDetail: String {
        let winningHands = engine.hands.filter { $0.result == .win || $0.result == .blackjack }.count
        let blackjacks = engine.hands.filter { $0.result == .blackjack }.count
        if blackjacks == 1 { return "Blackjack • Paid 3 to 2" }
        if blackjacks > 1 { return "\(blackjacks) blackjacks • Paid 3 to 2" }
        if evaluate(engine.dealer).total > 21 { return "Dealer went over 21" }
        if engine.hands.count > 1 { return "\(winningHands) winning \(winningHands == 1 ? "hand" : "hands") • Great round" }
        return "Dealer beaten • Nice hand"
    }

    private func doneActionButton(
        _ title: String,
        systemImage: String,
        primary: Bool,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(primary ? Color.onAccent : Color.textPrimary)
                .background(
                    primary ? Color.accent : Color.surfaceRaised,
                    in: RoundedRectangle(cornerRadius: 11)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(primary ? Color.clear : Color.divider)
                }
                .opacity(enabled ? 1 : 0.35)
        }
        .disabled(!enabled)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            footerItem("CHIPS", engine.money(engine.bankroll), Theme.accent)
            Divider().frame(height: 30).overlay(Color.divider)
            footerItem("SESSION", sessionNetText,
                       engine.sessionNet > 0.005 ? Theme.good : (engine.sessionNet < -0.005 ? Theme.bad : .textPrimary))
            Divider().frame(height: 30).overlay(Color.divider)
            footerItem("TRUE COUNT", engine.showCount ? String(format: "%+.1f", engine.trueCount) : "Off", .textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .background(.surface)
    }

    /// Session result shown with arrows instead of signs, so it reads like a
    /// scoreboard rather than an accounting line.
    private var sessionNetText: String {
        let net = engine.sessionNet
        if net > 0.005 { return "▲ \(engine.money(net))" }
        if net < -0.005 { return "▼ \(engine.money(-net))" }
        return "Even"
    }

    private func footerItem(_ label: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(Color.textTertiary)
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

    // MARK: - Helpers

    // The result itself is stamped over the cards, so the label stays a
    // clean total.
    private func handLabel(_ hand: PlayerHand) -> String {
        let v = hand.value
        return v.soft && v.total != 21 ? "soft \(v.total)" : "\(v.total)"
    }

    /// A result that's already locked in before the round settles: a bust,
    /// or a natural once the dealer has peeked and doesn't have one too.
    /// Insurance comes before the peek, so a natural waits until after it.
    private func earlyResult(_ hand: PlayerHand) -> HandResult? {
        if hand.busted { return .bust }
        let afterPeek = [GamePhase.countCheck, .playing, .dealer].contains(engine.phase)
        let dealerNatural = engine.dealer.count == 2 && evaluate(engine.dealer).total == 21
        if hand.isBlackjack && afterPeek && !dealerNatural { return .blackjack }
        return nil
    }

    private func resultColor(_ hand: PlayerHand) -> Color {
        if hand.busted { return Theme.bad }
        switch hand.result {
        case .win, .blackjack: return Theme.good
        case .lose, .bust, .dealerBlackjack: return Theme.bad
        default: return Color.textPrimary
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
