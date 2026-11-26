import SwiftUI

/// First launch, shown as a full-screen cover until it is completed:
/// the welcome screen, then the required app tour (`AppTourView`), then an
/// optional offer of the blackjack basics tutorial, then the app.
/// `onComplete` marks onboarding done; `RootView` never shows it again.
struct OnboardingView: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: OnboardingStep = .welcome
    @State private var showTutorial = false

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeScreen(onGetStarted: advance)
                    .transition(stepTransition)
            case .tour:
                AppTourView(onFinish: advance)
                    .transition(stepTransition)
            case .basicsOffer:
                BasicsOfferView(onStartTraining: onComplete,
                                onLearnBasics: { showTutorial = true })
                    .transition(stepTransition)
            }
        }
        .background(Color.bg.ignoresSafeArea())
        .presentationBackground(Color.bg)
        .fullScreenCover(isPresented: $showTutorial) {
            // Finishing the tutorial also finishes onboarding. Closing it
            // early returns to the offer, where Start training is waiting.
            BeginnerBlackjackTutorial(onFinish: onComplete)
        }
    }

    private var stepTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                          removal: .move(edge: .leading).combined(with: .opacity))
    }

    private func advance() {
        guard let next = step.next else {
            onComplete()
            return
        }
        Motion.perform(.standard, reduceMotion: reduceMotion) { step = next }
    }
}

/// The welcome screen: brand, a short promise, and one action that starts
/// the app tour.
private struct WelcomeScreen: View {
    let onGetStarted: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    OnboardingBrand()

                    WelcomeTableau()
                        .frame(height: min(max(proxy.size.height * 0.24, 150), 210))
                        .padding(.top, Space.md)

                    VStack(spacing: Space.sm) {
                        Text("Know the right move.")
                            .font(.display)
                            .foregroundStyle(.textPrimary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                            .accessibilityAddTraits(.isHeader)

                        Text("Practice blackjack decisions with clear feedback after every move.")
                            .font(.bodyText)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Space.md)

                    TrainingModes()
                        .padding(.top, Space.lg)

                    Spacer(minLength: Space.lg)

                    actions
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { OnboardingBackdrop() }
    }

    private var actions: some View {
        VStack(spacing: Space.sm) {
            Button(action: onGetStarted) {
                HStack(spacing: Space.xs) {
                    Text("Get started")
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.primary)
            .accessibilityHint("Shows a quick tour of the app")
            .accessibilityIdentifier("onboardingGetStarted")

            Text(PracticeNotice.line)
                .font(.captionText.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Space.xxs)
                .accessibilityIdentifier("practiceNotice")

            Label("Progress is saved on this device", systemImage: "lock.fill")
                .font(.captionText)
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
        }
    }
}

/// Flat navy base with a large, quiet spade watermark that is allowed to run
/// off the screen edge. Sized from the screen width so it never depends on a
/// fixed font size.
private struct OnboardingBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                Color.bg
                Image(systemName: "suit.spade.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: proxy.size.width * 0.85)
                    .foregroundStyle(.surfaceSubtle)
                    .rotationEffect(.degrees(-14))
                    .offset(x: -proxy.size.width * 0.28, y: proxy.size.width * 0.18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct OnboardingBrand: View {
    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "suit.spade.fill")
                .font(.captionText.weight(.bold))
                .foregroundStyle(.onAccent)
                .frame(width: 30, height: 30)
                .background(.accent, in: Circle())

            Text("Hit Me")
                .font(.heading)
                .foregroundStyle(.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hit Me")
    }
}
