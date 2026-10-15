# App UI architecture

How the SwiftUI app is wired and which of its behaviours are load-bearing. Most of what follows was learned by breaking it. Read the relevant section before editing a view that observes `TransferController`.

Engine contract: `crocmobile-bridge.md`. Open defects: `../known-issues.md`.

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

`Phase`: `idle` → `starting` → `waiting(code)` / `connecting` → `confirmSend` | `incoming(FileList, conflicts, blocked)` → `transferring(TransferProgress)` → `done(Summary, receivedText?)` | `stored(StoredReceipt)` | `failed(String)`. Views switch on it. `reset()` is unconditional — no guard — but is only meant to be called from a terminal phase, which is the only place the UI offers it.

### Event handling, learned the hard way

- **`.progress` ticks (~10 Hz) keep arriving while the accept prompt is unanswered, and must not clobber `.incoming`.** If they do, croc blocks in `GetInput` forever. Found by harness, fixed in d278c2e. Same guard protects `.confirmSend`. Also ignore `step == "waiting"` ticks.
- **Failure copy is picked by `EngineFailure.code`, never by text.** `friendlyMessage(for:cancelRequested:declineRequested:)` checks `cancelRequested` ("Transfer cancelled.") and `declineRequested` ("You declined the transfer.") first, then maps the code; it never shows `failure.message` (croc's wording changes per release and a recovered panic carries a stack trace). A peer's decline arrives as `.declined` ("The other side declined or cancelled the transfer."; a peer's cancel is indistinguishable), this side's own decline or prompt EOF as `.refused`.
- **`transferActive` on start: retry once after ~300 ms.** There is a release window after `done` where the next start still throws.
- `handle(.failed)` does not call the engine: the stream's `onTermination` cancels and clears the transfer by its ID. `TransferController` keeps that `transferID`; every cancel (user, background expiry, auto-accept block) targets it, and a cancel tapped before `run()` has the ID is applied as soon as `startSend`/`startReceive` returns.
- Copy precedence when several conditions collide, highest first: `blockedAutoAccept`, `backgroundExpired`, the auto-accept-vs-remote-`--ask` case, then cancel/decline mapping. `run()`'s catch mirrors the `backgroundExpired` step so a thrown expiry keeps the resume hint.
- **Code `refused` under auto-accept is not a peer decline.** croc forces the receiver prompt whenever the *remote sender* ran `--ask` (`croc.go`: `!NoPrompt || Ask || senderInfo.Ask`), and engine auto-accept has already closed the prompt pipe, so `GetInput` hits EOF and croc reports its local `refused files`. `autoAcceptActive && !cancelRequested && failure.code == .refused` discriminates it (after the `blockedAutoAccept` and `backgroundExpired` branches): `respond()` is never called on the auto-accept path, so `declineRequested` cannot be set. Under AutoAccept the pipe is not empty: crocmobile queues a batch of `n` answers for croc's other un-gated prompts (empty-folder, unzip member) and then closes it (`crocmobile-bridge.md`). The forced remote-`--ask` prompt reads the first `n` and ends as `refused` under either policy; the batch is `n` even for Replace for exactly this reason, and after a manual accept too, where a croc v11 reconnect re-runs the accept prompt (`verify-interop.sh` scenario 12 checks it).
- `blockedAutoAccept` is checked in `.done` as well as `.failed`: `cancel()` is fire-and-forget, so a small transfer can finish before the cancellation reaches the engine. Both paths record `.failed` (the schema has no blocked case, and "Cancelled" reads as a user action).
- `TransferStatusView` shows a "taking longer than usual" hint after 25 s (`slowPhaseThreshold`) spent in `.starting`/`.connecting`. A `.task(id: isInEarlyPhase)` resets the timer whenever that flips, so the hint never keeps counting once a transfer moves on, but it does survive the `.starting → .connecting` handoff — same stall to the user, no reason to reset the clock.

### Options, security scope, progress

- `baseOptions()` builds `EngineOptions` from `AppSettings`; receive also passes `whenFileExists` (`AppSettings.whenFileExists`, UserDefaults key `settings.whenFileExists`, default Keep Both, an unknown stored value reads as Keep Both). Receive passes `autoAccept && !bothSidesConfirm` — Ask wins, because engine-level autoAccept answers croc's prompts with `n` and closes the pipe, which would decline.
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

`relayPassword` is the one setting that is **not** in `UserDefaults`: it lives in the Keychain via `Support/KeychainStore.swift`, migrated out of the plist on first launch. Its `didSet` goes through `persistRelayPassword()`, which honours the same `persist` gate — that gate is load-bearing here in a way it is not for the other settings, because `resetToDefaults()` assigns `relayPassword = ""` and an ungated write would blank a real user's stored password on any machine that has ever run a verify script.

Relay strings use `""` to mean "croc default" (the `TextField` prompt reads "Public relay pool") and reach the engine as stored, password included. Go resolves them (`crocmobile/relay.go`): blank means croc's default, and with no custom relay and local-only off the relay comes from upstream's public pool by code. `relayKind` (`publicDefault` / `custom` / `localOnly`) is display-only and classifies as custom if either address is set to something other than `RelayDefaults` (CrocKit, read from Go).

`Views/PowerSettingsSections.swift` holds the shared `Form` sections — relay, connection (the Automatic / Relay only `Transport` picker, disabled while Local network only is on), transfer toggles, exclusions, confirmation with the auto-accept warning footer — embedded in both the macOS `SettingsView` (Settings scene, ⌘,) and the iOS `SettingsScreen` (gear toolbar → `Route.settings`). `TrustBadge(relay:)` appears in the waiting, transferring, and confirm-send views. `HowItWorksView` is the plain-language explainer; its facts come from `what-is-croc.md`.

`Phase.confirmSend` is the sender side of croc `--ask`: entered at `.connected` when `bothSidesConfirm` is on, progress-guarded like `.incoming`, accept is `respond(true)`, decline is `cancel()`.

### Stored transfers (R18-R21)

`isStoredTransfer` marks a transfer that goes through a stored-transfer server instead of a croc peer; it reuses `run()`, `handle(_:)`, the `BGContinuedProcessingTask` wrap and the history record.
- `startStoreSend(urls:downloads:lifetimeSeconds:)` uploads to `AppSettings.storedServer` (UserDefaults `settings.storedServer`, default `https://getcroc.com`). The engine sends `.progress`, then `.stored(receipt)` just before `.done`; the controller puts the receipt in the vault, keeps its id and expiry for the record, and turns `.done` into `Phase.stored(receipt)`.
- `startStoreReceive(link:into:folderIsScoped:)` takes the same path as a live receive: `.incoming` with the conflict scan, then `respond(accept:policy:)`. Auto-accept never applies; the engine always waits.
- Views. `SendView`: a "Send as link" toggle (disabled with a reason line for text or a staged folder), "Link lasts" picker (1 hour / 1 day default / 7 days), a downloads stepper (1-100, default 1) and a server note; with it on, the custom code field is hidden and the button reads Upload. It checks `AppSettings.storedServerError` and blocks Upload on an invalid server. `TransferStatusView`: `Phase.stored(receipt)` renders `storedView` (Link ready, expiry and download count, QR, link text, Copy Link via `Clipboard.copy(_, thisDeviceOnly: true)`, Share Link, Done); the transferring heading reads Uploading / Downloading and shows a caption instead of `TrustBadge` when `isStoredTransfer`. `ReceiveView`: `router.pendingReceive` carrying `.stored(url)` sets `storedLink`, which replaces the code field with a "Download link from <host>" row and a Clear button, and Receive calls `startStoreReceive`. `HistoryView`: stored rows add a "Link expires / expired / revoked" line, and Revoke Link (context menu; "Revoke" swipe on iOS) sits behind a confirmation dialog, with an alert on failure. `PowerSettingsSections`: a "Send as link" section with the Server field, inline `storedServerError` banner and a Reset button shown only when the value differs from the default.
- `AppSettings.storedServerError(_:)` accepts `https`, or `http` on loopback only, and nothing after the host. `TransferLink.parse` accepts a stored link only over `https`, or `http` on loopback, and the engine checks the id and key lengths.
- `Clipboard.copy(_, thisDeviceOnly:)` sets `UIPasteboard` with `.localOnly` on iOS so a link (its fragment is the key) stays off Universal Clipboard; the macOS pasteboard has no such option, so Copy Link there is an ordinary copy. The Camera app does not open CrocApp for a stored link: the Associated Domains entitlement and the AASA file cover only `crocapp.dev/r/*`. Receiving in the app is Paste or Scan QR Code.
- A stored transfer cannot resume, so no failure copy offers it. A background expiry reads "Upload interrupted … Try again" (send) or "Download interrupted … Open the link again" (receive), concern 4. `friendlyMessage(…, stored: true)` names the transfer server for `relayUnreachable` and `connectionLost`, which is how a store call reports a network failure.
- `revoke(_ record:)` (throws `EngineFailure`) calls `CrocEngine.revokeStored`, which needs no free engine slot, then drops the receipt and sets `revokedAt`. `canRevoke(_:)` is true for an unexpired, unrevoked record whose receipt this device still holds.

`Models/StoredTransferVault.swift` keeps receipts (id, origin, upload token, link, expiry) in the Keychain, all in one item (`storedReceipts`, a JSON array), because `SecretStore` cannot list accounts. Expired receipts are purged when the vault opens (each launch). A failed Keychain write is logged, never lost silently, and leaves the receipts already stored untouched; the new receipt then lasts until the app quits. Harness runs and previews use `MemorySecretStore`. History never holds the token or link: a stored record's `codeHint` is the server host (`codeHint(storedLink:)`).

### Advanced settings (R25)

Croc's own options, edited in `Views/AdvancedSettingsView.swift`: iOS pushes it from `SettingsScreen` (`Route.advancedSettings`, `--screen advanced`); macOS Settings is a `TabView` with General (the old form) and Advanced, because the Advanced controls and their footnotes would double a form that already scrolls.
- `AppSettings` has one property per control under `settings.advanced.<name>` (curve, hashAlgorithm, throttleUpload, noMultiplexing, basePort, transfers, multicastAddress, peerIP, internalDNS). Defaults come from `EngineOptions()`, so they are croc's. `resetAdvancedToDefaults()` backs the Reset to Defaults button (persists); the harness `resetToDefaults()` calls it with `persist` off.
- **The two proxies are Keychain-only** (`SecretStore` accounts `advanced.socks5Proxy`, `advanced.httpProxy`, deleted when blank, same `persist` gate as `relayPassword`). They can carry credentials: `ProxySettings`, `EngineOptions` and `StoredSendOptions` describe themselves without the value; the Go engine never quotes a proxy in an error; nothing logs them. `AppSettingsAdvancedTests` asserts UserDefaults holds no proxy key or value.
- `Models/AdvancedSettingsValidation.swift` holds the inline checks (`socks5ProxyError`, `httpProxyError`, `multicastAddressError`, `senderIPError`, `portsError`, `throttleError`). They mirror `crocmobile/network.go` (tables in `AdvancedSettingsValidationTests` match `network_test.go`); two are slightly stricter than the engine on purpose: a proxy or sender port outside 1-65535, and a one-character upload limit (croc ignores it silently). Blank always means the default.
- `TransferController.baseOptions()` passes every setting; `startReceive` adds `peerIP`; store send, store receive and revoke pass `ProxySettings`. Multicast reaches the engine on macOS only (`#if os(macOS)`): iOS lacks the multicast entitlement (concern 8), so the control is hidden and the engine keeps its default. The engine reports a bad proxy, port, multicast address or sender IP as `invalidSetting`; it does not classify a bad upload limit, so `requireUsableUploadLimit()` fails a send with the same code first. Copy for `invalidSetting` points at Settings > Advanced.
- A receive with a sender IP shows `RelayKind.directToSender` in the trust badge (`AppSettings.receiveRelayKind`), never the public pool.

### Menu bar and Shortcuts (R26-R28)

Neither surface owns transfer state. Both drive the one `TransferController`, so they show and respect a transfer started anywhere, and a second start is refused while `isActive`.
- **Menu bar (macOS, R26).** `CrocAppApp` declares a `MenuBarExtra` in window style, inserted while `AppSettings.showInMenuBar` is on (`settings.showInMenuBar`, default true). `Views/MenuBarQuickSendView.swift` switches on `controller.phase`; `Models/MenuBarQuickSend.swift` holds the actions (`send(urls:)`, `sendClipboardText()`, `chooseFiles()`) and only a `notice` string. Sends use a generated code. `chooseFiles()` uses a modal `NSOpenPanel`: the window-style extra closes when focus moves to a SwiftUI file importer's sheet. `.incoming` shows "Open CrocApp", because the accept prompt lives in the main window. A drop lands only on the open window, never on the status item.
- **Open at login.** `Models/LoginItem.swift` wraps `SMAppService.mainApp` behind the `LoginItemService` protocol (injected in tests). The toggle reads `status`, never a stored copy, since the user can change it in System Settings > General > Login Items; `SettingsView` refreshes on appear and when the app becomes active, and shows an Open Settings button (`SMAppService.openSystemSettingsLoginItems()`) for `.requiresApproval`.
- **Intents (R27).** `Intents/` holds `SendFilesIntent`, `SendTextIntent`, `ReceiveIntent` (all `supportedModes: .foreground`, because a transfer outlives the ~30 s iOS gives a background action) and `CrocAppShortcuts`. The intents take `TransferController` and `OutputFolderStore` with `@Dependency`; `CrocAppApp.init` registers both in `AppDependencyManager.shared` before any window, since an action can run right after launch.
- `TransferController.wait(for:)` (`TransferIntentSupport.swift`) suspends until a phase transform yields a value, re-arming `withObservationTracking` on `phase` in the same main-actor turn as the check so no change slips between them. `awaitCode()` ends at `.waiting` (the send actions return there, not at the end of the transfer) and `awaitReceive()` at `.done`; `.failed` becomes `TransferIntentError.failed`.
- `ReceivedFileLocator` finds what a receive wrote. croc keeps the sender's modification dates, so it tells new files apart by creation date: `name.ext` or its Keep Both copy `name (n).ext` created since the action started. `controller.offeredFileNames` gives the names.
- `IntentStaging` writes files that arrive without a usable file URL, and a received text as `Received text.txt`, under `ShortcutsFiles` in the temporary directory. A send outlives its action, so nothing is deleted on return; `SendFilesIntent` sweeps the folder at the start of the next send.
- A shortcut does not answer the accept prompt (auto-accept applies as usual), and Keep Both or Replace follows the setting.
- **iPad (R28).** `Views/AppCommands.swift` shows Send… (⌘1), Receive… (⌘2) and Show Receive Folder (⇧⌘R) in the File menu on both platforms. On iPadOS the last one opens `shareddocuments://` plus the percent-encoded receive-folder path with `UIApplication.open`, which is the Files app's scheme for a local folder. Not verified on a device.

## History

`Models/TransferHistory.swift` — `TransferRecord` is a SwiftData `@Model` (fields including `statusRaw` string storage for the enum). Stored uploads add optional `storedID`, `expiresAt` and `revokedAt`; optional so a store written by an older build opens without a migration step. `HistoryStore` is `@MainActor @Observable`, wraps `container.mainContext`, exposes `add` / `delete` / `clear` / `recordCount` / `markRevoked`. The container is in-memory when `AutoVerify.isHarnessRun`, and is injected twice: as `.environment(history)` and as `.modelContainer(history.container)`.

`Views/HistoryView.swift` (`Route.history`, clock toolbar icon on both platforms): `@Query` sorted date-descending, swipe and context delete, Clear behind a confirmation, and "Send Again" for send records that carry bookmarks — resolve bookmarks, then `router.openSend`.

**Both platform probe branches must call `startAccessingSecurityScopedResource()` before `fileExists`.** The sandbox denies `stat` on an unopened scope. Each platform's omission was a separately caught defect.

## Support/ helpers

- `Support/SecurityScopedBookmark.swift` — bookmark create/resolve/resolveIfReachable, shared by `OutputFolderStore` and `HistoryView`'s resend path (previously written four times over, one per platform per call site). `resolveIfReachable` starts the security scope before the existence probe — the sandbox denies `stat` on an unopened scope.
- `Support/EngineConstraints.swift` — `minCodeLength = 6`, mirroring the Go engine's `len(secret) < 6` check in `crocmobile/session.go` and `crocmobile.go`. UI-side validation only, for inline feedback before a doomed `startSend`/`startReceive` call; no shared source of truth across the Go/Swift boundary, kept in sync by hand.
- `Support/DesignTokens.swift` — the app's routing layer onto `design/`: `Spacing`, `Radius`, `BorderWidth`, `ControlHeight`, `IconSize`, `LayoutCap`, `ComponentMetrics`, `Motion`, plus `Color` aliases. The one file that splits `#if os(iOS)`/`#if os(macOS)` for UIKit/AppKit-backed colors. Where a system semantic already matches a token exactly, the alias routes there instead of duplicating an asset-catalog entry.

## Conflict scan

Asynchronous. `.incoming` is shown immediately with `conflicts: []`; `Self.scanConflicts` runs `Task.detached` and stats off the main actor; the write-back happens only when non-empty, only `if case .incoming`, and only if `transferGeneration` still matches the value captured at `.fileList`. The shape check alone was not enough: a scan can outlive a whole fast transfer and land on the *next* one's `.incoming`. Doing the scan synchronously froze the accept UI on large file lists. With conflicts, the sheet offers Decline, Replace and Keep Both (Keep Both prominent) and a banner; without conflicts, or while the scan runs, a single Accept, which means Keep Both. A zipped folder arrives as one `.zip` name, so the scan sees none of its members (`docs/known-issues.md`, Accepted).

`startSend`'s up-to-200 `bookmarkData` calls run off the main actor the same way, writing back into `pendingRecord`. If a transfer somehow terminates first, `pendingRecord` is already nil and the record carries no bookmarks — the same outcome as the pre-existing all-or-nothing fallback, so "Send Again" hides rather than breaks. `SecurityScopedBookmark.create` is `nonisolated` for this.

10k-file smoke tests pass in both directions: receive 427 s, send 358 s.

## Receive links (R22)

- `Models/TransferLink.swift` is the one parser. `TransferLink.parse(_:)` takes a bare code, `crocapp://receive?code=`, `croc://<code>` (0.9.9 QR codes), `https://crocapp.dev/r/#<code>` or `https://getcroc.com/?code=`, and yields `.code`. It also parses a stored-transfer link `https://<host>/s/<id>#v1.<key>` (`http` only for localhost, 127.0.0.1 and ::1) into `.stored(URL)`; `ReceiveView` takes it (see "Stored transfers (R18-R21)"). `TransferLink.webURL(forCode:)` builds the `crocapp.dev/r/` link.
- `AppRouter.open(_:)` stores the link in `pendingReceive` and calls `openReceive()` unless `isBusy`; mid-transfer the link is kept and the user is not moved. `ReceiveView` consumes `pendingReceive` (`onChange(initial: true)` on the form) and fills `code`. Opening a link never starts a receive: the user taps Receive.
- Entry points, all through `TransferLink.parse` then `router.open`: the QR scan sheet (iOS), the Paste button, typed or pasted text containing `://` in the code field, `.onOpenURL` in `CrocAppApp` (iOS universal links and `crocapp://`), and `AppDelegate.application(_:open:)` on macOS (file URLs still go to Send).
- The `crocapp` scheme is in all three Info.plists (`CrocApp-Info.plist`, `CrocApp-macOS-Info.plist`, `CrocApp-Direct-Info.plist`). Universal links for `crocapp.dev/r/*` need the Associated Domains entitlement and `web/landing/.well-known/apple-app-site-association`.
- `TransferStatusView.waitingView` encodes the QR as `TransferLink.webURL(forCode:)` and adds a Share Link button. `browserReceiveNote` adds a caption when the active relay is custom or local-only (R23): croc's browser client knows only the default relays.

## Platform layer, iOS

- `Platform/BackgroundCoordinator.swift` — cross-platform class with `#if os(iOS)` bodies (no-ops on macOS). Wraps a transfer in a `BGContinuedProcessingTask` and holds `isIdleTimerDisabled`. Controller hooks: `transferStarted` in `run()`, `progressChanged` inside the accepted `.progress` path only (the `.incoming` guard stays untouched), `transferEnded` at `.done` / `.failed` / startup catch, idempotent. Expiration sets `backgroundExpired` and cancels, producing dedicated "iOS paused the transfer…" copy. A generation token rejects stale late task launches.
- `Platform/LocalNetworkChecker.swift` — Bonjour self-probe on `_crocapp._tcp`, iOS only (the macOS branch is a no-op stub, `../known-issues.md`). `checkIfNeeded()` probes once per process, triggered by `ContentView.onChange(controller.isActive)`; `recheckIfDenied()` re-probes from `.denied` on `ContentView.onChange(scenePhase)` going `.active` (e.g. the user granted access in Settings and returned), gated so it never re-probes `.granted`/unresolved and never stacks a second in-flight probe. Denial shows a banner plus Open Settings in `TransferStatusView`. Denial only resolves at the 8 s timeout, because a first `.waiting` may just be the pending permission prompt.
- `Models/ShareInbox.swift` + `Views/StagedFilesSheet.swift` — App Group pickup of batches staged by the share extension (`ShareInbox/batch-<UUID>/` plus `manifest.json`). The whole `scenePhase` refresh is gated on `!controller.isActive`; an ungated refresh once purged a live batch mid-send, caught by harness. The manifest is consumed on the user's decision, the batch files outlive the send, and `purgeStaleBatches` runs at idle.
- `app/CrocShare/` — iOS-only appex. The pbxproj entry is hand-built; `platformFilters=(ios,)` on the dependency and the embed keep macOS clean. File-copy staging happens inside the `loadFileRepresentation` handler because of the ~120 MB extension memory cap, and never wipes existing batches. Both `Info.plist` files live in `app/Config/`, outside the synced folders, to avoid a generated-plist collision; the app's `INFOPLIST_FILE` is sdk-scoped to iOS.
- Files-app visibility comes from `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. **Those two do not work the same way, despite both being declared as sdk-scoped `INFOPLIST_KEY_*` settings in the pbxproj.** `LSSupportsOpeningDocumentsInPlace` is injected into the built `Info.plist` from the build setting alone; `UIFileSharingEnabled` is not, and only lands because `app/Config/CrocApp-Info.plist` also declares it literally. Measured, not inferred: delete the two plist lines and `plutil -p` on the built `CrocApp.app/Info.plist` shows `UIFileSharingEnabled` gone while `LSSupportsOpeningDocumentsInPlace`, `NSCameraUsageDescription` and `NSLocalNetworkUsageDescription` all survive — even though `xcodebuild -showBuildSettings` resolves `INFOPLIST_KEY_UIFileSharingEnabled = YES`. So the plist declaration is load-bearing and the pbxproj pair is inert for that one key. Do not "deduplicate" by deleting the plist lines; that silently removes the app from the Files app. "Open in Files" on receive-done uses the `shareddocuments://` scheme — community standard, no public API.

## Platform layer, macOS

- `Models/AppRouter.swift` — `@Observable` singleton (`shared`). `path: [Route]` drives `HomeView`'s `NavigationStack`. `pendingSendURLs` is consumed by `SendView` (`onAppear` plus `onChange`, deduplicated against `pickedURLs`, then cleared). `isBusy` is a computed read of `controller.isActive` through a weak controller reference that `CrocAppApp.init` attaches with `attach(controller:)`, so a dock drop mid-transfer queues without navigating. It is a singleton because `AppDelegate` and `Commands` sit outside the environment graph.
- Three drop entry points, one guard policy: the window drop (`ContentView`, macOS-only) refuses while active and filters `\.isFileURL`; the `SendView` list drop filters too; the dock drop (`Platform/AppDelegate.swift`, `application(_:open:)`) always queues and navigates only when idle.
- Dock drop works because `Config/CrocApp-macOS-Info.plist` declares `public.item` / Viewer / rank None document types. Side effect: the app is listed in Finder's "Open With" for everything, and `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace[sdk=macosx*]=YES` is required or Xcode auto-injects an invalid `NO`.
- `Views/SettingsView.swift` — a General tab (output-folder change/reset plus Show in Finder, the power sections) and an Advanced tab. `Views/AppCommands.swift` — Send ⌘1, Receive ⌘2 (disabled while active), Show Receive Folder ⇧⌘R. Window: `.defaultSize(560×700)`, content `minWidth 480` / `minHeight 560`.
- `CrocApp Direct` only (`#if DIRECT`, `app/CrocAppDirect/AppUpdater.swift`): a "Check for Updates…" item in the app menu right after "About CrocApp", backed by Sparkle's `SPUStandardUpdaterController`. The App Store target has no such item.
- Default output folder is `~/Downloads/CrocApp`, needing the `files.downloads.read-write` entitlement; the folder is auto-created in `defaultFolder` and `defaultDisplayName` supplies the UI label. Receive-done offers "Show in Finder" via `NSWorkspace.activateFileViewerSelecting`.
- Distribution: `scripts/build-appstore.sh [--upload] [ios|macos]` archives `CrocApp` and exports or uploads the iOS and Mac App Store builds with `Config/ExportOptions-{iOS,MAS}.plist` (automatic cloud signing). `scripts/build-devid.sh` archives the `CrocApp Direct` scheme with `ARCHS=arm64` and manual Developer ID signing, exports with `Config/ExportOptions-DevID.plist`, notarizes and staples the app, then builds, signs, notarizes and staples the DMG (it exits 1 without a Developer ID identity). `Config/ExportOptions-{iOS,MAS,DevID}.plist` carry the per-channel settings — no extra pbxproj configurations.

## Onboarding and store compliance

- `OnboardingView` is a sheet from `ContentView.task`, gated on `!onboardingSeen && !AutoVerify.isHarnessRun`; `onboarding.seen` is written in `onDismiss`. The staged-files sheet yields to it (`&& !showOnboarding`) and is re-offered when onboarding dismisses.
- Onboarding also primes the two system permission prompts it now names in its copy: `onDismiss` (iOS only) awaits `CameraPermission.requestIfNeeded()` then calls `localNetwork.checkIfNeeded()`, sequenced rather than simultaneous so the user never sees two system prompts stack. Camera and local-network are never requested during an `AutoVerify` harness run.
- `Platform/CameraPermission.swift` (iOS only) wraps `AVCaptureDevice.authorizationStatus/requestAccess(for: .video)`. `QRScannerSheet` resolves its own authorization first, as a separate gate from `DataScannerViewController.isSupported`, and renders distinct copy for all four `AVAuthorizationStatus` cases: `.authorized` shows the scanner, `.notDetermined` requests then re-reads status, `.denied` offers an Open Settings button, `.restricted` does not (Settings cannot fix a restriction).
- `PrivacyInfo.xcprivacy` sits in both synced target folders — app declares UserDefaults CA92.1, FileTimestamp C617.1 + 3B52.1 and SystemBootTime 35F9.1 (the Go engine's `stat` family and `mach_absolute_time` imports), extension declares an empty accessed-API list, both declare no tracking and no collection. Bundle inclusion was verified in the build products.
- `ITSAppUsesNonExemptEncryption=false` in both Config plists: croc bundles its own AES-256-GCM/PAKE rather than calling Apple OS crypto, but its source is public, so the app relies on the open-source exemption (EAR 742.15(b), owner decision for 1.0). `true` without an `ITSEncryptionExportComplianceCode` made App Store Connect refuse the first upload (2026-10-14). To be confirmed before Submit for Review, and France left out of 1.0 if App Store Connect requires the French declaration (`../known-issues.md`, Blocking release).
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
| `--auto-receive CODE` | receive into Documents, auto-accept via `respond(true)` on `.incoming` unless `--hold` is passed |
| `--when-exists keepBoth\|replace` | the file policy `AutoVerify` answers the incoming sheet with (the setting stays Keep Both, so the late answer must reach croc); default Keep Both |
| `--auto-send PATH --code CODE` | send with a custom code; on macOS the source must be container-resident (sandbox). Needs `--code`: without it nothing happens |
| `--auto-share-send CODE` | read the share inbox, then custom-code send |
| `--local` | sets `settings.onlyLocal` unpersisted (croc `onlyLocal`) |
| `--transport auto\|relay` | sets `settings.transport` unpersisted (sender-side Connection, F41); an unknown value is ignored |
| `--relay ADDR` | custom relay, plus `harnessDisableLocal` to kill the LAN race |
| `--no-compress` | disable compression |
| `--ask` | sets `settings.bothSidesConfirm` unpersisted (sender-side confirm, F19). The `.confirmSend` auto-answer happens in every harness mode, with or without this flag |

Settings overrides apply in any harness run (`isHarnessRun` is true for `--auto-receive`, `--auto-send`, `--auto-share-send` or `--screen`) and start from `resetToDefaults()`, with `persist = false` set first so real `UserDefaults` are never touched.

The screenshot flags (`--screen`, `--stage`, `--seed-history`, `--hold`) are documented in `docs/knowledge/screenshots.md`.

The harness writes `verify-result.txt` (`ok success=<bool>` or `error <msg>`) to Documents. It also writes `verify-code-ready.txt` (contents `ready`, written once, when the phase first reaches `.waiting`, i.e. a send has its code; `verify-share-sim.sh` and `verify-app-mac.sh` wait for it) and `verify-history.txt` (`records=N`, written when the transfer is done or failed; `verify-app-mac.sh` reads it). The result contract is shared by `scripts/verify-app-sim.sh`, `verify-app-mac.sh`, and `verify-share-sim.sh`. AutoVerify's Documents path is hardcoded, decoupled from `OutputFolderStore.defaultFolder`.

Launch gotchas, both macOS:

- Once `CFBundleDocumentTypes` exists, bare adjacent argv tokens are document-open candidates and AppKit skips creating the default window. Use flag-style arguments only.
- Scripted launches need `-ApplePersistenceIgnoreState YES` or they hang in window restoration.

On the CLI side of a verify run, a receiving `croc` needs `CROC_SECRET=` in the environment rather than a positional code: croc refuses custom positional codes in non-classic mode for receive as well as send.
