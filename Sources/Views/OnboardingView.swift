import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                onboardingBackground

                ScrollView {
                    VStack(spacing: 0) {
                        brand

                        Spacer(minLength: 18)

                        WelcomeTableau()
                            .frame(height: min(max(proxy.size.height * 0.27, 178), 224))

                        VStack(spacing: 12) {
                            Text("Know the right move.")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .tracking(-0.8)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)

                            Text("Practice blackjack decisions with clear feedback after every move.")
                                .font(.system(.body, design: .rounded, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 26)

                        TrainingModes()
                            .padding(.top, 28)

                        Spacer(minLength: 24)

                        Button(action: onComplete) {
                            HStack(spacing: 10) {
                                Text("Start training")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.cardBlack)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboardingGetStarted")
                        .padding(.horizontal, 24)

                        Text(PracticeNotice.line)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .accessibilityIdentifier("practiceNotice")

                        Label("Progress is saved on this device", systemImage: "lock.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 8)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.felt, Theme.feltDark, Color(red: 0.018, green: 0.075, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Theme.accent.opacity(0.06))
                .frame(width: 420, height: 420)
                .blur(radius: 10)
                .offset(x: 170, y: -290)

            Text("\u{2660}")
                .font(.system(size: 310, weight: .black))
                .foregroundStyle(.black.opacity(0.08))
                .rotationEffect(.degrees(-14))
                .offset(x: -150, y: 285)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.cardBlack)
            }
            .frame(width: 30, height: 30)

            Text("HIT ME")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.88))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hit Me")
    }
}

private struct WelcomeTableau: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 90)
                .stroke(Theme.accent.opacity(0.22), lineWidth: 1)
                .frame(width: 310, height: 166)

            RoundedRectangle(cornerRadius: 76)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .frame(width: 274, height: 132)

            CardView(card: Card(rank: .ace, suit: .spades), size: 1.55)
                .rotationEffect(.degrees(-9))
                .offset(x: -36, y: 6)

            CardView(card: Card(rank: .king, suit: .hearts), size: 1.55)
                .rotationEffect(.degrees(8))
                .offset(x: 38, y: 3)

            ChipView(value: 25, size: 50)
                .rotationEffect(.degrees(-12))
                .offset(x: -108, y: 64)

            ChipView(value: 100, size: 42)
                .rotationEffect(.degrees(10))
                .offset(x: 112, y: 59)

            Text("21")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Theme.cardBlack)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Theme.accent, in: Capsule())
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                .offset(y: 72)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

private struct TrainingModes: View {
    private let modes = [
        ("suit.spade.fill", "Real hands"),
        ("bolt.fill", "Fast drills"),
        ("chart.line.uptrend.xyaxis", "Clear progress")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                VStack(spacing: 8) {
                    Image(systemName: mode.0)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(height: 20)

                    Text(mode.1)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity)

                if index < modes.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.13))
                        .frame(width: 1, height: 34)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 22)
        .accessibilityElement(children: .contain)
    }
}
