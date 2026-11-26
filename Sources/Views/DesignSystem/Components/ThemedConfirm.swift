import SwiftUI

// MARK: - Themed confirmation, alert and text prompt
//
// Replaces `.alert`, `.confirmationDialog` and the alert-with-a-text-field.
// A centered Night ink card over a `scrim`; Reduce Motion turns the pop into a fade.
//
//     .themedConfirm("Reset all progress?", isPresented: $showReset,
//                    message: "This can't be undone.",
//                    actions: [.destructive("Reset everything") { stats.resetAll() },
//                              .cancel()])
//
//     .themedTextPrompt("Starting chips", message: "Type an amount up to 50,000.",
//                       text: $draft, isPresented: $isEditing) { commitDraft() }
//
// WHERE TO ATTACH IT: it is a ZStack overlay, so it covers the view it is attached
// to (and works from inside a sheet or fullScreenCover as long as it is attached
// *inside* that sheet's content). Attach it to the outermost view of the screen
// (the NavigationStack, or the body's root), not to a small row, so the scrim
// covers the whole screen.
//
// Tapping the scrim (and the VoiceOver two-finger "escape" gesture) runs the
// cancel button. With no cancel button, a single-button alert runs that button;
// anything else ignores the tap, so a real choice is never made by accident.

/// One button of a themed confirmation.
struct ThemedAlertButton {
    enum Role {
        /// Mint filled: the recommended action.
        case primary
        /// Raised surface: a plain extra choice.
        case normal
        /// `negative` red filled: erases or abandons something.
        case destructive
        /// Raised surface, always last: dismisses without doing anything.
        case cancel
    }

    let title: String
    let role: Role
    let action: () -> Void

    static func primary(_ title: String, action: @escaping () -> Void = {}) -> ThemedAlertButton {
        ThemedAlertButton(title: title, role: .primary, action: action)
    }

    static func normal(_ title: String, action: @escaping () -> Void = {}) -> ThemedAlertButton {
        ThemedAlertButton(title: title, role: .normal, action: action)
    }

    static func destructive(_ title: String, action: @escaping () -> Void = {}) -> ThemedAlertButton {
        ThemedAlertButton(title: title, role: .destructive, action: action)
    }

    static func cancel(_ title: String = "Cancel", action: @escaping () -> Void = {}) -> ThemedAlertButton {
        ThemedAlertButton(title: title, role: .cancel, action: action)
    }
}

extension View {
    /// A themed alert / confirmation card. Replaces `.alert` and `.confirmationDialog`.
    func themedConfirm(_ title: String,
                       isPresented: Binding<Bool>,
                       message: String? = nil,
                       actions: [ThemedAlertButton]) -> some View {
        let dismiss = ThemedAlertButton.dismissAction(of: actions)
        let escape: (() -> Void)? = dismiss.map { action in
            return { isPresented.wrappedValue = false; action() }
        }
        return modifier(ThemedModalPresenter(isPresented: isPresented, onDismiss: dismiss) {
            ThemedModalCard(title: title, message: message, focusesTitle: true,
                            onEscape: escape) {
                EmptyView()
            } footer: {
                ThemedAlertButtons(buttons: actions, isPresented: isPresented)
            }
        })
    }

    /// A themed alert with one text field and a numeric keyboard by default.
    /// Replaces the `.alert` + `TextField` used to edit an amount.
    /// `onConfirm` runs when the player taps the confirm button or presses return;
    /// reading `text` there gives the typed value. Cancel and scrim tap just close.
    func themedTextPrompt(_ title: String,
                          message: String? = nil,
                          text: Binding<String>,
                          isPresented: Binding<Bool>,
                          placeholder: String = "Amount",
                          keyboard: UIKeyboardType = .decimalPad,
                          confirmTitle: String = "Set",
                          onConfirm: @escaping () -> Void) -> some View {
        let confirm = {
            isPresented.wrappedValue = false
            onConfirm()
        }
        let cancel = { isPresented.wrappedValue = false }
        return modifier(ThemedModalPresenter(isPresented: isPresented, onDismiss: cancel) {
            ThemedModalCard(title: title, message: message, focusesTitle: false,
                            onEscape: cancel) {
                ThemedPromptField(text: text, placeholder: placeholder,
                                  keyboard: keyboard, onSubmit: confirm)
            } footer: {
                ThemedAlertButtons(
                    buttons: [.primary(confirmTitle, action: onConfirm), .cancel()],
                    isPresented: isPresented
                )
            }
        })
    }
}

