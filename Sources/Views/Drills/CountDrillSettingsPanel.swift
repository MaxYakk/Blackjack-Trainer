import SwiftUI

/// The drill's options in a collapsed panel. Closed by default (a one line
/// summary shows what is set), and locked while a drill is running so a setting
/// can't change underneath the player mid count.
struct CountDrillSettingsPanel: View {
    @Bindable var engine: CountDrillEngine
    @Binding var showTips: Bool
    @State private var expanded = false

    static let speeds: [(label: String, seconds: Double)] = [
        ("Extra Slow 2s", 2.0), ("Slow 1.5s", 1.5), ("Medium 1s", 1.0),
        ("Fast 0.6s", 0.6), ("Very Fast 0.35s", 0.35),
    ]
    static let cardCounts = [10, 20, 30, 52, 104]

    private var speedName: String {
        Self.speeds.first { $0.seconds == engine.speedSeconds }?.label ?? "\(engine.speedSeconds)s"
    }

    private var summary: String {
        "\(engine.numDecks) decks, \(engine.cardsPerDrill) cards, \(speedName)"
    }

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: Space.sm) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Decks in shoe").font(.calloutText).foregroundStyle(.textPrimary)
                    SegmentedChoice(CountDrillEngine.allowedDeckCounts, selection: $engine.numDecks,
                                    accessibilityLabel: "Decks in shoe") { "\($0)" }
                }
                menuRow("Cards", selection: $engine.cardsPerDrill,
                        options: Self.cardCounts.map { ($0, "\($0)") })
                menuRow("Speed", selection: $engine.speedSeconds,
                        options: Self.speeds.map { ($0.seconds, $0.label) })
                Toggle(isOn: $engine.showHint) {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text("Training wheels").font(.calloutText).foregroundStyle(.textPrimary)
                        Text("Shows the live running count while cards deal. Turn off to test yourself.")
                            .font(.detail).foregroundStyle(.textSecondary)
                    }
                }
                Toggle("Show Hi Lo reference and tips", isOn: $showTips)
                    .font(.calloutText)
                    .foregroundStyle(.textPrimary)
            }
            .toggleStyle(.themed)
            .disabled(engine.isActive)
            .padding(.top, Space.sm)
        } label: {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("Drill settings").font(.heading).foregroundStyle(.textPrimary)
                Text(engine.isActive ? "Locked while a drill is running" : summary)
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
            }
        }
        .tint(.textSecondary)
        .panel()
        .onChange(of: engine.isActive) { _, active in
            if active { expanded = false }
        }
    }

    private func menuRow<Value: Hashable>(_ title: String, selection: Binding<Value>,
                                          options: [(Value, String)]) -> some View {
        ThemedMenuPicker(title, selection: selection, options: options.map(\.0)) { value in
            options.first { $0.0 == value }?.1 ?? "\(value)"
        }
    }
}
