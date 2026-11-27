import SwiftUI

/// Short, plain-language terms of service shown inside the app.
struct TermsView: View {
    private let points: [(title: String, body: String)] = [
        ("Play money only", "\(AppInfo.appName) is a training tool. It uses play money only: nothing can be bought, won or cashed out."),
        ("Educational advice", "Strategy and counting advice is for learning. It does not guarantee any result at a real casino."),
        ("Provided as is", "The app is provided as is, without warranties of any kind."),
        ("Legal age", "If you ever play for real money, you must be of legal age to gamble where you live."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                SettingsSection(title: "The short version") {
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
                    if let url = AppInfo.termsURL {
                        HairlineDivider()
                        Link(destination: url) {
                            SettingsLinkLabel(title: "Read online", trailingImage: "arrow.up.right")
                        }
                    }
                }
                Text("Copyright \(AppInfo.copyrightLine)")
                    .font(.detail)
                    .foregroundStyle(.textTertiary)
                    .padding(.horizontal, Space.xs)
            }
            .padding(Space.md)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bg, for: .navigationBar)
    }
}
