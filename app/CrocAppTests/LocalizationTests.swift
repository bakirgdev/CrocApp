import Foundation
import Testing

@testable import CrocApp

/// How the String Catalog turns a count into words. The catalog has English
/// only, so these pin that plural handling works before a second language
/// depends on it.
@Suite struct LocalizationTests {
    private let english = Locale(identifier: "en_US")

    /// `Localizable.xcstrings` varies this key by plural; the Shortcuts dialog
    /// in `ReceiveIntent` is the one caller.
    @Test(arguments: [(1, "Received 1 item."), (3, "Received 3 items.")])
    func aCountedSentenceFollowsThePluralVariation(count: Int, sentence: String) {
        #expect(String(localized: "Received \(count) items.", locale: english) == sentence)
    }
}
