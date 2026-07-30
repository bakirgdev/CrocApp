# App UI architecture

How the SwiftUI app is wired and which of its behaviours are load-bearing. Most of what follows was learned by breaking it. Read the relevant section before editing a view that observes `TransferController`.

Decisions: conflict/paste/QR ADR 0009, iOS integration ADR 0010, macOS integration ADR 0011, settings/trust ADR 0012, history ADR 0013. Engine contract: `crocmobile-bridge.md`. Open defects: `../known-issues.md`.

## Structure

```
CrocAppApp owns @State TransferController + AppSettings + OutputFolderStore
  + HistoryStore + LocalNetworkChecker + AppRouter.shared
  → .environment on WindowGroup content
  (macOS Settings scene gets only outputFolder + settings — no router/controller/localNetwork)
ContentView → HomeView (sole NavigationStack, path: $router.path, value-based links)
  → SendView | ReceiveView | SettingsScreen | HistoryView | HowItWorksView
  each transfer screen: controller.isActive ? TransferStatusView() : input form
TransferStatusView renders every non-idle phase; IncomingRequestView = accept gate
QRCodeView (cross-platform gen) / QRScannerView.swift (whole file #if os(iOS), VisionKit)
```

Construction order in `CrocAppApp.init` matters: `AppSettings` first, then `TransferController(settings:)`, then the SwiftData container, then `controller.history = history`.

## TransferController

`@MainActor @Observable`, and the only consumer of `CrocKit` in the app.

`Phase`: `idle` → `starting` → `waiting(code)` / `connecting` → `confirmSend` | `incoming(FileList, conflicts, blocked)` → `transferring(TransferProgress)` → `done(Summary, receivedText?)` | `failed(String)`. Views switch on it. `reset()` is unconditional — no guard — but is only meant to be called from a terminal phase, which is the only place the UI offers it.

### Event handling, learned the hard way

