import SwiftUI

// MARK: - Spacing, radius and size scales
//
// Use these instead of literal numbers for padding, stack spacing and corner
// radii, so every screen keeps the same rhythm:
//     VStack(spacing: Space.sm) { ... }.padding(Space.md)
//     .background(.surface, in: RoundedRectangle(cornerRadius: Radius.large))

/// Spacing steps on a 4-point grid.
enum Space {
    /// 4 — icon-to-label gaps, tight stacks.
    static let xxs: CGFloat = 4
    /// 8 — between related items.
    static let xs: CGFloat = 8
    /// 12 — between controls in a group, grid gutters.
    static let sm: CGFloat = 12
    /// 16 — panel padding, screen side margins.
    static let md: CGFloat = 16
    /// 24 — between sections.
    static let lg: CGFloat = 24
    /// 32 — around hero content.
    static let xl: CGFloat = 32
}

/// Corner radii. For fully rounded ends use `Capsule()` ("pill").
enum Radius {
    /// 8 — small chips, chart cells, compact tags.
    static let small: CGFloat = 8
    /// 12 — buttons, tiles, inner panels.
    static let medium: CGFloat = 12
    /// 16 — top-level panels and cards, sheets.
    static let large: CGFloat = 16
}

/// Fixed control sizes.
enum Metrics {
    /// Apple's minimum comfortable tap target.
    static let minTapTarget: CGFloat = 44
    /// Height of primary/secondary/decision buttons.
    static let buttonHeight: CGFloat = 52
    /// Height of the compact button variant.
    static let compactButtonHeight: CGFloat = 44
    /// Fixed height of `FeedbackPill`, so the layout never jumps when it
    /// changes between empty, correct and incorrect.
    static let feedbackHeight: CGFloat = 44
    /// Thickness of `ProgressBar`.
    static let progressHeight: CGFloat = 8
    /// Hairline border width.
    static let hairline: CGFloat = 1
}
