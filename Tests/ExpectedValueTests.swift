import Foundation
import Testing
@testable import BlackjackTrainer

/// Checks the EV calculator against the published infinite-deck table:
/// Wizard of Odds, "Player's expected return using basic strategy",
/// wizardofodds.com/games/blackjack/player-expected-return/ (Appendix 5).
/// Rules there: infinite deck, dealer stands on soft 17, dealer does not have
/// blackjack, double after split, unlimited resplits, split aces get one card.
/// Each cell is the EV of the best play. Columns: dealer 2...10, A.
struct ExpectedValueTests {
    static let wizardHard: [Int: [Double]] = [
        5: [-0.1282, -0.0953, -0.0615, -0.024, -0.0012, -0.1194, -0.1881, -0.2666, -0.3134, -0.2786],
        6: [-0.1408, -0.1073, -0.0729, -0.0349, -0.013, -0.1519, -0.2172, -0.2926, -0.3377, -0.3041],
        7: [-0.1092, -0.0766, -0.043, -0.0073, 0.0292, -0.0688, -0.2106, -0.2854, -0.3191, -0.3101],
        8: [-0.0218, 0.008, 0.0388, 0.0708, 0.115, 0.0822, -0.0599, -0.2102, -0.2494, -0.197],
        9: [0.0744, 0.1208, 0.1819, 0.2431, 0.3171, 0.1719, 0.0984, -0.0522, -0.153, -0.0657],
        10: [0.3589, 0.4093, 0.4609, 0.5125, 0.5756, 0.3924, 0.2866, 0.1443, 0.0253, 0.0814],
        11: [0.4706, 0.5178, 0.566, 0.6147, 0.6674, 0.4629, 0.3507, 0.2278, 0.1797, 0.143],
        12: [-0.2534, -0.2337, -0.2111, -0.1672, -0.1537, -0.2128, -0.2716, -0.34, -0.381, -0.3505],
        13: [-0.2928, -0.2523, -0.2111, -0.1672, -0.1537, -0.2691, -0.3236, -0.3872, -0.4253, -0.3969],
        14: [-0.2928, -0.2523, -0.2111, -0.1672, -0.1537, -0.3213, -0.3719, -0.4309, -0.4663, -0.44],
        15: [-0.2928, -0.2523, -0.2111, -0.1672, -0.1537, -0.3698, -0.4168, -0.4716, -0.5044, -0.48],
        16: [-0.2928, -0.2523, -0.2111, -0.1672, -0.1537, -0.4148, -0.4584, -0.5093, -0.5398, -0.5171],
        17: [-0.153, -0.1172, -0.0806, -0.0449, 0.0117, -0.1068, -0.382, -0.4232, -0.4197, -0.478],
        18: [0.1217, 0.1483, 0.1759, 0.1996, 0.2834, 0.3996, 0.106, -0.1832, -0.1783, -0.1002],
        19: [0.3863, 0.4044, 0.4232, 0.4395, 0.496, 0.616, 0.5939, 0.2876, 0.0631, 0.2776],
        20: [0.64, 0.6503, 0.661, 0.6704, 0.704, 0.7732, 0.7918, 0.7584, 0.5545, 0.6555],
        21: [0.882, 0.8853, 0.8888, 0.8918, 0.9028, 0.9259, 0.9306, 0.9392, 0.9626, 0.9222],
    ]

    /// Keyed by the non-ace card: A,2 ... A,9.
    static let wizardSoft: [Int: [Double]] = [
        2: [0.0466, 0.0741, 0.1025, 0.1334, 0.1797, 0.1224, 0.0541, -0.0377, -0.1049, -0.0573],
        3: [0.0224, 0.0508, 0.0801, 0.126, 0.1797, 0.0795, 0.0133, -0.0752, -0.1395, -0.0939],
        4: [-0.0001, 0.0292, 0.0593, 0.126, 0.1797, 0.037, -0.0271, -0.1122, -0.1737, -0.13],
        5: [-0.021, 0.0091, 0.0584, 0.126, 0.1797, -0.0049, -0.0668, -0.1486, -0.2074, -0.1656],
        6: [-0.0005, 0.0551, 0.1187, 0.1824, 0.2561, 0.0538, -0.0729, -0.1498, -0.1969, -0.1796],
        7: [0.1217, 0.1776, 0.237, 0.2952, 0.3815, 0.3996, 0.106, -0.1007, -0.1438, -0.0929],
        8: [0.3863, 0.4044, 0.4232, 0.4395, 0.496, 0.616, 0.5939, 0.2876, 0.0631, 0.2776],
        9: [0.64, 0.6503, 0.661, 0.6704, 0.704, 0.7732, 0.7918, 0.7584, 0.5545, 0.6555],
    ]

