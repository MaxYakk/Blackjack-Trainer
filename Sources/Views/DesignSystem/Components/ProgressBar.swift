import SwiftUI

// MARK: - Progress bar
//
// A flat capsule bar for goals and accuracy.
//
//     ProgressBar(value: Double(today) / Double(goal), label: "Daily goal")
//     ProgressBar(value: 0.9, tint: .positive)
//
// `value` is clamped to 0...1. VoiceOver reads the label and a percentage.

struct ProgressBar: View {
    let value: Double
    var tint: Color = .accent
    var track: Color = .surfaceRaised
    var height: CGFloat = Metrics.progressHeight
    /// Spoken name; leave nil when a visible label right next to the bar
    /// already names it and the bar is combined into that element.
    var label: String?

    private var clamped: Double { min(max(value.isFinite ? value : 0, 0), 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * clamped)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}
