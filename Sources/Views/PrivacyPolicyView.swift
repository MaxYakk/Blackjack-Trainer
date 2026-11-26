import SwiftUI

/// Short, plain-language privacy policy shown inside the app.
struct PrivacyPolicyView: View {
    private let points: [(title: String, body: String)] = [
        ("No personal data", "\(AppInfo.appName) does not collect, store on a server, or share any personal information."),
        ("No accounts", "There is nothing to sign up for or log in to."),
        ("No ads, no tracking", "The app has no advertising and no analytics or tracking of any kind."),
        ("No network requests", "The app never connects to the internet. Everything runs on your device."),
        ("Your progress stays on your device", "Your stats, practice chips and settings are saved only on this device."),
        ("Reminders are local", "The optional daily reminder is a notification scheduled on your device. Nothing is sent to us."),
        ("Deleting the app deletes the data", "If you delete \(AppInfo.appName), everything it saved goes with it."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(points, id: \.title) { point in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(point.title).font(.headline)
                        Text(point.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                Text("\(AppInfo.appName) is made by \(AppInfo.companyName).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Theme.feltDark.ignoresSafeArea())
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
