import SwiftUI

/// The mid-session "Table Options" sheet. Coaching toggles are editable at
/// any time; table rules (decks, dealer soft 17) only between rounds, so a
/// rule never changes under a hand in progress. Session numbers (starting
/// chips, table minimum) are read-only because bets are graded in them.
struct SettingsSheet: View {
    @Bindable var engine: PlayEngine
    @Environment(\.dismiss) private var dismiss

    /// Rules can change only while bets are being placed.
    private var rulesEditable: Bool { engine.phase == .betting }

    var body: some View {
        NavigationStack {
            Form {
                tableRulesSection
                trainingHelpSection
                sessionSection
            }
            .tint(.accent)
            .scrollContentBackground(.hidden)
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("Table Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var tableRulesSection: some View {
        Section {
            // Each deck count is graded with its own chart (double deck or 4–8 decks).
            ThemedMenuPicker("Decks", selection: $engine.numDecks,
                             options: PlayEngine.allowedDeckCounts) { "\($0)" }
                .accessibilityIdentifier("tableOptionsDeckPicker")
                .accessibilityValue("\(engine.numDecks)")
                .disabled(!rulesEditable)
            ThemedMenuPicker("Dealer", selection: $engine.dealerHitsSoft17,
                             options: [false, true]) { $0 ? "Hits soft 17" : "Stands soft 17" }
                .accessibilityIdentifier("tableOptionsDealerPicker")
                .accessibilityValue(engine.dealerHitsSoft17 ? "Hits soft 17" : "Stands soft 17")
                .disabled(!rulesEditable)
            toggleRow("Show hand totals", "Off: add up the cards yourself.", $engine.showHandTotals)
                .accessibilityIdentifier("showHandTotalsToggle")
            toggleRow("Sound effects", nil, $engine.soundOn)
        } header: {
            Text("Table rules")
        } footer: {
            if !rulesEditable {
                Text("Decks and dealer can change between rounds. Finish this hand, then come back.")
                    .accessibilityIdentifier("rulesLockedNote")
            }
        }
        .listRowBackground(Color.surface)
    }

    private var trainingHelpSection: some View {
        Section {
            toggleRow("Show running / true count", nil, $engine.showCount)
            toggleRow("Betting hints", "Off: only told if a bet is too high or low.", $engine.betHints)
            toggleRow("Ask for count checks during play", "Now and then, asks for your running count.",
                      $engine.askCountChecks)
            toggleRow("Count-based strategy changes", "Grades the Illustrious 18 plays.", $engine.useDeviations)
                .accessibilityIdentifier("deviationsToggle")
        } header: {
            Text("Training help")
        }
        .listRowBackground(Color.surface)
    }

    private func toggleRow(_ title: String, _ subtitle: String?, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: Space.xxs / 2) {
                Text(title).font(.bodyText).foregroundStyle(.textPrimary)
                if let subtitle {
                    Text(subtitle).font(.detail).foregroundStyle(.textSecondary)
                }
            }
        }
        .toggleStyle(.themed)
    }

    private var sessionSection: some View {
        Section {
            readOnlyRow("Starting chips", Money.chips(engine.sessionBuyIn))
            readOnlyRow("Chips now", Money.chips(engine.bankroll))
            // Read-only mid-session: the minimum is the unit every bet is
            // graded in, and raising it could instantly leave the player out
            // of chips. It's chosen at session start (SessionSetupView).
            readOnlyRow("Table minimum", Money.chips(engine.tableMinimum))
        } header: {
            Text("Session")
        } footer: {
            Text("Bet-sizing practice: keep bets at the table minimum when the true count is low, and raise them by about one unit per point once it reaches +2. To change starting chips or the minimum, use End session at the table and start a new session. \(PracticeNotice.line)")
        }
        .listRowBackground(Color.surface)
    }

    private func readOnlyRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
