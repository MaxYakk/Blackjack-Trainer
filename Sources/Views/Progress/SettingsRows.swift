import SwiftUI

/// A titled group of rows on a panel, with an optional footnote underneath.
/// Put a `HairlineDivider` between rows.
struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(.overline)
                .textCase(.uppercase)
                .foregroundStyle(.textSecondary)
                .padding(.horizontal, Space.xs)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            if let footer {
                Text(footer)
                    .font(.detail)
                    .foregroundStyle(.textTertiary)
                    .padding(.horizontal, Space.xs)
            }
        }
    }
}

/// Padding and minimum height shared by every settings row.
private struct SettingsRowFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm)
            .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
    }
}

extension View {
    func settingsRowFrame() -> some View { modifier(SettingsRowFrame()) }
}

/// Title (and optional subtitle) on the left, an arbitrary view on the right.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let trailing: Trailing

    init(_ title: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Space.sm) {
            VStack(alignment: .leading, spacing: Space.xxs / 2) {
                Text(title)
                    .font(.bodyText)
                    .foregroundStyle(.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.detail)
                        .foregroundStyle(.textSecondary)
                }
            }
            Spacer(minLength: Space.xs)
            trailing
        }
        .settingsRowFrame()
    }
}

/// A row that opens another screen or a web page: title, optional icon, chevron.
struct SettingsLinkLabel: View {
    let title: String
    var systemImage: String?
    var trailingImage = "chevron.right"

    var body: some View {
        HStack(spacing: Space.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.bodyText)
                    .foregroundStyle(.accent)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.bodyText)
                .foregroundStyle(.textPrimary)
            Spacer(minLength: Space.xs)
            Image(systemName: trailingImage)
                .font(.captionText.weight(.semibold))
                .foregroundStyle(.textTertiary)
                .accessibilityHidden(true)
        }
        .settingsRowFrame()
        .contentShape(Rectangle())
    }
}
