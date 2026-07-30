# Architecture

Top-down map of CrocApp. Start here, then follow the links at the bottom for depth. Doubles as a Swift/SwiftUI learning trail through the repo: every type named below is real and worth opening.

## System summary

CrocApp is a native SwiftUI app (iOS 26 + macOS 26, one multiplatform target, ADR 0005) that embeds [croc](https://github.com/schollz/croc) as a Go library rather than shelling out to a CLI. There is **one process**: the app binary. croc's transfer engine runs in-process as linked Go code (via a `gomobile`-built `.xcframework`), not as a subprocess and not as a daemon — iOS forbids spawning processes, so a subprocess model was never an option (ADR 0006). A single Swift actor, `CrocEngine`, is the only thing in the app that calls into that Go code, and `TransferController` is the only thing in the app that calls `CrocEngine`. Everything above that is SwiftUI views reacting to one `@Observable` state machine.

## Layer diagram

```
croc v10.5.0 (schollz/croc, go.mod pin)
    │  Go function calls (croc.NewCtx, Client polling)
    ▼
crocmobile/ (Go wrapper package)
    │  gobind: scalars, strings, bools, interfaces, struct pointers only
    │  (no []string, no unsigned ints, no struct slices — paths/ports/excludes
    │  cross as newline- or comma-joined strings; fileList/progress/done cross
    │  as JSON strings)
    ▼
gomobile bind -target ios,iossimulator,macos/arm64
    ▼
CrocKit/Croc.xcframework  (gitignored build artifact, ADR 0006)
    │  ObjC-bridged Go symbols: CrocmobileOptions, CrocmobileTransfer,
    │  CrocmobileDelegateProtocol; import Croc
    ▼
CrocKit (Swift package: CrocEngine actor, DelegateBridge, Models.swift)
    │  AsyncStream<TransferEvent>; delegate callbacks arrive on Go threads,
    │  DelegateBridge only yields into the stream — no MainActor hop here
    ▼
TransferController (@MainActor @Observable, app/CrocApp/Models/)
    │  Phase enum; intents (startSend, startReceive, respond, cancel)
    ▼
SwiftUI views (app/CrocApp/Views/)
    switch over controller.phase; call intents; nothing else touches CrocKit
```

## Per-layer detail

### croc (vendored dependency, not this repo's code)

`schollz/croc/v10` v10.5.0, pinned in `crocmobile/go.mod`. PAKE-secured, relay-assisted, end-to-end encrypted transfer protocol. CrocApp does not fork or reimplement it (project non-goal, `docs/knowledge/project-overview.md`); upgrades are a version bump + rebind, tracked in `docs/knowledge/croc-upgrade-playbook.md`.

### `crocmobile/` — Go wrapper

Files: `crocmobile.go` (public API: `Options`, `Delegate` interface, `Transfer` handle, `StartSend`/`StartReceive`), `session.go` (the engine: `session` struct, `startSession`/`startReceiveSession`, the fd0 prompt pipe, the 10 Hz poller), `doc.go` (package-level gobind constraint comment), `cmd/croctest/main.go` (CLI harness, not linked into the app).

Responsibility: adapt croc's CLI-shaped library API (process-global `os.Chdir`, stdin-bound prompts, `os.Stdout`-piped text receive) into something callable repeatedly and concurrently-safely from a GUI. Key types: `Options` (mirrors croc CLI flags, gobind-safe scalar fields only), `Delegate` (7-method callback interface: `OnCodeReady`, `OnConnected`, `OnFileList`, `OnProgress`, `OnText`, `OnDone`, `OnError`), `Transfer` (`Cancel()`, `Respond(accept bool)`).

Deliberately does **not**: run more than one transfer at a time (package-global `activeMu` mutex, ADR 0008 — second `Start*` call returns `"another transfer is active"`), expose every croc knob (`RelayPorts`, `Curve`, `HashAlgorithm`, `ThrottleUpload`, `NoMultiplexing` are settable in `Options` but unwired above CrocKit — F20-F29 backlog, `docs/knowledge/features.md`), or let a Go panic cross the gobind boundary uncaught: `StartSend`/`StartReceive`/`Cancel`/`Respond` each carry their own `recover()`, `run()` recovers around `xfer()` and again around the terminal `OnError`/`OnText`/`OnDone` calls, and `poll()` recovers per tick around `OnConnected`/`OnFileList`/`OnProgress` (`session.go`'s `reportPanic`). `xfer()` itself has no watchdog, though — a hang there past context cancel still holds `activeMu` forever (`docs/known-issues.md`).

Gobind surface: the xcframework's ObjC module is `Croc` (`import Croc`); Go symbols get an `Crocmobile`-prefixed ObjC name (`CrocmobileOptions`, `CrocmobileStartSend`, protocol `CrocmobileDelegateProtocol` → Swift `CrocmobileDelegateProtocol`). Full type-restriction list and the JSON field-by-field contract: `docs/knowledge/crocmobile-bridge.md`.

### `Croc.xcframework` — the gomobile bind

Built by `scripts/build-xcframework.sh` (`gomobile bind -target ios,iossimulator,macos/arm64`), one output feeding both platforms. Gitignored; not part of this repo's source of truth (see Build-time architecture below).

### `CrocKit/` — Swift package

`Package.swift`: swift-tools 6.0, platforms `.iOS("26.0")`, `.macOS("26.0")`, targets `Croc` (the binaryTarget), `CrocKit` (depends on `Croc`), `crockit-verify` (executable harness, depends on `CrocKit`).

- `CrocEngine.swift` — `public actor CrocEngine`. Owns the one `CrocmobileTransfer` handle at a time (`activeTransfer`), exposes `startSend`/`startReceive` (return `AsyncStream<TransferEvent>`), `respond(accept:)`, `cancel()`. `crocOptions(from:)` maps Swift `EngineOptions` to `CrocmobileOptions` — this is the actual list of knobs the GUI can reach; anything in Go's `Options` not copied here is inert from the app's perspective. `CrocEngineError`: `.transferActive`, `.startFailed(String)`.
- `DelegateBridge.swift` — `final class DelegateBridge: NSObject, CrocmobileDelegateProtocol, @unchecked Sendable`. Bridges Go-thread callbacks into `AsyncStream<TransferEvent>.Continuation.yield`. Decodes the JSON event payloads into `Models.swift` structs; a malformed `fileList` or `done` payload becomes `.failed(...)` and finishes the stream (the Go side is then orphaned until the consumer calls `engine.cancel()`, per the doc comment on `DelegateBridge`).
- `Models.swift` — `EngineOptions` (Swift-side settings struct), `TransferEvent` enum (`codeReady`, `connected`, `fileList`, `progress`, `text`, `done`, `failed`), `FileList`, `TransferProgress`, `Summary` (all `Codable, Sendable`).
- `crockit-verify` — standalone executable (`send`/`receive`/`twice` subcommands), macOS-only interop harness, not shipped in the app.

Deliberately does **not**: hop to `MainActor` itself. `DelegateBridge` only yields; the consumer (`TransferController`) does the hop, because `@MainActor @Observable` state can only be mutated there.

### `TransferController` — app state machine

`app/CrocApp/Models/TransferController.swift`. `@MainActor @Observable final class`. The only consumer of `CrocKit` in the app. Owns a private `CrocEngine`, a `BackgroundCoordinator`, and the `Phase` enum every view switches on. Full event-handling invariants (why `.progress` must not clobber `.incoming`, the `transferActive` retry window, copy precedence): `docs/knowledge/app-ui-architecture.md`.

### SwiftUI views

`app/CrocApp/Views/`. `HomeView` is the sole `NavigationStack` (value-based `AppRouter.Route` links). `SendView`/`ReceiveView` show an input form when `!controller.isActive`, else `TransferStatusView`. `TransferStatusView` renders every non-idle `Phase`; `IncomingRequestView` (in the same file) is the accept gate. `SettingsScreen` (iOS route) and `SettingsView` (macOS `Settings` scene) both embed the shared `PowerSettingsSections`. `HistoryView`, `HowItWorksView`, `OnboardingView`, `StagedFilesSheet`, `QRCodeView`, `QRScannerView`, `TrustBadge` round out the view layer. Views never import `Croc` or `CrocKit` — they only read `TransferController.phase` and call its intent methods.

## Event and control flow

Real event names are the `TransferEvent` cases; `Phase` is `TransferController.Phase`.

### Send, happy path

1. `SendView` calls `controller.startSend(urls:customCode:)`. `phase = .starting`; `BackgroundCoordinator.transferStarted` wraps the transfer (iOS only); `engine.startSend` launches the Go session.
2. Go delegate fires `OnCodeReady` → Swift `.codeReady(code)` → `phase = .waiting(code:)`. The waiting view shows the code and a QR (`QRCodeView`).
3. Peer connects: `OnConnected` → `.connected`. If `settings.bothSidesConfirm` (croc `--ask`, F19) is on, `phase = .confirmSend` instead of `.connecting` — this is the sender-side "both sides confirm" gate; the user's accept calls `respond(accept: true)`, decline calls `cancel()`.
4. Progress ticks arrive at ~10 Hz as `OnProgress` → `.progress(TransferProgress)`, `step` cycling `waiting` → `connected` → `transferring`. `TransferController` ignores `step == "waiting"` ticks and, critically, ignores all progress while `phase` is `.confirmSend` (same guard protects the receive side's `.incoming`) — croc is blocked in `GetInput` waiting for `respond()`, and a clobbered phase there means the UI can never call it.
5. Transfer completes: `OnDone` → `.done(Summary)` → `phase = .done(summary, receivedText: nil)`. `finishRecord` writes a `TransferRecord` to `HistoryStore`.

### Receive, happy path (with accept prompt)

1. `ReceiveView` calls `controller.startReceive(code:into:folderIsScoped:)`. `options.overwrite = true` always (conflicts are surfaced in the UI, not deferred to croc — ADR 0009); `options.autoAccept = settings.autoAccept && !settings.bothSidesConfirm` (Ask always wins over auto-accept, since engine-level `AutoAccept` closes the prompt pipe and the resulting EOF would decline instead of accept).
2. `OnFileList` → `.fileList(FileList)`. If auto-accept is off, `phase = .incoming(list, conflicts: [], blocked: [...])` immediately (unsafe names, via `ReceivedName.isUnsafe`, are computed synchronously); a detached task then stats the output folder for name collisions and back-fills `conflicts` if the phase is still `.incoming`. Progress keeps ticking underneath (guarded, per above) because croc is blocked in `utils.GetInput`, reading the dup2'd fd0 pipe (`crocmobile/session.go`), waiting on `Respond`.
3. User accepts: `TransferController.respond(accept: true)` calls `engine.respond(accept:)` → `CrocmobileTransfer.respond` → Go writes `y\n` to the pipe (once, for receive; per-file for a sender-side Ask, see `docs/knowledge/crocmobile-bridge.md`) and closes it. `phase = .connecting`.
4. `OnProgress` resumes normally, `phase = .transferring(TransferProgress)`.
5. `OnDone` → `.done`. For a text transfer, `OnText` arrives just before `OnDone`; `receivedText` is threaded into `Phase.done(_, receivedText:)`.

### Decline and cancel

- User declines `.incoming`: `respond(accept: false)` writes `n\n`, sets `declineRequested = true`. croc surfaces this to both sides as the string `"refused files"` — `TransferController.friendlyMessage` maps it to "You declined the transfer." locally and "The other side declined the transfer." when it arrives as `.failed` on the peer's controller.
- User cancels mid-transfer: `controller.cancel()` sets `cancelRequested = true` and calls `engine.cancel()`, which calls the Go `Transfer.Cancel()` → `session.cancel()`: context-cancels *and* closes the prompt pipe (a bare context cancel does not unblock a pending `GetInput` read — ADR 0008's rationale for why `cancel()` must also touch the pipe).
- Any terminal event also triggers `Task { await engine.cancel() }` from `TransferController.handle(.failed)` as a belt-and-suspenders release, since the engine must be free for the next transfer to start.

Full JSON field lists, the `fileSent`-is-per-current-file wrinkle, and sub-100ms transfers that skip straight to `done`: `docs/knowledge/crocmobile-bridge.md`.

## State ownership

`CrocAppApp.init()` (`app/CrocApp/CrocAppApp.swift`) builds, in order:

1. `AppSettings()` — must exist first; `TransferController` takes it as a constructor dependency.
2. `HistoryStore(container:)` — `ModelContainer` is in-memory when `AutoVerify.isHarnessRun`, on-disk otherwise.
3. `TransferController(settings:)`, then `controller.history = history` set explicitly (not a constructor argument, since `HistoryStore` depends on the harness check that also gates settings).
4. `OutputFolderStore()`, `LocalNetworkChecker()`, `AppRouter.shared` — order among these three doesn't matter; none depend on the others.

`WindowGroup` content gets all six as `.environment(...)`, plus `.modelContainer(history.container)` for `@Query` in `HistoryView`. The macOS `Settings` scene is deliberately narrower: only `outputFolder` and `settings` are injected — no `router`, no `controller`, no `localNetwork` (Settings has no transfer to be busy with).

`@MainActor @Observable` types: `AppSettings`, `TransferController`, `HistoryStore`, `OutputFolderStore`, `LocalNetworkChecker`, `AppRouter` (all of them — the module default actor isolation is `MainActor`, see Concurrency below).

Persistence:

| What | Where | Notes |
|---|---|---|
| Power settings (F13-F19) | `UserDefaults`, keys prefixed `settings.` | `AppSettings`, `didSet`-triggered, gated by a `persist` flag |
| Output folder choice | `UserDefaults` (security-scoped bookmark) | `OutputFolderStore` |
| Transfer history (F12) | SwiftData, `TransferRecord` `@Model` | `HistoryStore`, in-memory under `AutoVerify` |
| Share-extension handoff | App Group container (`group.com.bakirgdev.CrocApp`) | `ShareInbox` reads, `ShareStager` writes; `ShareInbox/batch-<UUID>/` + `manifest.json` |
| Onboarding seen flag | `UserDefaults` via `@AppStorage` | `onboarding.seen`, read in `ContentView` |

## Platform split

One SwiftUI target, `#if os(iOS)` / `#if os(macOS)` isolated to dedicated files where real divergence exists (ADR 0005):

| Concern | iOS | macOS |
|---|---|---|
| Backgrounding | `BackgroundCoordinator` wraps transfers in `BGContinuedProcessingTask`; system Live Activity | no-op (all `BackgroundCoordinator` bodies are `#if os(iOS)`) |
| External send entry point | Share extension (`CrocShare` appex) + `ShareInbox`/`StagedFilesSheet` | Dock-icon drop + window drop, via `AppDelegate.application(_:open:)` and `AppRouter.shared` |
| Local-network probe | `LocalNetworkChecker` (Bonjour self-probe) | same file, same probe — macOS 15 added its own Local Network privacy pane, enforced as a Network Extension packet filter rather than through TCC |
| QR scan | `QRScannerView` (VisionKit `DataScannerViewController`), whole file `#if os(iOS)` | not offered (QR *generation*, `QRCodeView`, is cross-platform) |
| Settings surface | `SettingsScreen` (`Route.settings`, gear toolbar icon) | `SettingsView` (native `Settings` scene, ⌘,) |
| Menu commands | n/a | `AppCommands` (Send ⌘1, Receive ⌘2, Show Receive Folder ⇧⌘R) |

Two entitlement sets for the main app target, selected by SDK in the pbxproj (`CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]` etc.):

- `app/CrocApp/CrocApp.entitlements` (macOS): `com.apple.security.app-sandbox`, `network.client`, `network.server` (needed for the local-only relay listener), `files.user-selected.read-write`, `files.downloads.read-write` (default output folder is `~/Downloads/CrocApp`).
- `app/CrocApp/CrocApp-iOS.entitlements`: just `com.apple.security.application-groups` (`group.com.bakirgdev.CrocApp`, for the share-extension handoff).
- `app/CrocShare/CrocShare.entitlements`: same App Group group, nothing else (the extension has no network, no sandbox exception beyond the group).

Three `Info.plist` sources (`app/Config/CrocApp-Info.plist` for iOS, `CrocApp-macOS-Info.plist` for macOS, `CrocShare-Info.plist` for the extension) merged over Xcode's `GENERATE_INFOPLIST_FILE=YES` output; SDK-scoped `INFOPLIST_KEY_*` build settings (camera usage, local-network usage, file-sharing, document-types-in-place) live directly in the pbxproj rather than in these files.

Sandbox boundaries that shaped the design, concretely:

- Security-scoped URLs: every send/receive intent in `TransferController` calls `startAccessingSecurityScopedResource()` on user-picked URLs and tracks them in `scopedURLs` for release at stream end; `OutputFolderStore` and `HistoryView`'s bookmark-resolve path do the same, on both platforms, before any `fileExists`/`stat` call (the sandbox denies `stat` on an unopened scope — a defect caught separately on each platform, per `docs/knowledge/app-ui-architecture.md`).
- App Group container: the only channel between `CrocShare` (a separate process, ~120 MB memory cap, no long-running work) and the main app. The extension copies attachment bytes in `loadFileRepresentation`'s synchronous callback (the source temp file is deleted once that callback returns) and never deletes existing batches — a batch may be mid-send.
- Output folder: iOS defaults to the app's own Documents (Files-app visible via `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`); macOS defaults to `~/Downloads/CrocApp`, requiring the `files.downloads.read-write` entitlement — this is why that entitlement exists at all.
- `network.server` on macOS exists solely so croc's local relay listener can bind a port inside the sandbox (`--local`/`onlyLocal`); this was proven, not assumed (`docs/decisions/0011-macos-platform-integration-choices.md`).

## Concurrency model

Swift 6 language mode (`SWIFT_VERSION = 6.0`), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` set for every target in the pbxproj (app, both platform build configs, and `CrocShare`). Practical effect: any type in the app or share extension that doesn't opt out is implicitly `@MainActor` — this is why `AppSettings`, `TransferController`, `HistoryStore`, `OutputFolderStore`, `LocalNetworkChecker`, and `AppRouter` all carry an explicit `@MainActor` (belt-and-suspenders documentation of what the compiler already enforces) rather than needing it to compile.

`CrocEngine` is the one deliberate exception: it's a plain `actor`, isolated to its own executor, not `MainActor`. `CrocmobileDelegate` callbacks (`OnCodeReady`, `OnProgress`, etc.) arrive on arbitrary Go threads — `crocmobile`'s poller goroutine and the transfer goroutine both call the delegate directly, with no serialization guarantee about which Swift/Go thread runs which callback. `DelegateBridge` (`@unchecked Sendable`, because `NSObject` subclasses conforming to an ObjC protocol can't be verified `Sendable` by the compiler) receives those calls and does exactly one thing: `continuation.yield(...)` into the `AsyncStream`. `AsyncStream.Continuation.yield` is safe to call from any thread. The hop to `MainActor` happens implicitly at the `for await event in stream` loop inside `TransferController.run(_:)`, because that method (and the whole class) is `@MainActor`.

## Build-time architecture

`CrocKit/Package.swift` declares `Croc` as a `.binaryTarget(path: "Croc.xcframework")`; that path is gitignored. A fresh clone therefore builds nothing in `CrocKit` or the app until `scripts/build-xcframework.sh` has run once (ADR 0006). Full toolchain requirements, CI wiring, and the manual steps: `docs/BUILDING.md`.

## Where to go next

| Question | Document |
|---|---|
| Exact event JSON fields, croc gotchas, verification harnesses | `docs/knowledge/crocmobile-bridge.md` |
| View-by-view UI invariants, settings/trust details, platform layer specifics | `docs/knowledge/app-ui-architecture.md` |
| iOS/macOS platform limits (background, multicast, sandbox, App Store review) | `docs/knowledge/apple-platform-constraints.md` |
| Why a structural choice was made | `docs/decisions/` (ADRs, `NNNN-slug.md`) |
| Feature status (shipped / planned / skipped) | `docs/knowledge/features.md` |
| Fresh-clone build steps | `docs/BUILDING.md` |
| Design tokens, component specs, SF Symbols mapping | `design/README.md` |
| Term definitions (croc, PAKE, relay, etc.) | `docs/GLOSSARY.md` |
| Known defects, accepted papercuts | `docs/known-issues.md` |
