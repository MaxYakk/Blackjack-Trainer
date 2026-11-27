import SwiftUI

// Still pictures for the tour pages about Table Options, Quiz, Strategy and
// Progress. Each is a miniature of the real screen built from the same
// design-system pieces; none of it is tappable (the tour disables hit
// testing and reads a description instead).

// MARK: - Set up your table

struct TableOptionsDemo: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text("Table Options")
                .font(.heading)
                .foregroundStyle(.textPrimary)
                .padding(.bottom, Space.xxs)
            OptionRow(title: "Decks", value: "6")
            DemoDivider()
            OptionRow(title: "Dealer", value: "Stands on soft 17")
            DemoDivider()
            Toggle("Count based plays", isOn: .constant(true))
                .toggleStyle(.themed)
            DemoDivider()
            Toggle("Hints", isOn: .constant(true))
                .toggleStyle(.themed)
        }
    }
}

private struct OptionRow: View {
    let title: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.sm) {
                titleText
                Spacer(minLength: Space.xs)
                valueText
            }
            VStack(alignment: .leading, spacing: Space.xxs) {
                titleText
                valueText
            }
        }
        .frame(minHeight: Metrics.minTapTarget)
    }

    private var titleText: some View {
        Text(title)
            .font(.calloutText)
            .foregroundStyle(.textPrimary)
    }

    private var valueText: some View {
        Text(value)
            .font(.calloutText.weight(.semibold))
            .foregroundStyle(.accent)
    }
}

private struct DemoDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: Metrics.hairline)
    }
}

// MARK: - Quiz yourself fast

struct QuizDemo: View {
    private let modes = QuizDifficulty.allCases
    private let selected = QuizDifficulty.smart

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.xs) { modeChips }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.xs),
                                    GridItem(.flexible(), spacing: Space.xs)],
                          spacing: Space.xs) { modeChips }
            }

            Text(selected.summary)
                .font(.detail)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            DemoDivider()

            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.xs) {
                    Label("Daily Challenge", systemImage: "calendar")
                        .font(.heading)
                        .foregroundStyle(.textPrimary)
                    Spacer(minLength: Space.xs)
                    Text("7 of 10")
                        .font(.numberInline)
                        .foregroundStyle(.accent)
                }
                ProgressBar(value: 0.7)
            }
        }
    }

    @ViewBuilder
    private var modeChips: some View {
        ForEach(modes) { mode in
            let isOn = mode == selected
            Text(mode.rawValue)
                .font(.buttonLabelSmall)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(isOn ? Color.onAccent : Color.textPrimary)
                .padding(.horizontal, Space.sm)
                .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
                .background(isOn ? Color.accent : Color.surfaceRaised, in: Capsule())
        }
    }
}

// MARK: - The chart, and how you do

/// A slice of the real chart: hard 16, 12 and 11 against a dealer 2, 6 and
/// 10. Every cell comes from `BasicStrategy`, so it always matches the chart
/// the app grades with (6 decks, dealer stands on soft 17).
struct StrategyDemo: View {
    private static let dealerCards: [Rank] = [.two, .six, .ten]
    private static let hands: [(label: String, cards: [Card])] = [
        ("Hard 16", [Card(rank: .ten, suit: .spades), Card(rank: .six, suit: .hearts)]),
        ("Hard 12", [Card(rank: .ten, suit: .clubs), Card(rank: .two, suit: .diamonds)]),
        ("Hard 11", [Card(rank: .six, suit: .spades), Card(rank: .five, suit: .clubs)])
    ]

    /// My accuracy example for the same hard 16 row.
    private static let accuracy: [(percent: Int, mastery: Mastery)] = [
        (95, .solid), (72, .working), (40, .leak)
    ]

    var body: some View {
        Grid(horizontalSpacing: Space.xxs, verticalSpacing: Space.xxs) {
            GridRow {
                Text("Dealer")
                    .font(.fine)
                    .foregroundStyle(.textTertiary)
                    .gridColumnAlignment(.leading)
                ForEach(Self.dealerCards, id: \.self) { rank in
                    Text(rank.rawValue)
                        .font(.numberInline)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Self.hands, id: \.label) { hand in
                GridRow {
                    rowLabel(hand.label)
                    ForEach(Self.dealerCards, id: \.self) { up in
                        let action = BasicStrategy.correctAction(cards: hand.cards, dealerUp: up,
                                                                 canDouble: true, canSplit: false)
                        cell(action.rawValue, fill: ChartColors.fill(for: action.rawValue))
                    }
                }
            }
            GridRow {
                Text("My accuracy, hard 16")
                    .font(.overline)
                    .textCase(.uppercase)
                    .foregroundStyle(.textTertiary)
                    .gridCellColumns(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Space.xs)
            }
            GridRow {
                rowLabel("Hard 16")
                ForEach(Array(Self.accuracy.enumerated()), id: \.offset) { _, item in
                    cell("\(item.percent)", fill: item.mastery.fill)
                }
            }
        }
    }

    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.captionText.weight(.semibold))
            .foregroundStyle(.textPrimary)
            .fixedSize()
    }

    private func cell(_ text: String, fill: Color) -> some View {
        Text(text)
            .font(.numberInline)
            .foregroundStyle(ChartColors.text)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }
}

// MARK: - Know what to fix next

struct ProgressDemo: View {
    private static let leaks = [
        (spot: "Soft 18 vs 9", move: Action.hit),
        (spot: "Hard 12 vs 3", move: Action.hit)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                StatTile(label: "Accuracy", value: "86%", tint: .positive)
                StatTile(label: "Hands", value: "240")
                StatTile(label: "Streak", value: "5", tint: .warm)
            }

            Text("Fix next")
                .font(.heading)
                .foregroundStyle(.textPrimary)
                .padding(.top, Space.xxs)

            VStack(spacing: 0) {
                ForEach(Array(Self.leaks.enumerated()), id: \.offset) { index, leak in
                    if index > 0 { DemoDivider() }
                    HStack(spacing: Space.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.warning)
                        Text(leak.spot)
                            .font(.calloutText.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                        Spacer(minLength: Space.xs)
                        Text(leak.move.name)
                            .font(.buttonLabelSmall)
                            .foregroundStyle(ChartColors.text)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, Space.xxs)
                            .background(ChartColors.fill(for: leak.move.rawValue), in: Capsule())
                    }
                    .padding(.vertical, Space.xs)
                }
            }
            .padding(.horizontal, Space.sm)
            .background(.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
    }
}
