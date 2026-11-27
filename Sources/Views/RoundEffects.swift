import SwiftUI

// Visual language for a round: cards slide in from the shoe, the hole card
// flips, result stamps land on each hand, lost bets are swept to the dealer,
// won bets get their winnings beside them, and a small toast marks a winning
// round. Every movement goes through `Motion`, so Reduce Motion turns it into
// a short fade (or nothing).

// MARK: - Deal transition

private struct DealSlide: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active ? 10 : 0))
            .offset(x: active ? 150 : 0, y: active ? -230 : 0)
            .opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    /// Cards arrive from the shoe's corner with a slight twist; a plain fade
    /// with Reduce Motion.
    static func dealtCard(_ reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity
            : .modifier(active: DealSlide(active: true), identity: DealSlide(active: false))
    }
}

// MARK: - Dealer hole card flip

/// Turns the dealer's hole card over with a 3D flip (a cross-fade with
/// Reduce Motion).
struct HoleCardView: View {
    let card: Card
    let faceDown: Bool
    var size: CGFloat = 1.35

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var flip: Double { reduceMotion ? 0 : 180 }

    var body: some View {
        ZStack {
            CardView(card: card, faceDown: false, size: size)
                .opacity(faceDown ? 0 : 1)
                .accessibilityHidden(faceDown)
                .rotation3DEffect(.degrees(faceDown ? flip : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            CardView(card: card, faceDown: true, size: size)
                .opacity(faceDown ? 1 : 0)
                .accessibilityHidden(!faceDown)
                .rotation3DEffect(.degrees(faceDown ? 0 : -flip), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        }
        .motion(.emphasized, value: faceDown)
    }
}

// MARK: - Result stamp

/// A small result tag that lands on a settled hand.
struct ResultStamp: View {
    let result: HandResult
    var delay: Double = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var text: String {
        switch result {
        case .win: return "WIN"
        case .lose: return "LOSE"
        case .push: return "PUSH"
        case .bust: return "BUST"
        case .blackjack: return "BLACKJACK"
        case .dealerBlackjack: return "DEALER BJ"
        }
    }

    /// Coral for a natural, mint for a win, red for a loss.
    private var color: Color {
        switch result {
        case .win: return .positive
        case .blackjack: return .warm
        case .push: return .textPrimary
        case .lose, .bust, .dealerBlackjack: return .negative
        }
    }

    var body: some View {
        Text(text)
            .scaledFont(size: 13, weight: .black, relativeTo: .caption, maxSize: 16)
            .tracking(1.2)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, Space.xxs / 2)
            .background(.surface, in: RoundedRectangle(cornerRadius: Radius.small / 2))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.small / 2)
                    .strokeBorder(color, lineWidth: 2)
            }
            .rotationEffect(.degrees(reduceMotion ? 0 : -8))
            .shadow(color: .shadowColor, radius: 3, y: 2)
            .scaleEffect(shown || reduceMotion ? 1 : 1.8)
            .opacity(shown ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)   // the hand's own label carries the result
            .onAppear {
                withAnimation(Motion.spring.resolved(reduceMotion)?.delay(delay)) { shown = true }
            }
    }
}

extension HandResult {
    /// Spoken result for a hand.
    var spokenName: String {
        switch self {
        case .win: return "won"
        case .lose: return "lost"
        case .push: return "push"
        case .bust: return "bust"
        case .blackjack: return "blackjack"
        case .dealerBlackjack: return "dealer blackjack"
        }
    }
}

// MARK: - Bet chips: sweep on a loss, winnings on a win

/// The chips riding under one hand. When the round settles, a lost bet is
/// swept up toward the dealer; a won bet gets its winnings placed beside it.
struct BetChipsView: View {
    let hand: PlayerHand
    let settled: Bool
    var size: CGFloat = 34

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swept = false
    @State private var paid = false

    private var lost: Bool {
        hand.result == .lose || hand.result == .bust || hand.result == .dealerBlackjack
    }
    private var won: Bool {
        hand.result == .win || hand.result == .blackjack
    }
    private var winnings: Double {
        hand.result == .blackjack ? hand.bet * 1.5 : hand.bet
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Space.xxs) {
            ChipStack(amount: hand.bet, size: size)
                .offset(y: swept && !reduceMotion ? -300 : 0)
                .opacity(swept ? 0 : 1)
            if paid {
                ChipStack(amount: winnings, size: size)
                    .transition(reduceMotion ? .opacity : .offset(y: -260).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bet \(Money.chips(hand.bet))")
        .onChange(of: settled) { _, isSettled in
            if isSettled { resolve() }
        }
        .onAppear {
            if settled { resolve() }
        }
    }

    private func resolve() {
        if lost {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                Motion.perform(.standard, reduceMotion: reduceMotion) { swept = true }
            }
        } else if won {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                Sound.play(.chip)
                Motion.perform(.spring, reduceMotion: reduceMotion) { paid = true }
            }
        }
    }
}

// MARK: - Loss edge

