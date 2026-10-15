import AppIntents

/// The actions as ready-made shortcuts, so they appear in the Shortcuts app
/// and in Spotlight without setup. Every phrase must name the app.
struct CrocAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SendFilesIntent(),
            phrases: ["Send files with \(.applicationName)"],
            shortTitle: "Send Files",
            systemImageName: "arrow.up.circle")
        AppShortcut(
            intent: SendTextIntent(),
            phrases: ["Send text with \(.applicationName)"],
            shortTitle: "Send Text",
            systemImageName: "text.bubble")
        AppShortcut(
            intent: ReceiveIntent(),
            phrases: ["Receive with \(.applicationName)"],
            shortTitle: "Receive",
            systemImageName: "arrow.down.circle")
    }
}
