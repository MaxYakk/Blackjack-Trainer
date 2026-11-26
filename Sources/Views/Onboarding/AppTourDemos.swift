import SwiftUI

/// The small picture on each tour page, built from the real table pieces
/// (`CardView`, `ChipStack`, `DecisionButton`, `FeedbackPill`, `StatTile`).
/// The caller makes it non-interactive and gives VoiceOver one description.
struct AppTourDemo: View {
    let demo: AppTourPage.Demo
    let isActive: Bool

    var body: some View {
        switch demo {
        case .table: TableDemo(isActive: isActive)
        case .counting: CountingDemo(isActive: isActive)
        case .betting: BettingDemo(isActive: isActive)
        case .tableOptions: TableOptionsDemo()
        case .quiz: QuizDemo()
        case .strategy: StrategyDemo()
        case .progress: ProgressDemo()
        }
    }
}

// MARK: - Demo timing

/// Steps a demo through `steps` frames, about one a second, while its page is
/// showing, then holds the last frame for a beat and starts over. With Reduce
/// Motion on (or the page off screen) it shows the last, complete frame and
/// never moves.
struct DemoTimeline<Content: View>: View {
    let steps: Int
    let isActive: Bool
    @ViewBuilder let content: (Int) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Int?

    private static var interval: Duration { .milliseconds(1100) }
    private var lastStep: Int { max(steps - 1, 0) }
    private var animates: Bool { isActive && !reduceMotion }

    var body: some View {
        content(min(step ?? lastStep, lastStep))
            .task(id: animates) {
                guard animates else {
                    step = nil
                    return
                }
                step = 0
                // One extra tick holds the finished frame before looping.
                var tick = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: Self.interval)
                    guard !Task.isCancelled else { break }
                    tick = (tick + 1) % (steps + 1)
                    withAnimation(Motion.standard.animation) { step = tick }
                }
            }
    }
}

/// "Dealer" / "You" caption beside a row of cards.
private struct HandCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.captionText.weight(.semibold))
            .foregroundStyle(.textSecondary)
            .frame(minWidth: 52, alignment: .leading)
    }
}

// MARK: - Play a real table

/// 5 and 6 (hard 11) against a dealer 6: Double is chosen and graded correct.
private struct TableDemo: View {
    let isActive: Bool

    var body: some View {
        DemoTimeline(steps: 3, isActive: isActive) { step in
            VStack(spacing: Space.sm) {
                HStack(spacing: Space.xs) {
                    HandCaption(text: "Dealer")
                    CardView(card: Card(rank: .six, suit: .clubs))
                    CardView(card: nil, faceDown: true)
                    Spacer(minLength: 0)
                }
                HStack(spacing: Space.xs) {
                    HandCaption(text: "You")
                    CardView(card: Card(rank: .five, suit: .hearts))
                    CardView(card: Card(rank: .six, suit: .spades))
                    Text("11")
                        .font(.numberInline)
                        .foregroundStyle(.textPrimary)
                        .padding(.horizontal, Space.xs)
                        .padding(.vertical, Space.xxs)
                        .background(.surfaceRaised, in: Capsule())
                    Spacer(minLength: 0)
                }

                DemoDecisionGrid(chosen: step >= 1 ? .double : nil)
                    .padding(.top, Space.xxs)

                FeedbackPill(step >= 2 ? "Correct. Basic strategy says Double." : nil,
                             kind: .correct, announces: false)
            }
        }
    }
}

/// The Hit / Stand / Double / Split keys, with the chosen one outlined.
/// Split is dimmed because 5 and 6 aren't a pair, just like at the table.
private struct DemoDecisionGrid: View {
    let chosen: Action?

    var body: some View {
        VStack(spacing: Space.xs) {
            HStack(spacing: Space.xs) {
                key(.hit)
                key(.stand)
            }
            HStack(spacing: Space.xs) {
                key(.double)
                key(.split, enabled: false)
            }
        }
    }

    private func key(_ action: Action, enabled: Bool = true) -> some View {
        let isChosen = action == chosen
        return DecisionButton(title: action.name, enabled: enabled) {}
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(Color.accent, lineWidth: 2)
                    .opacity(isChosen ? 1 : 0)
            }
    }
}

// MARK: - Learn to count cards

/// Four cards come out one at a time; the running count under each card
/// follows Hi Lo (5 is +1, King is minus 1, 3 is +1, 6 is +1), ending on 2.
/// Then the table asks for the count.
private struct CountingDemo: View {
    let isActive: Bool

    private static let cards = [
        Card(rank: .five, suit: .hearts),
        Card(rank: .king, suit: .spades),
        Card(rank: .three, suit: .clubs),
        Card(rank: .six, suit: .diamonds)
    ]

    /// Running count after each card. Computed from the engine's Hi Lo values.
    private static let runningCounts: [Int] = cards.indices.map { index in
        cards[...index].reduce(0) { $0 + $1.rank.hiLo }
    }

    var body: some View {
        // Steps 0...3 deal the cards; step 4 adds the count check prompt.
        DemoTimeline(steps: Self.cards.count + 1, isActive: isActive) { step in
            VStack(spacing: Space.sm) {
                HStack(alignment: .top, spacing: Space.sm) {
                    ForEach(Self.cards.indices, id: \.self) { index in
                        let dealt = index <= step
                        VStack(spacing: Space.xxs) {
                            CardView(card: dealt ? Self.cards[index] : nil)
                            Text(dealt ? "\(Self.runningCounts[index])" : " ")
                                .font(.numberInline)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }

                let shown = min(step, Self.cards.count - 1)
                HStack(spacing: Space.xs) {
                    StatTile(label: "Cards seen", value: "\(shown + 1)", tint: .textPrimary)
                    StatTile(label: "Running count", value: "\(Self.runningCounts[shown])")
                }

                FeedbackPill(step >= Self.cards.count ? "What's the running count?" : nil,
                             kind: .info, announces: false)
            }
        }
    }
}

// MARK: - Bet with the count

/// A low count gets the table minimum; a true count of 3 gets 3 units, and
/// the table approves the bet.
private struct BettingDemo: View {
    let isActive: Bool

    private static let unit: Double = 25

    var body: some View {
        DemoTimeline(steps: 2, isActive: isActive) { step in
            VStack(spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    BetColumn(trueCount: "+1", units: 1, amount: Self.unit, highlighted: step == 0)
                    BetColumn(trueCount: "+3", units: 3, amount: Self.unit * 3, highlighted: step >= 1)
                }
                FeedbackPill(step >= 1 ? "Good bet for a true count of +3." : nil,
                             kind: .correct, announces: false)
            }
        }
    }
}

private struct BetColumn: View {
    let trueCount: String
    let units: Int
    let amount: Double
    let highlighted: Bool

    var body: some View {
        VStack(spacing: Space.xs) {
            Text("True count \(trueCount)")
                .font(.captionText.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            ChipStack(amount: amount, size: 40)
                .frame(minHeight: 60, alignment: .bottom)
            Text(units == 1 ? "1 unit" : "\(units) units")
                .font(.numberInline)
                .foregroundStyle(highlighted ? Color.accent : Color.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.sm)
        .background(.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                .strokeBorder(highlighted ? Color.accent : Color.divider,
                              lineWidth: highlighted ? 2 : Metrics.hairline)
        }
    }
}
