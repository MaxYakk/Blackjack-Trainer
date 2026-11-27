import SwiftUI

/// One compact row of colored chips with a short label each, so the chart's
/// colors never have to be decoded from a paragraph. Action letters are
/// printed on the chips too.
struct StrategyLegend: View {
    enum Mode { case actions, accuracy }
    let mode: Mode

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    private struct Entry: Identifiable {
        let id: String
        let chip: String
        let fill: Color
        let textColor: Color
        let label: String
        let spoken: String
        var mastery: Mastery?
    }

    private var entries: [Entry] {
        switch mode {
        case .actions:
            return [
                action("H", "Hit", spoken: "Hit"),
                action("S", "Stand", spoken: "Stand"),
                action("D", "Double", spoken: "Double, otherwise hit"),
                action("Ds", "Double or stand", spoken: "Double, otherwise stand"),
                action("P", "Split", spoken: "Split"),
            ]
        case .accuracy:
            return [
                mastery(.solid, chip: "90", label: "85%+"),
                mastery(.working, chip: "70", label: "60 to 84%"),
                mastery(.leak, chip: "40", label: "Under 60%"),
                mastery(.early, chip: "100", label: "1 or 2 tries"),
                mastery(.unpracticed, chip: "\u{00B7}", label: "None yet"),
            ]
        }
    }

    private func action(_ code: String, _ label: String, spoken: String) -> Entry {
        Entry(id: code, chip: code, fill: ChartColors.fill(for: code), textColor: ChartColors.text,
              label: label, spoken: "\(code) means \(spoken)")
    }

    private func mastery(_ level: Mastery, chip: String, label: String) -> Entry {
        Entry(id: label, chip: chip, fill: level.fill, textColor: level.textColor,
              label: label, spoken: level.name, mastery: level)
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Space.xs, alignment: .leading)],
                  alignment: .leading, spacing: Space.xxs) {
            ForEach(entries) { entry in
                HStack(spacing: Space.xxs) {
                    chip(entry)
                    Text(entry.label)
                        .font(.fine)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.spoken)
            }
        }
    }

    private func chip(_ entry: Entry) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.small / 2, style: .continuous)
        return Text(entry.chip)
            .font(.fine.weight(.bold))
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .foregroundStyle(entry.textColor)
            .frame(width: 28, height: 20)
            .background(entry.fill, in: shape)
            .overlay {
                if differentiate, let mastery = entry.mastery {
                    switch mastery {
                    case .leak: shape.strokeBorder(ChartColors.text, lineWidth: 2)
                    case .working: shape.strokeBorder(ChartColors.text, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    default: EmptyView()
                    }
                }
            }
    }
}
