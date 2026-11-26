import Foundation

// Headless check of the chip tray rule: smallest chip = table minimum,
// largest = biggest ladder chip that fits into the buy-in four times.
//
// Compile alongside: Sources/Engine/ChipSizing.swift

@main
struct ChipSizingTests {
    static func main() {
        expect(buyIn: 100, minimum: 5, [5, 10, 25])
        expect(buyIn: 100, minimum: 25, [25])
        expect(buyIn: 500, minimum: 5, [5, 10, 25, 50, 100])
        expect(buyIn: 1000, minimum: 25, [25, 50, 100, 250])
        expect(buyIn: 2000, minimum: 25, [25, 50, 100, 250, 500])
        expect(buyIn: 10000, minimum: 100, [100, 250, 500, 1000, 2000])
        expect(buyIn: 500_000, minimum: 1000, [1000, 5000, 10000, 25000, 100000])
        expect(buyIn: 100, minimum: 15, [15, 25])          // custom minimum becomes its own chip
        expect(buyIn: 25, minimum: 25, [25])               // buy-in equal to the minimum

        // Invariants across every lobby combination.
        let buyIns: [Double] = [25, 50, 100, 250, 500, 1000, 2000, 5000, 10_000, 25_000, 50_000, 100_000, 250_000, 500_000]
        for buyIn in buyIns {
            for minimum in ChipSizing.minimumOptions where minimum <= buyIn {
                let tray = ChipSizing.denominations(buyIn: buyIn, tableMinimum: minimum)
                precondition(tray.first == minimum, "smallest chip must be the minimum (\(buyIn)/\(minimum): \(tray))")
                precondition((1...5).contains(tray.count), "tray must hold 1 to 5 chips (\(tray))")
                precondition(tray == tray.sorted() && Set(tray).count == tray.count, "tray must be ascending and unique (\(tray))")
                if tray.count > 1 {
                    precondition(tray.last! * ChipSizing.buyInToTopChipRatio <= buyIn + 0.01,
                                 "top chip too big for the buy-in (\(buyIn)/\(minimum): \(tray))")
                }
            }
        }
        print("ChipSizingTests passed")
    }

    private static func expect(buyIn: Double, minimum: Double, _ expected: [Double]) {
        let tray = ChipSizing.denominations(buyIn: buyIn, tableMinimum: minimum)
        precondition(tray == expected, "buy-in \(buyIn), minimum \(minimum): expected \(expected), got \(tray)")
    }
}
