import Foundation

/// Words for the app tour, one entry per page. Kept free of SwiftUI so the
/// copy and the onboarding order can be checked in tests. Each page pairs with
/// a small demo built from real design-system pieces (see `AppTourDemos`).
///
/// Copy rules: short and friendly, no dash characters, and nothing that hints
/// at real money or prizes.
struct AppTourPage: Identifiable, Equatable {
    /// Which demo the page shows. Also the page's identity.
    enum Demo: String, CaseIterable {
        case table, counting, betting, tableOptions, quiz, strategy, progress
    }

    let demo: Demo
    /// Where the feature lives, shown above the title ("Play tab").
    let place: String
    let title: String
    let summary: String
    /// Two short lines under the demo.
    let points: [String]
    /// What VoiceOver reads for the demo, since the demo itself is a picture.
    let demoDescription: String

    var id: Demo { demo }

    static let pages: [AppTourPage] = [
        AppTourPage(
            demo: .table,
            place: "Play tab",
            title: "Play at a real table",
            summary: "Bet play money at a full blackjack table. Every move you make gets graded.",
            points: [
                "A wrong move gets a quick reason, so you learn as you play.",
                "Play up to three hands at once."
            ],
            demoDescription: "Example: you have 11 against a dealer 6. You choose Double, and the table says Correct."
        ),
        AppTourPage(
            demo: .counting,
            place: "Play and Count tabs",
            title: "Learn to count cards",
            summary: "Low cards add one. Tens and aces take one away. Keep the total in your head.",
            points: [
                "Count checks: now and then the table stops and asks for the count.",
                "Count drill: cards flash by, you name the running count, then see the true count."
            ],
            demoDescription: "Example: a 5, a King, a 3 and a 6 come out. The running count is 2, and the table asks for it."
        ),
        AppTourPage(
            demo: .betting,
            place: "Play tab",
            title: "Bet with the count",
            summary: "The true count tells you how much to bet. The table coaches every bet.",
            points: [
                "Below a true count of 2, bet the table minimum.",
                "From 2 up, add about one unit per point: 3 units at a true count of 3."
            ],
            demoDescription: "Example: at a true count of 1, bet 1 unit. At a true count of 3, bet 3 units, and the table says Good bet."
        ),
        AppTourPage(
            demo: .tableOptions,
            place: "Play tab, Table Options",
            title: "Set up your table",
            summary: "Make practice match the game you play.",
            points: [
                "Choose the number of decks and whether the dealer hits soft 17.",
                "Turn on count based strategy changes, count checks and hints."
            ],
            demoDescription: "Example settings: 6 decks, dealer stands on soft 17, count based plays on, hints on."
        ),
        AppTourPage(
            demo: .quiz,
            place: "Quiz tab",
            title: "Quiz yourself fast",
            summary: "Flash card hands with instant feedback. Pick Easy, Normal, Hard or Smart.",
            points: [
                "Smart mode deals the spots you miss most.",
                "Daily Challenge: ten new hands every day."
            ],
            demoDescription: "Example: Smart mode is picked, and today's Daily Challenge is 7 of 10 hands done."
        ),
        AppTourPage(
            demo: .strategy,
            place: "Strategy tab",
            title: "The chart, and how you do",
            summary: "The full basic strategy chart, matched to your table rules.",
            points: [
                "The count based strategy changes are listed there too.",
                "Switch to My accuracy to see how often you play each spot right."
            ],
            demoDescription: "Example: a slice of the strategy chart. Hard 16 stands against a 2 and a 6 and hits against a 10. Hard 12 hits against a 2, stands against a 6 and hits against a 10. Hard 11 doubles against all three. Below it, My accuracy shows how often you play hard 16 right against each card."
        ),
        AppTourPage(
            demo: .progress,
            place: "Progress tab",
            title: "Know what to fix next",
            summary: "Track your accuracy, skill rating and streaks.",
            points: [
                "Your leaks: the plays you miss most, with the right move.",
                "Drill them in Smart mode with one tap."
            ],
            demoDescription: "Example: 86 percent accuracy, 240 hands and a streak of 5. Fix next: soft 18 against a 9, the right move is Hit. Hard 12 against a 3, the right move is Hit."
        )
    ]
}

/// The steps of first launch, in order: welcome, the required app tour, an
/// optional offer of the blackjack basics tutorial, then the app.
enum OnboardingStep: Equatable {
    case welcome
    case tour
    case basicsOffer

    /// The step after this one; nil means onboarding is complete.
    var next: OnboardingStep? {
        switch self {
        case .welcome: return .tour
        case .tour: return .basicsOffer
        case .basicsOffer: return nil
        }
    }
}
