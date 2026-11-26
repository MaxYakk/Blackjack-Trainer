import SwiftUI

/// App-level settings and About, presented as a sheet from the Progress tab.
struct SettingsView: View {
    @Environment(Stats.self) private var stats
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(ReminderScheduler.enabledKey) private var reminderEnabled = false
    @State private var reminderDenied = false
    @State private var showResetConfirm = false
    @State private var showTour = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.lg) {
                    remindersSection
                    helpSection
                    dataSection
                    aboutSection
                    legalSection
                    supportSection
                }
                .padding(Space.md)
            }
            .background(Color.bg.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .frame(minHeight: Metrics.minTapTarget)
                }
            }
        }
        .themedConfirm("Reset all progress?", isPresented: $showResetConfirm,
                       message: "This erases your stats, accuracy history, achievements, streak and play money balance, and starts you fresh. It can't be undone.",
                       actions: [
                           .destructive("Reset everything") {
                               stats.resetAll()
                               dismiss()
                           },
                           .cancel(),
                       ])
        .onAppear(perform: refreshReminderAuthorization)
        .fullScreenCover(isPresented: $showTour) {
            AppTourView { showTour = false }
        }
    }

    // MARK: Help

    /// Replays the first-launch tour of what the app can do.
    private var helpSection: some View {
        SettingsSection(title: "Help") {
            Button {
                showTour = true
            } label: {
                SettingsLinkLabel(title: "Take the app tour")
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows the seven page tour of what Hit Me can do.")
            .accessibilityIdentifier("replayAppTourButton")
        }
    }

    // MARK: Reminders

    private var remindersSection: some View {
        SettingsSection(title: "Reminders") {
            Toggle(isOn: reminderBinding) {
                VStack(alignment: .leading, spacing: Space.xxs / 2) {
                    Text("Daily reminder")
                        .font(.bodyText)
                        .foregroundStyle(.textPrimary)
                    Text("One evening nudge, personalized to your streak and weakest spot.")
                        .font(.detail)
                        .foregroundStyle(.textSecondary)
                }
            }
            .toggleStyle(.themed)
            .settingsRowFrame()
            .accessibilityIdentifier("dailyReminderToggle")

            if reminderDenied {
                HairlineDivider()
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("Notifications are turned off for this app in iOS Settings, so reminders can't be sent.")
                        .font(.detail)
                        .foregroundStyle(.negative)
                        .padding(.horizontal, Space.md)
                        .padding(.top, Space.sm)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.bodyText.weight(.semibold))
                    .foregroundStyle(.accent)
                    .settingsRowFrame()
                }
            }
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminderEnabled },
            set: { wantsOn in
                if wantsOn {
                    reminderEnabled = true
                    ReminderScheduler.enable(stats: stats) { granted in
                        reminderDenied = !granted
                        if !granted { reminderEnabled = false }
                    }
                } else {
                    reminderEnabled = false
                    reminderDenied = false
                    ReminderScheduler.disable()
                }
            }
        )
    }

    /// The OS permission can be revoked in iOS Settings after the toggle was
    /// turned on; surface that instead of a silently dead toggle.
    private func refreshReminderAuthorization() {
        guard reminderEnabled else { return }
        ReminderScheduler.checkAuthorization { authorized in
            reminderDenied = !authorized
        }
    }

    // MARK: Data

    private var dataSection: some View {
        SettingsSection(title: "Data",
                        footer: "Erases all stats, history and your play money balance on this device.") {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Text("Reset all progress")
                    .font(.bodyText.weight(.semibold))
                    .foregroundStyle(.negative)
                    .settingsRowFrame()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("resetProgressButton")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        SettingsSection(title: "About", footer: AppInfo.copyrightLine) {
            SettingsRow("App") {
                Text(AppInfo.appName).font(.bodyText).foregroundStyle(.textSecondary)
            }
            HairlineDivider()
            SettingsRow("Version") {
                Text(AppInfo.currentVersionString).font(.bodyText).foregroundStyle(.textSecondary)
            }
            HairlineDivider()
            Text(AppInfo.tagline)
                .font(.calloutText)
                .foregroundStyle(.textPrimary)
                .settingsRowFrame()
            HairlineDivider()
            Text(AppInfo.practiceChipsNotice)
                .font(.calloutText)
                .foregroundStyle(.accent)
                .settingsRowFrame()
        }
    }

    // MARK: Privacy

    private var legalSection: some View {
        SettingsSection(title: "Privacy & Terms") {
            NavigationLink {
                PrivacyPolicyView()
            } label: {
                SettingsLinkLabel(title: "Privacy Policy")
            }
            .buttonStyle(.plain)
            HairlineDivider()
            NavigationLink {
                TermsView()
            } label: {
                SettingsLinkLabel(title: "Terms of Service")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("termsOfServiceLink")
            if let url = AppInfo.privacyPolicyURL {
                HairlineDivider()
                Link(destination: url) {
                    SettingsLinkLabel(title: "Privacy Policy on the web", trailingImage: "arrow.up.right")
                }
            }
            if let url = AppInfo.termsURL {
                HairlineDivider()
                Link(destination: url) {
                    SettingsLinkLabel(title: "Terms of Service on the web", trailingImage: "arrow.up.right")
                }
            }
        }
    }

    // MARK: Support

    @ViewBuilder
    private var supportSection: some View {
        if let url = AppInfo.supportMailURL(
            email: AppInfo.supportEmail,
            subject: "\(AppInfo.appName) support (\(AppInfo.currentVersionString.replacingOccurrences(of: "Version ", with: "v")))"
        ) {
            SettingsSection(title: "Support") {
                Link(destination: url) {
                    SettingsLinkLabel(title: "Contact support", systemImage: "envelope",
                                      trailingImage: "arrow.up.right")
                }
            }
        }
    }
}

/// Gear button for the Progress header.
struct SettingsGearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("settingsButton")
    }
}
