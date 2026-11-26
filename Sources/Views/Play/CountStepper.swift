import SwiftUI

/// Fast entry for a running count: −5 / −1 / value / +1 / +5, so reaching
/// +12 takes three taps instead of twelve. VoiceOver users swipe up or down
/// on the value to adjust by one.
struct CountStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = -60...60
    var label = "Your count"

    var body: some View {
        HStack(spacing: Space.xs) {
            stepButton(-5)
            stepButton(-1)
            Text(signed(value))
                .font(.statValue)
                .foregroundStyle(.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: Metrics.buttonHeight)
                .background(.surfaceSubtle, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(signed(value))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: step(1)
                    case .decrement: step(-1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier("countValue")
            stepButton(1)
            stepButton(5)
        }
    }

    private func stepButton(_ amount: Int) -> some View {
        let next = clamped(value + amount)
        return Button {
            step(amount)
        } label: {
            Text(amount > 0 ? "+\(amount)" : "\(amount)")
        }
        .buttonStyle(DecisionButtonStyle())
        .frame(width: 56)
        .disabled(next == value)
        .accessibilityLabel(amount > 0 ? "Add \(amount)" : "Subtract \(-amount)")
        .accessibilityIdentifier("countStep\(amount > 0 ? "Plus" : "Minus")\(abs(amount))")
    }

    private func step(_ amount: Int) {
        let next = clamped(value + amount)
        guard next != value else { return }
        value = next
        Haptics.tap()
    }

    private func clamped(_ n: Int) -> Int { min(range.upperBound, max(range.lowerBound, n)) }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}
