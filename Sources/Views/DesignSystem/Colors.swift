import SwiftUI

// MARK: - Night ink color roles
//
// Every color in the app comes from this file. Screens use the role names
// (`.foregroundStyle(.textSecondary)`, `.background(.surface, in: ...)`),
// never raw `Color(red:...)`, `.white.opacity(...)` or `.black.opacity(...)`.
//
// The roles are static members on `ShapeStyle where Self == Color`, so they
// work anywhere SwiftUI takes a style or a `Color`:
//     Text("Hi").foregroundStyle(.textPrimary)
//     RoundedRectangle(cornerRadius: Radius.medium).fill(.surface)
//     let tint: Color = .accent
//
// The app is dark-only (`.preferredColorScheme(.dark)` in the app entry), so
// each role is a single fixed color. Contrast ratios below are WCAG ratios.

extension Color {
    /// Builds a color from a 0xRRGGBB literal. For DesignSystem files only;
    /// screens should use a named role instead.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension ShapeStyle where Self == Color {
    // MARK: Backgrounds and surfaces

    /// Screen background behind everything. #0B0F1A
    static var bg: Color { Color(hex: 0x0B0F1A) }
    /// Cards, panels, the play table. #151B2B
    static var surface: Color { Color(hex: 0x151B2B) }
    /// Something sitting on a surface: secondary buttons, progress tracks,
    /// selected segments. #1C2438
    static var surfaceRaised: Color { Color(hex: 0x1C2438) }
    /// Quiet tile or zebra row inside a surface. #131A29
    static var surfaceSubtle: Color { Color(hex: 0x131A29) }
    /// Hairlines and dividers. #252E44
    static var divider: Color { Color(hex: 0x252E44) }
    /// Dimming layer behind a modal card.
    static var scrim: Color { Color.black.opacity(0.6) }
    /// Soft drop shadow under cards and chips (depth, not glow).
    static var shadowColor: Color { Color.black.opacity(0.35) }

    // MARK: Text

    /// Main text. 17:1 on bg. #EEF2FA
    static var textPrimary: Color { Color(hex: 0xEEF2FA) }
    /// Supporting text and labels. 6.2:1 on bg, 5.0:1 on surfaceRaised. #8A93A8
    static var textSecondary: Color { Color(hex: 0x8A93A8) }
    /// Hints and fine print. 5.2:1 on bg, 4.6:1 on surface. #7C859A
    static var textTertiary: Color { Color(hex: 0x7C859A) }

    // MARK: Accent and feedback

    /// Mint: primary buttons, selection, key numbers. #3DDC97
    static var accent: Color { Color(hex: 0x3DDC97) }
    /// Text and icons placed on `accent`. 9.4:1. #06231A
    static var onAccent: Color { Color(hex: 0x06231A) }
    /// Correct answers, wins, gains. Same mint as `accent`. #3DDC97
    static var positive: Color { Color(hex: 0x3DDC97) }
    /// Tinted background behind positive feedback. #0F2A22
    static var positiveBg: Color { Color(hex: 0x0F2A22) }
    /// Mistakes, losses, busts. #E5484D (4.4:1 on surface: use for bold or
    /// large text, icons and fills; it is just under 4.5:1 for small body text.)
    static var negative: Color { Color(hex: 0xE5484D) }
    /// Tinted background behind negative feedback. #2E1518
    static var negativeBg: Color { Color(hex: 0x2E1518) }
    /// Coral: streaks and warm highlights. 7.4:1 on surface. #FF8A5B
    static var warm: Color { Color(hex: 0xFF8A5B) }
    /// Tinted background behind warm highlights. #2E1C14
    static var warmBg: Color { Color(hex: 0x2E1C14) }
    /// Amber: "needs work" (between right and wrong). 9.7:1 on surface. #F5B94A
    static var warning: Color { Color(hex: 0xF5B94A) }

    // MARK: Disabled

    /// Fill of a disabled button. #182033
    static var disabledFill: Color { Color(hex: 0x182033) }
    /// Label of a disabled control (deliberately low contrast). #4F586C
    static var disabledText: Color { Color(hex: 0x4F586C) }

    // MARK: Playing cards

    /// Card face. #FFFFFF
    static var cardFace: Color { Color(hex: 0xFFFFFF) }
    /// Spades and clubs. #111827
    static var cardSuitBlack: Color { Color(hex: 0x111827) }
    /// Hearts and diamonds. #E5484D
    static var cardSuitRed: Color { Color(hex: 0xE5484D) }
    /// Face-down card. #2A3550, edged in `accent`.
    static var cardBack: Color { Color(hex: 0x2A3550) }
    /// Empty card slot outline/fill.
    static var cardSlot: Color { Color(hex: 0x1C2438) }

    // MARK: Achievement tiers (flat metals, read with `onTier` text)

    /// #CD8B5A — `onTier` text 6.6:1
    static var tierBronze: Color { Color(hex: 0xCD8B5A) }
    /// #C3CBD8 — `onTier` text 11.3:1
    static var tierSilver: Color { Color(hex: 0xC3CBD8) }
    /// #F2C14E — `onTier` text 11.0:1
    static var tierGold: Color { Color(hex: 0xF2C14E) }
    /// Text and icons on any tier color. #1A1206
    static var onTier: Color { Color(hex: 0x1A1206) }
}

// MARK: - Strategy chart

/// Cell colors for the basic-strategy chart. Hues follow the Okabe–Ito
/// colorblind-safe set (orange / blue / green / teal / amber / purple) and every
/// cell also prints its letter, so no meaning rests on red vs green alone.
/// White (`textPrimary`) text is at least 4.7:1 on each.
enum ChartColors {
    /// H. #A84C2A (coral, deep)
    static let hit = Color(hex: 0xA84C2A)
    /// S. #2F5FB3 (blue)
    static let stand = Color(hex: 0x2F5FB3)
    /// D. #1F7A5A (green)
    static let double = Color(hex: 0x1F7A5A)
    /// Ds (double, otherwise stand). #2B6E86 (teal)
    static let doubleOrStand = Color(hex: 0x2B6E86)
    /// P. #806210 (amber, deep)
    static let split = Color(hex: 0x806210)
    /// R (surrender), for charts that offer it. #6E4FB8 (purple)
    static let surrender = Color(hex: 0x6E4FB8)
    /// Unknown code.
    static let unknown = Color(hex: 0x2A3346)
    /// Text on every chart cell.
    static let text = Color(hex: 0xEEF2FA)

    /// Fill for a chart code ("H", "S", "D", "Ds", "P", "R").
    static func fill(for code: String) -> Color {
        switch code {
        case "H": return hit
        case "S": return stand
        case "D": return double
        case "Ds": return doubleOrStand
        case "P": return split
        case "R", "Rh", "Rs", "Rp": return surrender
        default: return unknown
        }
    }
}
