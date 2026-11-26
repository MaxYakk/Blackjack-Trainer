import SwiftUI

struct BeginnerBlackjackTutorial: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private let pages = BeginnerTutorialPage.pages

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Theme.feltDark, Theme.felt],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Text("LEARN THE GAME")
                            .font(.caption.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Button("Close") { dismiss() }
                            .foregroundStyle(.white.opacity(0.82))
                            .accessibilityIdentifier("tutorialClose")
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    TutorialPageContent(page: pages[currentPage])
                        .id(currentPage)
                        .transaction { transaction in
                            transaction.animation = nil
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack(spacing: 7) {
                        ForEach(pages.indices, id: \.self) { index in
                            Capsule()
                                .fill(index == currentPage ? Theme.accent : Color.white.opacity(0.28))
                                .frame(width: index == currentPage ? 22 : 7, height: 7)
                        }
                    }
                    .padding(.bottom, 18)

                    Button(action: advance) {
                        HStack(spacing: 8) {
                            Text(currentPage == pages.count - 1 ? "Try a hand" : "Continue")
                            Image(systemName: currentPage == pages.count - 1 ? "suit.spade.fill" : "arrow.right")
                        }
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.cardBlack)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent, in: Capsule())
                    }
                    .accessibilityIdentifier(currentPage == pages.count - 1 ? "tutorialDone" : "tutorialNext")
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func advance() {
        if currentPage == pages.count - 1 {
            dismiss()
        } else {
            currentPage += 1
        }
    }
}

private struct TutorialPageContent: View {
    let page: BeginnerTutorialPage

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 132, height: 132)
                    Image(systemName: page.icon)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }

                VStack(spacing: 10) {
                    Text(page.title)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(page.summary)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.76))
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(page.points, id: \.title) { point in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: point.icon)
                                .font(.headline)
                                .foregroundStyle(Theme.mint)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(point.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(point.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(18)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

private struct BeginnerTutorialPage {
    struct Point {
        let icon: String
        let title: String
        let detail: String
    }

    let icon: String
    let title: String
    let summary: String
    let points: [Point]

    static let pages = [
        BeginnerTutorialPage(
            icon: "suit.spade.fill",
            title: "Blackjack in one minute",
            summary: "Get closer to 21 than the dealer without going over.",
            points: [
                Point(icon: "number", title: "Card values", detail: "Cards 2 through 10 are worth their number. J, Q, and K are worth 10. An Ace is 1 or 11."),
                Point(icon: "star.fill", title: "Blackjack", detail: "An Ace and a card worth 10 on your first two cards is a blackjack."),
                Point(icon: "xmark.circle", title: "Bust", detail: "If your total goes over 21, your hand loses right away.")
            ]
        ),
        BeginnerTutorialPage(
            icon: "circle.circle.fill",
            title: "Place a bet, then deal",
            summary: "Use the chips to choose your wager before each hand.",
            points: [
                Point(icon: "circle.dashed", title: "Your betting spot", detail: "Tap a chip to add it to the circle. Your bet must meet the table minimum."),
                Point(icon: "rectangle.3.group.fill", title: "Deal", detail: "You and the dealer each receive two cards. One dealer card is face down."),
                Point(icon: "eye", title: "Dealer card", detail: "The visible dealer card helps you decide whether to take another card or stop.")
            ]
        ),
        BeginnerTutorialPage(
            icon: "hand.raised.fill",
            title: "Choose your move",
            summary: "After the deal, decide what to do with your hand.",
            points: [
                Point(icon: "plus.circle.fill", title: "Hit", detail: "Take one more card. You can hit again until you stand or bust."),
                Point(icon: "hand.raised.fill", title: "Stand", detail: "Keep your total and end your turn."),
                Point(icon: "arrow.up.right.circle.fill", title: "Double", detail: "Double your bet and take exactly one final card."),
                Point(icon: "rectangle.split.2x1.fill", title: "Split", detail: "If your first two cards match, turn them into two separate hands.")
            ]
        ),
        BeginnerTutorialPage(
            icon: "person.2.fill",
            title: "The dealer finishes the hand",
            summary: "Once you stand, the dealer reveals the hidden card and follows set rules.",
            points: [
                Point(icon: "arrow.down.circle.fill", title: "Dealer draws", detail: "The dealer keeps taking cards on 16 or less, then stops on 17 or more."),
                Point(icon: "trophy.fill", title: "You win", detail: "Win by having a higher total than the dealer, or when the dealer busts."),
                Point(icon: "equal.circle.fill", title: "Push", detail: "If you and the dealer tie, you keep your bet. This is called a push.")
            ]
        ),
        BeginnerTutorialPage(
            icon: "checkmark.seal.fill",
            title: "You're ready to play",
            summary: "Start small, take your time, and use the feedback after each decision.",
            points: [
                Point(icon: "1.circle.fill", title: "Set a bet", detail: "Choose a chip at or above the table minimum."),
                Point(icon: "2.circle.fill", title: "Deal your first hand", detail: "Use the dealer’s visible card and your total to choose an action."),
                Point(icon: "lightbulb.fill", title: "Learn as you go", detail: "The trainer explains whether a move matched basic strategy. The Quiz tab is great for extra practice.")
            ]
        )
    ]
}
