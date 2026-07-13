import SwiftUI

enum Theme {
    /// Deep casino-felt green — dark enough to give white/mint feedback text
    /// real contrast instead of the mid-green that used to wash it out.
    static let felt = Color(red: 0.043, green: 0.235, blue: 0.149)      // #0B3C26
    static let feltDark = Color(red: 0.051, green: 0.180, blue: 0.114)  // #0D2E1D
    static let accent = Color(red: 0.945, green: 0.769, blue: 0.059)
    /// Result/status color (badges, borders) — kept distinct from the mint
    /// used for feedback copy so the two don't read as duplicates.
    static let good = Color(red: 0.18, green: 0.80, blue: 0.44)
    /// High-contrast mint for success feedback text on the felt background.
    static let mint = Color(red: 0.322, green: 0.898, blue: 0.643)      // #52E5A4
    static let bad = Color(red: 0.91, green: 0.30, blue: 0.24)
    static let cardFace = Color(white: 0.98)
    static let cardRed = Color(red: 0.75, green: 0.22, blue: 0.17)
    static let cardBlack = Color(white: 0.13)
}

/// A lightweight inline title bar used in place of a NavigationStack.
/// (Multiple NavigationStacks inside a paged TabView crash UIKit on swipe.)
struct PageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            HStack {
                Spacer()
                trailing
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

struct CardView: View {
    let card: Card?
    var faceDown = false
    var size: CGFloat = 1.0

    private var width: CGFloat { 48 * size }
    private var height: CGFloat { 68 * size }
    private var corner: CGFloat { 7 * size }

    var body: some View {
        ZStack {
            if faceDown {
                RoundedRectangle(cornerRadius: corner)
                    .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.38, blue: 0.72),
                                                  Color(red: 0.10, green: 0.26, blue: 0.55)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                RoundedRectangle(cornerRadius: corner * 0.6)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    .padding(4 * size)
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 20 * size))
                    .foregroundStyle(.white.opacity(0.30))
            } else if let card {
                RoundedRectangle(cornerRadius: corner).fill(Theme.cardFace)
                RoundedRectangle(cornerRadius: corner)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                let color: Color = card.suit.isRed ? Theme.cardRed : Theme.cardBlack
                // Center suit
                Text(card.suit.rawValue)
                    .font(.system(size: 26 * size))
                    .foregroundStyle(color.opacity(0.85))
                // Corner index (top-left, and mirrored bottom-right)
                VStack(alignment: .leading, spacing: -2 * size) {
                    Text(card.rank.rawValue)
                        .font(.system(size: 13 * size, weight: .heavy, design: .rounded))
                    Text(card.suit.rawValue)
                        .font(.system(size: 10 * size))
                }
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(4 * size)
                VStack(alignment: .leading, spacing: -2 * size) {
                    Text(card.rank.rawValue)
                        .font(.system(size: 13 * size, weight: .heavy, design: .rounded))
                    Text(card.suit.rawValue)
                        .font(.system(size: 10 * size))
                }
                .foregroundStyle(color)
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(4 * size)
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .fill(Theme.cardFace.opacity(0.15))
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}

/// Standard casino chip colors by denomination.
enum ChipStyle {
    static func colors(for value: Double) -> (bg: Color, ring: Color, text: Color) {
        switch value {
        case 0.10: return (Color(white: 0.45), .white, .white)
        case 0.25: return (Color(red: 0.85, green: 0.45, blue: 0.62), .white, .white)
        case 1:     return (Color(white: 0.95), Color(white: 0.6), Theme.cardBlack)
        case 5:     return (Color(red: 0.78, green: 0.18, blue: 0.16), .white, .white)
        case 25:    return (Color(red: 0.13, green: 0.5, blue: 0.28), .white, .white)
        case 100:   return (Color(white: 0.12), .white, .white)
        default:    return (Color(red: 0.42, green: 0.2, blue: 0.6), .white, .white)
        }
    }

    static func label(_ value: Double) -> String {
        if value < 1 { return String(format: "%.2f", value) }
        return String(format: "%g", value)
    }

    /// Greedy breakdown of a bet into stackable chip denominations.
    static func breakdown(_ amount: Double) -> [Double] {
        let denoms = [100.0, 25, 5, 1, 0.25, 0.10]
        var remaining = (amount * 100).rounded() / 100
        var chips: [Double] = []
        for d in denoms {
            while remaining >= d - 0.001 && chips.count < 24 {
                chips.append(d)
                remaining = ((remaining - d) * 100).rounded() / 100
            }
        }
        return chips
    }
}

struct ChipView: View {
    let value: Double
    var size: CGFloat = 52

    var body: some View {
        let c = ChipStyle.colors(for: value)
        ZStack {
            Circle().fill(c.bg)
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: size * 0.09, dash: [size * 0.16, size * 0.12]))
                .foregroundStyle(c.ring)
                .padding(size * 0.10)
            Circle()
                .strokeBorder(c.ring.opacity(0.9), lineWidth: max(1, size * 0.03))
            Text(ChipStyle.label(value))
                .font(.system(size: size * 0.30, weight: .heavy, design: .rounded))
                .foregroundStyle(c.text)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}

/// A stack of chips representing a bet amount, sitting on the betting spot.
struct ChipStack: View {
    let amount: Double
    var size: CGFloat = 46

    var body: some View {
        let chips = ChipStyle.breakdown(amount)
        ZStack(alignment: .bottom) {
            ForEach(Array(chips.enumerated()), id: \.offset) { idx, value in
                ChipView(value: value, size: size)
                    .offset(y: -CGFloat(idx) * size * 0.16)
            }
        }
        .frame(height: size + CGFloat(max(chips.count - 1, 0)) * size * 0.16)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
    }
}
