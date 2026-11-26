import SwiftUI

// Visual language for round results: cards fly in from the shoe, result
// stamps slam onto each hand, losing bets get swept to the dealer, winning
// bets get matched with winnings next to the original stack, and the table celebrates a
// winning round with confetti and a gold banner.

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
    /// Cards arrive from the shoe's corner with a slight twist instead of
    /// fading straight down.
    static var dealtCard: AnyTransition {
        .modifier(active: DealSlide(active: true), identity: DealSlide(active: false))
    }
}

// MARK: - Dealer hole card flip

/// Turns the dealer's hole card over with a 3D flip instead of a crossfade.
struct HoleCardView: View {
    let card: Card
    let faceDown: Bool
    var size: CGFloat = 1.35

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CardView(card: card, faceDown: false, size: size)
                .opacity(faceDown ? 0 : 1)
                .accessibilityHidden(faceDown)
                .rotation3DEffect(.degrees(faceDown ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            CardView(card: card, faceDown: true, size: size)
                .opacity(faceDown ? 1 : 0)
                .accessibilityHidden(!faceDown)
                .rotation3DEffect(.degrees(faceDown ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: faceDown)
    }
}

// MARK: - Result stamp

/// A rubber-stamp result mark that slams onto a settled hand.
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

    private var color: Color {
        switch result {
        case .win: return Theme.good
        case .blackjack: return Theme.accent
        case .push: return Color.textPrimary
        case .lose, .bust, .dealerBlackjack: return Theme.bad
        }
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .black, design: .rounded))
            .tracking(1.6)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(color.opacity(0.9), lineWidth: 2)
            }
            .rotationEffect(.degrees(-9))
            .shadow(color: .shadowColor, radius: 4, y: 2)
            .scaleEffect(shown ? 1 : 2.6)
            .opacity(shown ? 1 : 0)
            .allowsHitTesting(false)
            .onAppear {
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55).delay(delay)) {
                        shown = true
                    }
                }
            }
    }
}

// MARK: - Bet chips: sweep on a loss, winnings on a win

/// The chips riding under one hand. When the round settles, a lost bet is
/// swept up toward the dealer; a won bet gets its winnings dropped beside it.
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
        HStack(alignment: .bottom, spacing: 5) {
            ChipStack(amount: hand.bet, size: size)
                .offset(y: swept ? -300 : 0)
                .opacity(swept ? 0 : 1)
            if paid {
                ChipStack(amount: winnings, size: size)
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .offset(y: -260).combined(with: .opacity)
                    )
            }
        }
        .onChange(of: settled) { _, isSettled in
            guard isSettled else { return }
            resolve()
        }
        .onAppear {
            if settled { resolve() }
        }
    }

    private func resolve() {
        if lost {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                Sound.play(.chip)
                if reduceMotion {
                    withAnimation(.easeIn(duration: 0.2)) { swept = true }
                } else {
                    withAnimation(.easeIn(duration: 0.35)) { swept = true }
                }
            }
        } else if won {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                Sound.play(.chip)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { paid = true }
            }
        }
    }
}

// MARK: - Loss vignette

/// A brief red table-light flash around the edges when the dealer wins the round.
struct LossVignetteView: View {
    var body: some View {
        RadialGradient(
            colors: [.clear, .clear, Theme.bad.opacity(0.42)],
            center: .center,
            startRadius: 90,
            endRadius: 520
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Win banner

/// The big table-center moment for a winning round.
struct WinOverlayView: View {
    let amount: Double
    let blackjack: Bool
    let detail: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            Text(blackjack ? "BLACKJACK" : "HAND WON")
                .font(.system(size: blackjack ? 38 : 44, weight: .black, design: .rounded))
                .tracking(3)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(Theme.accent)
            Text(Money.signedChips(amount))
                .monospacedDigit()
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.textPrimary)
            if !detail.isEmpty {
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.textPrimary)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .scaleEffect(appeared ? 1 : 0.55)
        .opacity(appeared ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(blackjack ? "Blackjack" : "Hand won"). Gained \(Money.chips(amount)). \(detail)")
        .accessibilityIdentifier("winCelebration")
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { appeared = true }
            }
        }
    }
}

// MARK: - End session confirmation

/// A confirmation card for ending the practice session, centered over the
/// table in place of the system's generic bottom action sheet.
struct EndSessionConfirmCard: View {
    let amount: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.16))
                    .frame(width: 64, height: 64)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(spacing: 6) {
                Text("END SESSION?")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.textPrimary)
                Text("Finish with \(amount)")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            VStack(spacing: 10) {
                Button(action: onConfirm) {
                    Text("End session")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.onAccent)
                }
                Button(action: onCancel) {
                    Text("Keep Playing")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(Color.textPrimary)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: 1)
        }
        .shadow(color: .shadowColor, radius: 24, y: 10)
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .accessibilityIdentifier("cashOutConfirmCard")
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { appeared = true }
            }
        }
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

/// A one-shot celebration burst: gold flecks and chips raining over the felt.
/// The parent removes this view when the celebration window ends.
struct ConfettiBurstView: View {
    let seed: Int

    @State private var start = Date()
    private let pieces: [ConfettiPiece]

    private static let palette: [Color] = [
        Color.accent,
        Color.accent,
        Color.warm,
        Color.textPrimary,
        Color.warning
    ]

    init(seed: Int) {
        self.seed = seed
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(seed)))
        pieces = (0..<70).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0.02...0.98, using: &rng),
                delay: Double.random(in: 0...0.4, using: &rng),
                fall: CGFloat.random(in: 150...330, using: &rng),
                swayAmp: CGFloat.random(in: 10...42, using: &rng),
                swayFreq: Double.random(in: 1.2...3.2, using: &rng),
                phase: Double.random(in: 0...(2 * .pi), using: &rng),
                spin: Double.random(in: 1.5...7, using: &rng),
                size: CGFloat.random(in: 5...11, using: &rng),
                color: Self.palette.randomElement(using: &rng) ?? Theme.accent,
                isChip: Double.random(in: 0...1, using: &rng) < 0.22
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, canvasSize in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let alpha = t > 1.5 ? max(0, 1 - (t - 1.5) / 0.55) : 1
                    guard alpha > 0 else { continue }
                    let y = -20 + piece.fall * t + 85 * t * t
                    guard y < canvasSize.height + 20 else { continue }
                    let x = piece.x * canvasSize.width
                        + piece.swayAmp * sin(t * piece.swayFreq + piece.phase)

                    var ctx = context
                    ctx.opacity = alpha
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(piece.spin * t + piece.phase))
                    if piece.isChip {
                        let r = piece.size * 0.62
                        let rect = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(piece.color))
                        ctx.stroke(
                            Path(ellipseIn: rect.insetBy(dx: r * 0.3, dy: r * 0.3)),
                            with: .color(Color.textPrimary.opacity(0.8)),
                            lineWidth: 1
                        )
                    } else {
                        let rect = CGRect(
                            x: -piece.size / 2, y: -piece.size * 0.3,
                            width: piece.size, height: piece.size * 0.6
                        )
                        ctx.fill(Path(rect), with: .color(piece.color))
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { start = Date() }
    }
}
