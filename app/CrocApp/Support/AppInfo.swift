import Foundation

/// Where the app points people for privacy and support, and the version
/// shown in Settings and the About panel.
enum AppInfo {
    // Literals checked by AppInfoTests, so there is no fallback to write.
    static let privacyURL = URL(string: "https://crocapp.dev/privacy/")!
    static let supportURL = URL(string: "https://crocapp.dev/support/")!
    static let crocLicenseURL = URL(string: "https://github.com/schollz/croc/blob/main/LICENSE")!
    /// The App Store build only; the disk image build has no listing to rate.
    static let reviewURL = URL(
        string: "https://apps.apple.com/app/id6805675003?action=write-review")!
    /// The landing page's sponsor section, which offers GitHub Sponsors and
    /// Buy Me a Coffee. The disk image build only (App Review guideline 3.1.1).
    static let sponsorURL = URL(string: "https://crocapp.dev/#sponsor")!

    /// "1.1.1": the version alone, which the review prompt is limited per.
    static var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    /// "1.0 (12)"; the build number is dropped when the bundle has none.
    static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = marketingVersion
        guard let build = info?["CFBundleVersion"] as? String, !build.isEmpty else {
            return version
        }
        return "\(version) (\(build))"
    }
}
