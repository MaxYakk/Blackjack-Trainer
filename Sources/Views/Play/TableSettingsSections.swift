import SwiftUI

/// The table settings players can tune, shown in two groups: "Table rules"
/// and "Training help". One view feeds both the Play setup screen and the
/// mid-session Table Options sheet, so the two always list the same things.
///
/// Settings that can't change during play (starting money, minimum bet and
/// hands per round) are not here or are setup-only: pass `hands` to show the
/// hands-per-round row (the setup screen owns that value until the session
/// starts); the sheet leaves it out.
struct TableSettingsSections: View {
    enum Context {
        /// Before a session starts. Training help starts collapsed.
        case setup
        /// During play (Table Options sheet). Everything is shown.
        case table
    }

    @Bindable var engine: PlayEngine
    let context: Context
    /// Hands per round, setup only. `nil` hides the row.
    var hands: Binding<Int>?
    /// Decks and dealer rule are frozen while a round is in progress.
    var rulesLocked = false

    @State private var trainingExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(engine: PlayEngine, context: Context, hands: Binding<Int>? = nil, rulesLocked: Bool = false) {
        self.engine = engine
        self.context = context
        self.hands = hands
        self.rulesLocked = rulesLocked
        _trainingExpanded = State(initialValue: context == .table)
    }

    private var idPrefix: String { context == .setup ? "buyIn" : "tableOptions" }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            tableRulesGroup
            trainingHelpGroup
        }
    }

    // MARK: - Table rules

    private var tableRulesGroup: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            groupHeader("Table rules")
            VStack(alignment: .leading, spacing: Space.sm) {
                if let hands {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Hands per round")
                            .font(.calloutText.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                        SegmentedChoice(Array(PlayEngine.spotRange), selection: hands,
                                        accessibilityLabel: "Hands per round") { "\($0)" }
                    }
                    rowDivider
                }
                // Each deck count is graded with its own chart (double deck or 4–8 decks).
                ThemedMenuPicker("Decks", selection: $engine.numDecks,
                                 options: PlayEngine.allowedDeckCounts) { "\($0)" }
                    .accessibilityIdentifier("\(idPrefix)DeckPicker")
                    .accessibilityValue("\(engine.numDecks)")
                    .disabled(rulesLocked)
                ThemedMenuPicker("Dealer", selection: $engine.dealerHitsSoft17,
                                 options: [false, true]) { $0 ? "Hits soft 17" : "Stands soft 17" }
                    .accessibilityIdentifier("\(idPrefix)DealerPicker")
                    .accessibilityValue(engine.dealerHitsSoft17 ? "Hits soft 17" : "Stands soft 17")
                    .disabled(rulesLocked)
                rowDivider
                toggleRow("Show hand totals", "Off: add up the cards yourself.",
                          $engine.showHandTotals, id: "showHandTotalsToggle")
                toggleRow("Sound effects", nil, $engine.soundOn, id: "soundEffectsToggle")
            }
            .panel()
            if context == .table && rulesLocked {
                Text("Decks and dealer can change between rounds. Finish this hand, then come back.")
                    .font(.detail)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, Space.xs)
                    .accessibilityIdentifier("rulesLockedNote")
            }
        }
    }

    // MARK: - Training help

    private var trainingHelpGroup: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            if context == .setup {
                trainingDisclosureRow
            } else {
                groupHeader("Training help")
            }
            if trainingExpanded {
                VStack(alignment: .leading, spacing: Space.sm) {
                    toggleRow("Show running / true count", nil,
                              $engine.showCount, id: "showCountToggle")
                    rowDivider
                    toggleRow("Betting hints", "Off: only told if a bet is too high or low.",
                              $engine.betHints, id: "betHintsToggle")
                    rowDivider
                    toggleRow("Ask for count checks during play", "Now and then, asks for your running count.",
                              $engine.askCountChecks, id: "countChecksToggle")
                    rowDivider
                    toggleRow("Count-based strategy changes", "Grades the Illustrious 18 plays.",
                              $engine.useDeviations, id: "deviationsToggle")
                }
                .panel()
            }
        }
    }

    /// Setup only: a tappable header that opens the four coaching toggles and
    /// says what is on while they are hidden.
    private var trainingDisclosureRow: some View {
        Button {
            Motion.perform(.standard, reduceMotion: reduceMotion) { trainingExpanded.toggle() }
        } label: {
            HStack(spacing: Space.sm) {
                VStack(alignment: .leading, spacing: Space.xxs / 2) {
                    Text("TRAINING HELP")
                        .font(.overline)
                        .tracking(1.6)
                        .foregroundStyle(.textTertiary)
                    Text(trainingSummary)
                        .font(.calloutText)
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.leading)
                        .accessibilityIdentifier("trainingHelpSummary")
                }
                Spacer(minLength: Space.xs)
                Image(systemName: "chevron.down")
                    .font(.detail.weight(.semibold))
                    .foregroundStyle(.textTertiary)
                    .rotationEffect(.degrees(trainingExpanded ? 180 : 0))
            }
            .frame(minHeight: Metrics.minTapTarget)
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Training help. \(trainingSummary)")
        .accessibilityHint(trainingExpanded ? "Collapses the training help options" : "Shows the training help options")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("trainingHelpDisclosure")
    }

    /// What is switched on, e.g. "Count shown · Bet hints"; "All off" if nothing.
    private var trainingSummary: String {
        let active = [
            engine.showCount ? "Count shown" : nil,
            engine.betHints ? "Bet hints" : nil,
            engine.askCountChecks ? "Count checks" : nil,
            engine.useDeviations ? "Strategy changes" : nil,
        ].compactMap { $0 }
        return active.isEmpty ? "All off" : active.joined(separator: " · ")
    }

    // MARK: - Pieces

    private func groupHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.overline)
            .tracking(1.6)
            .foregroundStyle(.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isHeader)
    }

    private var rowDivider: some View {
        Rectangle().fill(Color.divider).frame(height: 1)
    }

    private func toggleRow(_ title: String, _ subtitle: String?,
                           _ isOn: Binding<Bool>, id: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: Space.xxs / 2) {
                Text(title).font(.bodyText).foregroundStyle(.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.detail).foregroundStyle(.textSecondary)
                }
            }
        }
        .toggleStyle(.themed)
        .accessibilityIdentifier(id)
    }
}
