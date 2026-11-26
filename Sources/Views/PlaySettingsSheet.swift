import SwiftUI

/// The mid-session "Table Options" sheet. Rules and coaching toggles are
/// editable; session-shaping numbers (starting chips, table minimum) are
/// read-only here because they're chosen at session start and grading is
/// measured in them.
struct SettingsSheet: View {
    @Bindable var engine: PlayEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Table Rules") {
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
                }
                Section {
                    Toggle("Show hand totals", isOn: $engine.showHandTotals)
                        .accessibilityIdentifier("showHandTotalsToggle")
                } header: {
                    Text("Realism")
                } footer: {
                    Text("Turn off to hide the total shown above your hands and the dealer's, so you add the cards up yourself like at a real table.")
                }
                Section {
                    Toggle("Show running / true count", isOn: $engine.showCount)
                    Toggle("Betting hints", isOn: $engine.betHints)
                    Toggle("Ask for count checks during play", isOn: $engine.askCountChecks)
                } header: {
                    Text("Counting")
                } footer: {
                    Text("With betting hints off, the app only tells you if your bet was too high or too low. It does not reveal the count. Count checks occasionally ask for your running count before you act.")
                }
                Section {
                    Toggle("Count deviations (Illustrious 18)", isOn: $engine.useDeviations)
                } header: {
                    Text("Advanced")
                } footer: {
                    Text("Grades your plays against index deviations based on the count. For example, stand on 16 against a 10 when the true count is 0 or higher. Also grades insurance: take it at true count +3 or higher. See the full list on the Strategy tab.")
                }
                Section("Sound") {
                    Toggle("Sound effects", isOn: $engine.soundOn)
                }
                Section {
                    HStack {
                        Text("Starting chips")
                        Spacer()
                        Text(Money.chips(engine.sessionBuyIn)).foregroundStyle(.textSecondary)
                    }
                    HStack {
                        Text("Chips now")
                        Spacer()
                        Text(Money.chips(engine.bankroll)).foregroundStyle(.textSecondary)
                    }
                    // Read-only mid-session: the minimum is the unit every bet
                    // is graded in, and raising it could instantly leave the player
                    // out of chips. It's chosen at session start (SessionSetupView).
                    HStack {
                        Text("Table minimum")
                        Spacer()
                        Text(Money.chips(engine.tableMinimum)).foregroundStyle(.textSecondary)
                    }
                } header: {
                    Text("Session")
                } footer: {
                    Text("Use End session at the table to finish this session and start a new one with different starting chips or a different table minimum.")
                }
                Section {
                    Text("Bet-sizing practice: keep bets at the table minimum when the true count is low, and raise them by about one unit per point once it reaches +2. The app grades each bet against the count. Chips here are for practice only.")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
            }
            .navigationTitle("Table Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
