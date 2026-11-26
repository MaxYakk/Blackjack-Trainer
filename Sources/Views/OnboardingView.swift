import SwiftUI

/// The welcome screen, shown as a full-screen cover on first launch. One
/// primary action (start training) and one optional detour (learn the basics).
struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var showTutorial = false

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
        .presentationBackground(Color.bg)
        .fullScreenCover(isPresented: $showTutorial) {
            // Finishing the tutorial also finishes the welcome screen.
            BeginnerBlackjackTutorial(onFinish: onComplete)
        }
    }

    private var actions: some View {
        VStack(spacing: Space.sm) {
            Button(action: onComplete) {
                HStack(spacing: Space.xs) {
                    Text("Start training")
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("onboardingGetStarted")

            SecondaryButton("New to blackjack? Learn the basics") {
                showTutorial = true
            }
            .accessibilityIdentifier("onboardingLearnBasics")

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
