// macOS-only interop harness for CrocKit <-> croc CLI.
// Usage:
//   crockit-verify send <code> <path>
//   crockit-verify receive <code> <outdir> [y|n] [cancel-after-ms]
//   crockit-verify twice <code1> <code2> <outdir>
// Prints EVENT lines like croctest; exits 0 on done, 1 on error.
// cancel-after-ms: fires engine.cancel() from a detached timer after the
// given delay, to prove the Swift-side cancel path actually tears down a
// transfer mid-wire (as opposed to only being exercised pre/post-transfer).
// twice: receives code1 to completion, then code2 to completion, in the same
// process -- proves fd0/stdout/cwd/mutex restoration in crocmobile composes
// across repeated transfers, not just a single one.
import Foundation
import CrocKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: crockit-verify send|receive|twice ...\n".utf8))
    exit(2)
}

let engine = CrocEngine()

/// EngineOptions with relay overrides from the environment, mirroring croc
/// CLI's own CROC_RELAY/CROC_PASS -- lets this harness point at a private
/// relay (e.g. `croc relay`) instead of the public one, whose one-room-per-IP
/// limit makes it unsuitable for exercising two concurrent transfers from a
/// single test host.
func defaultOptions() -> EngineOptions {
    var options = EngineOptions()
    let env = ProcessInfo.processInfo.environment
    if let relay = env["CROC_RELAY"], !relay.isEmpty { options.relayAddress = relay }
    if let pass = env["CROC_PASS"], !pass.isEmpty { options.relayPassword = pass }
    return options
}

/// Drains a transfer's event stream to completion, printing EVENT lines.
/// Returns true iff the transfer reached `.done(success: true)`.
func drive(_ stream: AsyncStream<TransferEvent>, answer: Bool) async -> Bool {
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
            return s.success
        case .failed(let message):
            print("EVENT error \(message)")
            return false
        }
    }
    return false // stream ended without done/error
}

/// Starts a receive for `code`, retrying past CrocEngineError.transferActive:
/// the previous transfer's `activeTransfer` slot is cleared by an
/// unstructured Task spawned from onTermination (see CrocEngine.swift), so it
/// can still be racing to clear when the next transfer wants to start.
func receiveToCompletion(code: String, options: EngineOptions) async -> Bool {
    var stream: AsyncStream<TransferEvent>?
    for _ in 0..<40 {
        do {
            stream = try await engine.startReceive(code: code, options: options)
            break
        } catch CrocEngineError.transferActive {
            try? await Task.sleep(nanoseconds: 50_000_000)
        } catch {
            print("EVENT error \(error)")
            return false
        }
    }
    guard let stream else {
        print("EVENT error transfer still active after retries")
        return false
    }
    return await drive(stream, answer: true)
}

func run() async {
    do {
        switch args[1] {
        case "send":
            var options = defaultOptions()
            options.customCode = args[2]
            let stream = try await engine.startSend(paths: [args[3]], text: nil, options: options)
            let ok = await drive(stream, answer: true)
            exit(ok ? 0 : 1)
        case "receive":
            var options = defaultOptions()
            options.outDir = args[3]
            let answer = args.count < 5 || args[4] == "y"
            let stream = try await engine.startReceive(code: args[2], options: options)
            if args.count >= 6, let ms = UInt64(args[5]) {
                // Spawned only after startReceive has returned, so
                // activeTransfer is guaranteed set before the timer can fire
                // -- otherwise a short delay could race engine.cancel() into
                // a silent no-op (activeTransfer still nil).
                Task {
                    try? await Task.sleep(nanoseconds: ms * 1_000_000)
                    print("EVENT cancelling")
                    await engine.cancel()
                }
            }
            let ok = await drive(stream, answer: answer)
            exit(ok ? 0 : 1)
        case "twice":
            guard args.count >= 5 else { exit(2) }
            var options = defaultOptions()
            options.outDir = args[4]
            options.overwrite = true
            let ok1 = await receiveToCompletion(code: args[2], options: options)
            let ok2 = await receiveToCompletion(code: args[3], options: options)
            exit(ok1 && ok2 ? 0 : 1)
        default:
            exit(2)
        }
    } catch {
        print("EVENT error \(error)")
        exit(1)
    }
}

await run()
