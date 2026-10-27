import Testing

@testable import CrocApp

@Suite struct ReceivedNameTests {
    @Test(arguments: [
        "file.txt", "folder/file.txt", "a/b/c.bin", ".hidden", "..dots-in-name", "name..txt",
        "a/.../b",
    ])
    func allowsPlainNames(name: String) {
        #expect(!ReceivedName.isUnsafe(name))
    }

    @Test(arguments: [
        "", "/etc/passwd", "..", "../x", "a/../b", "a/..", "a\\b", "..\\x", "a\0b",
        "photo.jpg\n..", "a\rb", "a\tb", "a\u{7F}b", "a\u{85}b",
    ])
    func blocksUnsafeNames(name: String) {
        #expect(ReceivedName.isUnsafe(name))
    }

    /// A combining mark glues itself to the character before it, so "/" plus
    /// U+0301 is one Character. The separator must still be seen.
    @Test(arguments: [
        "../\u{301}x", "/\u{301}etc/passwd", "a\\\u{301}b", "a\0\u{301}b", "a/../\u{301}b",
    ])
    func seesASeparatorBehindACombiningMark(name: String) {
        #expect(ReceivedName.isUnsafe(name))
    }

    /// Only a component of exactly two dots is parent-directory traversal.
    /// A dot component that carries a combining mark is not "..".
    @Test(arguments: ["a/..\u{301}/b", "a/.\u{301}./b"])
    func aMarkedDotComponentIsAnOrdinaryName(name: String) {
        #expect(!ReceivedName.isUnsafe(name))
    }

    /// Characters that let a sender change how a name reads: every
    /// bidirectional control (marks, embeddings, overrides, isolates) and the
    /// line and paragraph separators.
    @Test(arguments: [
        "invoice\u{202E}fdp.exe", "a\u{202A}b", "a\u{202B}b", "a\u{202C}b", "a\u{202D}b",
        "a\u{2066}b", "a\u{2067}b", "a\u{2068}b", "a\u{2069}b",
        "a\u{200E}b", "a\u{200F}b", "a\u{061C}b",
        "a\u{2028}b", "a\u{2029}b",
        "folder/inv\u{202E}fdp.exe",
    ])
    func blocksNamesThatChangeHowTheyRead(name: String) {
        #expect(ReceivedName.isUnsafe(name))
    }

    /// These are format characters too, but real names need them: a joined
    /// emoji sequence, a Persian word, a subdivision flag.
    @Test(arguments: [
        // Man, woman, girl joined by ZERO WIDTH JOINER.
        "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}.png",
        // Persian "mikhaham" with ZERO WIDTH NON-JOINER.
        "\u{0645}\u{06CC}\u{200C}\u{062E}\u{0648}\u{0627}\u{0647}\u{0645}.txt",
        // Flag of Scotland: black flag plus tag characters.
        "\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}.png",
        "folder/\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}/photo.png",
    ])
    func allowsLegitimateFormatCharacters(name: String) {
        #expect(!ReceivedName.isUnsafe(name))
    }

    // MARK: - Shown form

    /// A name `isUnsafe` blocks is still drawn and recorded, so the sender's
    /// bytes must show as code points, never act on the reader.
    @Test(arguments: [
        ("invoice\u{202E}fdp.exe", "invoice\\u{202E}fdp.exe"),
        ("a\u{2066}b\u{2069}", "a\\u{2066}b\\u{2069}"),
        ("a\u{200F}b", "a\\u{200F}b"),
        ("a\nb", "a\\u{000A}b"),
        ("a\0b\u{7F}", "a\\u{0000}b\\u{007F}"),
        ("a\u{85}b", "a\\u{0085}b"),
        ("a\u{2028}b\u{2029}", "a\\u{2028}b\\u{2029}"),
        ("folder/inv\u{202E}fdp.exe", "folder/inv\\u{202E}fdp.exe"),
    ])
    func showsHiddenScalarsAsCodePoints(name: String, shown: String) {
        #expect(ReceivedName.shown(name) == shown)
    }

    @Test(arguments: [
        "file.txt", "folder/file.txt", "", "..", "a\\b", "Café.txt", "日本語.txt",
        "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}.png",
        "\u{0645}\u{06CC}\u{200C}\u{062E}\u{0648}\u{0627}\u{0647}\u{0645}.txt",
        "\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}.png",
    ])
    func leavesAnyOtherNameUnchanged(name: String) {
        #expect(ReceivedName.shown(name) == name)
    }

    /// `isUnsafe` and `shown` read one predicate, so a name blocked for how
    /// it reads never draws raw.
    @Test(arguments: [
        "\u{202E}", "\u{200E}", "\u{061C}", "\u{2067}", "\n", "\u{2028}", "\u{2029}",
    ])
    func blockedScalarsAreTheEscapedOnes(scalar: String) {
        let name = "a\(scalar)b"
        #expect(ReceivedName.isUnsafe(name))
        #expect(ReceivedName.shown(name) != name)
        #expect(scalar.unicodeScalars.allSatisfy(ReceivedName.isSpoofingScalar))
    }

    @Test func formatCharactersRealNamesNeedAreNotSpoofing() {
        #expect(!ReceivedName.isSpoofingScalar("\u{200D}"))
        #expect(!ReceivedName.isSpoofingScalar("\u{200C}"))
        #expect(!ReceivedName.isSpoofingScalar("\u{E0067}"))
    }
}
