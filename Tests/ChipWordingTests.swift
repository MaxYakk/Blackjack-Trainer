import Foundation
import Testing
@testable import BlackjackTrainer

// Play-money wording: amounts show a "$" so the table feels real, but nothing
// promises real money or prizes, and the notice says so plainly.
//
// Compile alongside: Sources/Engine, Sources/Store and Money from Sources/Views/Money.swift

struct ChipWordingTests {
    @Test func amountsShowADollarSign() {
        #expect(Money.string(1250) == "$1,250")
        #expect(Money.wholeString(1250) == "$1,250")
        #expect(Money.string(0) == "$0")
        #expect(Money.string(10_000) == "$10,000")
    }

    @Test func fractionalPayoutsShowCents() {
        // A 3:2 blackjack on an odd bet pays a fraction.
        #expect(Money.string(7.5) == "$7.50")
        #expect(Money.string(0.25) == "$0.25")
        #expect(Money.string(12.345) == "$12.35" || Money.string(12.345) == "$12.34")
    }

    @Test func lossesUseATrueMinus() {
        #expect(Money.string(-25) == "\u{2212}$25")
        #expect(Money.signed(-25) == "\u{2212}$25")
        #expect(Money.signed(50) == "+$50")
        #expect(Money.signed(7.5) == "+$7.50")
        #expect(Money.signed(0) == "$0")
    }

    @Test func chipsHelpersDoNotAddTheWordChips() {
        #expect(Money.chips(1) == "$1")
        #expect(Money.chips(25) == "$25")
        #expect(Money.signedChips(50) == "+$50")
        #expect(Money.signedChips(-50) == "\u{2212}$50")
    }

    @Test func noticeSaysPlayMoneyAndNeverPromisesRealMoney() {
        let line = PracticeNotice.line.lowercased()
        #expect(line.contains("play money"))
        #expect(line.contains("no real money"))
        #expect(line.contains("no prizes"))
        for phrase in ["win real", "cash out", "cash-out", "withdraw", "buy chips", "deposit", "payout"] {
            #expect(!line.contains(phrase), "notice must not mention \"\(phrase)\"")
        }
    }

    @Test func trophyWordingHasNoMoneyOrGamblingSlang() {
        let banned = ["cash", "roller", "whale", "bankroll", "buy in", "buy-in",
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
