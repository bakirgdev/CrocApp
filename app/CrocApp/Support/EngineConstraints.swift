import Foundation

/// Validation constraints that mirror a check the Go engine actually
/// enforces. The UI validates early only to give inline feedback before a
/// doomed startSend/startReceive call -- the engine is the real gate.
enum EngineConstraints {
    /// Mirrors `minCodeLength` in crocmobile/crocmobile.go. No shared source
    /// of truth across the Go/Swift boundary -- keep these in sync by hand.
    /// Go counts bytes and this counts characters, so the UI check is the
    /// stricter one for non-ASCII codes.
    static let minCodeLength = 6
}
