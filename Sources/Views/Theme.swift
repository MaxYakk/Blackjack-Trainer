import SwiftUI

/// Legacy color names, kept compiling as thin aliases onto the Night ink
/// roles in `DesignSystem/Colors.swift` so older screens pick up the new
/// palette without layout changes.
///
/// Don't use these in new code: use the role names directly
/// (`.surface`, `.accent`, `.positive`, ...). Screen sessions should replace
/// `Theme.*` as they redesign each screen; delete this file once nothing uses it.
enum Theme {
    /// Was the light felt green (raised areas, decision buttons). Now `surface`.
    static let felt: Color = .surface
    /// Was the dark felt green used as every screen's background. Now `bg`.
    static let feltDark: Color = .bg
    /// Was gold. Now the mint `accent`.
    static let accent: Color = .accent
    /// Was the green result color. Now `positive`.
    static let good: Color = .positive
    /// Was the mint feedback text color. Now `positive`.
    static let mint: Color = .positive
    /// Was the red result color. Now `negative`.
    static let bad: Color = .negative
    static let cardFace: Color = .cardFace
    static let cardRed: Color = .cardSuitRed
    static let cardBlack: Color = .cardSuitBlack
}
