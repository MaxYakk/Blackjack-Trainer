# Blackjack Trainer engineering instructions

## Project

Native SwiftUI iOS app (iOS 17+, Swift language mode 5, iPhone) that trains blackjack basic strategy, Hi-Lo card counting and bet sizing with practice chips. No backend, no accounts, no network; all progress is stored on-device in `UserDefaults`. The goal is an App Store release under the Vyne Events LLC developer account, so App Store Review Guideline 5.3 (gambling) matters: the app must read as a skills trainer with play-money chips, never as real-money gambling.

- `Sources/Engine/`: game rules and drills. `BasicStrategy.swift` (charts, Illustrious 18 deviations), `PlayEngine.swift` (table, rounds, grading, settlement), `Cards.swift` (shoe, Hi-Lo), `BetSizing.swift`, `ChipSizing.swift`, quiz/count/daily-challenge engines.
- `Sources/Store/`: persistence and derived progress (`Stats.swift`, `Achievements.swift`, `ProgressMetrics.swift`, `SkillRating.swift`, `ReminderScheduler.swift`).
- `Sources/Views/`: SwiftUI screens. `Theme.swift` holds the shared colors, `Money` formatter and card/chip components.
- `Tests/`: Swift Testing unit tests (`import Testing`, `@testable import BlackjackTrainer`). `UITests/`: XCUITest flows.
- `project.yml` is the source of truth for the Xcode project (XcodeGen). Edit it, then run `xcodegen generate`; never hand-edit `project.pbxproj`. New files under `Sources/`, `Tests/` or `UITests/` are picked up by regenerating.

## Engineering

- Trace view → engine/store before changing behavior; fix root causes. Follow nearby conventions; extend the existing structure instead of rewriting it.
- Keep observable state on the main actor. Saved data must stay upgrade-safe: new fields decode with defaults, and a decode failure must never silently wipe a player's progress.
- Strategy and counting content must be correct for the rules the app says it uses. Check charts and index plays against published references, not memory.
- Prefer shared `Theme` tokens and components over one-off colors and sizes. Add accessibility labels, respect Dynamic Type and Reduce Motion.
- Act as coordinating engineer for large work: split it into independent pieces with clear file ownership; avoid two agents editing the same files.

## Verification

Do not launch or drive the iOS Simulator; the owner does visual checks on his phone. Instead:

```sh
scripts/logic-tests.sh                      # unit tests on macOS (engine + stores), no simulator
xcodebuild build-for-testing -project BlackjackTrainer.xcodeproj -scheme BlackjackTrainer \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO   # compiles app + all tests
```

Add focused regression tests for every behavior change in `Tests/`. Tests may only use Engine/, Store/ and `Money` from `Theme.swift`, because `scripts/logic-tests.sh` compiles just those. Report exactly what ran; never claim an unrun check passed.

## Git and communication

- Work on focused `claude/` branches; commit with conventional messages (`feat:`, `fix:`, ...). Never push, open PRs, or touch App Store Connect without explicit permission.
- Preserve other people's uncommitted work.
- The owner is not a technical coder: explain changes in plain language and what they mean for players, briefly say why significant decisions were made, and keep reports concise.
