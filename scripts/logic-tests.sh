#!/bin/zsh
# Runs the unit tests in Tests/ on this Mac, without a simulator.
#
# It builds a throwaway Swift package (outside the repo) that compiles the
# game engine, the stores and Views/Money.swift (for `Money`) together with the test
# files, then runs `swift test`. Other views are left out, so
# tests must only touch Engine/, Store/ and `Money`.
#
# Usage: scripts/logic-tests.sh [extra swift test args, e.g. --filter Spot]
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${TMPDIR:-/tmp}/blackjack-logic-tests-$(echo "$REPO" | shasum | cut -c1-8)"

rm -rf "$WORK/Sources" "$WORK/Tests"
mkdir -p "$WORK/Sources/BlackjackTrainer" "$WORK/Tests/BlackjackTrainerTests"

for f in "$REPO"/Sources/Engine/*.swift "$REPO"/Sources/Store/*.swift "$REPO/Sources/Views/Money.swift"; do
  ln -s "$f" "$WORK/Sources/BlackjackTrainer/"
done
for f in "$REPO"/Tests/*.swift; do
  ln -s "$f" "$WORK/Tests/BlackjackTrainerTests/"
done

cat > "$WORK/Package.swift" <<'SWIFT'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlackjackTrainer",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BlackjackTrainer",
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "BlackjackTrainerTests",
                    dependencies: ["BlackjackTrainer"],
                    swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
SWIFT

cd "$WORK"
swift test "$@"
