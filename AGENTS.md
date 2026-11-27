# Hit Me (blackjack trainer) engineering instructions

## Project

"Hit Me" (App Store: "Hit Me: Blackjack Coach"; Xcode target and bundle id keep the name BlackjackTrainer). Native SwiftUI iOS app (iOS 17+, Swift language mode 5, iPhone) that trains blackjack basic strategy, Hi-Lo card counting and bet sizing with practice chips. No backend, no accounts, no network; all progress is stored on-device in `UserDefaults`. The goal is an App Store release under the Vyne Events LLC developer account, so App Store Review Guideline 5.3 (gambling) matters: the app must read as a skills trainer with play-money chips, never as real-money gambling.

- `Sources/Engine/`: game rules and drills. `BasicStrategy.swift` (charts, Illustrious 18 deviations), `PlayEngine.swift` (table, rounds, grading, settlement), `Cards.swift` (shoe, Hi-Lo), `BetSizing.swift`, `ChipSizing.swift`, quiz/count/daily-challenge engines.
- `Sources/Store/`: persistence and derived progress (`Stats.swift`, `Achievements.swift`, `ProgressMetrics.swift`, `SkillRating.swift`, `ReminderScheduler.swift`).
- `Sources/Views/`: SwiftUI screens. `DesignSystem/` holds the Night ink tokens and shared components (see Design system below); `Money.swift` holds the chip-amount formatter; `Theme.swift` is only legacy color aliases.
- `Tests/`: Swift Testing unit tests (`import Testing`, `@testable import BlackjackTrainer`). `UITests/`: XCUITest flows.
- `project.yml` is the source of truth for the Xcode project (XcodeGen). Edit it, then run `xcodegen generate`; never hand-edit `project.pbxproj`. New files under `Sources/`, `Tests/` or `UITests/` are picked up by regenerating.

## Engineering

- Trace view → engine/store before changing behavior; fix root causes. Follow nearby conventions; extend the existing structure instead of rewriting it.
- Keep observable state on the main actor. Saved data must stay upgrade-safe: new fields decode with defaults, and a decode failure must never silently wipe a player's progress.
- Strategy and counting content must be correct for the rules the app says it uses. Check charts and index plays against published references, not memory.
- Use the design-system tokens and components, never raw colors or fixed font sizes. Add accessibility labels, respect Dynamic Type and Reduce Motion.
- Act as coordinating engineer for large work: split it into independent pieces with clear file ownership; avoid two agents editing the same files.

## Design system ("Night ink")

Flat, calm, dark training-app look: no gradients, no glows, no green felt. Everything lives in `Sources/Views/DesignSystem/`; `DesignSystemPreview.swift` (DEBUG, `#Preview`) shows every token and component.

- **Rule:** use tokens and components, never raw colors (`Color(red:)`, `.white.opacity`, `.black.opacity`, `.orange`, `.gray`) or fixed font sizes (`.system(size:)`). Don't add new `Theme.*` uses; those names are legacy aliases to be removed as screens are redesigned.
- **Colors** (`Colors.swift`, usable as `.foregroundStyle(.textSecondary)` or `Color.surface`): `bg`, `surface`, `surfaceRaised`, `surfaceSubtle`, `divider`, `scrim`, `shadowColor`, `textPrimary/Secondary/Tertiary`, `accent` + `onAccent` (mint), `positive`/`positiveBg`, `negative`/`negativeBg`, `warm`/`warmBg` (coral: streaks), `warning`/`warningBg` (amber: "needs work", yellow "close" grades), `disabledFill`/`disabledText`, card colors, tier colors + `onTier`; `ChartColors` for the strategy chart.
- **Type** (`Typography.swift`): `.display`, `.sectionTitle`, `.heading`, `.bodyText`, `.calloutText`, `.detail`, `.captionText`, `.fine` (smallest allowed), `.overline`, `.buttonLabel`, `.statValue`, `.numberInline`, `.numberHero`; `.scaledFont(size:...)` when a size must be numeric.
- **Layout** (`Spacing.swift`): `Space.xxs…xl` (4/8/12/16/24/32), `Radius.small/medium/large` (8/12/16, `Capsule()` for pills), `Metrics` (44pt min tap target, button heights). **Motion** (`Motion.swift`): `.motion(.standard, value:)`, `Motion.perform`, `Motion.slide/pop` honor Reduce Motion.
- **Components** (`Components/`): `PrimaryButton` / `SecondaryButton` (or `.buttonStyle(.primary/.secondary)`), `DecisionPad` (Hit/Stand/Double/Split, optional Surrender), `DecisionButton`, `Panel` / `.panel()`, `StatTile`, `ProgressBar`, `SectionHeader`, `FeedbackPill`, `PageHeader`, `CardView`, `ChipView`, `ChipStack`.
- **Themed controls** (never the stock Apple look; see `Components/`): `.themedConfirm(_:isPresented:message:actions:)` with `ThemedAlertButton` (`.primary/.normal/.destructive/.cancel`) replaces `.alert` and `.confirmationDialog`; `.themedTextPrompt(...)` replaces alert-with-TextField; `SegmentedChoice(options, selection:, accessibilityLabel:) { label }` replaces `.pickerStyle(.segmented)`; `ThemedMenuPicker(title, selection:, options:) { label }` replaces `.pickerStyle(.menu)`; `.toggleStyle(.themed)` on every `Toggle`; `.buttonStyle(.destructive)` for red actions. Attach `themedConfirm`/`themedTextPrompt` to the screen's outermost view (inside the sheet's content when in a sheet).

## Verification

Do not launch or drive the iOS Simulator; the owner does visual checks on his phone. Instead:

```sh
scripts/logic-tests.sh                      # unit tests on macOS (engine + stores), no simulator
xcodebuild build-for-testing -project BlackjackTrainer.xcodeproj -scheme BlackjackTrainer \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO   # compiles app + all tests
```

Add focused regression tests for every behavior change in `Tests/`. Tests may only use Engine/, Store/ and `Money` from `Sources/Views/Money.swift`, because `scripts/logic-tests.sh` compiles just those. Report exactly what ran; never claim an unrun check passed.

## Git and communication

- Work on focused `claude/` branches; commit with conventional messages (`feat:`, `fix:`, ...). Never push, open PRs, or touch App Store Connect without explicit permission.
- Preserve other people's uncommitted work.
- The owner is not a technical coder: explain changes in plain language and what they mean for players, briefly say why significant decisions were made, and keep reports concise.
