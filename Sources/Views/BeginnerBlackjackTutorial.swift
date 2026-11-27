import SwiftUI

/// The five-page "how blackjack works" walkthrough. Presented full screen from
/// the Play menu and from the last onboarding step (after the app tour).
/// Swipe or use Back / Continue.
struct BeginnerBlackjackTutorial: View {
    /// Called after the last page's button closes the tutorial. Onboarding
    /// flow uses it to finish onboarding too.
    var onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0

    private let pages = BeginnerTutorialPage.pages
    private var isLastPage: Bool { currentPage == pages.count - 1 }

    init(onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    TutorialPageContent(page: pages[index])
                        .tag(index)
                        // Only the visible page is read by VoiceOver.
                        .accessibilityHidden(index != currentPage)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            TutorialPageDots(count: pages.count, current: currentPage, onStep: go)
                .padding(.vertical, Space.md)

            footer
        }
        .background(Color.bg.ignoresSafeArea())
        .presentationBackground(Color.bg)
    }

    private var header: some View {
        HStack {
            Text("Learn the game")
                .font(.overline)
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(.accent)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.heading)
                    .foregroundStyle(.textSecondary)
                    .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Close tutorial")
            .accessibilityIdentifier("tutorialClose")
        }
        .padding(.leading, Space.lg)
        .padding(.trailing, Space.xs)
        .padding(.top, Space.xxs)
    }

    private var footer: some View {
        HStack(spacing: Space.sm) {
            if currentPage > 0 {
                SecondaryButton("Back") { go(to: currentPage - 1) }
                    .frame(maxWidth: 120)
                    .accessibilityIdentifier("tutorialBack")
            }

            Button(action: advance) {
                if isLastPage {
                    Label("Try a hand", systemImage: "suit.spade.fill")
                } else {
                    HStack(spacing: Space.xs) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier(isLastPage ? "tutorialDone" : "tutorialNext")
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
    }

    private func advance() {
        if isLastPage {
            dismiss()
            onFinish?()
        } else {
            go(to: currentPage + 1)
        }
    }

    private func go(to page: Int) {
        guard pages.indices.contains(page) else { return }
        Motion.perform(.standard, reduceMotion: reduceMotion) { currentPage = page }
    }
}

/// Page indicator that VoiceOver reads as one adjustable element
/// ("Tutorial progress, Page 2 of 5").
private struct TutorialPageDots: View {
    let count: Int
    let current: Int
    let onStep: (Int) -> Void

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accent : Color.textTertiary)
                    .frame(width: index == current ? Space.lg : Space.xs, height: Space.xs)
            }
        }
        .motion(.standard, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tutorial progress")
        .accessibilityValue("Page \(current + 1) of \(count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onStep(current + 1)
            case .decrement: onStep(current - 1)
            @unknown default: break
            }
        }
    }
}

private struct TutorialPageContent: View {
    let page: BeginnerTutorialPage

    @ScaledMetric(relativeTo: .largeTitle) private var badgeSize: CGFloat = 112

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                Image(systemName: page.icon)
                    .scaledFont(size: 44, weight: .medium, design: .default,
                                relativeTo: .largeTitle, maxSize: 64)
                    .foregroundStyle(.accent)
                    .frame(width: badgeSize, height: badgeSize)
                    .background(.positiveBg, in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: Space.xs) {
                    Text(page.title)
                        .font(.sectionTitle)
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.summary)
                        .font(.bodyText)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Panel(spacing: Space.md) {
                    ForEach(page.points, id: \.title) { point in
                        HStack(alignment: .top, spacing: Space.sm) {
                            Image(systemName: point.icon)
                                .font(.heading)
                                .foregroundStyle(.accent)
                                .frame(width: Space.lg)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                Text(point.title)
                                    .font(.calloutText.weight(.bold))
                                    .foregroundStyle(.textPrimary)
                                Text(point.detail)
                                    .font(.calloutText)
                                    .foregroundStyle(.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.md)
        }
        .scrollIndicators(.hidden)
    }
}
