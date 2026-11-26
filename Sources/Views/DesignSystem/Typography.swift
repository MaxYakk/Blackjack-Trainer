import SwiftUI

// MARK: - Type scale
//
// Every font is built on a Dynamic Type text style, so it grows and shrinks
// with the player's text-size setting. Rounded design for display text and
// numbers (friendly, "training app"), default design for reading text.
//
//     Text("Progress").font(.display)
//     Text("Today").font(.sectionTitle)
//     Text("1,250").font(.statValue)
//
// Never use `.font(.system(size: N))` in a screen. If a size truly has to be
// numeric (a giant result number, a glyph inside a graphic), use
// `.scaledFont(size:weight:relativeTo:)` below, which still follows Dynamic Type.

extension Font {
    /// Screen titles and hero headings. largeTitle, rounded, bold.
    static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    /// Section and sheet titles. title2, rounded, bold.
    static let sectionTitle = Font.system(.title2, design: .rounded, weight: .bold)
    /// Card titles, page-header titles, emphasized rows. headline, rounded.
    static let heading = Font.system(.headline, design: .rounded, weight: .semibold)
    /// Reading text. body.
    static let bodyText = Font.body
    /// Secondary reading text, list rows. callout.
    static let calloutText = Font.callout
    /// Supporting explanation under a control. footnote.
    static let detail = Font.footnote
    /// Labels on tiles, captions, fine print. caption.
    static let captionText = Font.caption
    /// Smallest allowed text: tiny tile labels. caption2 (never go below this).
    static let fine = Font.caption2
    /// Small uppercase-style labels ("CHIPS", "TRUE COUNT"). caption2, semibold.
    static let overline = Font.system(.caption2, design: .rounded, weight: .semibold)

    /// Button labels. headline, rounded, semibold.
    static let buttonLabel = Font.system(.headline, design: .rounded, weight: .semibold)
    /// Smaller button labels (secondary/compact). subheadline, rounded, semibold.
    static let buttonLabelSmall = Font.system(.subheadline, design: .rounded, weight: .semibold)

    /// Numbers in stat tiles. title2, rounded, bold, tabular digits.
    static let statValue = Font.system(.title2, design: .rounded, weight: .bold).monospacedDigit()
    /// Inline numbers in rows (counts, totals). headline, rounded, tabular digits.
    static let numberInline = Font.system(.headline, design: .rounded, weight: .bold).monospacedDigit()
    /// Hero numbers (chip stack, final score). largeTitle, rounded, heavy, tabular.
    static let numberHero = Font.system(.largeTitle, design: .rounded, weight: .heavy).monospacedDigit()
}

/// A numeric font size that still follows Dynamic Type, via `@ScaledMetric`.
/// Use only when a text style can't express the size (e.g. a 44pt result
/// stamp). `relativeTo` picks which text style's growth curve it follows.
struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design
    private let maxSize: CGFloat?

    init(size: CGFloat, weight: Font.Weight, design: Font.Design,
         relativeTo textStyle: Font.TextStyle, maxSize: CGFloat?) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
        self.maxSize = maxSize
    }

    func body(content: Content) -> some View {
        let resolved = maxSize.map { min(size, $0) } ?? size
        content.font(.system(size: resolved, weight: weight, design: design))
    }
}

extension View {
    /// A fixed design size that scales with Dynamic Type. `maxSize` caps the
    /// growth for text that must fit a fixed layout (e.g. a stamp on a card).
    func scaledFont(size: CGFloat,
                    weight: Font.Weight = .regular,
                    design: Font.Design = .rounded,
                    relativeTo textStyle: Font.TextStyle = .body,
                    maxSize: CGFloat? = nil) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design,
                            relativeTo: textStyle, maxSize: maxSize))
    }
}
