# Blackjack Trainer — iOS App

A native SwiftUI card-counting & strategy trainer. Five tabs:

- **Play** — a real felt table with chips, a play-money bankroll, and selectable table minimums.
  Deals are animated with sound + haptics. Grades every decision against basic strategy, and grades
  your **bet size against the true count** (bet-spread training). Optional: mid-hand "what's the count?"
  checks, count-based **deviations (Illustrious 18)** grading, and a betting-hints toggle.
- **Quiz** — rapid-fire basic-strategy drills: hand + dealer card → Hit/Stand/Double/Split, instant
  feedback, streak tracking.
- **Count** — Hi-Lo counting drill (multi-deck, true-count practice).
- **Strategy** — full hard/soft/pairs chart + the Illustrious 18 deviation reference.
- **Progress** — persistent stats: strategy/quiz/bet/count accuracy, hands W/L, a bankroll curve,
  an accuracy-over-time chart, and achievements. All saved on-device (upgrade-safe decoding).

## Open it

```bash
open blackjack-trainer-ios/BlackjackTrainer.xcodeproj
```

(The Xcode project is already generated. If you ever edit `project.yml`, regenerate with `xcodegen generate`.)

## Run on the iOS Simulator

Just press the ▶︎ Run button in Xcode (or pick any iPhone simulator). No setup needed.

## Run on YOUR iPhone

1. Plug your iPhone into the Mac.
2. In Xcode: **Settings → Accounts → +** and sign in with your Apple ID (free is fine).
3. Select the **BlackjackTrainer** target → **Signing & Capabilities** tab →
   set **Team** to your Apple ID. Leave "Automatically manage signing" checked.
   - If it complains the bundle id is taken, change `PRODUCT_BUNDLE_IDENTIFIER`
     in `project.yml` to something unique (e.g. `com.YOURNAME.blackjack`), then run `xcodegen generate`.
4. At the top of Xcode, choose your iPhone as the run destination, press ▶︎ Run.
5. On the iPhone: **Settings → General → VPN & Device Management** → tap your
   developer profile → **Trust**. Launch the app from your home screen.

### Free vs paid Apple account
- **Free Apple ID:** the app works but the signing expires after **7 days** — just re-run
  from Xcode to renew it.
- **Apple Developer Program ($99/yr):** permanent installs, plus TestFlight and App Store distribution.

## Project layout
- `Sources/Engine/` — cards, hand evaluation, Hi-Lo counting, basic-strategy tables, game + drill engines
- `Sources/Store/Stats.swift` — persistent progress tracking (saved via UserDefaults)
- `Sources/Views/` — the four tabs: Play, Count Drill, Strategy chart, Progress
- `Resources/Assets.xcassets/` — app icon + accent color
- `project.yml` — XcodeGen project definition
