import Foundation
import Testing

@testable import CrocApp

@Suite struct AppInfoTests {
    @Test func privacyURLIsTheProjectSitePrivacyPage() {
        expectHTTPSPage(AppInfo.privacyURL, path: "/privacy/")
    }

    @Test func supportURLIsTheProjectSiteSupportPage() {
        expectHTTPSPage(AppInfo.supportURL, path: "/support/")
    }

    // URLComponents, not URL.path: URL.path drops the trailing slash.
    private func expectHTTPSPage(_ url: URL, path: String) {
        let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(parts?.scheme == "https")
        #expect(parts?.host == "crocapp.dev")
        #expect(parts?.path == path)
    }
}
