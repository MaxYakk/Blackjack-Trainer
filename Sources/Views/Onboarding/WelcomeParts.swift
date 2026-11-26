import SwiftUI

/// Decorative hero for the welcome screen: two cards, two chips and a "21"
/// pill inside two soft rings. Hidden from VoiceOver. Everything is sized to
/// fit a 375pt-wide screen (the narrowest iPhone iOS 17 supports).
struct WelcomeTableau: View {
    var body: some View {
        ZStack {
            Capsule()
                .stroke(Color.accent.opacity(0.22), lineWidth: Metrics.hairline)
                .frame(width: 300, height: 160)

            Capsule()
                .stroke(Color.divider, lineWidth: Metrics.hairline)
                .frame(width: 264, height: 128)

            CardView(card: Card(rank: .ace, suit: .spades), size: 1.55)
                .rotationEffect(.degrees(-9))
                .offset(x: -36, y: 6)

            CardView(card: Card(rank: .king, suit: .hearts), size: 1.55)
                .rotationEffect(.degrees(8))
                .offset(x: 38, y: 3)

            ChipView(value: 25, size: 50)
                .rotationEffect(.degrees(-12))
                .offset(x: -104, y: 62)

            ChipView(value: 100, size: 42)
                .rotationEffect(.degrees(10))
                .offset(x: 108, y: 57)

            Text("21")
                .font(.numberInline)
                .foregroundStyle(.onAccent)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, Space.xxs)
                .background(.accent, in: Capsule())
                .shadow(color: .shadowColor, radius: 6, y: 3)
                .offset(y: 70)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

/// Three one-line promises under the headline.
struct TrainingModes: View {
    private let modes = [
        ("suit.spade.fill", "Real hands"),
        ("bolt.fill", "Fast drills"),
        ("chart.line.uptrend.xyaxis", "Clear progress")
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                VStack(spacing: Space.xs) {
                    Image(systemName: mode.0)
                        .font(.heading)
                        .foregroundStyle(.accent)
                        .accessibilityHidden(true)

                    Text(mode.1)
                        .font(.captionText.weight(.semibold))
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)

                if index < modes.count - 1 {
                    Rectangle()
                        .fill(Color.divider)
                        .frame(width: Metrics.hairline, height: 36)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}