extension ThemedAlertButton {
    /// What the scrim tap / escape gesture should do, or nil to ignore it.
    fileprivate static func dismissAction(of buttons: [ThemedAlertButton]) -> (() -> Void)? {
        if let cancel = buttons.first(where: { $0.role == .cancel }) { return cancel.action }
        if buttons.count == 1 { return buttons[0].action }
        return nil
    }
}

// MARK: - Presenter

/// Overlays a modal card and scrim on the content, hides the content from
/// VoiceOver while it is up, and animates in and out (Reduce Motion aware).
private struct ThemedModalPresenter<Card: View>: ViewModifier {
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    @ViewBuilder let card: () -> Card

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .accessibilityHidden(isPresented)
            if isPresented {
                ZStack {
                    Color.scrim
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard let onDismiss else { return }
                            isPresented = false
                            onDismiss()
                        }
                        .accessibilityHidden(true)
                    card()
                        .padding(Space.md)
                        .transition(Motion.pop(reduceMotion))
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(Motion.standard.resolved(reduceMotion), value: isPresented)
    }
}

// MARK: - Card

/// The Night ink card: title, optional message, optional accessory (the text
/// field), then the buttons. Scrolls instead of clipping at large text sizes.
private struct ThemedModalCard<Accessory: View, Footer: View>: View {
    let title: String
    let message: String?
    let focusesTitle: Bool
    let onEscape: (() -> Void)?
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let footer: () -> Footer

    @AccessibilityFocusState private var titleFocused: Bool

    private let maxWidth: CGFloat = 340

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: maxWidth)
        .background(.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(Color.divider, lineWidth: Metrics.hairline)
        )
        .shadow(color: .shadowColor, radius: 24, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) { onEscape?() }
        .accessibilityIdentifier("themedAlert")
        .onAppear {
            if focusesTitle { titleFocused = true }
        }
    }

    private var content: some View {
        VStack(spacing: Space.md) {
            VStack(spacing: Space.xs) {
                Text(title)
                    .font(.heading)
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleFocused)
                if let message {
                    Text(message)
                        .font(.calloutText)
                        .foregroundStyle(.textSecondary)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            accessory()
            footer()
        }
        .padding(Space.lg)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Buttons

private struct ThemedAlertButtons: View {
    let buttons: [ThemedAlertButton]
    @Binding var isPresented: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Everything but cancel in the order given, then cancel last.
    private var ordered: [ThemedAlertButton] {
        buttons.filter { $0.role != .cancel } + buttons.filter { $0.role == .cancel }
    }

    var body: some View {
        if ordered.count == 2 && !dynamicTypeSize.isAccessibilitySize {
            // Side by side, cancel on the left like a system alert.
            HStack(spacing: Space.xs) {
                ForEach(Array(ordered.reversed().enumerated()), id: \.offset) { _, button in
                    row(button)
                }
            }
        } else {
            VStack(spacing: Space.xs) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, button in
                    row(button)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ button: ThemedAlertButton) -> some View {
        let run = {
            isPresented = false
            button.action()
        }
        switch button.role {
        case .primary:
            Button(button.title, action: run).buttonStyle(.primary)
        case .destructive:
            Button(button.title, action: run).buttonStyle(.destructive)
        case .normal, .cancel:
            Button(button.title, action: run).buttonStyle(.secondary)
        }
    }
}

// MARK: - Text field

private struct ThemedPromptField: View {
    @Binding var text: String
    let placeholder: String
    let keyboard: UIKeyboardType
    let onSubmit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text,
                  prompt: Text(placeholder).foregroundStyle(.textTertiary))
            .font(.bodyText)
            .foregroundStyle(.textPrimary)
            .tint(.accent)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .submitLabel(.done)
            .focused($focused)
            .onSubmit(onSubmit)
            .padding(.horizontal, Space.sm)
            .frame(minHeight: Metrics.minTapTarget)
            .background(.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .accessibilityLabel(placeholder)
            .accessibilityIdentifier("themedPromptField")
            .task {
                // Let the card finish appearing so the keyboard comes up cleanly.
                try? await Task.sleep(nanoseconds: 150_000_000)
                focused = true
            }
    }
}
