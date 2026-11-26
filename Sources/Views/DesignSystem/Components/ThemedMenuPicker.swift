import SwiftUI

// MARK: - ThemedMenuPicker
//
// Themed replacement for `Picker(...).pickerStyle(.menu)` rows. A full-width row
// (title on the left, current value + chevron on the right) that opens a Night
// ink bottom sheet listing the choices; tapping one selects it and closes.
//
//     ThemedMenuPicker("Decks", selection: $engine.numDecks,
//                      options: PlayEngine.allowedDeckCounts) { "\($0)" }
//         .accessibilityIdentifier("buyInDeckPicker")
//     ThemedMenuPicker("Dealer", selection: $engine.dealerHitsSoft17,
//                      options: [false, true]) { $0 ? "Hits soft 17" : "Stands soft 17" }
//
// The row has no background of its own, so put it in a `.panel()` or `Panel` like
// the rows it replaces. The sheet is its own presentation, so it works inside
// other sheets and covers the tab bar. Rows are at least 44pt tall.

struct ThemedMenuPicker<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let message: String?
    let label: (Value) -> String

    @State private var isOpen = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ title: String,
         selection: Binding<Value>,
         options: [Value],
         message: String? = nil,
         label: @escaping (Value) -> String) {
        self.title = title
        self._selection = selection
        self.options = options
        self.message = message
        self.label = label
    }

    var body: some View {
        Button {
            isOpen = true
        } label: {
            rowContent
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(PickerRowButtonStyle())
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
        .accessibilityHint("Opens a list of choices")
        .sheet(isPresented: $isOpen) {
            ThemedChoiceSheet(title: title, message: message, selection: $selection,
                              options: options, label: label)
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Space.xxs) {
                titleText
                valueView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: Space.xs) {
                titleText
                Spacer(minLength: Space.xs)
                valueView
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.calloutText)
            .foregroundStyle(.textPrimary)
            .multilineTextAlignment(.leading)
    }

    private var valueView: some View {
        HStack(spacing: Space.xxs) {
            Text(label(selection))
                .font(.buttonLabelSmall)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.up.chevron.down")
                .font(.fine.weight(.semibold))
                .foregroundStyle(.textSecondary)
        }
    }
}

private struct PickerRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Choice sheet

private struct ThemedChoiceSheet<Value: Hashable>: View {
    let title: String
    let message: String?
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String

    @Environment(\.dismiss) private var dismiss
    @State private var contentHeight: CGFloat = 360

    var body: some View {
        ScrollView {
            VStack(spacing: Space.md) {
                Capsule()
                    .fill(.divider)
                    .frame(width: 36, height: 4)
                    .accessibilityHidden(true)
                VStack(spacing: Space.xxs) {
                    Text(title)
                        .font(.heading)
                        .foregroundStyle(.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let message {
                        Text(message)
                            .font(.detail)
                            .foregroundStyle(.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                VStack(spacing: Space.xs) {
                    ForEach(options, id: \.self) { option in
                        choiceRow(option)
                    }
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.lg)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(SheetHeightKey.self) { contentHeight = $0 }
        .background(Color.surface)
        .presentationDetents([.height(contentHeight), .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.surface)
        .presentationCornerRadius(Radius.large)
    }

    private func choiceRow(_ option: Value) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
            dismiss()
        } label: {
            HStack(spacing: Space.sm) {
                Text(label(option))
                    .font(.calloutText)
                    .foregroundStyle(isSelected ? Color.accent : Color.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.heading)
                    .foregroundStyle(isSelected ? Color.accent : Color.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.md)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
            .background(isSelected ? Color.positiveBg : Color.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(option))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
