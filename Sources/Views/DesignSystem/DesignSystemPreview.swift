#if DEBUG
import SwiftUI

/// A living reference sheet for the Night ink design system: every color
/// role, the type scale, spacing/radius steps and each shared component.
/// Debug builds only; open the canvas preview at the bottom of this file.
struct DesignSystemPreview: View {
    @State private var feedback: String? = "Correct. Stand on 16 vs 10 at true count 0+."
    @State private var feedbackKind: FeedbackPill.Kind = .correct

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                PageHeader("Night ink") {
                    Image(systemName: "gearshape.fill").foregroundStyle(.textSecondary)
                }
                colorsSection
                typeSection
                spacingSection
                buttonsSection
                feedbackSection
                dataSection
                cardsAndChipsSection
            }
            .padding(Space.md)
        }
        .background(Color.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: Colors

    private var colorsSection: some View {
        Panel {
            SectionHeader("Color roles", subtitle: "Use the name, never a raw color")
            swatchGrid([
                ("bg", .bg), ("surface", .surface), ("surfaceRaised", .surfaceRaised),
                ("surfaceSubtle", .surfaceSubtle), ("divider", .divider),
                ("textPrimary", .textPrimary), ("textSecondary", .textSecondary),
                ("textTertiary", .textTertiary), ("accent", .accent), ("onAccent", .onAccent),
                ("positive", .positive), ("positiveBg", .positiveBg), ("negative", .negative),
                ("negativeBg", .negativeBg), ("warm", .warm), ("warmBg", .warmBg),
                ("warning", .warning), ("disabledFill", .disabledFill),
                ("disabledText", .disabledText), ("cardBack", .cardBack),
            ])
            SectionHeader("Strategy chart")
            swatchGrid([
                ("H hit", ChartColors.hit), ("S stand", ChartColors.stand),
                ("D double", ChartColors.double), ("Ds", ChartColors.doubleOrStand),
                ("P split", ChartColors.split), ("R surrender", ChartColors.surrender),
            ])
            SectionHeader("Achievement tiers")
            HStack(spacing: Space.xs) {
                tierBadge("Bronze", .tierBronze)
                tierBadge("Silver", .tierSilver)
                tierBadge("Gold", .tierGold)
            }
        }
    }

    private func swatchGrid(_ items: [(String, Color)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Space.xs)], spacing: Space.xs) {
            ForEach(items, id: \.0) { name, color in
                VStack(alignment: .leading, spacing: Space.xxs) {
                    RoundedRectangle(cornerRadius: Radius.small)
                        .fill(color)
                        .frame(height: 36)
                        .overlay(RoundedRectangle(cornerRadius: Radius.small)
                            .strokeBorder(Color.divider, lineWidth: Metrics.hairline))
                    Text(name).font(.fine).foregroundStyle(.textSecondary)
                }
            }
        }
    }

    private func tierBadge(_ name: String, _ color: Color) -> some View {
        Text(name)
            .font(.overline)
            .foregroundStyle(.onTier)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xxs)
            .background(color, in: Capsule())
    }

    // MARK: Type

    private var typeSection: some View {
        Panel(spacing: Space.xs) {
            SectionHeader("Type scale", subtitle: "All sizes follow Dynamic Type")
            Text("display").font(.display)
            Text("sectionTitle").font(.sectionTitle)
            Text("heading").font(.heading)
            Text("bodyText — reading text").font(.bodyText)
            Text("calloutText").font(.calloutText)
            Text("detail (footnote)").font(.detail).foregroundStyle(.textSecondary)
            Text("captionText").font(.captionText).foregroundStyle(.textSecondary)
            Text("fine (caption2, the smallest)").font(.fine).foregroundStyle(.textTertiary)
            Text("OVERLINE").font(.overline).foregroundStyle(.textSecondary)
            HStack {
                Text("1,250").font(.numberHero).foregroundStyle(.accent)
                Text("82%").font(.statValue).foregroundStyle(.positive)
                Text("+3").font(.numberInline).foregroundStyle(.warm)
            }
            Text("scaledFont(size: 44)").scaledFont(size: 44, weight: .black, relativeTo: .largeTitle)
        }
        .foregroundStyle(.textPrimary)
    }

    // MARK: Spacing

    private var spacingSection: some View {
        Panel {
            SectionHeader("Spacing and radius")
            ForEach([("xxs", Space.xxs), ("xs", Space.xs), ("sm", Space.sm),
                     ("md", Space.md), ("lg", Space.lg), ("xl", Space.xl)], id: \.0) { name, value in
                HStack {
                    Text("Space.\(name)").font(.captionText).foregroundStyle(.textSecondary)
                        .frame(width: 90, alignment: .leading)
                    Rectangle().fill(.accent).frame(width: value * 4, height: 6)
                    Text("\(Int(value))").font(.fine).foregroundStyle(.textTertiary)
                }
            }
            HStack(spacing: Space.sm) {
                ForEach([("small", Radius.small), ("medium", Radius.medium), ("large", Radius.large)], id: \.0) { name, r in
                    RoundedRectangle(cornerRadius: r).fill(.surfaceRaised)
                        .frame(width: 64, height: 44)
                        .overlay(Text(name).font(.fine).foregroundStyle(.textSecondary))
                }
                Capsule().fill(.surfaceRaised).frame(width: 64, height: 44)
                    .overlay(Text("pill").font(.fine).foregroundStyle(.textSecondary))
            }
        }
    }

    // MARK: Buttons

    private var buttonsSection: some View {
        Panel {
            SectionHeader("Buttons")
            PrimaryButton("Deal", systemImage: "suit.spade.fill") {}
            PrimaryButton("Deal (disabled)") {}.disabled(true)
            HStack(spacing: Space.sm) {
                SecondaryButton("Clear", compact: true) {}
                SecondaryButton("Repeat", compact: true) {}.disabled(true)
            }
            SectionHeader("DecisionPad", subtitle: "Split disabled")
            DecisionPad(canSplit: false) { _ in }
            SectionHeader("DecisionPad with surrender")
            DecisionPad(canDouble: false, onSurrender: {}) { _ in }
        }
    }

    // MARK: Feedback

    private var feedbackSection: some View {
        Panel {
            SectionHeader("FeedbackPill", subtitle: "Fixed height, announced by VoiceOver")
            FeedbackPill(feedback, kind: feedbackKind)
            FeedbackPill("Not quite. Basic strategy hits 12 vs 2.", kind: .incorrect, announces: false)
            FeedbackPill("Shuffling a new shoe", kind: .info, announces: false)
            FeedbackPill("Bet was larger than the count supports", kind: .warning, announces: false)
            FeedbackPill(nil)
                .overlay(Text("(empty: keeps its space)").font(.fine).foregroundStyle(.textTertiary))
            SecondaryButton("Toggle first pill", compact: true) {
                feedbackKind = feedbackKind == .correct ? .incorrect : .correct
                feedback = feedbackKind == .correct ? "Correct." : "Incorrect: double 11 vs 6."
            }
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Panel {
            SectionHeader("Stats") { Text("Today").font(.captionText).foregroundStyle(.textSecondary) }
            HStack(spacing: Space.sm) {
                StatTile(label: "Accuracy", value: "82%", tint: .positive)
                StatTile(label: "Streak", value: "5 days", tint: .warm)
                StatTile(label: "Chips", value: "1,250")
            }
            ProgressBar(value: 0.4, label: "Daily goal")
            ProgressBar(value: 1, tint: .positive, label: "Done")
            Panel(.raised) {
                Text("Panel(.raised) inside a panel").font(.calloutText).foregroundStyle(.textPrimary)
            }
            Panel(.subtle) {
                Text("Panel(.subtle)").font(.calloutText).foregroundStyle(.textPrimary)
            }
        }
    }

    // MARK: Cards and chips

    private var cardsAndChipsSection: some View {
        Panel {
            SectionHeader("Cards")
            HStack(spacing: Space.xs) {
                CardView(card: Card(rank: .king, suit: .hearts), size: 1.3)
                CardView(card: Card(rank: .ace, suit: .spades), size: 1.3)
                CardView(card: Card(rank: .ten, suit: .diamonds), size: 1.3)
                CardView(card: nil, faceDown: true, size: 1.3)
                CardView(card: nil, size: 1.3)
            }
            SectionHeader("Chips")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: Space.xs)], spacing: Space.xs) {
                ForEach([0.10, 0.25, 1, 5, 10, 25, 50, 100, 250, 500, 1000, 2000, 5000,
                         10000, 25000, 50000, 100000], id: \.self) { value in
                    ChipView(value: value, size: 48)
                }
            }
            HStack(alignment: .bottom, spacing: Space.lg) {
                ChipStack(amount: 175)
                ChipStack(amount: 1_350)
            }
        }
    }
}

#Preview("Night ink") {
    DesignSystemPreview()
}
#endif
