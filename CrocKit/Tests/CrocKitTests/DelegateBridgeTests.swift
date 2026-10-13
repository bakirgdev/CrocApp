import Testing

@testable import CrocKit

/// Feeds Go-shaped payloads through the bridge and collects what reaches the stream.
private func events(_ drive: (DelegateBridge) -> Void) async -> [TransferEvent] {
    let (stream, continuation) = AsyncStream.makeStream(of: TransferEvent.self)
    let bridge = DelegateBridge(continuation: continuation)
    drive(bridge)
    continuation.finish()
    var out: [TransferEvent] = []
    for await event in stream { out.append(event) }
    return out
}

@Suite struct DelegateBridgeTests {
    @Test func decodesFileList() async throws {
        let got = await events {
            $0.onFileList(
                #"{"files":[{"name":"dir/a.txt","size":3},{"name":"b","size":5}],"emptyFolders":1,"totalSize":8}"#
            )
        }
        guard case .fileList(let list) = try #require(got.first) else {
            Issue.record("expected .fileList, got \(got)")
            return
        }
        #expect(list.files.map(\.name) == ["dir/a.txt", "b"])
        #expect(list.files.map(\.size) == [3, 5])
        #expect(list.emptyFolders == 1)
        #expect(list.totalSize == 8)
    }

    @Test func decodesProgress() async throws {
        let got = await events {
            $0.onProgress(
                #"{"currentFile":1,"totalFiles":2,"fileName":"b","fileSent":4,"fileSize":5,"bytesFinished":3,"totalSize":8,"step":"transferring"}"#
            )
        }
        guard case .progress(let p) = try #require(got.first) else {
            Issue.record("expected .progress, got \(got)")
            return
        }
        #expect(p.currentFile == 1)
        #expect(p.totalFiles == 2)
        #expect(p.fileName == "b")
        #expect(p.fileSent == 4)
        #expect(p.fileSize == 5)
        #expect(p.bytesFinished == 3)
        #expect(p.totalSize == 8)
        #expect(p.step == "transferring")
    }

    @Test func decodesDoneAndFinishesStream() async throws {
        let got = await events {
            $0.onDone(#"{"success":true,"files":2,"totalSize":8}"#)
            $0.onConnected()
        }
        #expect(got.count == 1, "nothing may follow a terminal event")
        guard case .done(let s) = try #require(got.first) else {
            Issue.record("expected .done, got \(got)")
            return
        }
        #expect(s.success)
        #expect(s.files == 2)
        #expect(s.totalSize == 8)
    }

    @Test func passesThroughSimpleEvents() async {
        let got = await events {
            $0.onCodeReady("1234-some-code")
            $0.onConnected()
            $0.onText("hello")
            $0.onCodeReady(nil)
        }
        #expect(got.count == 4)
        if case .codeReady(let code) = got[0] {
            #expect(code == "1234-some-code")
        } else {
            Issue.record("\(got[0])")
        }
        if case .connected = got[1] {} else { Issue.record("\(got[1])") }
        if case .text(let text) = got[2] {
            #expect(text == "hello")
        } else {
            Issue.record("\(got[2])")
        }
        if case .codeReady(let code) = got[3] {
            #expect(code == "")
        } else {
            Issue.record("\(got[3])")
        }
    }

    @Test func errorFailsAndFinishesStream() async {
        let got = await events {
            $0.onError(#"{"code":"roomFull","message":"relay admission rejected"}"#)
            $0.onConnected()
        }
        #expect(got.count == 1)
        if case .failed(let f) = got.first {
            #expect(f == EngineFailure(code: .roomFull, message: "relay admission rejected"))
        } else {
            Issue.record("\(got)")
        }

        let unknown = await events { $0.onError(nil) }
        if case .failed(let f) = unknown.first {
            #expect(f == EngineFailure(code: .other, message: "unknown error"))
        } else {
            Issue.record("\(unknown)")
        }
    }

    @Test(arguments: [
        nil, "", "not json", #"{"files":[{"name":"a"}],"emptyFolders":0,"totalSize":1}"#,
    ])
    func malformedFileListFailsAndFinishes(payload: String?) async {
        let got = await events {
            $0.onFileList(payload)
            $0.onConnected()
        }
        #expect(got.count == 1)
        if case .failed(let f) = got.first {
            #expect(f == EngineFailure(code: .other, message: "malformed fileList payload"))
        } else {
            Issue.record("\(got)")
        }
    }

    @Test(arguments: [nil, "", "{}", #"{"success":"yes","files":1,"totalSize":1}"#])
    func malformedDoneFailsAndFinishes(payload: String?) async {
        let got = await events {
            $0.onDone(payload)
            $0.onConnected()
        }
        #expect(got.count == 1)
        if case .failed(let f) = got.first {
            #expect(f == EngineFailure(code: .other, message: "malformed done payload"))
        } else {
            Issue.record("\(got)")
        }
    }

    @Test(arguments: [nil, "", "[]", #"{"currentFile":0}"#])
    func malformedProgressIsDropped(payload: String?) async {
        let got = await events {
            $0.onProgress(payload)
            $0.onConnected()
        }
        #expect(
            got.count == 1, "progress is advisory: a bad tick is skipped, the stream stays open")
        if case .connected = got.first {} else { Issue.record("\(got)") }
    }
}
