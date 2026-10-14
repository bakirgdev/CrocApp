import Croc
import Testing

@testable import CrocKit

@Suite struct CrocOptionsMappingTests {
    @Test func defaultsMapThrough() throws {
        let o = try CrocEngine.crocOptions(from: EngineOptions())
        #expect(o.relayAddress == "")
        #expect(o.relayAddress6 == "")
        #expect(o.relayPassword == "")
        #expect(o.code == "")
        #expect(o.exclude == "")
        #expect(!o.autoAccept)
        #expect(!o.overwrite)
        #expect(o.rename, "Keep Both is the default")
        #expect(!o.ask)
    }

    @Test(arguments: FilePolicy.allCases)
    func filePolicyMapsToExactlyOneFlag(_ policy: FilePolicy) throws {
        var e = EngineOptions()
        e.whenFileExists = policy
        let o = try CrocEngine.crocOptions(from: e)
        #expect(o.rename == (policy == .keepBoth))
        #expect(o.overwrite == (policy == .replace))
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
        e.whenFileExists = .replace
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
        #expect(!o.rename)
        #expect(o.noCompress)
        #expect(o.zipFolder)
        #expect(o.gitIgnore)
        #expect(o.exclude == "node_modules\n.git", "Go splits exclude on newlines")
        #expect(o.ask)
    }

    private struct Flag {
        let name: String
        let source: WritableKeyPath<EngineOptions, Bool>
        let target: KeyPath<CrocmobileOptions, Bool>
    }

    /// Every bool on at once cannot catch two fields mapped onto each other.
    @Test func eachBoolMapsAlone() throws {
        let flags = [
            Flag(name: "disableLocal", source: \.disableLocal, target: \.disableLocal),
            Flag(name: "onlyLocal", source: \.onlyLocal, target: \.onlyLocal),
            Flag(name: "autoAccept", source: \.autoAccept, target: \.autoAccept),
            Flag(name: "noCompress", source: \.noCompress, target: \.noCompress),
            Flag(name: "zipFolder", source: \.zipFolder, target: \.zipFolder),
            Flag(name: "gitIgnore", source: \.gitIgnore, target: \.gitIgnore),
            Flag(name: "ask", source: \.ask, target: \.ask),
        ]
        for flag in flags {
            var e = EngineOptions()
            e[keyPath: flag.source] = true
            let o = try CrocEngine.crocOptions(from: e)
            for other in flags {
                #expect(
                    o[keyPath: other.target] == (other.name == flag.name),
                    "set \(flag.name), read \(other.name)")
            }
        }
    }
}
