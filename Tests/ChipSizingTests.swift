import Foundation
import Testing
@testable import BlackjackTrainer

// Headless check of the chip tray rule: smallest chip = table minimum,
// largest = biggest ladder chip that fits into the starting chips four times.
//
// Compile alongside: Sources/Engine/ChipSizing.swift

struct ChipSizingTests {
    @Test static func runAll() {
        expect(buyIn: 100, minimum: 5, [5, 10, 25])
        expect(buyIn: 100, minimum: 25, [25])
        expect(buyIn: 500, minimum: 5, [5, 10, 25, 50, 100])
        expect(buyIn: 1000, minimum: 25, [25, 50, 100, 250])
        expect(buyIn: 2000, minimum: 25, [25, 50, 100, 250, 500])
        expect(buyIn: 10000, minimum: 100, [100, 250, 500, 1000, 2000])
        expect(buyIn: 10000, minimum: 1000, [1000, 2000])
        expect(buyIn: 10000, minimum: 2000, [2000])
        expect(buyIn: 100, minimum: 15, [15, 25])          // custom minimum becomes its own chip
        expect(buyIn: 25, minimum: 25, [25])               // buy-in equal to the minimum

        // The starting chips ladder stops at the cap, and the cap is a preset.
        #expect(ChipSizing.startingChipOptions.max() == ChipSizing.maxStartingChips)
        #expect(ChipSizing.maxStartingChips == 10_000)
        #expect(ChipSizing.startingChipOptions == ChipSizing.startingChipOptions.sorted())
        // Every minimum must fit inside the largest starting chips, several times over.
        #expect((ChipSizing.minimumOptions.max() ?? 0) * 5 <= ChipSizing.maxStartingChips)
        // Chip labels carry no currency symbol.
        #expect(ChipSizing.label(25) == "25" && ChipSizing.label(2000) == "2K" && ChipSizing.label(0.1) == "0.10")

        // Invariants across every lobby combination.
        for buyIn in ChipSizing.startingChipOptions {
            for minimum in ChipSizing.minimumOptions where minimum <= buyIn {
                let tray = ChipSizing.denominations(buyIn: buyIn, tableMinimum: minimum)
                #expect(tray.first == minimum, "smallest chip must be the minimum (\(buyIn)/\(minimum): \(tray))")
                #expect((1...5).contains(tray.count), "tray must hold 1 to 5 chips (\(tray))")
                #expect(tray == tray.sorted() && Set(tray).count == tray.count, "tray must be ascending and unique (\(tray))")
                if tray.count > 1 {
                    #expect(tray.last! * ChipSizing.buyInToTopChipRatio <= buyIn + 0.01,
                                 "top chip too big for the buy-in (\(buyIn)/\(minimum): \(tray))")
                }
            }
        }
    }

    private static func expect(buyIn: Double, minimum: Double, _ expected: [Double]) {
        let tray = ChipSizing.denominations(buyIn: buyIn, tableMinimum: minimum)
        #expect(tray == expected, "buy-in \(buyIn), minimum \(minimum): expected \(expected), got \(tray)")
    }
}
