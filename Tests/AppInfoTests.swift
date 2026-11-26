import Testing
import Foundation
@testable import BlackjackTrainer

struct AppInfoTests {
    @Test func versionWithBuild() {
        #expect(AppInfo.versionString(version: "1.0", build: "3") == "Version 1.0 (3)")
    }

    @Test func versionFallbacks() {
        #expect(AppInfo.versionString(version: "1.0", build: nil) == "Version 1.0")
        #expect(AppInfo.versionString(version: " ", build: "7") == "Build 7")
        #expect(AppInfo.versionString(version: nil, build: nil) == "Version unknown")
    }

    @Test func supportRowHiddenWithoutEmail() {
        #expect(AppInfo.supportMailURL(email: nil, subject: "Hi") == nil)
        #expect(AppInfo.supportMailURL(email: "", subject: "Hi") == nil)
    }

    @Test func supportMailLink() {
        let url = AppInfo.supportMailURL(email: "help@example.com", subject: "Hit Me support")
        #expect(url?.scheme == "mailto")
        #expect(url?.absoluteString.hasPrefix("mailto:help@example.com") == true)
        #expect(url?.absoluteString.contains("Hit%20Me%20support") == true)
    }

    @Test func shippedConstants() {
        #expect(AppInfo.privacyPolicyURL == nil)
        #expect(AppInfo.termsURL == nil)
        #expect(AppInfo.supportEmail == nil)
        #expect(AppInfo.supportMailURL(email: AppInfo.supportEmail, subject: "x") == nil)
    }

    @Test func aboutNoticeStatesNoRealMoney() {
        #expect(AppInfo.practiceChipsNotice.hasPrefix(PracticeNotice.line))
    }
}
