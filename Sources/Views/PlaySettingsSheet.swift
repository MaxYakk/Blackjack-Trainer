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
                rulesSection
                Section {
                    Toggle("Show hand totals", isOn: $engine.showHandTotals)
                        .accessibilityIdentifier("showHandTotalsToggle")
                } header: {
                    Text("Realism")
                } footer: {
                    Text("Turn off to hide the totals above your hands and the dealer's, so you add the cards up yourself like at a real table.")
                }
                .listRowBackground(Color.surface)
                Section {
                    Toggle("Show running / true count", isOn: $engine.showCount)
                    Toggle("Betting hints", isOn: $engine.betHints)
                    Toggle("Ask for count checks during play", isOn: $engine.askCountChecks)
                } header: {
                    Text("Counting")
                } footer: {
                    Text("With betting hints off, the app only tells you if your bet was too high or too low. It does not reveal the count. Count checks occasionally ask for your running count before you act.")
                }
                .listRowBackground(Color.surface)
                Section {
                    Toggle("Count-based strategy changes", isOn: $engine.useDeviations)
                        .accessibilityIdentifier("deviationsToggle")
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Grades your plays against the Illustrious 18, the best known count-based changes to basic strategy. For example, stand on 16 against a 10 when the true count is 0 or higher. Also grades insurance: take it at a true count of +3 or higher. See the full list on the Strategy tab.")
                }
                .listRowBackground(Color.surface)
                Section("Sound") {
                    Toggle("Sound effects", isOn: $engine.soundOn)
                }
                .listRowBackground(Color.surface)
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

    private var rulesSection: some View {
        Section {
            // Each deck count is graded with its own chart (double deck or 4–8 decks).
            Picker("Decks", selection: $engine.numDecks) {
                ForEach(PlayEngine.allowedDeckCounts, id: \.self) { Text("\($0)").tag($0) }
            }
            .accessibilityIdentifier("tableOptionsDeckPicker")
            .accessibilityValue("\(engine.numDecks)")
            Picker("Dealer", selection: $engine.dealerHitsSoft17) {
                Text("Stands soft 17").tag(false)
                Text("Hits soft 17").tag(true)
            }
            .accessibilityIdentifier("tableOptionsDealerPicker")
            .accessibilityValue(engine.dealerHitsSoft17 ? "Hits soft 17" : "Stands soft 17")
        } header: {
            Text("Table Rules")
        } footer: {
            if !rulesEditable {
                Text("Rules can change between rounds. Finish this hand, then come back.")
                    .accessibilityIdentifier("rulesLockedNote")
            }
        }
        .disabled(!rulesEditable)
        .listRowBackground(Color.surface)
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
