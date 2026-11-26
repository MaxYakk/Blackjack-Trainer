// The tour's copy and the onboarding order live in Sources/Views/Onboarding,
// which scripts/logic-tests.sh (macOS, Engine/Store/Money only) doesn't
// compile. These tests build with the app for iOS and run in Xcode's test
// action; on macOS this file compiles to nothing.
#if os(iOS)
import Foundation
import Testing
@testable import BlackjackTrainer

struct AppTourContentTests {
    private let pages = AppTourPage.pages

    private func allCopy(_ page: AppTourPage) -> [String] {
        [page.place, page.title, page.summary, page.demoDescription] + page.points
    }

    @Test func tourIsShortAndShowsEveryDemoOnce() {
        #expect((5...7).contains(pages.count))
        #expect(pages.map(\.demo) == AppTourPage.Demo.allCases)
    }

    @Test func everyPageIsShortAndComplete() {
        for page in pages {
            #expect(!page.title.isEmpty && page.title.count <= 30, "\(page.title)")
            #expect(page.summary.count <= 100, "\(page.summary)")
            #expect(page.points.count == 2, "\(page.title)")
            for point in page.points {
                #expect(point.count <= 90, "\(point)")
            }
            #expect(page.demoDescription.hasPrefix("Example"), "\(page.title)")
        }
    }

    @Test func copyHasNoDashCharacters() {
        for text in pages.flatMap(allCopy) {
            for dash in ["-", "\u{2013}", "\u{2014}", "\u{2212}"] {
                #expect(!text.contains(dash), "\(text)")
            }
        }
    }

    @Test func copyMakesNoMoneyOrPrizePromises() {
        let banned = ["real money", "cash", "prize", "win money", "payout", "jackpot", "casino"]
        for text in pages.flatMap(allCopy) {
            for word in banned {
                #expect(!text.lowercased().contains(word), "\(word) in: \(text)")
            }
        }
    }

    /// Every feature the owner asked the tour to cover is named somewhere.
    @Test(arguments: [
        "play money", "graded", "asks for the count", "true count", "decks", "soft 17",
        "count based strategy changes", "hints", "Smart", "Daily Challenge",
        "Count drill", "strategy chart", "My accuracy", "leaks"
    ])
    func tourCoversFeature(_ phrase: String) {
        let copy = pages.flatMap(allCopy).joined(separator: " ").lowercased()
        #expect(copy.contains(phrase.lowercased()), "\(phrase)")
    }

    @Test func onboardingRunsWelcomeThenTourThenBasicsOffer() {
        #expect(OnboardingStep.welcome.next == .tour)
        #expect(OnboardingStep.tour.next == .basicsOffer)
        #expect(OnboardingStep.basicsOffer.next == nil)
    }
}
#endif
