import SwiftUI

/// The mid-session "Table Options" sheet. It shows the same settings as the
/// Play setup screen (`TableSettingsSections`); decks and dealer soft 17 can
/// change only between rounds so a rule never changes under a hand in
/// progress. Session numbers (starting chips, table minimum) are read-only
/// because bets are graded in them.
struct SettingsSheet: View {
    @Bindable var engine: PlayEngine
    @Environment(\.dismiss) private var dismiss

    /// Rules can change only while bets are being placed.
    private var rulesEditable: Bool { engine.phase == .betting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    TableSettingsSections(engine: engine, context: .table,
                                          rulesLocked: !rulesEditable)
                    sessionSection
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.md)
            }
            .background(Color.bg.ignoresSafeArea())
            .tint(.accent)
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

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("SESSION")
                .font(.overline)
                .tracking(1.6)
                .foregroundStyle(.textTertiary)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: Space.sm) {
                readOnlyRow("Starting money", Money.chips(engine.sessionBuyIn))
                readOnlyRow("Balance now", Money.chips(engine.bankroll))
                // Read-only mid-session: the minimum is the unit every bet is
                // graded in, and raising it could instantly leave the player out
                // of chips. It's chosen at session start (SessionSetupView).
                readOnlyRow("Table minimum", Money.chips(engine.tableMinimum))
            }
            .font(.bodyText)
            .foregroundStyle(.textPrimary)
            .panel()
            Text("Bet-sizing practice: keep bets at the table minimum when the true count is low, and raise them by about one unit per point once it reaches +2. To change starting money or the minimum, use End session at the table and start a new session. \(PracticeNotice.line)")
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Space.xs)
        }
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
