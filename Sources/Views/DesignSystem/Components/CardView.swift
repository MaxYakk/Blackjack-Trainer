import SwiftUI

// MARK: - Playing card
//
//     CardView(card: card, size: 1.35)          // face up
//     CardView(card: card, faceDown: true)      // card back
//     CardView(card: nil)                       // empty slot
//
// `size` scales the 48×68pt base card (`CardView.baseSize`). Pass
// `scalesWithText: true` where the layout has room, and the card also grows a
// little (up to 20%) with larger Dynamic Type settings via `@ScaledMetric`; it
// never shrinks below `size`. It's off by default because table layouts (the
// Play screen's hand columns) do their own math with `baseSize * size`.
// The rank/suit glyphs are part of the card graphic, so their sizes follow
// the card rather than a text style. VoiceOver reads "King of hearts",
// "Face-down card", or nothing for an empty slot.

struct CardView: View {
    let card: Card?
    var faceDown = false
    var size: CGFloat = 1.0
    var scalesWithText = false

    /// The unscaled card size; multiply by `size` for layout math.
    static let baseSize = CGSize(width: 48, height: 68)

    @ScaledMetric(relativeTo: .body) private var dynamicScale: CGFloat = 1

    private var scale: CGFloat {
        scalesWithText ? size * min(max(dynamicScale, 1), 1.2) : size
    }
    private var width: CGFloat { Self.baseSize.width * scale }
    private var height: CGFloat { Self.baseSize.height * scale }
    private var corner: CGFloat { 7 * scale }

    var body: some View {
        ZStack {
            if faceDown {
                back
            } else if let card {
                face(card)
            } else {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.cardSlot)
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .shadowColor, radius: 2, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHidden(card == nil && !faceDown)
    }

    private var accessibilityText: String {
        if faceDown { return "Face-down card" }
        return card?.spokenName ?? ""
    }

    private var back: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        return ZStack {
            shape.fill(.cardBack)
            shape.strokeBorder(.accent, lineWidth: max(1, 1.5 * scale))
            RoundedRectangle(cornerRadius: corner * 0.6, style: .continuous)
                .strokeBorder(Color.accent.opacity(0.25), lineWidth: 1)
                .padding(5 * scale)
            Image(systemName: "suit.spade.fill")
                .font(.system(size: 18 * scale))
                .foregroundStyle(Color.accent.opacity(0.45))
        }
    }

    private func face(_ card: Card) -> some View {
        let color: Color = card.suit.isRed ? .cardSuitRed : .cardSuitBlack
        return ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous).fill(.cardFace)
            Text(card.suit.rawValue)
                .font(.system(size: 26 * scale))
                .foregroundStyle(color)
            cornerIndex(card, color: color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(4 * scale)
            cornerIndex(card, color: color)
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(4 * scale)
        }
    }

    private func cornerIndex(_ card: Card, color: Color) -> some View {
        VStack(alignment: .leading, spacing: -2 * scale) {
            Text(card.rank.rawValue)
                .font(.system(size: 13 * scale, weight: .heavy, design: .rounded))
            Text(card.suit.rawValue)
                .font(.system(size: 10 * scale))
        }
        .foregroundStyle(color)
    }
}

extension Card {
    /// "King of hearts", "Ten of clubs" — for VoiceOver.
    var spokenName: String { "\(rank.spokenName) of \(suit.spokenName)" }
}

extension Rank {
    var spokenName: String {
        switch self {
        case .two: return "Two"
        case .three: return "Three"
        case .four: return "Four"
        case .five: return "Five"
        case .six: return "Six"
        case .seven: return "Seven"
        case .eight: return "Eight"
        case .nine: return "Nine"
        case .ten: return "Ten"
        case .jack: return "Jack"
        case .queen: return "Queen"
        case .king: return "King"
        case .ace: return "Ace"
        }
    }
}

extension Suit {
    var spokenName: String {
        switch self {
        case .spades: return "spades"
        case .hearts: return "hearts"
        case .diamonds: return "diamonds"
        case .clubs: return "clubs"
        }
    }
}
