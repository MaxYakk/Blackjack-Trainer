import SwiftUI

// MARK: - Feedback pill
//
// The "Correct" / "Not quite" line after a decision. It always takes the same
// height, even when empty, so the layout under it never jumps.
//
//     FeedbackPill(engine.feedback.isEmpty ? nil : engine.feedback,
//                  kind: engine.feedbackGood ? .correct : .incorrect)
//
// When `message` changes to new text, VoiceOver announces it (turn off with
// `announces: false` if the screen already announces it some other way).

struct FeedbackPill: View {
    enum Kind {
        case correct, incorrect, info, warning

        var tint: Color {
            switch self {
            case .correct: return .positive
            case .incorrect: return .negative
            case .info: return .textSecondary
            case .warning: return .warning
            }
        }

        var fill: Color {
            switch self {
            case .correct: return .positiveBg
            case .incorrect: return .negativeBg
            case .info: return .surfaceRaised
            case .warning: return .warmBg
            }
        }

        var symbol: String {
            switch self {
            case .correct: return "checkmark.circle.fill"
            case .incorrect: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }

        /// Spoken before the message so meaning never relies on color.
        var spokenPrefix: String {
            switch self {
            case .correct: return "Correct"
            case .incorrect: return "Incorrect"
            case .info: return ""
            case .warning: return "Note"
            }
        }
    }

    let message: String?
    var kind: Kind = .info
    var announces = true

    @ScaledMetric(relativeTo: .subheadline) private var height: CGFloat = 48

    init(_ message: String?, kind: Kind = .info, announces: Bool = true) {
        self.message = message
        self.kind = kind
        self.announces = announces
    }

    private var spokenText: String {
        guard let message else { return "" }
        let prefix = kind.spokenPrefix
        return prefix.isEmpty || message.localizedCaseInsensitiveContains(prefix)
            ? message : "\(prefix). \(message)"
    }

    var body: some View {
        ZStack {
            if let message {
                HStack(spacing: Space.xs) {
                    Image(systemName: kind.symbol)
                        .foregroundStyle(kind.tint)
                        .accessibilityHidden(true)
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(kind == .info ? Color.textPrimary : kind.tint)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, Space.md)
                .frame(maxHeight: .infinity)
                .background(kind.fill, in: Capsule())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenText)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: max(height, Metrics.feedbackHeight))
        .onChange(of: message) { _, newValue in
            guard announces, newValue != nil else { return }
            AccessibilityNotification.Announcement(spokenText).post()
        }
    }
}
