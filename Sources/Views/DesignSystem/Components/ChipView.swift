import SwiftUI

// MARK: - Practice chips
//
//     ChipView(value: 25)              // one chip
//     ChipStack(amount: engine.bet)    // a bet as a short stack of chips
//
// Every denomination ChipSizing can hand out has its own color (falling
// through to `default` once made the 250 and 1,000 chips look identical).
// Colors are flat and tuned to Night ink; each label meets at least 3.9:1
// (large bold text) against its chip. VoiceOver reads "25 chip" / "Stack of
// 1,250 chips".

enum ChipStyle {
    /// Fill, edge-spot ring and label colors for a denomination.
    static func colors(for value: Double) -> (bg: Color, ring: Color, text: Color) {
        let white = Color(hex: 0xFFFFFF)
        let ink = Color(hex: 0x111827)
        switch value {
        case 0.10:   return (Color(hex: 0x6B7488), white, white)                 // slate
        case 0.25:   return (Color(hex: 0xD9739B), Color(hex: 0x2A0E1A), Color(hex: 0x2A0E1A)) // rose
        case 1:      return (Color(hex: 0xEEF2FA), Color(hex: 0x8A93A8), ink)    // white
        case 5:      return (Color(hex: 0xE5484D), white, white)                 // red
        case 10:     return (Color(hex: 0x3B7BE0), white, white)                 // blue
        case 25:     return (Color(hex: 0x2A8F5E), white, white)                 // green
        case 50:     return (Color(hex: 0xFF8A5B), Color(hex: 0x2A1206), Color(hex: 0x2A1206)) // coral
        case 100:    return (Color(hex: 0x1B2233), Color(hex: 0xEEF2FA), white)  // ink
        case 250:    return (Color(hex: 0x7C4FE0), white, white)                 // violet
        case 500:    return (Color(hex: 0x22B5B0), Color(hex: 0x04282A), Color(hex: 0x04282A)) // teal
        case 1000:   return (Color(hex: 0x4652C8), white, white)                 // indigo
        case 2000:   return (Color(hex: 0xC92A62), white, white)                 // magenta
        case 5000:   return (Color(hex: 0xF2C14E), Color(hex: 0x2A1E02), Color(hex: 0x2A1E02)) // gold
        case 10000:  return (Color(hex: 0x8FD12A), Color(hex: 0x132402), Color(hex: 0x132402)) // lime
        case 25000:  return (Color(hex: 0xAEB6C6), ink, ink)                     // silver
        case 50000:  return (Color(hex: 0x12306B), white, white)                 // navy
        case 100000: return (Color(hex: 0x7A1F2B), white, white)                 // maroon
        default:     return (Color(hex: 0x5B4B8A), white, white)                 // fallback
        }
    }

    static func label(_ value: Double) -> String {
        if value < 1 { return String(format: "%.2f", value) }
        if value >= 1000 { return String(format: "%gK", value / 1000) }
        return String(format: "%g", value)
    }

    /// Greedy breakdown of a bet into stackable chip denominations — covers
    /// every value ChipSizing can produce so a big bet renders as a short
    /// stack of large chips instead of a tower of small ones.
    static func breakdown(_ amount: Double) -> [Double] {
        let denoms = [100_000.0, 50_000, 25_000, 10_000, 5_000, 2_000, 1_000, 500, 250, 100, 50, 25, 10, 5, 1, 0.25, 0.10]
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
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, size * 0.18)
        }
        .frame(width: size, height: size)
        .shadow(color: .shadowColor, radius: 1.5, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Money.string(value)) chip")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stack of \(Money.chips(amount))")
    }
}
