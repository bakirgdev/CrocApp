import Foundation

/// Validation constraints that mirror a check the Go engine actually
/// enforces. The UI validates early only to give inline feedback before a
/// doomed startSend/startReceive call -- the engine is the real gate.
enum EngineConstraints {
    /// Mirrors `len(secret) < 6` in crocmobile/session.go and
    /// crocmobile.go. No shared source of truth across the Go/Swift
    /// boundary -- keep these in sync by hand if the engine's check changes.
    static let minCodeLength = 6
}
