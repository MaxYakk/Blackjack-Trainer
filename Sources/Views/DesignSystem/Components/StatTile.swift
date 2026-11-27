import SwiftUI

// MARK: - Stat tile
//
// A big number over a small label ("82%" / "Accuracy"), used in grids on
// Progress and session summaries.
//
//     StatTile(label: "Accuracy", value: "82%", tint: .positive)
//
// VoiceOver reads it as one element: "Accuracy, 82%".

struct StatTile: View {
    let label: String
    let value: String
    var tint: Color = .accent

    var body: some View {
        VStack(spacing: Space.xxs) {
            Text(value)
                .font(.statValue)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.fine)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.sm)
        .padding(.horizontal, Space.xxs)
        .background(.surfaceSubtle, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}
