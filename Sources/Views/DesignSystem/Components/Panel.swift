import SwiftUI

// MARK: - Panel
//
// The card/container every grouped block of content sits in.
//
//     Panel { Text("Today") ; ProgressBar(value: 0.4) }
//     VStack { ... }.panel()                    // same look, as a modifier
//     VStack { ... }.panel(.subtle, padding: Space.sm)
//
// Flat: a filled rounded rectangle, no border, no shadow.

enum PanelStyle {
    /// `surface` on the screen background. The default.
    case surface
    /// `surfaceRaised`, for a panel inside a panel or a highlighted block.
    case raised
    /// `surfaceSubtle`, for quiet tiles and grouped rows.
    case subtle

    var fill: Color {
        switch self {
        case .surface: return .surface
        case .raised: return .surfaceRaised
        case .subtle: return .surfaceSubtle
        }
    }
}

struct Panel<Content: View>: View {
    var style: PanelStyle = .surface
    var padding: CGFloat = Space.md
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = Space.sm
    @ViewBuilder let content: Content

    init(_ style: PanelStyle = .surface,
         padding: CGFloat = Space.md,
         alignment: HorizontalAlignment = .leading,
         spacing: CGFloat = Space.sm,
         @ViewBuilder content: () -> Content) {
        self.style = style
        self.padding = padding
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) { content }
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
            .panel(style, padding: padding)
    }
}

extension View {
    /// Pads the view and puts it on a rounded panel fill.
    func panel(_ style: PanelStyle = .surface,
               padding: CGFloat = Space.md,
               cornerRadius: CGFloat = Radius.large) -> some View {
        self
            .padding(padding)
            .background(style.fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
