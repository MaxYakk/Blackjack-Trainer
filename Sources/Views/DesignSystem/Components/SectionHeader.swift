import SwiftUI

// MARK: - Section header
//
// Title (and optional one-line subtitle) above a group of content, with an
// optional trailing accessory such as a "See all" button.
//
//     SectionHeader("Your leaks", subtitle: "Spots you miss most")
//     SectionHeader("Achievements") { Text("12/30").foregroundStyle(.textSecondary) }
//
// Marked as a header for VoiceOver's rotor.

struct SectionHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing

    init(_ title: String, subtitle: String? = nil,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            VStack(alignment: .leading, spacing: Space.xxs / 2) {
                Text(title)
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.detail)
                        .foregroundStyle(.textSecondary)
                }
            }
            Spacer(minLength: Space.xs)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
