import SwiftUI

// MARK: - Decision pad
//
// The Hit / Stand / Double / Split grid shared by Play, Quiz and the Daily
// Challenge (one component instead of three copies).
//
//     DecisionPad(canSplit: engine.canSplit) { engine.answer($0) }
//
// Each button is a raised surface tile at least 52pt tall. A move that isn't
// allowed right now shows the disabled colors and can't be tapped (VoiceOver
// reads it as "dimmed"). Pass `onSurrender` to add a full-width Surrender row
// for rule sets that offer it (the current engine doesn't).

struct DecisionPad: View {
    var canHit = true
    var canStand = true
    var canDouble = true
    var canSplit = true
    var canSurrender = true
    var onSurrender: (() -> Void)?
    let onSelect: (Action) -> Void

    var body: some View {
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                DecisionButton(title: Action.hit.name, enabled: canHit) { onSelect(.hit) }
                DecisionButton(title: Action.stand.name, enabled: canStand) { onSelect(.stand) }
            }
            HStack(spacing: Space.sm) {
                DecisionButton(title: Action.double.name, enabled: canDouble) { onSelect(.double) }
                DecisionButton(title: Action.split.name, enabled: canSplit) { onSelect(.split) }
            }
            if let onSurrender {
                DecisionButton(title: "Surrender", enabled: canSurrender, action: onSurrender)
            }
        }
    }
}

/// One tile of the decision pad. Usable alone for other table choices
/// (e.g. the insurance Yes/No pair) so they match the pad.
struct DecisionButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) { Text(title) }
            .buttonStyle(DecisionButtonStyle())
            .disabled(!enabled)
    }
}

/// Raised tile with a hairline edge, so the pad reads as a set of keys.
struct DecisionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DecisionButtonBody(configuration: configuration)
    }
}

private struct DecisionButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
        configuration.label
            .font(.buttonLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, Space.xs)
            .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
            .foregroundStyle(isEnabled ? Color.textPrimary : Color.disabledText)
            .background(isEnabled ? Color.surfaceRaised : Color.disabledFill, in: shape)
            .overlay(shape.strokeBorder(isEnabled ? Color.divider : Color.clear,
                                        lineWidth: Metrics.hairline))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(Motion.quick.resolved(reduceMotion), value: configuration.isPressed)
    }
}
