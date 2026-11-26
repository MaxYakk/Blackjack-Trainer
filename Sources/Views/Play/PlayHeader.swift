import SwiftUI

/// The Play screen's top bar: End session on the left, the title in the
/// middle, How to Play (?) and Table Options (gear) on the right. Every
/// action is visible; nothing hides behind a menu.
struct PlayHeader: View {
    let canEndSession: Bool
    let onEndSession: () -> Void
    let onHelp: () -> Void
    let onOptions: () -> Void

    var body: some View {
        ZStack {
            Text("Hit Me")
                .font(.sectionTitle)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Space.xs) {
                Button(action: onEndSession) {
                    Text("End session")
                        .font(.buttonLabelSmall)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, Space.sm)
                        .frame(minHeight: Metrics.minTapTarget)
                        .foregroundStyle(canEndSession ? Color.textPrimary : Color.disabledText)
                        .background(canEndSession ? Color.surface : Color.disabledFill, in: Capsule())
                        .overlay { Capsule().strokeBorder(Color.divider, lineWidth: Metrics.hairline) }
                }
                .buttonStyle(.plain)
                .disabled(!canEndSession)
                .accessibilityHint(canEndSession ? "Shows your session summary" : "Available between rounds")
                .accessibilityIdentifier("cashOutButton")

                Spacer(minLength: Space.xs)

                iconButton("questionmark", label: "How to Play", action: onHelp)
                    .accessibilityIdentifier("learnBlackjackHeaderButton")
                iconButton("gearshape.fill", label: "Table Options", action: onOptions)
                    .accessibilityIdentifier("settingsButton")
            }
        }
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
        .padding(.horizontal, Space.md)
        .padding(.top, Space.xxs)
    }

    private func iconButton(_ systemImage: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.heading)
                .foregroundStyle(.textPrimary)
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .background(.surface, in: Circle())
                .overlay { Circle().strokeBorder(Color.divider, lineWidth: Metrics.hairline) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// One line of session numbers under the header: chips, session result and,
/// when count display is on, the running and true counts.
struct PlayStatsStrip: View {
    let engine: PlayEngine

    var body: some View {
        HStack(spacing: 0) {
            item("Chips", engine.money(engine.bankroll), .accent)
            divider
            item("Session", sessionText, sessionColor, spoken: sessionSpoken)
            if engine.showCount {
                divider
                item("Running", signed(engine.runningCount), .textPrimary)
                divider
                item("True", String(format: "%+.1f", engine.trueCount), .textPrimary)
            }
        }
        .padding(.vertical, Space.xs)
        .background(.surfaceSubtle, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .padding(.horizontal, Space.md)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(width: Metrics.hairline, height: 24)
            .accessibilityHidden(true)
    }

    /// Arrows instead of signs, so it reads like a scoreboard.
    private var sessionText: String {
        let net = engine.sessionNet
        if net > 0.005 { return "▲ \(engine.money(net))" }
        if net < -0.005 { return "▼ \(engine.money(-net))" }
        return "Even"
    }

    private var sessionSpoken: String {
        let net = engine.sessionNet
        if net > 0.005 { return "up \(Money.chips(net))" }
        if net < -0.005 { return "down \(Money.chips(-net))" }
        return "even"
    }

    private var sessionColor: Color {
        let net = engine.sessionNet
        if net > 0.005 { return .positive }
        if net < -0.005 { return .negative }
        return .textPrimary
    }

    private func item(_ label: String, _ value: String, _ tint: Color, spoken: String? = nil) -> some View {
        VStack(spacing: 0) {
            Text(label.uppercased())
                .font(.overline)
                .foregroundStyle(.textTertiary)
            Text(value)
                .font(.numberInline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(spoken ?? value)
    }

    private func signed(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
}
