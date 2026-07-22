// macOS-only interop harness for CrocKit <-> croc CLI.
// Usage:
//   crockit-verify send <code> <path>
//   crockit-verify receive <code> <outdir> [y|n] [cancel-after-ms]
// Prints EVENT lines like croctest; exits 0 on done, 1 on error.
// cancel-after-ms: fires engine.cancel() from a detached timer after the
// given delay, to prove the Swift-side cancel path actually tears down a
// transfer mid-wire (as opposed to only being exercised pre/post-transfer).
import Foundation
import CrocKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: crockit-verify send|receive ...\n".utf8))
    exit(2)
}

let engine = CrocEngine()

func run() async {
    do {
        var options = EngineOptions()
        let stream: AsyncStream<TransferEvent>
        var answer = true
        switch args[1] {
        case "send":
            options.customCode = args[2]
            stream = try await engine.startSend(paths: [args[3]], text: nil, options: options)
        case "receive":
            options.outDir = args[3]
            answer = args.count < 5 || args[4] == "y"
            if args.count >= 6, let ms = UInt64(args[5]) {
                Task {
                    try? await Task.sleep(nanoseconds: ms * 1_000_000)
                    print("EVENT cancelling")
                    await engine.cancel()
                }
            }
            stream = try await engine.startReceive(code: args[2], options: options)
        default:
            exit(2)
        }
        for await event in stream {
            switch event {
            case .codeReady(let code): print("EVENT code \(code)")
            case .connected: print("EVENT connected")
            case .fileList(let list):
                print("EVENT filelist files=\(list.files.count) total=\(list.totalSize)")
                await engine.respond(accept: answer)
                print("EVENT responded \(answer ? "y" : "n")")
            case .progress(let p):
                print("EVENT progress \(p.step) \(p.fileSent)/\(p.fileSize)")
            case .text(let t): print("EVENT text \(t)")
            case .done(let s):
                print("EVENT done success=\(s.success)")
                exit(s.success ? 0 : 1)
            case .failed(let message):
                print("EVENT error \(message)")
                exit(1)
            }
        }
        exit(1) // stream ended without done/error
    } catch {
        print("EVENT error \(error)")
        exit(1)
    }
}

await run()
