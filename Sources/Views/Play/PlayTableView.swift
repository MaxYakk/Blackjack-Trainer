import SwiftUI

/// The table: one `surface` panel on the `bg` screen with three stacked
/// bands that never change height between phases:
///   1. dealer (label + cards),
///   2. the message slot (feedback, bet advice, prompts),
///   3. the player area (betting spots, then the dealt hands).
/// Card sizes come from the panel's own height, so a small iPhone gets
/// smaller cards instead of overlapping controls.
struct PlayTableView: View {
    @Bindable var engine: PlayEngine
    let refundedChips: Double
    let lossFlash: Bool

    var body: some View {
        GeometryReader { geo in
            let inner = CGSize(width: geo.size.width - Space.sm * 2,
                               height: geo.size.height - Space.sm * 2)
            // 1.0 on an SE-size table (~360pt tall), up to 1.3 on big phones.
            let dealerScale = min(1.3, max(0.9, inner.height / 340))
            VStack(spacing: Space.xs) {
                DealerArea(engine: engine, cardScale: dealerScale, width: inner.width)
                TableMessageSlot(engine: engine, refundedChips: refundedChips)
                PlayerArea(engine: engine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(Space.sm)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .lossEdge(lossFlash)
    }
}

// MARK: - Dealer

private struct DealerArea: View {
    let engine: PlayEngine
    let cardScale: CGFloat
    let width: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cardHeight: CGFloat { CardView.baseSize.height * cardScale }

    var body: some View {
        VStack(spacing: Space.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text("Dealer")
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                if engine.showHandTotals, let total = totalText {
                    Text(total)
                        .font(.numberInline)
                        .foregroundStyle(.textSecondary)
                        .accessibilityIdentifier("dealerTotal")
                }
                Spacer(minLength: Space.xs)
                if engine.showCount {
                    Text("Shoe \(engine.decksRemaining, specifier: "%.1f") decks")
                        .font(.captionText)
                        .foregroundStyle(.textSecondary)
                        .accessibilityLabel("\(engine.decksRemaining, specifier: "%.1f") decks left in the shoe")
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            cards
                .frame(height: cardHeight)
        }
    }

    @ViewBuilder
    private var cards: some View {
        if engine.dealer.isEmpty {
            // Empty slots keep the band the same height before the deal.
            HStack(spacing: Space.xs) {
                CardView(card: nil, size: cardScale)
                CardView(card: nil, size: cardScale)
            }
        } else {
            HStack(spacing: spacing(for: engine.dealer.count)) {
                ForEach(Array(engine.dealer.enumerated()), id: \.offset) { idx, card in
                    Group {
                        if idx == 1 {
                            HoleCardView(card: card, faceDown: engine.dealerHoleHidden, size: cardScale)
                        } else {
                            CardView(card: card, size: cardScale)
                        }
                    }
                    .transition(.dealtCard(reduceMotion))
                    .accessibilityIdentifier("dealerCard\(idx)")
                }
            }
            .motion(.spring, value: engine.dealer.count)
        }
    }

    /// Overlaps the dealer's cards once a long draw would overflow the panel.
    private func spacing(for count: Int) -> CGFloat {
        let cardWidth = CardView.baseSize.width * cardScale
        let needed = CGFloat(count) * cardWidth + CGFloat(count - 1) * Space.xs
        guard count > 1, needed > width else { return Space.xs }
        return (width - CGFloat(count) * cardWidth) / CGFloat(count - 1)
    }

    private var totalText: String? {
        guard !engine.dealer.isEmpty else { return nil }
        if engine.dealerHoleHidden { return "shows \(engine.dealerUpValue)" }
        let value = evaluate(engine.dealer)
        return value.soft && value.total != 21 ? "soft \(value.total)" : "\(value.total)"
    }
}

// MARK: - Player area

private struct PlayerArea: View {
    @Bindable var engine: PlayEngine

    var body: some View {
        if engine.hands.isEmpty {
            BettingArea(engine: engine)
        } else {
            HandsArea(engine: engine)
        }
    }
}

/// Betting phase: a compact row with the hands picker and table minimum,
/// then one betting spot per hand.
private struct BettingArea: View {
    @Bindable var engine: PlayEngine

    var body: some View {
        VStack(spacing: Space.xs) {
            tableRow
            GeometryReader { geo in spots(in: geo.size) }
        }
    }

    private var tableRow: some View {
        HStack(spacing: Space.xs) {
            Text("Hands")
                .font(.captionText)
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
            Picker("Hands", selection: $engine.numHands) {
                ForEach(PlayEngine.spotRange, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 120)
            .accessibilityLabel("Hands per round")
            Spacer(minLength: Space.xs)
            VStack(alignment: .trailing, spacing: 0) {
                Text("Min \(Money.string(engine.tableMinimum))")
                    .accessibilityLabel("Table minimum \(Money.chips(engine.tableMinimum))")
                    .accessibilityIdentifier("tableMinimumLabel")
                if engine.numHands > 1 && engine.totalWager > 0 {
                    Text("Total \(Money.string(engine.totalWager))")
                        .foregroundStyle(.accent)
                        .accessibilityLabel("Total bet \(Money.chips(engine.totalWager))")
                }
            }
            .font(.captionText)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
        }
    }

    private func spots(in size: CGSize) -> some View {
        let count = engine.numHands
        let mid = Double(count - 1) / 2
        let labelHeight: CGFloat = count > 1 ? 18 : 0
        let chromeHeight = labelHeight + 22 + Space.xxs * 2
        let arcDrop = count > 1 ? min(size.height * 0.1, 16) : 0
        let spacing: CGFloat = count == 3 ? Space.sm : Space.lg
        let widthBudget = (size.width - CGFloat(count - 1) * spacing) / CGFloat(max(count, 1))
        let heightBudget = size.height - chromeHeight - arcDrop
        // 44pt floor (a tap target) only matters at the largest capped text size on an SE.
        let spotSize = max(Metrics.minTapTarget, min(120, min(heightBudget, widthBudget)))
        return HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<count, id: \.self) { idx in
                BettingSpot(engine: engine, index: idx, size: spotSize)
                    .offset(y: count > 1 ? abs(Double(idx) - mid) / max(mid, 1) * arcDrop : 0)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .motion(.spring, value: count)
    }
}

private struct BettingSpot: View {
    let engine: PlayEngine
    let index: Int
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bet: Double {
        engine.spotBets.indices.contains(index) ? engine.spotBets[index] : 0
    }
    private var isActive: Bool { engine.activeSpot == index }

    private var spokenName: String {
        let name = engine.numHands > 1 ? "Spot \(index + 1)" : "Betting spot"
        return bet > 0 ? "\(name), bet \(Money.string(bet))" : "\(name), no bet"
    }

    var body: some View {
        Button {
            engine.selectSpot(index)
        } label: {
            VStack(spacing: Space.xxs) {
                if engine.numHands > 1 {
                    Text("Spot \(index + 1)")
                        .font(.overline)
                        .foregroundStyle(isActive ? Color.accent : Color.textTertiary)
                }
                circle
                Text("Bet \(engine.money(bet))")
                    .font(.numberInline)
                    .foregroundStyle(bet > 0 ? Color.accent : Color.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityIdentifier(index == 0 ? "betAmount" : "betAmount\(index)")
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("spot\(index)")
        .accessibilityLabel(spokenName)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityHint(engine.numHands > 1 ? "Chips you tap go on this spot" : "")
    }

    private var circle: some View {
        ZStack {
            Circle()
                .fill(isActive ? Color.surfaceRaised : Color.surfaceSubtle)
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: isActive ? 2.5 : 1.5,
                                                 dash: bet > 0 ? [] : [6, 5]))
                .foregroundStyle(isActive ? Color.accent : Color.textTertiary)
            if bet > 0 {
                ChipStack(amount: bet, size: min(46, size * 0.5))
                    .transition(Motion.pop(reduceMotion))
            } else {
                Text("Tap chips\nto bet")
                    .font(.captionText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.textTertiary)
                    .frame(width: max(36, size - 24), height: max(32, size - 24))
                    .accessibilityIdentifier("bettingInstruction\(index)")
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bettingCircle\(index)")
        .motion(.spring, value: bet)
    }
}

/// Dealt hands, in a shallow arc so they never crowd the panel edges.
private struct HandsArea: View {
    let engine: PlayEngine

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in row(in: geo.size) }
    }

    private func row(in size: CGSize) -> some View {
        let count = engine.hands.count
        let mid = Double(count - 1) / 2
        let arcDrop = count > 1 ? min(size.height * 0.1, 20) : 0
        let columnSpacing: CGFloat = count >= 4 ? Space.xs : Space.md
        let columnWidth = (size.width - columnSpacing * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1))
        // Size cards for the common two-card hand from whichever dimension is
        // tighter. Longer hands overlap their own cards (HandColumn) instead
        // of shrinking every hand on the table.
        let widthCardSize = (columnWidth - HandColumn.cardPadding * 2 - Space.xs) / 2 / CardView.baseSize.width
        let heightBudget = size.height - HandColumn.chromeHeight - arcDrop
        // Each point of card scale also buys ~40pt of chip stack under the cards.
        let heightCardSize = heightBudget / (CardView.baseSize.height + 40)
        let cardSize = max(0.65, min(1.35, min(widthCardSize, heightCardSize)))

        let hands = HStack(alignment: .top, spacing: columnSpacing) {
            ForEach(Array(engine.hands.enumerated()), id: \.element.id) { idx, hand in
                HandColumn(engine: engine, hand: hand, index: idx,
                           cardSize: cardSize, columnWidth: columnWidth)
                    .offset(y: count > 1 ? abs(Double(idx) - mid) / max(mid, 1) * arcDrop : 0)
                    .id(idx)
            }
        }
        .motion(.spring, value: count)

        return Group {
            if count > 4 {
                // A heavily resplit round scrolls and keeps the active hand in view.
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) { hands }
                        .onChange(of: engine.currentIndex) { _, idx in
                            Motion.perform(.standard, reduceMotion: reduceMotion) {
                                proxy.scrollTo(idx, anchor: .center)
                            }
                        }
                }
            } else {
                hands.frame(maxWidth: .infinity)
            }
        }
        // Top-aligned so the arc-dropped outer hands stay inside the panel.
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}

private struct HandColumn: View {
    let engine: PlayEngine
    let hand: PlayerHand
    let index: Int
    let cardSize: CGFloat
    let columnWidth: CGFloat

    static let cardPadding: CGFloat = 6
    /// Total label + paddings + spacing around the cards (chips counted separately).
    static let chromeHeight: CGFloat = 18 + cardPadding * 2 + Space.xs * 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActive: Bool { engine.phase == .playing && index == engine.currentIndex }
    private var lost: Bool {
        hand.busted || hand.result == .lose || hand.result == .bust || hand.result == .dealerBlackjack
    }

    /// A result locked in before the round settles: a bust, or a natural once
    /// the dealer has peeked and doesn't have one too. Insurance comes before
    /// the peek, so a natural waits until after it.
    private var earlyResult: HandResult? {
        if hand.busted { return .bust }
        let afterPeek = [GamePhase.countCheck, .playing, .dealer].contains(engine.phase)
        let dealerNatural = engine.dealer.count == 2 && evaluate(engine.dealer).total == 21
        if hand.isBlackjack && afterPeek && !dealerNatural { return .blackjack }
        return nil
    }

    private var totalText: String {
        let v = hand.value
        return v.soft && v.total != 21 ? "soft \(v.total)" : "\(v.total)"
    }

    private var totalColor: Color {
        switch hand.result ?? earlyResult {
        case .win: return .positive
        case .blackjack: return .warm
        case .lose, .bust, .dealerBlackjack: return .negative
        default: return .textPrimary
        }
    }

    private var spokenName: String {
        var parts = [engine.hands.count > 1 ? "Hand \(index + 1)" : "Your hand"]
        if engine.showHandTotals { parts.append(totalText) }
        if let result = hand.result ?? earlyResult { parts.append(result.spokenName) }
        if isActive { parts.append("your turn") }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        let n = hand.cards.count
        let cardWidth = CardView.baseSize.width * cardSize
        let available = max(columnWidth - Self.cardPadding * 2, 0)
        let needed = CGFloat(n) * cardWidth + CGFloat(max(n - 1, 0)) * Space.xs
        let cardSpacing = n > 1 && needed > available
            ? (available - CGFloat(n) * cardWidth) / CGFloat(n - 1)
            : Space.xs

        VStack(spacing: Space.xs) {
            Text(totalText)
                .font(.numberInline)
                .foregroundStyle(totalColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 18)
                .opacity(engine.showHandTotals ? 1 : 0)   // keep the slot so nothing shifts
                .accessibilityHidden(!engine.showHandTotals)
                .accessibilityIdentifier("handTotal\(index)")
            HStack(spacing: cardSpacing) {
                ForEach(hand.cards) { card in
                    CardView(card: card, size: cardSize)
                        .transition(.dealtCard(reduceMotion))
                }
            }
            .padding(Self.cardPadding)
            .background {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(isActive ? Color.accent : Color.clear, lineWidth: 2)
            }
            .motion(.spring, value: hand.cards.count)
            // A beaten hand dims.
            .saturation(lost ? 0.55 : 1)
            .opacity(lost ? 0.75 : 1)
            .motion(.standard, value: lost)
            // A bust or a natural stamps the moment it happens; everything
            // else waits for the dealer.
            .overlay {
                if let result = hand.result ?? earlyResult {
                    ResultStamp(result: result, delay: hand.result == nil ? 0 : Double(index) * 0.06)
                }
            }
            BetChipsView(hand: hand, settled: engine.phase == .done, size: 34 * min(cardSize, 1))
        }
        .frame(width: columnWidth)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(spokenName)
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("playerHand\(index)")
    }
}
