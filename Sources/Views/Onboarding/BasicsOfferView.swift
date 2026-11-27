import SwiftUI

/// The last onboarding step, after the app tour: an optional offer of the
/// "how blackjack works" tutorial for players who don't know the rules yet.
struct BasicsOfferView: View {
    let onStartTraining: () -> Void
    let onLearnBasics: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat = 112

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Space.lg) {
                    Spacer(minLength: Space.md)

                    Image(systemName: "graduationcap.fill")
                        .scaledFont(size: 44, weight: .medium, design: .default,
                                    relativeTo: .largeTitle, maxSize: 64)
                        .foregroundStyle(.accent)
                        .frame(width: badgeSize, height: badgeSize)
                        .background(.positiveBg, in: Circle())
                        .accessibilityHidden(true)

                    VStack(spacing: Space.sm) {
                        Text("New to blackjack?")
                            .font(.display)
                            .foregroundStyle(.textPrimary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text("A short lesson covers card values, betting, and what Hit, Stand, Double and Split mean. If you already know the rules, jump straight in.")
                            .font(.bodyText)
                            .foregroundStyle(.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Space.lg)

                    VStack(spacing: Space.sm) {
                        Button(action: onStartTraining) {
                            HStack(spacing: Space.xs) {
                                Text("Start training")
                                Image(systemName: "arrow.right")
                                    .accessibilityHidden(true)
                            }
                        }
                        .buttonStyle(.primary)
                        .accessibilityIdentifier("onboardingStartTraining")

                        SecondaryButton("Learn the basics first") {
                            onLearnBasics()
                        }
                        .accessibilityHint("Opens a short tutorial on the rules of blackjack")
                        .accessibilityIdentifier("onboardingLearnBasics")
                    }
                }
                .padding(.horizontal, Space.lg)
                .padding(.vertical, Space.md)
                .frame(minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.bg.ignoresSafeArea())
    }
}
