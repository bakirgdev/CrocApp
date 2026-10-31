import AppIntents

/// Where a widget button or a Control Center control sends the user. The app
/// installs `handler` at launch. The system runs a foreground intent in the
/// app's process, so the widget extension never calls `perform()` itself.
enum OpenScreen {
    @MainActor static var handler: ((OpenScreen.Target) -> Void)?
    enum Target { case send, receive }
}

/// The widget and control buttons. The Shortcuts actions in `Intents/` need
/// files, text or a code as input, so a one-tap button cannot run them.
struct OpenSendIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Send"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult {
        OpenScreen.handler?(.send)
        return .result()
    }
}

struct OpenReceiveIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Receive"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = .foreground

    @MainActor func perform() async throws -> some IntentResult {
        OpenScreen.handler?(.receive)
        return .result()
    }
}
