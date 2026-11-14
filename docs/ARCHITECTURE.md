# Architecture

Top-down map of CrocApp. Terms like PAKE, relay and gobind are in `docs/GLOSSARY.md`. Depth lives in `docs/knowledge/`: the bridge contract in `crocmobile-bridge.md`, view and state rules in `app-ui-architecture.md`, OS limits in `apple-platform-constraints.md`.

## System summary

CrocApp is a native SwiftUI app for iOS, iPadOS and macOS 26. It embeds [croc](https://github.com/schollz/croc) as a Go library instead of running the croc command.

- There is one process: the app. croc's transfer engine runs inside it as linked Go code, built into an `.xcframework` with `gomobile`. It is not a subprocess and not a daemon: iOS does not allow spawning processes.
- One Swift actor, `CrocEngine`, is the only code that calls the Go code. `TransferController` is the only code that calls `CrocEngine`. Everything above that is SwiftUI views reacting to one `@Observable` state machine.

The sources build six targets, each Direct twin sharing its sources. `app/Shared/` is a folder group compiled into every target (the share-handoff contract and `ReceivedName.swift`, the rule for a file name that arrives from outside):

| Target | Platforms | Channel |
| --- | --- | --- |
| `CrocApp` | iOS and macOS | App Store builds |
| `CrocApp Direct` | macOS, arm64 | Direct download (notarized DMG with Sparkle updates, `docs/RELEASING.md`) |
| `CrocShare`, `CrocShare Direct` | iOS and macOS | Share extension (iOS Share sheet, Finder's Share menu on macOS). A separate Direct target because an extension's bundle ID must be prefixed by its host's |
| `CrocWidgets`, `CrocWidgets Direct` | iOS and macOS | WidgetKit extension: the Last Transfer widget and the Send and Receive controls. Reads `last-transfer.json` from the App Group |

## Why a Go bridge

The one property the app promises is that a code phrase works between CrocApp and the croc CLI in both directions. Every alternative loses on it: a subprocess is forbidden on iOS and leaves progress and the accept prompt to parsing terminal output on the Mac; a Swift rewrite of PAKE, the relay handshake and the file protocol must track every upstream change by hand, and drift breaks interop silently; porting part of croc has the same drift risk. croc ships no Apple library, so `crocmobile/` is that layer.

The cost is bounded: the engine is most of an executable of about 10 MB (`docs/BUILDING.md`, "What build-xcframework.sh does"), croc's process-global state needs the transfer lock and the stdio restoration in `crocmobile/`, and an upgrade is a version bump plus the harnesses (`docs/knowledge/croc-upgrade-playbook.md`).

## Layer diagram

```
croc 11 (schollz/croc, pinned in crocmobile/go.mod)
    │
    ▼
crocmobile/            Go wrapper package
    │
    ▼
gomobile bind          ios, iossimulator/arm64, macos/arm64
    │
    ▼
CrocKit/Croc.xcframework   (gitignored build output)
    │
    ▼
CrocKit                Swift package: CrocEngine, DelegateBridge, Models.swift
    │                  AsyncStream<TransferEvent>
    ▼
TransferController     @MainActor @Observable, app/CrocApp/Models/
    │                  Phase enum and intent methods
    ▼
SwiftUI views          app/CrocApp/Views/
```

- Go calls croc directly (`croc.NewCtx`, then polling the client). gobind only passes scalars, strings, bools, interfaces and struct pointers, so lists cross as joined strings and file lists, progress and the summary cross as JSON strings.
- Delegate callbacks arrive on Go threads. `DelegateBridge` only yields into the stream and does not hop to `MainActor`.
- `CrocKit/Croc.xcframework` is gitignored: a fresh clone cannot build `CrocKit` or the app until `scripts/build-xcframework.sh` has run once.

## Per-layer detail

### `crocmobile/`: Go wrapper

It adapts croc's command-line-shaped library (process-global `os.Chdir`, stdin prompts, text receive through `os.Stdout`) so a GUI can call it repeatedly and safely. `crocmobile.go` is the public API (`Options`, the `Delegate` interface, the `Transfer` handle), `session.go` the engine (the prompt pipe on fd 0, the 10 Hz poller), `store.go` stored transfers, `errors.go` the croc-error-to-failure-code mapping, `network.go` the Advanced-option validation and the croc CLI defaults the library does not apply, and `relayhost.go` and `relaycheck.go` the relay this Mac can run and its health probe. The exact contract is in `docs/knowledge/crocmobile-bridge.md`. What it deliberately does:

- Runs one transfer at a time. A package-global mutex makes a second start fail with code `transferActive`; it is freed before the terminal event, so a start made on that event succeeds.
- Never lets a Go panic cross into Swift: every exported entry point and the run and poll loops recover and report code `other`.
- Reports `OnError` as JSON `{"code","message"}`. The app picks its wording from the code and never reads croc's text.
- Does not force the lock open when croc hangs past a cancel: a watchdog reports `engineStuck` after 15 s and later starts fail fast with it until relaunch.

The xcframework module is `Croc`; Go symbols get a `Crocmobile` prefix in Objective-C (`CrocmobileOptions`, `CrocmobileStartSend`).

### `CrocKit/`: Swift package

- `CrocEngine` is the `public actor` and conforms to `TransferEngine`, exactly what `TransferController` calls (it exists so the app's tests can stand in a fake engine). It holds the one active transfer; a start returns an `EngineTransfer` with a `TransferID` and `events: AsyncStream<TransferEvent>`. `respond` and `cancel` ignore a stale ID, so a late answer cannot reach the next transfer. `crocOptions(from:)` is the list of settings the app can reach: a Go option not copied there is unused.
- `DelegateBridge` turns Go-thread callbacks into stream yields and decodes the JSON payloads. A malformed payload becomes `.failed` with code `other`, and the stream finishes. When the stream finishes, `onTermination` cancels that transfer by ID, so the consumer needs no cancel call.
- `Models.swift` holds `EngineOptions`, `TransferEvent` (`codeReady`, `connected`, `fileList`, `progress`, `text`, `stored`, `done`, `failed`), `EngineFailure` and `EngineSetting.validate(_:)`, which runs the engine's own check for the app's settings fields.
- `crockit-verify` is a macOS-only executable that tests interop with the croc command. It is not shipped.

### `TransferController`: app state machine

`app/CrocApp/Models/TransferController.swift`, a `@MainActor @Observable final class`. It holds the engine as `any TransferEngine` (tests pass `FakeTransferEngine`), a `BackgroundCoordinator` and the `Phase` enum every view switches on: `idle`, `starting`, `waiting`, `connecting`, `confirmSend`, `incoming`, `transferring`, `done`, `stored`, `failed`. Progress lives outside the phase, so a tick does not change it. Intents are `start(_ request:)`, `retry`, `respond`, `cancel`, `reset` and `revoke`. Pure pieces sit in their own files under `Models/` (`EngineStart`, `TransferFailure`, `HistoryDraft`, `SecurityScopes` and others). Event-handling rules: `docs/knowledge/app-ui-architecture.md`, "TransferController".

### SwiftUI views

`app/CrocApp/Views/`. `ContentView` picks the layout from the horizontal size class, with one `AppRouter.path` of value-based routes. `SendView` and `ReceiveView` show an input form while idle, otherwise `TransferStatusView`, which draws every non-idle `Phase`. `Models/TransferLink.swift` is the one parser for every way a link or code arrives, and `AppRouter.open(_:)` hands the result to Receive, which fills in the code and never connects by itself. Views may import `CrocKit` for its value types but never `Croc`, and never call `CrocEngine`.

## Event and control flow

Event names are the `TransferEvent` cases. `Phase` is `TransferController.Phase`.

### Send, happy path

1. `SendView` calls `controller.start(.sendFiles(urls:code:))`. Phase becomes `.starting`. On iOS, `BackgroundCoordinator.transferStarted` wraps the transfer. `engine.startSend` starts the Go session.
2. Go calls `OnCodeReady`, Swift yields `.codeReady(code)`, and phase becomes `.waiting(code:)`. The screen shows the code, a QR code of the `https://crocapp.dev/r/#<code>` link, and a **Share Link** button.
3. The peer connects: `OnConnected` gives `.connected`. With **Confirm on Both Sides** on (croc's `--ask`), phase becomes `.confirmSend` and **Accept** calls `respond(accept: true)`.
4. `OnProgress` ticks arrive about 10 times a second as `.progress`. The controller ignores `waiting` ticks and all progress while phase is `.confirmSend` or `.incoming`: croc is blocked in `GetInput` waiting for `respond()`, and a phase overwritten there leaves the UI with nothing to call.
5. `OnDone` gives `.done(Summary)`, and `finishRecord` writes a `TransferRecord` to `HistoryStore`.

### Receive, happy path (with accept prompt)

1. `ReceiveView` calls `controller.start(.receive(code:folder:folderIsScoped:))`. `EngineStart` builds the options. `autoAccept` is `settings.autoAccept && !settings.bothSidesConfirm`: Confirm on Both Sides wins, because engine-level auto-accept closes the prompt pipe, which croc reads as "no".
2. `OnFileList` gives `.fileList`. With auto-accept off, phase becomes `.incoming(list, conflicts: [], blocked: [...])` at once. Unsafe names (`ReceivedName.isUnsafe`) are checked synchronously, and a detached task then checks the output folder for name clashes. Progress keeps ticking underneath (and is ignored) because croc is blocked reading the pipe that replaced fd 0.
3. The user accepts: `respond(accept: true, policy:)` reaches `CrocmobileTransfer.respond`. Go sets the file policy on the croc client and writes `y\n` to the pipe, then the policy's answers to croc's other stdin prompts, and closes the pipe. If files already exist the sheet offers **Decline**, **Replace** and **Keep Both**; otherwise one **Accept** button, which means Keep Both. Phase becomes `.connecting`.
4. `OnProgress` resumes, phase becomes `.transferring`, and `OnDone` gives `.done`. For a text transfer, `OnText` arrives just before `OnDone`.

### Decline and cancel

- Declining `.incoming` writes `n\n`. Locally croc reports `refused files` (code `refused`); the peer gets `refusing files` (code `declined`). A peer's cancel and a peer's decline look the same on the wire.
- Cancelling mid-transfer calls `engine.cancel(transferID)` (a cancel tapped before the ID exists is applied once it does), which reaches Go `session.cancel()`. That cancels the context and also closes the prompt pipe, because a context cancel alone does not unblock a pending `GetInput` read.
- Any final event finishes the stream, and `onTermination` cancels and clears that transfer by ID, which frees the engine.

JSON field lists, the per-file `fileSent` detail and transfers under 100 ms that jump straight to `done`: `docs/knowledge/crocmobile-bridge.md`.

## State ownership

`CrocAppApp.init()` creates `AppSettings` (on `UserDefaults` and the Keychain, or in-memory stores unless `LaunchMode.current` is `.app`, which covers harness and hosted-test runs, see `docs/GLOSSARY.md`), `HistoryStore`, `StoredTransferVault`, then `TransferController(settings:vault:)`, `OutputFolderStore`, `LocalNetworkChecker`, `MenuBarQuickSend` on macOS and `AppRouter.shared.attach(controller:)`. The one main window gets them through `.environment(...)`, plus `.modelContainer` for `@Query` in `HistoryView`; the app has one window because one transfer runs at a time. The macOS `Settings` scene gets only `outputFolder` and `settings`.

| What | Where | Owner |
| --- | --- | --- |
| App settings | `UserDefaults`, one `settings.`-prefixed key each, saved in `didSet` through the injected `SettingsStorage` | `AppSettings` |
| Proxy credentials | Keychain | `AppSettings` |
| Output folder | `UserDefaults` bookmark, security-scoped on macOS | `OutputFolderStore` |
| Transfer history | SwiftData `TransferRecord` | `HistoryStore` |
| Stored-upload receipts | Keychain item `storedReceipts`, removed on revoke and expiry | `StoredTransferVault` |
| Share-extension handoff | App Group container (`ShareInbox/batch-<UUID>/`, files first, then `manifest.json`) | `ShareStager` writes, `ShareInbox` reads; contract in `app/Shared/ShareHandoff.swift` |

## Platform split

One shared source tree, with `#if os(iOS)` and `#if os(macOS)` kept to dedicated files where behavior really differs. Backgrounding (`BGContinuedProcessingTask` with a Live Activity), QR scanning (VisionKit) and the multicast entitlement are iOS only. The Dock and window drop, the `Settings` scene, `AppCommands` and the `MenuBarExtra` are macOS only. The entitlement and `Info.plist` values live in `app/CrocApp/*.entitlements` and `app/Config/*.plist`; the reasons that are not obvious from them:

- `network.server` (macOS) lets croc's local relay listen inside the sandbox. croc starts it on every send unless **Skip Local Network** is on, and fails the send when it cannot bind. **Run a Relay** listens too. App Review needs the reason spelled out (`docs/knowledge/app-store-listing.md`, "Review notes").
- `networking.multicast` (iOS) is croc's local-network discovery. Apple grants it per team, so without it only the LAN race is lost, not the relay path (`docs/knowledge/apple-platform-constraints.md`).
- Security-scoped URLs: every send or receive intent calls `startAccessingSecurityScopedResource()` on URLs the user picked and tracks them in `SecurityScopes` until the stream ends, because the sandbox denies `stat` on a scope that is not open.
- The share extension is a separate process with a memory cap of about 120 MB. The App Group container is the only channel between it and the app, because a security-scoped bookmark does not resolve in another process. It copies the files in (on iOS inside the synchronous `loadFileRepresentation` callback, because the source temp file is deleted when it returns) and never deletes existing batches, because one may be mid-send.
- Associated Domains needs a provisioning profile, so signing a local macOS build needs the team set in the project (`docs/BUILDING.md`, "Verification harnesses").

## Concurrency model

- Swift 6 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` on every app target. Any type in the app or the share extension is `@MainActor` unless it opts out.
- `CrocEngine` is the deliberate exception: a plain `actor` on its own executor.
- Delegate callbacks arrive on arbitrary Go threads, and the poller goroutine and the transfer goroutine both call the delegate directly, with no ordering between threads.
- `DelegateBridge` is `@unchecked Sendable`, because the compiler cannot check an `NSObject` subclass that conforms to an Objective-C protocol. It only calls `continuation.yield(...)`, which is safe from any thread.
- The hop to `MainActor` happens at the `for await event in transfer.events` loop in `TransferController.run(_:)`.
