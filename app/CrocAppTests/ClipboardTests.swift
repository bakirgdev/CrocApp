import Foundation
import Testing

@testable import CrocApp

#if os(macOS)
import AppKit

/// A copied secret is marked concealed and leaves the pasteboard after its
/// lifetime, unless the user copied something else first. Each test uses its
/// own private pasteboard, never the general one.
@MainActor @Suite struct ClipboardSecretTests {
    private static let lifetime: TimeInterval = 0.05

    private func withPasteboard(_ body: (NSPasteboard) async -> Void) async {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("app.crocapp.tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        await body(pasteboard)
    }

    @Test func secretCarriesTheConcealedMarker() async {
        await withPasteboard { pasteboard in
            let task = Clipboard.copySecret(
                "wiry-buzz-grope", thisDeviceOnly: false, to: pasteboard, lifetime: Self.lifetime)
            #expect(pasteboard.string(forType: .string) == "wiry-buzz-grope")
            #expect(pasteboard.types?.contains(Clipboard.concealedType) == true)
            await task.value
        }
    }

    @Test func concealedTypeIsTheNSPasteboardOrgIdentifier() {
        #expect(Clipboard.concealedType.rawValue == "org.nspasteboard.ConcealedType")
    }

    @Test func untouchedSecretIsClearedAfterTheLifetime() async {
        await withPasteboard { pasteboard in
            let task = Clipboard.copySecret(
                "wiry-buzz-grope", thisDeviceOnly: false, to: pasteboard, lifetime: Self.lifetime)
            await task.value
            #expect(pasteboard.string(forType: .string) == nil)
            #expect(pasteboard.types?.contains(Clipboard.concealedType) != true)
        }
    }

    @Test func linkIsClearedToo() async {
        await withPasteboard { pasteboard in
            let task = Clipboard.copySecret(
                "https://getcroc.com/s/abc#key", thisDeviceOnly: true, to: pasteboard,
                lifetime: Self.lifetime)
            #expect(pasteboard.string(forType: .string) == "https://getcroc.com/s/abc#key")
            await task.value
            #expect(pasteboard.string(forType: .string) == nil)
        }
    }

    @Test func somethingCopiedLaterIsKept() async {
        await withPasteboard { pasteboard in
            let task = Clipboard.copySecret(
                "wiry-buzz-grope", thisDeviceOnly: false, to: pasteboard, lifetime: Self.lifetime)
            pasteboard.clearContents()
            pasteboard.setString("the user's own text", forType: .string)
            await task.value
            #expect(pasteboard.string(forType: .string) == "the user's own text")
        }
    }

    @Test func aSecondSecretKeepsItsOwnLifetime() async {
        await withPasteboard { pasteboard in
            let first = Clipboard.copySecret(
                "first-code", thisDeviceOnly: false, to: pasteboard, lifetime: Self.lifetime)
            let second = Clipboard.copySecret(
                "second-code", thisDeviceOnly: false, to: pasteboard, lifetime: 60)
            await first.value
            #expect(pasteboard.string(forType: .string) == "second-code")
            second.cancel()
            await second.value
            #expect(pasteboard.string(forType: .string) == "second-code")
        }
    }
}
#endif

@Suite struct ClipboardLifetimeTests {
    @Test func secretsLastFiveMinutes() {
        #expect(Clipboard.secretLifetime == 300)
    }
}
