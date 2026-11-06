import SwiftUI

/// Version, the privacy and support links, and the croc attribution its MIT
/// license requires (`design/brand.md`, "Attribution and legal"). Last
/// section of Settings on both platforms.
struct AboutSection: View {
    var body: some View {
        Section {
            LabeledContent("Version", value: AppInfo.versionDescription)
                .accessibilityElement(children: .combine)
            Link("Privacy Policy", destination: AppInfo.privacyURL)
                .linkRow()
            Link("Support", destination: AppInfo.supportURL)
                .linkRow()
            Link("croc License", destination: AppInfo.crocLicenseURL)
                .linkRow()
            // Tips are a payment outside In-App Purchase (guideline 3.1.1), so
            // only the disk image build links them; only the App Store build
            // has a listing to rate.
            #if DIRECT
            Link("Support CrocApp", destination: AppInfo.sponsorURL)
                .linkRow()
            #else
            Link("Rate CrocApp", destination: AppInfo.reviewURL)
                .linkRow()
            #endif
        } header: {
            Text("About")
        } footer: {
            Text(
                "Built on croc by Zack Scholl (MIT). CrocApp is unofficial and not affiliated with croc."
            )
            .foregroundStyle(Color.textSecondary)
        }
    }
}

extension View {
    /// 44 pt target on iOS (design/principles.md); macOS rows keep their
    /// natural height.
    fileprivate func linkRow() -> some View {
        #if os(iOS)
        frame(maxWidth: .infinity, minHeight: ControlHeight.hitTargetMin, alignment: .leading)
            .contentShape(Rectangle())
        #else
        self
        #endif
    }
}
