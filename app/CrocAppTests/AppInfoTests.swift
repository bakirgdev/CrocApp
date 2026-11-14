import Foundation
import Testing

@testable import CrocApp

@Suite struct AppInfoTests {
    /// The links are force-unwrapped literals, so a malformed one would crash
    /// the first screen that shows it.
    @Test func everyLinkIsAWellFormedHTTPSURL() {
        let links = [
            AppInfo.privacyURL, AppInfo.supportURL, AppInfo.crocLicenseURL,
            AppInfo.reviewURL, AppInfo.sponsorURL,
        ]
        for link in links {
            #expect(link.scheme == "https", "\(link)")
            #expect(link.host() != nil, "\(link)")
        }
    }
}
