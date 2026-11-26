import SwiftUI

// MARK: - Primary and secondary buttons
//
// Two ways to use them:
//     PrimaryButton("Deal", systemImage: "suit.spade.fill") { engine.deal() }
//     SecondaryButton("Clear") { engine.clearBet() }
// or, for a custom label, the button styles directly:
//     Button { ... } label: { Label("Replay", systemImage: "arrow.clockwise") }
//         .buttonStyle(.primary)
//
// Disabled state comes from `.disabled(...)`; the styles read `isEnabled`.
// Both are full width by default and at least 44pt tall (52pt regular).

/// Mint, filled: the one main action on a screen (Deal, Submit, Done).
struct PrimaryButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyledButtonBody(configuration: configuration, compact: compact,
                         fill: .accent, text: .onAccent)
    }
}

/// Raised surface: supporting actions next to a primary (Clear, Repeat, Skip).
struct SecondaryButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        StyledButtonBody(configuration: configuration, compact: compact,
                         fill: .surfaceRaised, text: .textPrimary)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Mint filled button, 52pt tall.
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    /// Mint filled button, 44pt tall.
    static var primaryCompact: PrimaryButtonStyle { PrimaryButtonStyle(compact: true) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    /// Raised-surface button, 52pt tall.
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    /// Raised-surface button, 44pt tall.
    static var secondaryCompact: SecondaryButtonStyle { SecondaryButtonStyle(compact: true) }
}

/// Shared body for the filled button styles.
private struct StyledButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let compact: Bool
    let fill: Color
    let text: Color

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        configuration.label
            .font(compact ? .buttonLabelSmall : .buttonLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, Space.sm)
            .frame(maxWidth: .infinity,
                   minHeight: compact ? Metrics.compactButtonHeight : Metrics.buttonHeight)
            .foregroundStyle(isEnabled ? text : Color.disabledText)
            .background(isEnabled ? fill : Color.disabledFill, in: shape)
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(Motion.quick.resolved(reduceMotion), value: configuration.isPressed)
    }
}

/// A full-width mint button with a text (and optional SF Symbol) label.
struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    var compact = false
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, compact: Bool = false,
         action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.compact = compact
        self.action = action
    }

    var body: some View {
        Button(action: action) { ButtonLabel(title: title, systemImage: systemImage) }
            .buttonStyle(PrimaryButtonStyle(compact: compact))
    }
}

/// A full-width raised-surface button with a text (and optional SF Symbol) label.
struct SecondaryButton: View {
    let title: String
    var systemImage: String?
    var compact = false
    let action: () -> Void

    init(_ title: String, systemImage: String? = nil, compact: Bool = false,
         action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.compact = compact
        self.action = action
    }

    var body: some View {
        Button(action: action) { ButtonLabel(title: title, systemImage: systemImage) }
            .buttonStyle(SecondaryButtonStyle(compact: compact))
    }
}

private struct ButtonLabel: View {
    let title: String
    let systemImage: String?

    var body: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}
