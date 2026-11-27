import SwiftUI

/// The app tour: seven short pages that show what Hit Me can do. New players
/// see it on first launch, right after the welcome screen. It can be replayed
/// any time (for example from Settings):
///
///     .fullScreenCover(isPresented: $showTour) {
///         AppTourView { showTour = false }
///     }
///
/// There is no Skip or Close button: the only way out is Done on the last
/// page, which calls `onFinish`. The caller decides what happens next (the
/// welcome flow moves on to the basics offer; a replay just closes).
/// Swipe or use Back / Next to move between pages.
struct AppTourView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentPage = 0

    private let pages = AppTourPage.pages
    private var isLastPage: Bool { currentPage == pages.count - 1 }

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    AppTourPageView(page: page, isActive: index == currentPage)
                        .tag(index)
                        // Only the visible page is read by VoiceOver.
                        .accessibilityHidden(index != currentPage)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            AppTourDots(count: pages.count, current: currentPage, onStep: go)
                .padding(.vertical, Space.sm)

            footer
        }
        .background(Color.bg.ignoresSafeArea())
        .presentationBackground(Color.bg)
        .interactiveDismissDisabled()
        .onChange(of: currentPage) { _, page in
            announce(page)
        }
    }

    private var header: some View {
        HStack {
            Text("What you can do")
                .font(.overline)
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(.accent)
            Spacer()
            Text("\(currentPage + 1) of \(pages.count)")
                .font(.captionText.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.textTertiary)
                // The page dots already read the position.
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.sm)
        .padding(.bottom, Space.xxs)
    }

    private var footer: some View {
        HStack(spacing: Space.sm) {
            if currentPage > 0 {
                SecondaryButton("Back") { go(to: currentPage - 1) }
                    .frame(maxWidth: 120)
                    .accessibilityIdentifier("appTourBack")
            }

            Button(action: advance) {
                HStack(spacing: Space.xs) {
                    Text(isLastPage ? "Done" : "Next")
                    Image(systemName: isLastPage ? "checkmark" : "arrow.right")
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.primary)
            .accessibilityHint(isLastPage ? "Finishes the tour" : "Shows the next page")
            .accessibilityIdentifier(isLastPage ? "appTourDone" : "appTourNext")
        }
        .padding(.horizontal, Space.lg)
        .padding(.bottom, Space.md)
    }

    private func advance() {
        if isLastPage {
            onFinish()
        } else {
            go(to: currentPage + 1)
        }
    }

    private func go(to page: Int) {
        guard pages.indices.contains(page) else { return }
        Motion.perform(.standard, reduceMotion: reduceMotion) { currentPage = page }
    }

    /// Tells VoiceOver which page is now showing, whether the player tapped
    /// Next, swiped, or adjusted the page dots.
    private func announce(_ page: Int) {
        guard pages.indices.contains(page) else { return }
        AccessibilityNotification.Announcement(
            "Page \(page + 1) of \(pages.count). \(pages[page].title)"
        ).post()
    }
}

/// Page indicator that VoiceOver reads as one adjustable element
/// ("Tour progress, Page 2 of 7").
private struct AppTourDots: View {
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
        .accessibilityLabel("Tour progress")
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

/// One page: where the feature lives, a title, a one-line summary, a small
/// demo built from real table pieces, and two short points. Scrolls when
/// Dynamic Type makes it taller than the screen.
private struct AppTourPageView: View {
    let page: AppTourPage
    let isActive: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(page.place)
                        .font(.overline)
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(.textTertiary)
                    Text(page.title)
                        .font(.sectionTitle)
                        .foregroundStyle(.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.summary)
                        .font(.bodyText)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppTourDemo(demo: page.demo, isActive: isActive)
                    .frame(maxWidth: .infinity)
                    .panel()
                    // The demo is a picture of the feature: never tappable,
                    // read by VoiceOver as one plain description.
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(page.demoDescription)
                    .accessibilityAddTraits(.isImage)

                VStack(alignment: .leading, spacing: Space.sm) {
                    ForEach(page.points, id: \.self) { point in
                        HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.calloutText)
                                .foregroundStyle(.accent)
                                .accessibilityHidden(true)
                            Text(point)
                                .font(.calloutText)
                                .foregroundStyle(.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if page.demo == .table {
                    Text(PracticeNotice.line)
                        .font(.captionText.weight(.semibold))
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("appTourPracticeNotice")
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.sm)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}
