import SwiftUI

/// "This session": a short recap of today's run, shown only once the player
/// has answered something since launching the app.
struct ProgressSessionPanel: View {
    @Environment(Stats.self) private var stats

    var body: some View {
        if stats.sessionDecisions > 0 {
            let accuracy = Double(stats.sessionCorrect) / Double(max(stats.sessionDecisions, 1))
            let tint: Color = accuracy >= 0.9 ? .positive : accuracy >= 0.7 ? .warning : .negative
            Panel(spacing: Space.xs) {
                HStack {
                    Text("This session")
                        .font(.heading)
                        .foregroundStyle(.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: Space.xs)
                    Text("\(stats.sessionCorrect) of \(stats.sessionDecisions) correct")
                        .font(.calloutText.weight(.bold))
                        .foregroundStyle(tint)
                }
                if stats.sessionMistakes.isEmpty {
                    Text("No mistakes yet this session. Textbook.")
                        .font(.detail)
                        .foregroundStyle(.positive)
                } else {
                    let recent = Array(stats.sessionMistakes.suffix(6))
                    VStack(spacing: 0) {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { offset, mistake in
                            HStack(alignment: .firstTextBaseline) {
                                Text(SpotID.displayName(mistake.spotKey))
                                    .font(.detail.weight(.semibold))
                                    .foregroundStyle(.textPrimary)
                                Spacer(minLength: Space.xs)
                                Text("\(mistake.chose) instead of \(mistake.correctPlay)")
                                    .font(.detail)
                                    .foregroundStyle(.textSecondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, Space.xs)
                            .padding(.horizontal, Space.sm)
                            .background(offset % 2 == 0 ? Color.surfaceSubtle : Color.clear)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    if stats.sessionMistakes.count > 6 {
                        Text("Showing the last 6 of \(stats.sessionMistakes.count) mistakes.")
                            .font(.fine)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
    }
}
