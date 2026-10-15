import SwiftUI

/// R38: version and the privacy and support links, last section of Settings
/// on both platforms.
struct AboutSection: View {
    var body: some View {
        Section("About") {
            LabeledContent("Version", value: AppInfo.versionDescription)
                .accessibilityElement(children: .combine)
            Link("Privacy Policy", destination: AppInfo.privacyURL)
                .linkRow()
            Link("Support", destination: AppInfo.supportURL)
                .linkRow()
        }
    }
}

extension View {
    /// 44 pt target on iOS (design/accessibility.md); macOS rows keep their
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
