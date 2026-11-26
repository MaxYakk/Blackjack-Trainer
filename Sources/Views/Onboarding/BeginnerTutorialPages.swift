import Foundation

/// Content of the beginner tutorial, one entry per page.
struct BeginnerTutorialPage {
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
            summary: "Use the chips to choose your bet before each hand.",
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
