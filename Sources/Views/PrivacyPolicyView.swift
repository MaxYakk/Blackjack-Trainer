import SwiftUI

/// Short, plain-language privacy policy shown inside the app.
struct PrivacyPolicyView: View {
    private let points: [(title: String, body: String)] = [
        ("No personal data", "\(AppInfo.appName) does not collect, store on a server, or share any personal information."),
        ("No accounts", "There is nothing to sign up for or log in to."),
        ("No ads, no tracking", "The app has no advertising and no analytics or tracking of any kind."),
        ("No network requests", "The app never connects to the internet. Everything runs on your device."),
        ("Your progress stays on your device", "Your stats, play money balance and settings are saved only on this device."),
        ("Reminders are local", "The optional daily reminder is a notification scheduled on your device. Nothing is sent to us."),
        ("Deleting the app deletes the data", "If you delete \(AppInfo.appName), everything it saved goes with it."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                SettingsSection(title: "How your data is handled") {
                    ForEach(Array(points.enumerated()), id: \.offset) { offset, point in
                        if offset > 0 { HairlineDivider() }
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            Text(point.title)
                                .font(.heading)
                                .foregroundStyle(.textPrimary)
                            Text(point.body)
                                .font(.calloutText)
                                .foregroundStyle(.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .settingsRowFrame()
                        .accessibilityElement(children: .combine)
                    }
                }
                Text(AppInfo.copyrightLine)
                    .font(.detail)
                    .foregroundStyle(.textTertiary)
                    .padding(.horizontal, Space.xs)
            }
            .padding(Space.md)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
    }
}
