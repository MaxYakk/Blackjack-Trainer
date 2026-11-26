import SwiftUI

/// One spot in the review: how often it is missed and, when known, which
/// wrong play the player keeps choosing.
struct ReviewItem: Identifiable {
    let key: String
    let stat: SpotStat
    let commonChoice: String?
    let choiceCount: Int

    var id: String { key }

    init(_ mistake: RecurringMistake) {
        key = mistake.key
        stat = mistake.stat
        commonChoice = mistake.commonChoice
        choiceCount = mistake.choiceCount
    }

    /// A weak spot, with its most common wrong play looked up from the
    /// player's saved mistakes (nil when there is no clear pattern yet).
    init(key: String, stat: SpotStat, choices: [String: Int]?) {
        self.key = key
        self.stat = stat
        let top = choices?.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }
        commonChoice = top?.key
        choiceCount = top?.value ?? 0
    }
}

/// A set of spots to step through, starting at `startIndex`.
struct ReviewSession: Identifiable {
    let id = UUID()
    let items: [ReviewItem]
    var startIndex = 0
}

/// Steps through weak spots one at a time with Back and Next.
struct MistakeReviewView: View {
    let session: ReviewSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index: Int

    init(session: ReviewSession) {
        self.session = session
        _index = State(initialValue: min(max(session.startIndex, 0), max(session.items.count - 1, 0)))
    }

    private var item: ReviewItem { session.items[index] }
    private var isLast: Bool { index == session.items.count - 1 }

    private var catalogSpot: CatalogSpot? {
        SpotCatalog.all.first { spot in
            SpotID.key(cards: spot.cards, dealerUp: spot.dealerRank, canSplit: spot.isPair) == item.key
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.md) {
                    progressHeader
                    spotPanel
                    navigationButtons
                }
                .padding(Space.md)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("Mistake Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .frame(minHeight: Metrics.minTapTarget)
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: Space.xs) {
            Text("Mistake \(index + 1) of \(session.items.count)")
                .font(.calloutText.weight(.semibold))
                .foregroundStyle(.textSecondary)
            ProgressBar(value: Double(index + 1) / Double(max(session.items.count, 1)))
                .accessibilityHidden(true)
        }
    }

    private var spotPanel: some View {
        Panel(alignment: .center, spacing: Space.md) {
            Text(SpotID.displayName(item.key))
                .font(.sectionTitle)
                .foregroundStyle(.accent)
                .multilineTextAlignment(.center)

            if let spot = catalogSpot {
                VStack(spacing: Space.sm) {
                    VStack(spacing: Space.xxs) {
                        Text("Dealer shows")
                            .font(.captionText)
                            .foregroundStyle(.textSecondary)
                        CardView(card: Card(rank: spot.dealerRank, suit: .clubs), size: 1.45)
                    }
                    VStack(spacing: Space.xxs) {
                        Text("Your hand")
                            .font(.captionText)
                            .foregroundStyle(.textSecondary)
                        HStack(spacing: Space.xs) {
                            ForEach(spot.cards) { card in
                                CardView(card: card, size: 1.45)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dealer card and your two cards for \(SpotID.displayName(item.key))")
            }

            verdict
        }
        .id(item.key)
    }

    private var verdict: some View {
        VStack(spacing: Space.xs) {
            if let choice = item.commonChoice {
                Text("You chose \(choice) \(item.choiceCount) times")
                    .font(.heading)
                    .foregroundStyle(.negative)
            }
            if let correct = SpotID.correctActionName(item.key) {
                Text("Correct play: \(correct)")
                    .font(.heading)
                    .foregroundStyle(.positive)
            }
            Text("\(Int(item.stat.accuracy * 100))% correct across \(item.stat.total) attempts")
                .font(.captionText)
                .foregroundStyle(.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .panel(.raised, padding: Space.md, cornerRadius: Radius.medium)
    }

    @ViewBuilder
    private var navigationButtons: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Space.xs))
            : AnyLayout(HStackLayout(spacing: Space.xs))
        layout {
            SecondaryButton("Back", systemImage: "chevron.left") { go(-1) }
                .disabled(index == 0)
                .accessibilityIdentifier("reviewBackButton")
            PrimaryButton(isLast ? "Finish Review" : "Next Mistake") {
                if isLast { dismiss() } else { go(1) }
            }
            .accessibilityIdentifier("reviewNextButton")
        }
    }

    private func go(_ step: Int) {
        Motion.perform(.standard, reduceMotion: reduceMotion) {
            index = min(max(index + step, 0), session.items.count - 1)
        }
    }
}
