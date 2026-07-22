import SwiftUI
import CrocKit
import UniformTypeIdentifiers

/// Phase 1 smoke UI: proves CrocEngine works end-to-end from the app.
/// Replaced by the real UI in Phase 2.
struct EngineSmokeView: View {
    enum Mode: String, CaseIterable { case send = "Send", receive = "Receive" }

    @State private var mode: Mode = .send
    @State private var engine = CrocEngine()
    @State private var log: [String] = []
    @State private var code = ""
    @State private var receiveCode = ""
    @State private var pickedURLs: [URL] = []
    @State private var showImporter = false
    @State private var progressLine = ""
    @State private var pendingAccept = false
    @State private var running = false

    var body: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            if mode == .send {
                Button("Pick files") { showImporter = true }
                    .fileImporter(isPresented: $showImporter,
                                  allowedContentTypes: [.item],
                                  allowsMultipleSelection: true) { result in
                        pickedURLs = (try? result.get()) ?? []
                    }
                Text(pickedURLs.map(\.lastPathComponent).joined(separator: ", "))
                    .font(.caption)
                Button("Send") { Task { await startSend() } }
                    .disabled(pickedURLs.isEmpty || running)
                if !code.isEmpty {
                    Text("Code: \(code)").font(.title3.monospaced()).textSelection(.enabled)
                }
            } else {
                TextField("Code phrase", text: $receiveCode)
                    .textFieldStyle(.roundedBorder)
                Button("Receive") { Task { await startReceive() } }
                    .disabled(receiveCode.count < 6 || running)
                if pendingAccept {
                    HStack {
                        Button("Accept") { Task { await engine.respond(accept: true); pendingAccept = false } }
                        Button("Decline") { Task { await engine.respond(accept: false); pendingAccept = false } }
                    }
                }
            }

            if running {
                Button("Cancel") { Task { await engine.cancel() } }
            }
            Text(progressLine).font(.caption.monospaced())
            List(log.indices, id: \.self) { Text(log[$0]).font(.caption2.monospaced()) }
        }
        .padding()
        .task { await autoVerifyIfRequested() }
    }

    private func consume(_ stream: AsyncStream<TransferEvent>) async {
        running = true
        defer { running = false }
        for await event in stream {
            switch event {
            case .codeReady(let c): code = c; log.append("code \(c)")
            case .connected: log.append("connected")
            case .fileList(let list):
                log.append("incoming: \(list.files.map(\.name).joined(separator: ", "))")
                pendingAccept = true
            case .progress(let p):
                progressLine = "\(p.step) \(p.fileName) \(p.fileSent)/\(p.fileSize)"
            case .text(let t): log.append("text: \(t)")
            case .done(let s):
                log.append("done success=\(s.success)")
            case .failed(let m):
                log.append("error: \(m)")
                await engine.cancel()
            }
        }
    }

    private func startSend() async {
        var options = EngineOptions()
        options.workDir = FileManager.default.temporaryDirectory.path
        let paths = pickedURLs.compactMap { url -> String? in
            guard url.startAccessingSecurityScopedResource() else { return nil }
            return url.path
        }
        do {
            let stream = try await engine.startSend(paths: paths, text: nil, options: options)
            await consume(stream)
        } catch { log.append("start error: \(error)") }
        pickedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
    }

    private func startReceive() async {
        do {
            let stream = try await engine.startReceive(code: receiveCode, options: receiveOptions())
            await consume(stream)
        } catch { log.append("start error: \(error)") }
    }

    private func receiveOptions() -> EngineOptions {
        var options = EngineOptions()
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        options.outDir = docs.path
        options.overwrite = true
        return options
    }

    /// Launch-argument-driven receive for scripted iOS simulator verification:
    /// CrocApp --auto-receive CODE  -> receives into Documents, auto-accepts,
    /// writes verify-result.txt with "ok" or the error.
    private func autoVerifyIfRequested() async {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--auto-receive"), i + 1 < args.count else { return }
        var options = receiveOptions()
        options.autoAccept = true
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let resultURL = docs.appendingPathComponent("verify-result.txt")
        do {
            let stream = try await engine.startReceive(code: args[i + 1], options: options)
            for await event in stream {
                switch event {
                case .done(let s):
                    try? "ok success=\(s.success)".write(to: resultURL, atomically: true, encoding: .utf8)
                case .failed(let m):
                    try? "error \(m)".write(to: resultURL, atomically: true, encoding: .utf8)
                default: break
                }
            }
        } catch {
            try? "error \(error)".write(to: resultURL, atomically: true, encoding: .utf8)
        }
    }
}

#Preview { EngineSmokeView() }