    /// Keyed by the pair card value (11 = aces).
    static let wizardPairs: [Int: [Double]] = [
        2: [-0.0842, -0.0153, 0.0597, 0.1526, 0.2282, 0.0073, -0.1593, -0.2407, -0.2892, -0.2531],
        3: [-0.1377, -0.056, 0.0305, 0.1272, 0.2026, -0.0525, -0.2172, -0.2926, -0.3377, -0.3041],
        4: [-0.0218, 0.008, 0.0388, 0.082, 0.1516, 0.0822, -0.0599, -0.2102, -0.2494, -0.197],
        5: [0.3589, 0.4093, 0.4609, 0.5125, 0.5756, 0.3924, 0.2866, 0.1443, 0.0253, 0.0814],
        6: [-0.2123, -0.119, -0.0202, 0.0824, 0.1555, -0.2128, -0.2716, -0.34, -0.381, -0.3505],
        7: [-0.1305, -0.0425, 0.0508, 0.1485, 0.2498, -0.0485, -0.3719, -0.4309, -0.4663, -0.44],
        8: [0.076, 0.1485, 0.2234, 0.3002, 0.4127, 0.3254, -0.0202, -0.3865, -0.4803, -0.3717],
        9: [0.1961, 0.2592, 0.3243, 0.3931, 0.4725, 0.3996, 0.2352, -0.0774, -0.1783, -0.1002],
        10: [0.64, 0.6503, 0.661, 0.6704, 0.704, 0.7732, 0.7918, 0.7584, 0.5545, 0.6555],
    ]

    static let ups = Array(2...11)
    /// The table prints 4 decimals; allow rounding plus a hair of float noise.
    static let tolerance = 0.0006

    static let unlimited = ExpectedValue(dealerHitsSoft17: false, maxSplitHands: nil)

    static func state(_ total: Int, soft: Bool = false) -> ExpectedValue.HandState {
        .init(total: total, soft: soft)
    }

    /// Best of stand / hit / double for a two-card total.
    static func bestTwoCard(_ ev: ExpectedValue, _ s: ExpectedValue.HandState, up: Int) -> Double {
        max(ev.stand(s, up: up), ev.hit(s, up: up), ev.double(s, up: up))
    }

    @Test static func hardTotalsMatchPublishedTable() {
        let ev = unlimited
        for (total, row) in wizardHard {
            for (i, up) in ups.enumerated() {
                let s = state(total)
                // 21 here is a three-card 21 (no doubling); everything else is two cards.
                let got = total == 21 ? ev.stand(s, up: up) : bestTwoCard(ev, s, up: up)
                #expect(abs(got - row[i]) <= tolerance, "hard \(total) vs \(up): \(got) vs \(row[i])")
            }
        }
    }

    @Test static func softTotalsMatchPublishedTable() {
        let ev = unlimited
        for (other, row) in wizardSoft {
            for (i, up) in ups.enumerated() {
                let got = bestTwoCard(ev, state(11 + other, soft: true), up: up)
                #expect(abs(got - row[i]) <= tolerance, "A,\(other) vs \(up): \(got) vs \(row[i])")
            }
        }
    }

    @Test static func pairsMatchPublishedTable() {
        let ev = unlimited
        for (r, row) in wizardPairs {
            for (i, up) in ups.enumerated() {
                let asTotal = bestTwoCard(ev, state(2 * r), up: up)
                let got = max(asTotal, ev.split(pairValue: r, up: up))
                #expect(abs(got - row[i]) <= tolerance, "\(r),\(r) vs \(up): \(got) vs \(row[i])")
            }
        }
    }

    /// The published A,A row matches hard 11 in every column but the ace,
    /// which looks like a copy of the wrong row, so it isn't used. Instead:
    /// split aces vs A matches the table (0.1091), and splitting aces always
    /// beats playing soft 12.
    @Test static func splitAces() {
        let ev = unlimited
        #expect(abs(ev.split(pairValue: 11, up: 11) - 0.1091) <= tolerance)
        for up in ups {
            let split = ev.split(pairValue: 11, up: up)
            #expect(split > bestTwoCard(ev, state(12, soft: true), up: up), "A,A vs \(up)")
        }
    }

    /// The table's four-hand resplit cap costs a little, never helps.
    @Test static func cappedResplitsCostAtMostALittle() {
        let capped = ExpectedValue(dealerHitsSoft17: false, maxSplitHands: 4)
        for r in 2...10 {
            for up in ups {
                let free = unlimited.split(pairValue: r, up: up)
                let four = capped.split(pairValue: r, up: up)
                #expect(four <= free + 1e-9 && free - four < 0.01, "\(r),\(r) vs \(up)")
            }
        }
    }

    /// Hitting soft 17 helps the dealer, so standing on 18 against a 6 is worth less.
    @Test static func dealerHittingSoft17HurtsTheStand() {
        let h17 = ExpectedValue(dealerHitsSoft17: true)
        let s17 = ExpectedValue(dealerHitsSoft17: false)
        #expect(h17.stand(state(18), up: 6) < s17.stand(state(18), up: 6))
        // Classic H17 chart changes: 11 vs A doubles, A,7 vs 2 doubles, A,8 vs 6 doubles.
        let up = 11
        #expect(h17.double(state(11), up: up) > h17.hit(state(11), up: up))
        #expect(s17.double(state(11), up: up) < s17.hit(state(11), up: up))
        #expect(h17.double(state(18, soft: true), up: 2) > h17.stand(state(18, soft: true), up: 2))
        #expect(h17.double(state(19, soft: true), up: 6) > h17.stand(state(19, soft: true), up: 6))
    }
}
