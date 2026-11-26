import SwiftUI

/// Colored chips with a label each, so the chart's colors never have to be
/// decoded from a paragraph. Action letters are printed on the chips too.
struct StrategyLegend: View {
    enum Mode { case actions, accuracy }
    let mode: Mode

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    private struct Entry: Identifiable {
        let id: String
        let chip: String
        let fill: Color
        let label: String
        var mastery: Mastery?
    }

    private var entries: [Entry] {
        switch mode {
        case .actions:
            return [
                Entry(id: "H", chip: "H", fill: ChartColors.fill(for: "H"), label: "Hit"),
                Entry(id: "S", chip: "S", fill: ChartColors.fill(for: "S"), label: "Stand"),
                Entry(id: "D", chip: "D", fill: ChartColors.fill(for: "D"), label: "Double, else hit"),
                Entry(id: "Ds", chip: "Ds", fill: ChartColors.fill(for: "Ds"), label: "Double, else stand"),
                Entry(id: "P", chip: "P", fill: ChartColors.fill(for: "P"), label: "Split"),
            ]
        case .accuracy:
            return [
                Entry(id: "solid", chip: "90", fill: Mastery.solid.fill, label: "Solid, 85% or better", mastery: .solid),
                Entry(id: "working", chip: "70", fill: Mastery.working.fill, label: "Getting there, 60 to 84%", mastery: .working),
                Entry(id: "leak", chip: "40", fill: Mastery.leak.fill, label: "A leak, under 60%", mastery: .leak),
                Entry(id: "none", chip: "\u{00B7}", fill: Mastery.unpracticed.fill, label: "Not practiced yet", mastery: .unpracticed),
            ]
        }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Space.sm, alignment: .leading)],
                  alignment: .leading, spacing: Space.xs) {
            ForEach(entries) { entry in
                HStack(spacing: Space.xs) {
                    chip(entry)
                    Text(entry.label)
                        .font(.detail)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibleLabel(entry))
            }
        }
    }

    private func accessibleLabel(_ entry: Entry) -> String {
        mode == .actions ? "\(entry.chip) means \(entry.label)" : entry.label
    }

    private func chip(_ entry: Entry) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous)
        return Text(entry.chip)
            .font(.fine.weight(.semibold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(entry.mastery == .unpracticed ? Color.textTertiary : ChartColors.text)
            .frame(width: 32, height: 24)
            .background(Color.surfaceSubtle, in: shape)
            .background(entry.fill, in: shape)
            .overlay {
                if differentiate, let mastery = entry.mastery {
                    switch mastery {
                    case .leak: shape.strokeBorder(Color.textPrimary, lineWidth: 2)
                    case .working: shape.strokeBorder(Color.textPrimary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    default: EmptyView()
                    }
                }
            }
    }
}
