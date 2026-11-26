import SwiftUI

/// The mid-session "Table Options" sheet. Rules and coaching toggles are
/// editable; session-shaping numbers (buy-in, table minimum) are read-only
/// here because they're chosen at buy-in and grading is denominated in them.
struct SettingsSheet: View {
    @Bindable var engine: PlayEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Table Rules") {
                    Picker("Decks", selection: $engine.numDecks) {
                        ForEach([1, 2, 4, 6, 8], id: \.self) { Text("\($0)").tag($0) }
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
                        Text("Buy in")
                        Spacer()
                        Text(engine.money(engine.sessionBuyIn)).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Balance")
                        Spacer()
                        Text(engine.money(engine.bankroll)).foregroundStyle(.secondary)
                    }
                    // Read-only mid-session: the minimum is the unit every bet
                    // is graded in, and raising it could instantly "felt" a
                    // live stack. It's chosen at buy-in (SessionSetupView).
                    HStack {
                        Text("Table minimum")
                        Spacer()
                        Text(engine.money(engine.tableMinimum)).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Session")
                } footer: {
                    Text("Use Cash Out at the table to end this session and start a new one with a different stack or table minimum.")
                }
                Section {
                    Text("Betting tip: keep bets at the table minimum when the true count is low, and ramp up by about one unit per point once it reaches +2. The app grades each bet against the count.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
