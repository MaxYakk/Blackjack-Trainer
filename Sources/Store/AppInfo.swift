import Foundation

/// Fixed facts about the app shown in Settings. Kept free of UI so it can be
/// unit tested.
enum AppInfo {
    static let appName = "Hit Me"
    static let companyName = "Vyne Events LLC"
    static let tagline = "Practice blackjack basic strategy, card counting and bet sizing."
    static let practiceChipsNotice = "Practice chips only. No real money, no prizes. For training and entertainment."

    /// Hosted privacy policy page. Leave nil until the owner publishes one;
    /// Settings shows the link only when this is set.
    static let privacyPolicyURL: URL? = nil

    /// Support address. Leave nil until the owner provides one; Settings hides
    /// the "Contact support" row while this is nil.
    static let supportEmail: String? = nil

    /// "Version 1.0 (3)"; falls back gracefully when a value is missing.
    static func versionString(version: String?, build: String?) -> String {
        let v = version?.trimmingCharacters(in: .whitespaces) ?? ""
        let b = build?.trimmingCharacters(in: .whitespaces) ?? ""
        switch (v.isEmpty, b.isEmpty) {
        case (false, false): return "Version \(v) (\(b))"
        case (false, true): return "Version \(v)"
        case (true, false): return "Build \(b)"
        case (true, true): return "Version unknown"
        }
    }

    static var currentVersionString: String {
        let info = Bundle.main.infoDictionary
        return versionString(version: info?["CFBundleShortVersionString"] as? String,
                             build: info?["CFBundleVersion"] as? String)
    }

    /// mailto: link for support, nil when no (valid) address is set.
    static func supportMailURL(email: String?, subject: String) -> URL? {
        guard let email, !email.isEmpty else { return nil }
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = email
        c.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return c.url
    }
}
