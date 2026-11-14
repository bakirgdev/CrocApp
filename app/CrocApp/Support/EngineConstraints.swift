import CrocKit
import Foundation

/// Validation constraints that mirror a check the Go engine actually
/// enforces. The UI validates early only to give inline feedback before a
/// doomed send or receive start -- the engine is the real gate.
enum EngineConstraints {
    /// Go counts bytes and `isValidCode` counts characters, so the UI check is
    /// the stricter one for non-ASCII codes.
    static let minCodeLength = EngineLimits.minCodeLength

    static func isValidCode(_ code: String) -> Bool { code.count >= minCodeLength }
}