/// A thin red edge that briefly outlines the table when the dealer takes the
/// round. Flat (no gradient), subtle, and skipped entirely with Reduce Motion.
private struct LossEdge: ViewModifier {
    let active: Bool
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.negative, lineWidth: 2)
                .opacity(active && !reduceMotion ? 0.7 : 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Outlines the view's rounded shape in red while `active` (not with Reduce Motion).
    func lossEdge(_ active: Bool, cornerRadius: CGFloat = Radius.large) -> some View {
        modifier(LossEdge(active: active, cornerRadius: cornerRadius))
    }
}

// MARK: - Win toast

/// A small toast at the top of the table for a winning round. The result card
/// in the control dock carries the full details; this is just the moment.
struct WinToastView: View {
    let outcome: RoundOutcome

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: outcome.symbol)
                .foregroundStyle(outcome.tint)
            Text(outcome.title)
                .font(.heading)
                .foregroundStyle(outcome.tint)
            Text(outcome.amountText)
                .font(.numberInline)
                .foregroundStyle(.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs)
        .background(outcome.tintBackground, in: Capsule())
        .overlay { Capsule().strokeBorder(outcome.tint.opacity(0.6), lineWidth: Metrics.hairline) }
        .shadow(color: .shadowColor, radius: 6, y: 3)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(outcome.title). \(outcome.amountText)")
        .accessibilityIdentifier("winCelebration")
    }
}

// MARK: - End session confirmation

/// A confirmation card for ending the practice session, centered over the
/// table. Modal for VoiceOver, with the escape gesture (two-finger scrub)
/// meaning "Keep playing".
struct EndSessionConfirmCard: View {
    let amount: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "flag.checkered")
                .font(.sectionTitle)
                .foregroundStyle(.accent)
                .frame(width: 56, height: 56)
                .background(.positiveBg, in: Circle())
                .accessibilityHidden(true)
            VStack(spacing: Space.xxs) {
                Text("End this session?")
                    .font(.sectionTitle)
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("You'll finish with \(amount) and see your session summary.")
                    .font(.calloutText)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: Space.xs) {
                PrimaryButton("End session", action: onConfirm)
                SecondaryButton("Keep playing", action: onCancel)
            }
        }
        .padding(Space.lg)
        .frame(maxWidth: 340)
        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: Metrics.hairline)
        }
        .shadow(color: .shadowColor, radius: 24, y: 10)
        .padding(.horizontal, Space.lg)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onCancel)
        .accessibilityIdentifier("cashOutConfirmCard")
    }
}

// MARK: - Confetti

private struct ConfettiPiece {
    let x: CGFloat        // 0...1 across the width
    let delay: Double
    let fall: CGFloat     // base fall speed, points per second
    let swayAmp: CGFloat
    let swayFreq: Double
    let phase: Double
    let spin: Double
    let size: CGFloat
    let color: Color
    let isChip: Bool
}

/// Deterministic generator so a given burst renders identically across
/// re-renders of the same seed.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// A one-shot burst for a natural blackjack (never with Reduce Motion; see
/// `WinCelebrationPolicy`). The parent removes it when the moment ends.
struct ConfettiBurstView: View {
    let seed: Int

    @State private var start = Date()
    private let pieces: [ConfettiPiece]

    private static let palette: [Color] = [.warm, .warm, .accent, .textPrimary, .warning]

    init(seed: Int) {
        self.seed = seed
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(seed)))
        pieces = (0..<60).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0.02...0.98, using: &rng),
                delay: Double.random(in: 0...0.4, using: &rng),
                fall: CGFloat.random(in: 150...330, using: &rng),
                swayAmp: CGFloat.random(in: 10...42, using: &rng),
                swayFreq: Double.random(in: 1.2...3.2, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng),
                spin: Double.random(in: 1.5...7, using: &rng),
                size: CGFloat.random(in: 5...11, using: &rng),
                color: Self.palette.randomElement(using: &rng) ?? .warm,
                isChip: Double.random(in: 0...1, using: &rng) < 0.22
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, canvasSize in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    draw(piece, elapsed: elapsed, in: &context, size: canvasSize)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { start = Date() }
    }

    private func draw(_ piece: ConfettiPiece, elapsed: Double,
                      in context: inout GraphicsContext, size canvasSize: CGSize) {
        let t = elapsed - piece.delay
        guard t > 0 else { return }
        let alpha = t > 1.5 ? max(0, 1 - (t - 1.5) / 0.55) : 1
        guard alpha > 0 else { return }
        let y = -20 + piece.fall * t + 85 * t * t
        guard y < canvasSize.height + 20 else { return }
        let x = piece.x * canvasSize.width + piece.swayAmp * sin(t * piece.swayFreq + piece.phase)

        var ctx = context
        ctx.opacity = alpha
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: .radians(piece.spin * t + piece.phase))
        if piece.isChip {
            let r = piece.size * 0.62
            let rect = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(piece.color))
            ctx.stroke(Path(ellipseIn: rect.insetBy(dx: r * 0.3, dy: r * 0.3)),
                       with: .color(Color.textPrimary.opacity(0.8)), lineWidth: 1)
        } else {
            let rect = CGRect(x: -piece.size / 2, y: -piece.size * 0.3,
                              width: piece.size, height: piece.size * 0.6)
            ctx.fill(Path(rect), with: .color(piece.color))
        }
    }
}
