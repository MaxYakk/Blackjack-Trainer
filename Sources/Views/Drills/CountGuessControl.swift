import SwiftUI

// MARK: - Running count guess control
//
// The big number plus quick steps: −5 and −1 on the left, +1 and +5 on the
// right, so a count of +14 takes a few taps instead of fourteen. The number
// also works as a VoiceOver "adjustable" (swipe up/down for ±1).

struct CountGuessControl: View {
    @Binding var guess: Int
    let range: ClosedRange<Int>
    var enabled = true

    var body: some View {
        HStack(spacing: Space.xs) {
            stepButton(-5)
            stepButton(-1)
            Text(signed(guess))
                .font(.numberHero)
                .foregroundStyle(.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(minWidth: 72)
                .layoutPriority(1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Your running count guess")
                .accessibilityValue(signed(guess))
                .accessibilityAdjustableAction { direction in
                    guard enabled else { return }
                    switch direction {
                    case .increment: nudge(1)
                    case .decrement: nudge(-1)
                    @unknown default: break
                    }
                }
            stepButton(1)
            stepButton(5)
        }
    }

    private func stepButton(_ step: Int) -> some View {
        Button { nudge(step) } label: {
            Text(step > 0 ? "+\(step)" : "\u{2212}\(abs(step))")
        }
        .buttonStyle(.secondaryCompact)
        .disabled(!enabled || !canStep(step))
        .accessibilityLabel(step > 0 ? "Add \(step)" : "Subtract \(abs(step))")
    }

    private func canStep(_ step: Int) -> Bool {
        step > 0 ? guess < range.upperBound : guess > range.lowerBound
    }

    private func nudge(_ step: Int) {
        guess = min(max(guess + step, range.lowerBound), range.upperBound)
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}
