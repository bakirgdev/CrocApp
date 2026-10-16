import Foundation

/// R38: where the app points people for privacy and support, and the version
/// shown in Settings and the About panel.
enum AppInfo {
    // Literals checked by AppInfoTests, so there is no fallback to write.
    static let privacyURL = URL(string: "https://crocapp.dev/privacy/")!
    static let supportURL = URL(string: "https://crocapp.dev/support/")!

    /// "1.0 (12)"; the build number is dropped when the bundle has none.
    static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        guard let build = info?["CFBundleVersion"] as? String, !build.isEmpty else {
            return version
        }
        return "\(version) (\(build))"
    }
}
