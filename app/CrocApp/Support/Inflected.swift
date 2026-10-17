import Foundation

/// Resolves automatic grammar agreement (`^[3 file](inflect: true)`) into a
/// plain `String`. `String(localized:)` leaves the markup in place;
/// `AttributedString(localized:)` applies it.
func inflected(_ text: AttributedString) -> String {
    String(text.characters)
}