- **`.progress` ticks (~10 Hz) keep arriving while the accept prompt is unanswered, and must not clobber `.incoming`.** If they do, croc blocks in `GetInput` forever. Found by harness, fixed in d278c2e. Same guard protects `.confirmSend`. Also ignore `step == "waiting"` ticks.
- **A local decline surfaces croc's `"refused files"` string** — the same string the sender sees. Track `cancelRequested` / `declineRequested` to pick the right copy: "Transfer cancelled." / "You declined the transfer." / "The other side declined the transfer."
- **`transferActive` on start: retry once after ~300 ms.** There is a release window after `done` where the next start still throws.
- `engine.cancel()` on `.failed`, belt-and-suspenders with the stream's `onTermination`.
- Copy precedence when several conditions collide, highest first: `blockedAutoAccept`, `backgroundExpired`, the auto-accept-vs-remote-`--ask` case, then cancel/decline mapping. `run()`'s catch mirrors the `backgroundExpired` step so a thrown expiry keeps the resume hint.
- **`"refused files"` under auto-accept is not a peer decline.** croc forces the receiver prompt whenever the *remote sender* ran `--ask` (`croc.go`: `!NoPrompt || Ask || senderInfo.Ask`), and engine auto-accept has already closed the prompt pipe, so `GetInput` hits EOF and croc reports its local `"refused files"`. `autoAcceptActive && !cancelRequested && !blockedAutoAccept` discriminates it: `respond()` is never called on the auto-accept path, so `declineRequested` cannot be set. Do **not** "fix" this by pre-writing `y\n` under AutoAccept — croc's empty-folder-overwrite prompt is gated on neither `NoPrompt` nor `Ask` and reads the same pipe, so a buffered `y` would turn its safe EOF default into an unwanted overwrite.
- `blockedAutoAccept` is checked in `.done` as well as `.failed`: `cancel()` is fire-and-forget, so a small transfer can finish before the cancellation reaches the engine. Both paths record `.failed` (ADR 0013's schema has no blocked case, and "Cancelled" reads as a user action).
- `TransferStatusView` shows a "taking longer than usual" hint after 25 s (`slowPhaseThreshold`) spent in `.starting`/`.connecting`. A `.task(id: isInEarlyPhase)` resets the timer whenever that flips, so the hint never keeps counting once a transfer moves on, but it does survive the `.starting → .connecting` handoff — same stall to the user, no reason to reset the clock.

### Options, security scope, progress

- `baseOptions()` builds `EngineOptions` from `AppSettings`. Receive passes `autoAccept && !bothSidesConfirm` — Ask wins, because engine-level autoAccept closes the prompt pipe and the resulting EOF would decline.
- Intent methods start security scope on send URLs and the user-picked output folder, track them in `scopedURLs`, and release at stream end. `startAccessingSecurityScopedResource() == false` is fine for non-scoped drops — keep the call anyway.
- Speed is an EMA (0.25/0.75) over `bytesFinished + fileSent` deltas, spaced ≥0.2 s. Overall progress is `(bytesFinished + fileSent) / totalSize`; `fileSent` is per-current-file.
- `activeRelay` is captured at start, for the trust badge.
- `harnessDisableLocal` is a harness-only flag, not a user setting.

### History capture

- A `PendingRecord` snapshot is set in all three start intents. Send: names capped at 20, bookmarks all-or-nothing up to 200, built while security scope is held. Receive: filled from `.fileList`. `codeHint` is backfilled at `.codeReady` for generated codes.
- `finishRecord(status:summary:)` runs at `.done`, `.failed`, and the startup catch. It sets `pendingRecord = nil` first so a double terminal event is idempotent, and must run while `receivedText` is still set so `isText` backfills.
- Status mapping: `done` → completed or failed per the summary; `failed` + `cancelRequested` → cancelled, + `declineRequested` → declined.

## Settings and trust

`Models/AppSettings.swift` — `@MainActor @Observable`, `UserDefaults` keys prefixed `settings.`, `didSet` persistence gated by a `persist` flag (the harness override channel).

`relayPassword` is the one setting that is **not** in `UserDefaults`: it lives in the Keychain via `Support/KeychainStore.swift` (ADR 0033), migrated out of the plist on first launch. Its `didSet` goes through `persistRelayPassword()`, which honours the same `persist` gate — that gate is load-bearing here in a way it is not for the other settings, because `resetToDefaults()` assigns `relayPassword = ""` and an ungated write would blank a real user's stored password on any machine that has ever run a verify script.

Relay strings use `""` to mean "croc default", shown as a `TextField` prompt. Two accessor families, and the difference matters:

| Accessor | Purpose |
|---|---|
| `effective*` | display only; never hands back an empty value |
| `engineRelayAddresses` | what reaches the engine; blanks the *non*-customised side when only one of v4/v6 is customised |

That blanking is CLI parity (ADR 0012): croc skips empty relay addresses when dialling, so it stops a custom relay from losing the dial race to the public default. Never leave both empty. `relayKind` (`publicDefault` / `custom` / `localOnly`) classifies as custom if either address is customised.

`Views/PowerSettingsSections.swift` holds the shared `Form` sections — relay, transfer toggles, exclusions, confirmation with the auto-accept warning footer — embedded in both the macOS `SettingsView` (Settings scene, ⌘,) and the iOS `SettingsScreen` (gear toolbar → `Route.settings`). `TrustBadge(relay:)` appears in the waiting, transferring, and confirm-send views. `HowItWorksView` is the plain-language explainer; its facts come from `what-is-croc.md`.

`Phase.confirmSend` is the sender side of croc `--ask`: entered at `.connected` when `bothSidesConfirm` is on, progress-guarded like `.incoming`, accept is `respond(true)`, decline is `cancel()`.

## History

`Models/TransferHistory.swift` — `TransferRecord` is a SwiftData `@Model` (fields per ADR 0013, including `statusRaw` string storage for the enum). `HistoryStore` is `@MainActor @Observable`, wraps `container.mainContext`, exposes `add` / `delete` / `clear` / `recordCount`. The container is in-memory when `AutoVerify.isHarnessRun`, and is injected twice: as `.environment(history)` and as `.modelContainer(history.container)`.

`Views/HistoryView.swift` (`Route.history`, clock toolbar icon on both platforms): `@Query` sorted date-descending, swipe and context delete, Clear behind a confirmation, and "Send Again" for send records that carry bookmarks — resolve bookmarks, then `router.openSend`.

**Both platform probe branches must call `startAccessingSecurityScopedResource()` before `fileExists`.** The sandbox denies `stat` on an unopened scope. Each platform's omission was a separately caught defect.

## Support/ helpers

- `Support/SecurityScopedBookmark.swift` — bookmark create/resolve/resolveIfReachable, shared by `OutputFolderStore` and `HistoryView`'s resend path (previously written four times over, one per platform per call site). `resolveIfReachable` starts the security scope before the existence probe — the sandbox denies `stat` on an unopened scope.
- `Support/EngineConstraints.swift` — `minCodeLength = 6`, mirroring the Go engine's `len(secret) < 6` check in `crocmobile/session.go` and `crocmobile.go`. UI-side validation only, for inline feedback before a doomed `startSend`/`startReceive` call; no shared source of truth across the Go/Swift boundary, kept in sync by hand.
- `Support/DesignTokens.swift` — the app's routing layer onto `design/`: `Spacing`, `Radius`, `BorderWidth`, `ControlHeight`, `IconSize`, `LayoutCap`, `ComponentMetrics`, `Motion`, plus `Color` aliases. The one file that splits `#if os(iOS)`/`#if os(macOS)` for UIKit/AppKit-backed colors. Where a system semantic already matches a token exactly, the alias routes there instead of duplicating an asset-catalog entry (ADR 0029).

## Conflict scan

Asynchronous. `.incoming` is shown immediately with `conflicts: []`; `Self.scanConflicts` runs `Task.detached` and stats off the main actor; the write-back happens only when non-empty, only `if case .incoming`, and only if `transferGeneration` still matches the value captured at `.fileList`. The shape check alone was not enough: a scan can outlive a whole fast transfer and land on the *next* one's `.incoming`. Doing the scan synchronously froze the accept UI on large file lists.

`startSend`'s up-to-200 `bookmarkData` calls run off the main actor the same way, writing back into `pendingRecord`. If a transfer somehow terminates first, `pendingRecord` is already nil and the record carries no bookmarks — the same outcome as the pre-existing all-or-nothing fallback, so "Send Again" hides rather than breaks. `SecurityScopedBookmark.create` is `nonisolated` for this.

10k-file smoke tests pass in both directions: receive 427 s, send 358 s.

## Platform layer, iOS

- `Platform/BackgroundCoordinator.swift` — cross-platform class with `#if os(iOS)` bodies (no-ops on macOS). Wraps a transfer in a `BGContinuedProcessingTask` and holds `isIdleTimerDisabled`. Controller hooks: `transferStarted` in `run()`, `progressChanged` inside the accepted `.progress` path only (the `.incoming` guard stays untouched), `transferEnded` at `.done` / `.failed` / startup catch, idempotent. Expiration sets `backgroundExpired` and cancels, producing dedicated "iOS paused the transfer…" copy. A generation token rejects stale late task launches.
- `Platform/LocalNetworkChecker.swift` — Bonjour self-probe on `_crocapp._tcp`, iOS only (the macOS branch is a no-op stub, `../known-issues.md`). `checkIfNeeded()` probes once per process, triggered by `ContentView.onChange(controller.isActive)`; `recheckIfDenied()` re-probes from `.denied` on `ContentView.onChange(scenePhase)` going `.active` (e.g. the user granted access in Settings and returned), gated so it never re-probes `.granted`/unresolved and never stacks a second in-flight probe. Denial shows a banner plus Open Settings in `TransferStatusView`. Denial only resolves at the 8 s timeout, because a first `.waiting` may just be the pending permission prompt.
- `Models/ShareInbox.swift` + `Views/StagedFilesSheet.swift` — App Group pickup of batches staged by the share extension (`ShareInbox/batch-<UUID>/` plus `manifest.json`). The whole `scenePhase` refresh is gated on `!controller.isActive`; an ungated refresh once purged a live batch mid-send, caught by harness. The manifest is consumed on the user's decision, the batch files outlive the send, and `purgeStaleBatches` runs at idle.
- `app/CrocShare/` — iOS-only appex. The pbxproj entry is hand-built; `platformFilters=(ios,)` on the dependency and the embed keep macOS clean. File-copy staging happens inside the `loadFileRepresentation` handler because of the ~120 MB extension memory cap, and never wipes existing batches. Both `Info.plist` files live in `app/Config/`, outside the synced folders, to avoid a generated-plist collision; the app's `INFOPLIST_FILE` is sdk-scoped to iOS.
- Files-app visibility comes from `INFOPLIST_KEY_UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`, both sdk-scoped to iOS. "Open in Files" on receive-done uses the `shareddocuments://` scheme — community standard, no public API.

## Platform layer, macOS

- `Models/AppRouter.swift` — `@Observable` singleton (`shared`). `path: [Route]` drives `HomeView`'s `NavigationStack`. `pendingSendURLs` is consumed by `SendView` (`onAppear` plus `onChange`, deduplicated against `pickedURLs`, then cleared). `isBusy` mirrors `controller.isActive`, set in `ContentView`'s `onChange`, so a dock drop mid-transfer queues without navigating. It is a singleton because `AppDelegate` and `Commands` sit outside the environment graph.
- Three drop entry points, one guard policy: the window drop (`ContentView`, macOS-only) refuses while active and filters `\.isFileURL`; the `SendView` list drop filters too; the dock drop (`Platform/AppDelegate.swift`, `application(_:open:)`) always queues and navigates only when idle.
- Dock drop works because `Config/CrocApp-macOS-Info.plist` declares `public.item` / Viewer / rank None document types. Side effect: the app is listed in Finder's "Open With" for everything, and `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace[sdk=macosx*]=YES` is required or Xcode auto-injects an invalid `NO`.
- `Views/SettingsView.swift` — output-folder change/reset plus Show in Finder. `Views/AppCommands.swift` — Send ⌘1, Receive ⌘2 (disabled while active), Show Receive Folder ⇧⌘R. Window: `.defaultSize(560×700)`, content `minWidth 480` / `minHeight 560`.
- Default output folder is `~/Downloads/CrocApp`, needing the `files.downloads.read-write` entitlement; the folder is auto-created in `defaultFolder` and `defaultDisplayName` supplies the UI label. Receive-done offers "Show in Finder" via `NSWorkspace.activateFileViewerSelecting`.
- Distribution: `scripts/build-devid.sh` archives with `ARCHS=arm64`, exports Developer ID, runs `codesign --verify`, then `syspolicy_check distribution`; it degrades to `DEVID-PENDING-CERT` until a cert is installed. `Config/ExportOptions-{MAS,DevID}.plist` carry the per-channel settings — no extra pbxproj configurations (ADR 0011).

## Onboarding and store compliance

- `OnboardingView` is a sheet from `ContentView.task`, gated on `!onboardingSeen && !AutoVerify.isHarnessRun`; `onboarding.seen` is written in `onDismiss`. The staged-files sheet yields to it (`&& !showOnboarding`) and is re-offered when onboarding dismisses.
- Onboarding also primes the two system permission prompts it now names in its copy: `onDismiss` (iOS only) awaits `CameraPermission.requestIfNeeded()` then calls `localNetwork.checkIfNeeded()`, sequenced rather than simultaneous so the user never sees two system prompts stack. Camera and local-network are never requested during an `AutoVerify` harness run.
- `Platform/CameraPermission.swift` (iOS only) wraps `AVCaptureDevice.authorizationStatus/requestAccess(for: .video)`. `QRScannerSheet` resolves its own authorization first, as a separate gate from `DataScannerViewController.isSupported`, and renders distinct copy for all four `AVAuthorizationStatus` cases: `.authorized` shows the scanner, `.notDetermined` requests then re-reads status, `.denied` offers an Open Settings button, `.restricted` does not (Settings cannot fix a restriction).
- `PrivacyInfo.xcprivacy` sits in both synced target folders — app declares UserDefaults CA92.1 and FileTimestamp C617.1, extension declares an empty accessed-API list, both declare no tracking and no collection. Bundle inclusion was verified in the build products.
- `ITSAppUsesNonExemptEncryption=true` in both Config plists — croc bundles its own AES-256-GCM/ChaCha20-Poly1305 rather than calling Apple OS crypto, so no exemption applies (ADR 0030).
- Two `.glassEffect()` call sites: the code card in `waitingView`, and the macOS-only "Drop to send" full-window overlay in `ContentView` (design/components.md → DropZone macOS overlay).

## SwiftUI and Xcode API facts

Verified against Xcode 26, not inferred:

- `fileImporter` **without** `allowsMultipleSelection:` gives the completion a `Result<URL, Error>`; **with** it — at any value — a `Result<[URL], Error>`. Code that mixes the two does not compile.
- `PasteButton`'s closure is `nonisolated`. Hop to the main actor before touching `@State`.
- `.qr` symbology needs `import Vision` alongside VisionKit. `DataScannerViewController.isSupported` is `false` on the simulator, so the sheet shows a fallback; `startScanning` failures surface through `onStartFailure` as "Camera unavailable".
- QR generation: `CIFilter.qrCodeGenerator` with a static shared `CIContext`, cache the `CGImage` in `@State` keyed by `.task(id: content)`, render with `Image(decorative:scale:).interpolation(.none)`.
- Using a type across files in the same module still needs a per-file `import CrocKit`.
- The camera key is `INFOPLIST_KEY_NSCameraUsageDescription`, and it must be in both pbxproj configurations.
- `app/CrocApp/AppIcon.icon` is an Icon Composer bundle; it is picked up by synced-folder auto-include as long as its name matches `ASSETCATALOG_COMPILER_APPICON_NAME`, and compiles for both platforms with no pbxproj edit.

## AutoVerify harness

Launch arguments that drive the real controller, not the engine directly — the point is that the verified path is the one users take.

`AutoVerify`'s bodies are `#if DEBUG`; in Release, `isHarnessRun` is a hardcoded `false` and `runIfRequested` is a no-op, so the harness itself cannot run in a store build. The type still exists in Release because `CrocAppApp.swift` and `ContentView.swift` call it unconditionally. The verify scripts build Debug, so they are unaffected.

| Argument | Effect |
|---|---|
| `--auto-receive CODE` | receive into Documents, auto-accept via `respond(true)` on `.incoming` |
| `--auto-send PATH --code CODE` | send with a custom code; on macOS the source must be container-resident (sandbox) |
| `--auto-share-send CODE` | read the share inbox, then custom-code send |
| `--local` | sets `settings.onlyLocal` unpersisted (croc `onlyLocal`) |
| `--relay ADDR` | custom relay, plus `harnessDisableLocal` to kill the LAN race |
| `--no-compress` | disable compression |
| `--ask` | auto-answers `.confirmSend` |

Settings overrides only apply when an `--auto-*` mode is present (the `isHarnessRun` guard) and start from `resetToDefaults()`, with `persist = false` set first so real `UserDefaults` are never touched.

The harness writes `verify-result.txt` (`ok success=<bool>` or `error <msg>`) to Documents. That contract is shared by `scripts/verify-app-sim.sh`, `verify-app-mac.sh`, and `verify-share-sim.sh`. AutoVerify's Documents path is hardcoded, decoupled from `OutputFolderStore.defaultFolder`.

Launch gotchas, both macOS:

- Once `CFBundleDocumentTypes` exists, bare adjacent argv tokens are document-open candidates and AppKit skips creating the default window. Use flag-style arguments only.
- Scripted launches need `-ApplePersistenceIgnoreState YES` or they hang in window restoration.

On the CLI side of a verify run, a receiving `croc` needs `CROC_SECRET=` in the environment rather than a positional code: croc refuses custom positional codes in non-classic mode for receive as well as send.
