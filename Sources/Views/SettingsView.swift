import SwiftUI

/// App-level settings and About, presented as a sheet from the Progress tab.
struct SettingsView: View {
    @Environment(Stats.self) private var stats
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage(ReminderScheduler.enabledKey) private var reminderEnabled = false
    @State private var reminderDenied = false
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                remindersSection
                dataSection
                aboutSection
                legalSection
                supportSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.feltDark.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) {
                    stats.resetAll()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This erases your stats, accuracy history, achievements, streak and practice chips, and starts you fresh. It can't be undone.")
            }
        }
        .onAppear(perform: refreshReminderAuthorization)
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        Section {
            Toggle(isOn: reminderBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily reminder")
                    Text("One evening nudge, personalized to your streak and weakest spot.")
                        .font(.footnote)
                        .foregroundStyle(.textSecondary)
                }
            }
            .tint(Theme.accent)
            .frame(minHeight: 44)
            .accessibilityIdentifier("dailyReminderToggle")

            if reminderDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications are turned off for this app in iOS Settings, so reminders can't be sent.")
                        .font(.footnote)
                        .foregroundStyle(Theme.bad)
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .frame(minHeight: 44, alignment: .leading)
                }
            }
        } header: {
            Text("Reminders")
        }
        .listRowBackground(rowBackground)
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

    // MARK: - Data

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Text("Reset all progress")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("resetProgressButton")
        } header: {
            Text("Data")
        } footer: {
            Text("Erases all stats, history and practice chips on this device.")
        }
        .listRowBackground(rowBackground)
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("App", value: AppInfo.appName)
            LabeledContent("Version", value: AppInfo.currentVersionString)
            Text(AppInfo.tagline)
            Text(AppInfo.practiceChipsNotice)
                .foregroundStyle(Theme.mint)
        } header: {
            Text("About")
        } footer: {
            Text(AppInfo.copyrightLine)
        }
        .listRowBackground(rowBackground)
    }

    // MARK: - Privacy

    private var legalSection: some View {
        Section {
            NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                .frame(minHeight: 44)
            if let url = AppInfo.privacyPolicyURL {
                Link("Privacy Policy on the web", destination: url)
                    .frame(minHeight: 44, alignment: .leading)
            }
            if let url = AppInfo.termsURL {
                Link("Terms of Use", destination: url)
                    .frame(minHeight: 44, alignment: .leading)
            }
        } header: {
            Text("Privacy")
        }
        .listRowBackground(rowBackground)
    }

    // MARK: - Support

    @ViewBuilder
    private var supportSection: some View {
        if let url = AppInfo.supportMailURL(email: AppInfo.supportEmail,
                                            subject: "\(AppInfo.appName) support (\(AppInfo.currentVersionString.replacingOccurrences(of: "Version ", with: "v")))") {
            Section {
                Link(destination: url) {
                    Label("Contact support", systemImage: "envelope")
                        .frame(minHeight: 44, alignment: .leading)
                }
            } header: {
                Text("Support")
            }
            .listRowBackground(rowBackground)
        }
    }

    private var rowBackground: some View { Color.surface }
}

/// Gear button for the Progress header.
struct SettingsGearButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("settingsButton")
    }
}
