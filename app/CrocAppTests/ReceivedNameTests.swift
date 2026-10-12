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
    ])
    func blocksUnsafeNames(name: String) {
        #expect(ReceivedName.isUnsafe(name))
    }
}
