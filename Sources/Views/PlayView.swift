import SwiftUI

struct PlayView: View {
    @Environment(Stats.self) private var stats
    @State private var engine: PlayEngine?
    /// Chips returned after an interrupted hand, shown once on the table.
    @State private var refundedChips = 0.0

    var body: some View {
        Group {
            if let engine {
                if engine.sessionActive {
                    PlayContent(engine: engine, refundedChips: $refundedChips)
                } else {
                    SessionSetupView(engine: engine)
                }
            } else {
                Color.bg.ignoresSafeArea()
            }
        }
        .onAppear {
            if engine == nil {
                engine = PlayEngine(stats: stats)
                refundedChips = stats.refundedWagerOnLaunch
            }
        }
    }
}

/// The table screen, top to bottom: header (End session, title, ?, gear),
/// session numbers, the table panel, and the fixed-height control dock.
private struct PlayContent: View {
    @Bindable var engine: PlayEngine
    @Binding var refundedChips: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showOptions = false
    @State private var showTutorial = false
    @State private var showEndSession = false

    // Round-result effects, triggered when the round settles.
    @State private var winToast: RoundOutcome?
    @State private var confettiSeed = 0
    @State private var confettiActive = false
    @State private var lossFlash = false
    /// Bumped every time a round settles, so a delayed effect from one round
    /// can't fire on (or clear) the next one.
    @State private var settledRound = 0

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            VStack(spacing: Space.xs) {
                PlayHeader(
                    canEndSession: engine.canCashOut,
                    onEndSession: { showEndSession = true },
                    onHelp: { showTutorial = true },
                    onOptions: { showOptions = true }
                )
                PlayStatsStrip(engine: engine)
                PlayTableView(engine: engine, refundedChips: refundedChips, lossFlash: lossFlash)
                    .overlay(alignment: .top) { toastLayer }
                    .padding(.horizontal, Space.md)
                ControlDock(engine: engine)
                    .padding(.horizontal, Space.md)
                    .padding(.bottom, Space.xs)
            }
            // The table is a fixed-height layout: cap text growth here only
            // (the setup screen and sheets scale freely).
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .accessibilityHidden(showEndSession)

            if confettiActive {
                ConfettiBurstView(seed: confettiSeed)
            }
            endSessionOverlay
        }
        .motion(.standard, value: showEndSession)
        .sheet(isPresented: $showOptions) {
            SettingsSheet(engine: engine)
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showTutorial) {
            BeginnerBlackjackTutorial()
        }
        .onChange(of: engine.phase) { _, phase in
            if phase != .betting { refundedChips = 0 }   // the returned-chips note shows once
            roundSettled(phase)
        }
        .onChange(of: engine.canCashOut) { _, canCashOut in
            if !canCashOut { showEndSession = false }
        }
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let winToast {
            WinToastView(outcome: winToast)
                .padding(.top, Space.xs)
                .transition(Motion.pop(reduceMotion))
        }
    }

    /// Confirmation centered over the table. Modal for VoiceOver; the scrim
    /// and the escape gesture both mean "Keep playing".
    @ViewBuilder
    private var endSessionOverlay: some View {
        if showEndSession {
            Color.scrim
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { showEndSession = false }
                .accessibilityHidden(true)
            EndSessionConfirmCard(
                amount: Money.chips(engine.bankroll),
                onConfirm: {
                    engine.cashOut()
                    showEndSession = false
                },
                onCancel: { showEndSession = false }
            )
            .transition(Motion.pop(reduceMotion))
        }
    }

    /// Starts the win toast (and confetti for a natural) or the loss edge when
    /// a round settles, announces the result to VoiceOver, and clears every
    /// effect the moment the next round starts.
    private func roundSettled(_ phase: GamePhase) {
        guard phase == .done else {
            winToast = nil
            confettiActive = false
            lossFlash = false
            return
        }
        settledRound += 1
        let round = settledRound
        let outcome = RoundOutcome(engine: engine)
        Task { @MainActor in
            // Let any move feedback be spoken first.
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard isCurrent(round) else { return }
            AccessibilityNotification.Announcement(outcome.announcement).post()
        }
        switch outcome.kind {
        case .win, .blackjack:
            showWinToast(outcome, round: round)
        case .loss:
            Motion.perform(.quick, reduceMotion: reduceMotion) { lossFlash = true }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard settledRound == round else { return }
                Motion.perform(.standard, reduceMotion: reduceMotion) { lossFlash = false }
            }
        case .push:
            break
        }
    }

    /// True while `round` is still the settled round on the table.
    private func isCurrent(_ round: Int) -> Bool {
        settledRound == round && engine.phase == .done
    }

    private func showWinToast(_ outcome: RoundOutcome, round: Int) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: WinCelebrationPolicy.bannerDelayNanoseconds)
            guard isCurrent(round) else { return }
            Motion.perform(.spring, reduceMotion: reduceMotion) { winToast = outcome }
            confettiActive = WinCelebrationPolicy.showsConfetti(
                hasBlackjack: outcome.kind == .blackjack,
                reduceMotion: reduceMotion
            )
            if confettiActive { confettiSeed += 1 }

            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard settledRound == round else { return }
            Motion.perform(.standard, reduceMotion: reduceMotion) {
                winToast = nil
                confettiActive = false
            }
        }
    }
}
