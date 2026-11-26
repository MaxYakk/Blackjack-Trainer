import SwiftUI

/// A 1pt divider line between rows inside a panel.
struct HairlineDivider: View {
    var body: some View {
        Rectangle()
            .fill(.divider)
            .frame(height: Metrics.hairline)
            .accessibilityHidden(true)
    }
}
