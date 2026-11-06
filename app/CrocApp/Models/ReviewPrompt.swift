import Foundation

/// When to ask for an App Store review. The system limits how often the
/// prompt really shows; this keeps the request to people who have used the
/// app a few times, and to once per version (Apple's sample code stores the
/// version the same way).
enum ReviewPrompt {
    static let minimumSuccessfulTransfers = 3

    static func shouldAsk(
        successfulTransfers: Int, lastPromptedVersion: String, currentVersion: String
    ) -> Bool {
        successfulTransfers >= minimumSuccessfulTransfers && lastPromptedVersion != currentVersion
    }
}
