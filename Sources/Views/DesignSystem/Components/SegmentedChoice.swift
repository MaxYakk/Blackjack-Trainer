import SwiftUI

// MARK: - SegmentedChoice
//
// Themed replacement for `Picker(...).pickerStyle(.segmented)`.
//
//     SegmentedChoice(PlayEngine.spotRange, selection: $hands,
//                     accessibilityLabel: "Hands per round") { "\($0)" }
//     SegmentedChoice(QuizDifficulty.allCases, selection: $engine.difficulty,
//                     accessibilityLabel: "Difficulty")        // String raw values
//
// The selected segment is a mint `accent` pill with `onAccent` text that slides
// to the new choice (it just jumps with Reduce Motion). Every segment is its
// own VoiceOver button with the `.isSelected` trait, and at least 44pt tall.
// At accessibility text sizes the segments stack vertically so labels never shrink.

struct SegmentedChoice<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let accessibilityLabel: String?
    let label: (Value) -> String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isEnabled) private var isEnabled

    init(_ options: [Value],
         selection: Binding<Value>,
         accessibilityLabel: String? = nil,
         label: @escaping (Value) -> String) {
        self.options = options
        self._selection = selection
        self.accessibilityLabel = accessibilityLabel
        self.label = label
    }

    private var selectedIndex: Int? { options.firstIndex(of: selection) }
    private var stacksVertically: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        Group {
            if stacksVertically {
                VStack(spacing: Space.xxs) {
                    ForEach(options, id: \.self) { segment($0, ownFill: true) }
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(options, id: \.self) { segment($0, ownFill: false) }
                }
                .background(alignment: .leading) { slidingIndicator }
            }
        }
        .padding(Space.xxs)
        .background(.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.medium + Space.xxs, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel ?? "")
    }

    /// The mint pill behind the selected segment. Segments are equal width, so
    /// its position is just `index × width`.
    private var slidingIndicator: some View {
        GeometryReader { proxy in
            if let index = selectedIndex, !options.isEmpty {
                let width = proxy.size.width / CGFloat(options.count)
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .fill(isEnabled ? Color.accent : Color.disabledFill)
                    .frame(width: width)
                    .offset(x: width * CGFloat(index))
                    .animation(reduceMotion ? nil : Motion.standard.animation, value: index)
            }
        }
        .accessibilityHidden(true)
    }

    private func segment(_ value: Value, ownFill: Bool) -> some View {
        let isSelected = value == selection
        let text = label(value)
        return Button {
            selection = value
        } label: {
            Text(text)
                .font(.buttonLabelSmall)
                .lineLimit(stacksVertically ? 3 : 1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xs)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
                .foregroundStyle(foreground(isSelected: isSelected))
                .background {
                    if ownFill && isSelected {
                        RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                            .fill(isEnabled ? Color.accent : Color.disabledFill)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func foreground(isSelected: Bool) -> Color {
        guard isEnabled else { return .disabledText }
        return isSelected ? .onAccent : .textSecondary
    }
}

extension SegmentedChoice where Value: RawRepresentable, Value.RawValue == String {
    /// For enums with String raw values: the raw value is the segment's title.
    init(_ options: [Value], selection: Binding<Value>, accessibilityLabel: String? = nil) {
        self.init(options, selection: selection, accessibilityLabel: accessibilityLabel) { $0.rawValue }
    }
}
