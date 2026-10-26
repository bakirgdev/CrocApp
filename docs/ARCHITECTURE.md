# Architecture

Top-down map of CrocApp. Start here, then follow the links at the end for depth. Terms like PAKE, relay and gobind are in `docs/GLOSSARY.md`.

## System summary

CrocApp is a native SwiftUI app for iOS, iPadOS and macOS 26. It embeds [croc](https://github.com/schollz/croc) as a Go library instead of running the croc command.

- There is one process: the app. croc's transfer engine runs inside it as linked Go code, built into an `.xcframework` with `gomobile`.
- It is not a subprocess and not a daemon. iOS does not allow spawning processes, so a subprocess design was never possible.
- One Swift actor, `CrocEngine`, is the only code that calls the Go code.
- `TransferController` is the only code that calls `CrocEngine`.
- Everything above that is SwiftUI views reacting to one `@Observable` state machine.

The SwiftUI sources build three targets:

| Target | Platforms | Channel |
| --- | --- | --- |
| `CrocApp` | iOS and macOS | App Store builds (status: `docs/knowledge/project-overview.md`, "Status") |
| `CrocApp Direct` | macOS, arm64 | Direct download (notarized DMG with Sparkle updates) |
| `CrocShare` | iOS | Share extension |

## Layer diagram

```
croc v11.5.5 (schollz/croc, pinned in crocmobile/go.mod)
    │
    ▼
crocmobile/            Go wrapper package
    │
    ▼
gomobile bind          ios, iossimulator, macos/arm64
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

Notes on the arrows:

- Go calls croc directly (`croc.NewCtx`, then polling the client).
- gobind only passes scalars, strings, bools, interfaces and struct pointers. Lists cross as newline- or comma-joined strings. File lists, progress and the final summary cross as JSON strings.
- Delegate callbacks arrive on Go threads. `DelegateBridge` only yields into the stream and does not hop to `MainActor`.

## Per-layer detail

### croc (dependency, not this repo's code)

- `schollz/croc/v11` v11.5.5, pinned in `crocmobile/go.mod`.
- CrocApp does not fork or reimplement it (see `docs/knowledge/project-overview.md`).
- Upgrades are a version bump plus a rebuild of the xcframework: `docs/knowledge/croc-upgrade-playbook.md`.

### `crocmobile/`: Go wrapper

Job: adapt croc's command-line-shaped library (process-global `os.Chdir`, stdin prompts, text receive through `os.Stdout`) so a GUI can call it repeatedly and safely.

Files:

- `crocmobile.go`: public API (`Options`, the `Delegate` interface, the `Transfer` handle, `StartSend`, `StartReceive`).
- `session.go`: the engine (the `session` struct, `startSession`, `startReceiveSession`, the prompt pipe on fd 0, the 10 Hz poller).
- `store.go`: stored transfers (`StartStoreSend`, `StartStoreReceive`, `RevokeStored`), run on the same `Transfer` handle.
- `errors.go`: turns croc errors into failure codes.
- `network.go`: validates Advanced options and sets croc's process-wide proxy and DNS globals.
- `relay.go`: public relay selection.
- `doc.go`: the gobind constraint comment.
- `cmd/croctest/main.go`: a command-line test harness, not linked into the app.

Key types:

- `Options` mirrors croc's command-line flags, using gobind-safe scalar fields only.
- `Delegate` has 8 callbacks: `OnCodeReady`, `OnConnected`, `OnFileList`, `OnProgress`, `OnText`, `OnDone`, `OnError`, `OnStored`.
- `Transfer` has `Cancel()` and `Respond(accept bool, policy string)`. The policy is `PolicyKeepBoth` or `PolicyReplace`.

Errors:

- `OnError` receives JSON `{"code","message"}`. `StartSend` and `StartReceive` return the same JSON as their error text, because gobind gives Swift only the text.
- `errors.go` maps croc's sentinel errors, this package's `codedError` and croc v11.5.5 error text to these codes: `peerVersion`, `relayUnreachable`, `noPublicRelay`, `declined`, `refused`, `roomFull`, `badPassword`, `wrongCode`, `cancelled`, `connectionLost`, `storeLimit`, `storeExpired`, `invalidSetting`, `other`.
- The app picks its wording from the code and never reads croc's text.

Network settings:

- `network.go` sets croc's proxy and DNS globals for the length of one transfer and restores them before `activeMu` is released.
- Stored transfers get their own proxied HTTP client instead, because `RevokeStored` runs outside the lock.

What it deliberately does not do:

- Run more than one transfer at a time. A package-global `activeMu` mutex makes a second `Start*` call return `"another transfer is active"`.
- Let a Go panic cross into Swift. `StartSend`, `StartReceive`, `Cancel` and `Respond` each recover. `run()` recovers around `xfer()` and around the final `OnError`, `OnText` and `OnDone` calls. `poll()` recovers on every tick. A recovered panic reports code `other` (`reportPanic` in `session.go`).
- Guard against a hang inside `xfer()` past context cancel. That would hold `activeMu` for the life of the process (`docs/known-issues.md`, "Accepted").

Gobind naming: the xcframework's module is `Croc` (`import Croc`). Go symbols get a `Crocmobile` prefix in Objective-C: `CrocmobileOptions`, `CrocmobileTransfer`, `CrocmobileStartSend`. The Go interface `Delegate` is the Objective-C protocol `CrocmobileDelegate`, which Swift imports as `CrocmobileDelegateProtocol`. The full type rules and the JSON field list are in `docs/knowledge/crocmobile-bridge.md`.

### `Croc.xcframework`

- Built by `scripts/build-xcframework.sh` with `gomobile bind -target ios,iossimulator,macos/arm64`. One output serves both platforms.
- Gitignored. See "Build-time architecture" below.

### `CrocKit/`: Swift package

`Package.swift`: swift-tools 6.0, platforms iOS 26 and macOS 26. Targets: `Croc` (the binary target), `CrocKit`, `crockit-verify` (executable) and `CrocKitTests`.

- `CrocEngine.swift`: `public actor CrocEngine`, and the `TransferEngine` protocol it conforms to.
  - `TransferEngine` is exactly what `TransferController` calls: `startSend`, `startReceive`, `startStoreSend`, `startStoreReceive`, `respond`, `cancel` and `revokeStored`, all `async`. It exists so the app's tests can stand in a fake engine. `TransferID` and `EngineTransfer` have public initializers for the same reason.
  - Holds the one active `CrocmobileTransfer` (`activeTransfer`).
  - `startSend` and `startReceive` return an `EngineTransfer` with an `id: TransferID` and `events: AsyncStream<TransferEvent>`.
  - `startStoreSend`, `startStoreReceive` and `revokeStored` do the same for stored transfers.
  - `respond(accept:policy:)` answers the accept prompt.
  - `cancel(_ id: TransferID)` ignores a stale ID, so a late cancel cannot reach the next transfer.
  - `crocOptions(from:)` maps Swift `EngineOptions` to `CrocmobileOptions`. It is the list of settings the app can reach. A Go option not copied there is unused by the app.
  - `CrocEngineError` is `.transferActive` or `.startFailed(EngineFailure)`.
- `DelegateBridge.swift`: `final class DelegateBridge: NSObject, CrocmobileDelegateProtocol, @unchecked Sendable`.
  - Turns Go-thread callbacks into `AsyncStream<TransferEvent>.Continuation.yield`.
  - Decodes the JSON payloads. A malformed file list, receipt or summary becomes `.failed` with code `other`, and the stream finishes.
  - When the stream finishes, `CrocEngine`'s `onTermination` cancels that transfer by ID, so the consumer needs no cancel call.
- `Models.swift`: `EngineOptions`, `FilePolicy`, `Transport`, `Curve`, `HashAlgorithm`, `ProxySettings`, `FileList`, `TransferProgress`, `Summary`, `StoredReceipt`, `EngineFailure`.
  - `TransferEvent` cases: `codeReady`, `connected`, `fileList`, `progress`, `text`, `stored`, `done`, `failed`.
  - `EngineFailure.Code` mirrors the Go codes. An unknown code or a malformed payload decodes as `.other` with the raw text.
- `crockit-verify`: a macOS-only executable (`send`, `receive` and `twice` subcommands) that tests interop with the croc command. It is not shipped.

CrocKit does not hop to `MainActor`. `DelegateBridge` only yields. `TransferController` does the hop, because its `@MainActor` state can only change there.

### `TransferController`: app state machine

File: `app/CrocApp/Models/TransferController.swift`. A `@MainActor @Observable final class`.

- The only caller of `CrocEngine`. It holds the engine as `any TransferEngine`, a `BackgroundCoordinator` and the `Phase` enum that every view switches on.
- `init(settings:vault:engine:)` defaults `engine` to `CrocEngine()`. `TransferControllerTests` passes `FakeTransferEngine` (both in `app/CrocAppTests/`).
- Intents: `startSend`, `startSendText`, `startStoreSend`, `startReceive`, `startStoreReceive`, `respond`, `cancel`, `revoke`.
- `Phase` cases: `idle`, `starting`, `waiting`, `connecting`, `confirmSend`, `incoming`, `transferring`, `done`, `stored`, `failed`.
- Event-handling rules (why progress must not overwrite `incoming`, the retry window after `transferActive`, copy precedence): `docs/knowledge/app-ui-architecture.md`, "TransferController".

### SwiftUI views

Folder: `app/CrocApp/Views/`.

- `HomeView` is the only `NavigationStack`. It uses value-based `AppRouter.Route` links.
- `SendView` and `ReceiveView` show an input form when `controller.isActive` is false, otherwise `TransferStatusView`.
- `TransferStatusView` draws every non-idle `Phase`. `IncomingRequestView` (same file) is the accept screen.
- `SettingsScreen` (iOS, a route) and `SettingsView` (macOS `Settings` scene) both embed `PowerSettingsSections`.
- Others: `HistoryView`, `HowItWorksView`, `OnboardingView`, `StagedFilesSheet`, `QRCodeView`, `QRScannerView`, `TrustBadge`.
- `Models/TransferLink.swift` is the one parser for every way a link or code arrives: a bare code, a stored-transfer link, `crocapp://receive?code=`, `https://crocapp.dev/r/#<code>`, `https://getcroc.com/?code=` and `croc://<code>`.
- `AppRouter.open(_:)` passes the parsed link to Receive, which fills in the code and never connects by itself.
- Views may import `CrocKit` for its value types (`Summary`, `FilePolicy`, `Transport`). They never import `Croc` and never call `CrocEngine`. They read `TransferController.phase` and call its intent methods.

## Event and control flow

Event names are the `TransferEvent` cases. `Phase` is `TransferController.Phase`.

### Send, happy path

1. `SendView` calls `controller.startSend(urls:customCode:)`. Phase becomes `.starting`. On iOS, `BackgroundCoordinator.transferStarted` wraps the transfer. `engine.startSend` starts the Go session.
2. Go calls `OnCodeReady`, Swift yields `.codeReady(code)`, and phase becomes `.waiting(code:)`. The screen shows the code, a QR code (`QRCodeView`) of the `https://crocapp.dev/r/#<code>` link, and a **Share Link** button.
3. The peer connects: `OnConnected` gives `.connected`.
   - If the **Confirm on Both Sides** setting (`settings.bothSidesConfirm`, croc's `--ask`) is on, phase becomes `.confirmSend` instead of `.connecting`. Accept calls `respond(accept: true)`. **Cancel** calls `cancel()`.
4. `OnProgress` ticks arrive about 10 times a second as `.progress(TransferProgress)`. The `step` field goes `waiting`, `connected`, `transferring`.
   - `TransferController` ignores `waiting` ticks.
   - It also ignores all progress while phase is `.confirmSend` or `.incoming`. croc is blocked in `GetInput` waiting for `respond()`, and a phase overwritten there leaves the UI with nothing to call.
5. `OnDone` gives `.done(Summary)`, and phase becomes `.done(summary, receivedText: nil)`. `finishRecord` writes a `TransferRecord` to `HistoryStore`.

### Receive, happy path (with accept prompt)

1. `ReceiveView` calls `controller.startReceive(code:into:folderIsScoped:)`.
   - `options.whenFileExists` comes from the settings (Keep Both by default). It applies directly only under auto-accept. Otherwise the incoming sheet's choice goes to `respond(accept:policy:)`.
   - `options.autoAccept = settings.autoAccept && !settings.bothSidesConfirm`. Confirm on Both Sides wins, because engine-level auto-accept closes the prompt pipe, which croc reads as "no".
2. `OnFileList` gives `.fileList(FileList)`. With auto-accept off, phase becomes `.incoming(list, conflicts: [], blocked: [...])` at once.
   - Unsafe names (`ReceivedName.isUnsafe`) are checked synchronously.
   - A detached task then checks the output folder for name clashes and fills in `conflicts` if the phase is still `.incoming`.
   - Progress keeps ticking underneath (and is ignored, see above) because croc is blocked in `utils.GetInput`, reading the pipe that replaced fd 0 (`crocmobile/session.go`).
3. The user accepts: `TransferController.respond(accept: true, policy:)` calls `engine.respond`, then `CrocmobileTransfer.respond`.
   - Go sets the file policy on the croc client and writes `y\n` to the pipe (once for a receive, once per file for a sender-side confirm). It then writes the policy's answers to croc's other stdin prompts and closes the pipe (`docs/knowledge/crocmobile-bridge.md`).
   - If the check found existing files, the sheet offers **Decline**, **Replace** and **Keep Both**. Otherwise it offers one **Accept** button, which means Keep Both.
   - Phase becomes `.connecting`.
4. `OnProgress` resumes, and phase becomes `.transferring(TransferProgress)`.
5. `OnDone` gives `.done`. For a text transfer, `OnText` arrives just before `OnDone`, and the text goes into `Phase.done(_, receivedText:)`.

### Decline and cancel

- The user declines `.incoming`: `respond(accept: false)` writes `n\n` and sets `declineRequested`.
  - Locally, croc reports `refused files` (code `refused`). The peer gets `refusing files` (code `declined`).
  - `TransferController.friendlyMessage(for:cancelRequested:declineRequested:stored:)` picks text by code: "You declined the transfer." locally, and "The other device declined or cancelled the transfer." on the peer.
  - A peer's cancel and a peer's decline look the same on the wire.
- The user cancels mid-transfer: `controller.cancel()` sets `cancelRequested` and calls `engine.cancel(transferID)`. A cancel tapped before the ID exists is applied once it does.
  - This reaches Go `Transfer.Cancel()`, then `session.cancel()`, which cancels the context and also closes the prompt pipe. A context cancel alone does not unblock a pending `GetInput` read.
- Any final event finishes the stream. The stream's `onTermination` cancels and clears that transfer by ID, which frees the engine. `TransferController.handle(.failed)` does not call `engine.cancel`.

JSON field lists, the per-file `fileSent` detail, and transfers under 100 ms that jump straight to `done`: `docs/knowledge/crocmobile-bridge.md`.

## State ownership

`CrocAppApp.init()` (`app/CrocApp/CrocAppApp.swift`) creates, in this order:

1. `AppSettings()`. `TransferController` takes it as a constructor argument.
2. `HistoryStore(container:)`. The `ModelContainer` is in memory when `AutoVerify.isHarnessRun` is true (see `AutoVerify harness` in `docs/GLOSSARY.md`), on disk otherwise.
3. `StoredTransferVault`, backed by the Keychain (or an in-memory store under the harness).
4. `TransferController(settings:vault:)`, then `controller.history = history`.
5. `OutputFolderStore()` and `LocalNetworkChecker()`.
6. On macOS, `MenuBarQuickSend(controller:)`.
7. `AppDependencyManager.shared.add(dependency:)` for the controller and output folder, so Shortcuts actions work right after launch.
8. `AppRouter.shared.attach(controller:)`. `AppRouter.shared` already exists before `init` runs, so the controller is attached afterwards.

Why `history` is set after construction: not verified. The code does it, with no comment saying why.

Injection:

- `WindowGroup` content gets `controller`, `settings`, `outputFolder`, `localNetwork`, `router` and `history` through `.environment(...)`, plus `.modelContainer(history.container)` for `@Query` in `HistoryView`.
- The macOS `Settings` scene gets only `outputFolder` and `settings`. It has no transfer to be busy with.

`@MainActor @Observable` types: `AppSettings`, `TransferController`, `HistoryStore`, `OutputFolderStore`, `LocalNetworkChecker`, `AppRouter`, `ShareInbox`, `MenuBarQuickSend`, `LoginItem`. `StoredTransferVault` and `BackgroundCoordinator` are `@MainActor` but not `@Observable`. See "Concurrency model".

Persistence:

| What | Where | Notes |
| --- | --- | --- |
| Power settings (relay, local-only, compression and the like) | `UserDefaults`, keys prefixed `settings.` | `AppSettings`; each property saves in `didSet`; a `persist` flag turns saving off |
| Advanced settings | `UserDefaults`, keys `settings.advanced.*` | Proxies go to the Keychain instead (accounts `advanced.socks5Proxy`, `advanced.httpProxy`) |
| Output folder | `UserDefaults` key `outputFolderBookmark` | `OutputFolderStore`; security-scoped bookmark on macOS |
| Transfer history | SwiftData, `TransferRecord` `@Model` | `HistoryStore`; in memory under the harness |
| Stored-upload receipts | Keychain, one item `storedReceipts` | `StoredTransferVault`; removed on revoke and when expired; in memory under the harness |
| Share-extension handoff | App Group container `group.com.bakirgdev.CrocApp` | `ShareStager` (extension) writes `ShareInbox/batch-<UUID>/` plus `manifest.json`; `ShareInbox` (app) reads |
| Onboarding seen flag | `UserDefaults` via `@AppStorage("onboarding.seen")` | Read in `ContentView` |

## Platform split

One shared source tree, with `#if os(iOS)` and `#if os(macOS)` kept to dedicated files where behavior really differs.

| Concern | iOS | macOS |
| --- | --- | --- |
| Backgrounding | `BackgroundCoordinator` wraps transfers in `BGContinuedProcessingTask`, with a system Live Activity | Nothing; the `BackgroundCoordinator` bodies are `#if os(iOS)` |
| Sending from outside the app | Share extension (`CrocShare`) plus `ShareInbox` and `StagedFilesSheet` | Dock icon drop and window drop, through `AppDelegate.application(_:open:)` and `AppRouter.shared` |
| Local-network check | `LocalNetworkChecker` (Bonjour self-probe) | Same file, same probe |
| Receive links | `.onOpenURL` in `CrocAppApp` | `.onOpenURL` too, plus `AppDelegate.application(_:open:)`; file URLs go to Send; both parse with `TransferLink` and call `AppRouter.open(_:)` |
| QR scan | `QRScannerView` (VisionKit `DataScannerViewController`); whole file is `#if os(iOS)` | Not offered (QR generation in `QRCodeView` works on both) |
| Settings | `SettingsScreen` (`Route.settings`, gear icon in the toolbar) | `SettingsView` (native `Settings` scene, command-comma) |
| Menu commands | None | `AppCommands`: **Send…** (command-1), **Receive…** (command-2), **Show Receive Folder in Finder** or **Show Receive Folder in Files** (shift-command-R); in `CrocApp Direct` only, **Check for Updates…** right after **About CrocApp** |
| Menu bar | None | `MenuBarExtra` window (`MenuBarQuickSendView`), shown while **Show in Menu Bar** is on |

macOS also enforces a Local Network privacy prompt of its own. How it is enforced (a Network Extension packet filter instead of TCC) is inferred from Apple's behavior, not verified here. See `docs/knowledge/apple-platform-constraints.md`.

### Entitlements

The main app target picks its entitlements file by SDK in the project (`CODE_SIGN_ENTITLEMENTS[sdk=iphoneos*]` and the simulator variant), with the macOS file as the default.

- `app/CrocApp/CrocApp.entitlements` (macOS):
  - `com.apple.security.app-sandbox`
  - `network.client`
  - `network.server`, so croc's local-only relay can listen on a port inside the sandbox
  - `files.user-selected.read-write`
  - `files.downloads.read-write`, for the default output folder `~/Downloads/CrocApp`
  - `com.apple.developer.associated-domains` (`applinks:crocapp.dev`)
- `app/CrocApp/CrocApp-iOS.entitlements`: `application-groups` (`group.com.bakirgdev.CrocApp`, for the share-extension handoff) and `associated-domains` (`applinks:crocapp.dev`).
- `app/CrocAppDirect/CrocAppDirect.entitlements`: the macOS set above, plus Sparkle's mach-lookup exceptions `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` and `-spki`.
- `app/CrocShare/CrocShare.entitlements`: the same App Group and nothing else.

Associated Domains needs a provisioning profile, so signing a local macOS build needs the team set in the project. See `docs/BUILDING.md`, "Verification harnesses".

### Info.plist

Four files in `app/Config/` are merged over Xcode's generated plist: `CrocApp-Info.plist` (iOS), `CrocApp-macOS-Info.plist`, `CrocApp-Direct-Info.plist` and `CrocShare-Info.plist`.

- `NSCameraUsageDescription` and `NSLocalNetworkUsageDescription` are plain `INFOPLIST_KEY_*` build settings, not tied to an SDK, so they apply on every platform.
- `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` are SDK-scoped `INFOPLIST_KEY_*` settings. `UIFileSharingEnabled` is also in `CrocApp-Info.plist`, and that copy is the one that works (`docs/known-issues.md`, "Accepted").
- `NSBonjourServices` is only in `CrocApp-Info.plist`, so it applies to the iOS SDKs only.

### `CrocApp Direct`: the direct-download target

- macOS only, arm64. Bundle ID `com.bakirgdev.CrocApp.direct`. Product name `CrocApp.app`, the same as the App Store target, so two schemes sharing one DerivedData replace each other's build.
- Builds `app/CrocApp/` plus `app/CrocAppDirect/` with the Swift condition `DIRECT`. Only this target compiles `app/CrocAppDirect/`.
- Only this target links Sparkle 2.10.1 (SwiftPM). `app/CrocAppDirect/AppUpdater.swift` owns an `SPUStandardUpdaterController` and adds **Check for Updates…** to the app menu.
- `CrocApp-Direct-Info.plist` sets `SUFeedURL` and `SUPublicEDKey` from the `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_ED_KEY` build settings, plus `SUEnableInstallerLauncherService` (on) and `SUEnableSystemProfiling` (off).
- Its shared scheme has an empty test action; `CrocApp` is the scheme with tests.
- How it ships: `docs/RELEASING.md`, "Direct download (Developer ID)".

### Sandbox limits that shaped the design

- Security-scoped URLs: every send or receive intent in `TransferController` calls `startAccessingSecurityScopedResource()` on URLs the user picked and tracks them in `scopedURLs` until the stream ends. `OutputFolderStore` and `HistoryView`'s bookmark path do the same before any `fileExists` or `stat` call, because the sandbox denies `stat` on a scope that is not open.
- App Group container: the only channel between `CrocShare` and the app. `CrocShare` is a separate process with a memory cap of about 120 MB and no room for long work.
  - It copies attachment bytes inside the synchronous `loadFileRepresentation` callback, because the source temp file is deleted when the callback returns.
  - It never deletes existing batches, because one may be mid-send.
- Output folder: iOS defaults to the app's Documents folder, visible in Files through `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. macOS defaults to `~/Downloads/CrocApp`, which is why the `files.downloads.read-write` entitlement exists.
- `network.server` on macOS exists so croc's local relay can bind a port inside the sandbox (the **Local Network Only** setting). Not verified; see `docs/knowledge/apple-platform-constraints.md`.

## Concurrency model

- Swift 6 language mode (`SWIFT_VERSION = 6.0`), `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Set on every app target (`CrocApp`, `CrocApp Direct`, `CrocShare`, `CrocAppTests`), in Debug and Release.
- Effect: any type in the app or the share extension is `@MainActor` unless it opts out. The explicit `@MainActor` on `AppSettings`, `TransferController` and the others documents what the compiler already enforces.
- `CrocEngine` is the deliberate exception. It is a plain `actor` on its own executor.
- Delegate callbacks (`OnCodeReady`, `OnProgress` and the rest) arrive on arbitrary Go threads. The poller goroutine and the transfer goroutine both call the delegate directly, with no ordering between threads.
- `DelegateBridge` is `@unchecked Sendable`, because the compiler cannot check an `NSObject` subclass that conforms to an Objective-C protocol. It only calls `continuation.yield(...)`, which is safe from any thread.
- The hop to `MainActor` happens at the `for await event in transfer.events` loop in `TransferController.run(_:)`, because that class is `@MainActor`.

## Build-time architecture

- `CrocKit/Package.swift` declares `Croc` as `.binaryTarget(path: "Croc.xcframework")`, and that path is gitignored. A fresh clone cannot build `CrocKit` or the app until `scripts/build-xcframework.sh` has run once.
- App version numbers live in `app/Config/Version.xcconfig`, which every target inherits (`docs/BUILDING.md`, "Build settings that must not change casually").
- Toolchain, CI wiring and manual steps: `docs/BUILDING.md`, "First build".

## Where to go next

| Question | Document |
| --- | --- |
| Event JSON fields, croc gotchas, verification harnesses | `docs/knowledge/crocmobile-bridge.md` |
| View-by-view UI rules, settings, platform layer | `docs/knowledge/app-ui-architecture.md` |
| iOS and macOS limits (background, multicast, sandbox, App Store review) | `docs/knowledge/apple-platform-constraints.md` |
| What is planned and what is not | `docs/ROADMAP.md` |
| Fresh-clone build steps | `docs/BUILDING.md`, "First build" |
| Signing, notarization, releases | `docs/RELEASING.md` |
| Design tokens, components, SF Symbols mapping | `design/AGENTS.md` |
| Term definitions | `docs/GLOSSARY.md` |
| Known defects and accepted limits | `docs/known-issues.md` |
