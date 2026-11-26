import Foundation
import Testing
@testable import BlackjackTrainer

// Practice-chip wording: amounts carry no currency symbol, and no trophy
// title or description reads like money or gambling slang.
//
// Compile alongside: Sources/Engine, Sources/Store and Money from Theme.swift

struct ChipWordingTests {
    @Test func amountsHaveNoCurrencySymbol() {
        #expect(Money.string(1250) == "1,250")
        #expect(Money.wholeString(1250) == "1,250")
        #expect(Money.string(0) == "0")
        #expect(Money.string(10_000) == "10,000")
    }

    @Test func fractionalPayoutsKeepTheirFraction() {
        // A 3:2 blackjack on an odd bet pays a half chip.
        #expect(Money.string(7.5) == "7.5")
        #expect(Money.string(0.25) == "0.25")
        #expect(Money.string(12.345) == "12.35" || Money.string(12.345) == "12.34")
        #expect(Money.chips(7.5) == "7.5 chips")
    }

    @Test func chipWordAgreesWithTheAmount() {
        #expect(Money.chips(1) == "1 chip")
        #expect(Money.chips(25) == "25 chips")
        #expect(Money.chips(0) == "0 chips")
        #expect(Money.signedChips(50) == "+50 chips")
        #expect(Money.signedChips(-50) == "-50 chips")
        #expect(Money.signedChips(0) == "0 chips")
    }

    @Test func trophyWordingHasNoMoneyOrGamblingSlang() {
        let banned = ["$", "cash", "roller", "whale", "bankroll", "buy in", "buy-in",
                      "grinder", "lucky", "jackpot", "casino", "wager", "house"]
        let all = Achievements.all(from: Achievements.Inputs())
        #expect(!all.isEmpty)
        for achievement in all {
            let text = "\(achievement.title) \(achievement.detail) \(achievement.progressText)".lowercased()
            for word in banned {
                #expect(!text.contains(word), "\(achievement.id) mentions \"\(word)\": \(text)")
            }
        }
    }

    @Test func trophyIdsStayStable() {
        // Saved progress is keyed by id, so renaming titles must not change them.
        let ids = Set(Achievements.all(from: Achievements.Inputs()).map(\.id))
        for id in ["high-roller", "whale", "bankroll-boss", "lucky-sevens", "grinder"] {
            #expect(ids.contains(id), "\(id) must keep its id")
        }
    }

    @Test func sessionProfitTrophyProgressReadsInChips() {
        var inputs = Achievements.Inputs()
        inputs.bestSessionNet = 250
        let hot = Achievements.all(from: inputs).first { $0.id == "high-roller" }
        #expect(hot?.progressText == "250/500 chips")
    }
}
