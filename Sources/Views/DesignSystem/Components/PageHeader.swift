import SwiftUI

// MARK: - Page header
//
// A lightweight inline title bar used in place of a NavigationStack.
// (Multiple NavigationStacks inside a paged TabView crash UIKit on swipe.)
//
//     PageHeader("Progress") { Button { ... } label: { Image(systemName: "gearshape") } }
//
// The title is centered and marked as a header for VoiceOver; the trailing
// accessory sits at the right edge. At least 44pt tall.

struct PageHeader<Trailing: View>: View {
    let title: String
    let titleFont: Font
    @ViewBuilder let trailing: Trailing

    init(
        _ title: String,
        titleFont: Font = .heading,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.titleFont = titleFont
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(titleFont)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Spacer()
                trailing
            }
            .padding(.horizontal, Space.md)
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
        .padding(.top, Space.xxs)
        .padding(.bottom, Space.xs)
    }
}
