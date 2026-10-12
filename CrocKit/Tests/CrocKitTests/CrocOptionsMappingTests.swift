import Testing

@testable import CrocKit

@Suite struct CrocOptionsMappingTests {
    @Test func defaultsMapThrough() throws {
        let o = try CrocEngine.crocOptions(from: EngineOptions())
        #expect(o.relayAddress == "croc.schollz.com:9009")
        #expect(o.relayAddress6 == "croc6.schollz.com:9009")
        #expect(o.relayPassword == "pass123")
        #expect(o.code == "")
        #expect(o.exclude == "")
        #expect(!o.autoAccept)
        #expect(!o.overwrite)
        #expect(!o.ask)
    }

    @Test func everyFieldMaps() throws {
        var e = EngineOptions()
        e.relayAddress = "relay.example:9009"
        e.relayAddress6 = ""
        e.relayPassword = "secret"
        e.customCode = "1234-custom-code"
        e.outDir = "/tmp/out"
        e.workDir = "/tmp/work"
        e.disableLocal = true
        e.onlyLocal = true
        e.autoAccept = true
        e.overwrite = true
        e.noCompress = true
        e.zipFolder = true
        e.gitIgnore = true
        e.exclude = ["node_modules", ".git"]
        e.ask = true

        let o = try CrocEngine.crocOptions(from: e)
        #expect(o.relayAddress == "relay.example:9009")
        #expect(o.relayAddress6 == "")
        #expect(o.relayPassword == "secret")
        #expect(o.code == "1234-custom-code")
        #expect(o.outDir == "/tmp/out")
        #expect(o.workDir == "/tmp/work")
        #expect(o.disableLocal)
        #expect(o.onlyLocal)
        #expect(o.autoAccept)
        #expect(o.overwrite)
        #expect(o.noCompress)
        #expect(o.zipFolder)
        #expect(o.gitIgnore)
        #expect(o.exclude == "node_modules\n.git", "Go splits exclude on newlines")
        #expect(o.ask)
    }
}
