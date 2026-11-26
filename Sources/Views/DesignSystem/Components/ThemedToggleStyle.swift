import SwiftUI

// MARK: - Themed toggle
//
// Mint-on / raised-off switch for `Toggle` rows:
//
//     Toggle("Sound effects", isOn: $engine.soundOn).toggleStyle(.themed)
//     Toggle(isOn: $x) { VStack { Text("Title"); Text("Hint") } }.toggleStyle(.themed)
//
// The whole row is one tap target (at least 44pt tall). Label fonts you set on
// the label's own views win; the defaults are `calloutText` / `textPrimary`.
// VoiceOver reads "<label>, On/Off, switch button" and the on/off position also
// differs by thumb placement, not just color.

struct ThemedToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        ThemedToggleBody(configuration: configuration)
    }
}

extension ToggleStyle where Self == ThemedToggleStyle {
    /// Night ink switch: mint when on, raised surface when off.
    static var themed: ThemedToggleStyle { ThemedToggleStyle() }
}

private struct ThemedToggleBody: View {
    let configuration: ToggleStyleConfiguration

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var trackHeight: CGFloat = 30

    private var trackWidth: CGFloat { trackHeight * 1.7 }
    private var thumbInset: CGFloat { 4 }

    var body: some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: Space.sm) {
                configuration.label
                    .font(.calloutText)
                    .foregroundStyle(isEnabled ? Color.textPrimary : Color.disabledText)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                track
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Metrics.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }

    private var track: some View {
        let thumbSize = trackHeight - thumbInset * 2
        return ZStack(alignment: configuration.isOn ? .trailing : .leading) {
            Capsule()
                .fill(trackFill)
            Capsule()
                .strokeBorder(configuration.isOn ? Color.clear : Color.divider, lineWidth: Metrics.hairline)
            Circle()
                .fill(thumbFill)
                .frame(width: thumbSize, height: thumbSize)
                .padding(thumbInset)
        }
        .frame(width: trackWidth, height: trackHeight)
        .animation(Motion.quick.resolved(reduceMotion), value: configuration.isOn)
    }

    private var trackFill: Color {
        guard isEnabled else { return .disabledFill }
        return configuration.isOn ? .accent : .surfaceRaised
    }

    private var thumbFill: Color {
        guard isEnabled else { return .disabledText }
        return configuration.isOn ? .onAccent : .textSecondary
    }
}
