# App UI architecture (Phases 2-4)

Facts from Phases 2-4 (2026-07-23). Conflict/paste/QR decisions: ADR 0009; iOS platform integration: ADR 0010; macOS platform integration: ADR 0011. Engine contract: `crocmobile-bridge.md`.

## Structure

```
CrocAppApp owns @State TransferController + OutputFolderStore + LocalNetworkChecker
  + AppRouter.shared → .environment on WindowGroup content AND macOS Settings scene
HomeView (sole NavigationStack, path: $router.path, value-based links) → SendView | ReceiveView
  each: controller.isActive ? TransferStatusView() : input form
TransferStatusView renders every non-idle phase; IncomingRequestView = accept gate
QRCodeView (cross-platform gen) / QRScannerView.swift (whole file #if os(iOS), VisionKit)
```

## TransferController (@MainActor @Observable, sole CrocKit consumer)

- `Phase`: idle → starting → waiting(code)/connecting → incoming(FileList, conflicts, blocked) → transferring(TransferProgress) → done(Summary, receivedText?) | failed(String). Views switch on it; `reset()` only exits terminal phases.
- Event-handling gotchas learned the hard way:
  - `.progress` ticks (~10 Hz) keep arriving while the accept prompt is unanswered — **must not clobber `.incoming`** (croc otherwise blocks in GetInput forever; found by harness, fixed d278c2e). Also ignore `step == "waiting"` ticks.
  - Local decline surfaces croc's `"refused files"` — same string the sender sees. Track `cancelRequested`/`declineRequested` flags to pick correct copy ("Transfer cancelled." / "You declined the transfer." / "The other side declined the transfer.").
  - `transferActive` on start: retry once after ~300 ms (post-done release window).
  - `engine.cancel()` on `.failed` (belt-and-suspenders with stream onTermination).
- Security scope: intent methods start access (send URLs, user-picked out folder), tracked in `scopedURLs`, released at stream end; `startAccessingSecurityScopedResource() == false` is fine (non-scoped drops) — keep the path anyway.
- Speed: EMA (0.25/0.75) over `bytesFinished + fileSent` deltas, ≥0.2 s spacing. Overall progress = `(bytesFinished + fileSent) / totalSize` (fileSent is per-current-file).

## SwiftUI API facts (verified this phase)

- `fileImporter` WITHOUT `allowsMultipleSelection:` → completion `Result<URL, Error>`; WITH it (any value) → `Result<[URL], Error>`. Plan code mixing these does not compile.
- `PasteButton` closure is nonisolated — hop to MainActor before touching @State.
- `.qr` symbology needs `import Vision` alongside VisionKit; `DataScannerViewController.isSupported == false` on simulator (sheet shows fallback); startScanning failures surfaced via onStartFailure → "Camera unavailable".
- QR gen: `CIFilter.qrCodeGenerator` + static shared CIContext, cache CGImage in @State keyed by `.task(id: content)`, render `Image(decorative:scale:).interpolation(.none)`.
- Same-module cross-file type use still needs per-file `import CrocKit`.
- Camera key: `INFOPLIST_KEY_NSCameraUsageDescription` in both pbxproj configs.

## AutoVerify harness (launch args, drives the real controller)

- `--auto-receive CODE`: receive into Documents, auto-accept via `respond(true)` on `.incoming` (real prompt path). `--auto-send PATH --code CODE`: send with custom code (source must be container-resident on macOS — sandbox). `--local`: sets `controller.forceLocalOnly` (croc onlyLocal). Phase 4 gotchas: bare adjacent argv tokens are document-open candidates once CFBundleDocumentTypes exists (AppKit skips creating the default window) — flags only; macOS launches need `-ApplePersistenceIgnoreState YES` or headless runs hang in window restoration. AutoVerify's Documents path is hardcoded (decoupled from `OutputFolderStore.defaultFolder`).
- Writes `verify-result.txt` (`ok success=<bool>` | `error <msg>`) to Documents. Contract shared by `scripts/verify-app-sim.sh` (receive) and `scripts/verify-app-mac.sh` (both directions; CLI receive needs `CROC_SECRET=` env, not positional code — croc refuses custom positional codes in non-classic mode for recv too).

## Phase 3 platform layer

- `Platform/BackgroundCoordinator.swift` — cross-platform class, `#if os(iOS)` bodies (macOS no-op): wraps transfer in BGContinuedProcessingTask + holds `isIdleTimerDisabled`. Controller hooks: `transferStarted` (in `run()`), `progressChanged` (inside accepted `.progress` path only — `.incoming` guard untouched), `transferEnded` (`.done`/`.failed`/startup-catch, idempotent). Expiration → `backgroundExpired` + `cancel()` → dedicated "iOS paused the transfer…" copy, precedence over cancel/decline mapping. Generation token rejects stale late task launches.
- `Platform/LocalNetworkChecker.swift` — Bonjour self-probe (`_crocapp._tcp`), once per process, triggered by `ContentView.onChange(controller.isActive)`; denied ⇒ banner + Open Settings in `TransferStatusView`. Denied resolves only at 8 s timeout (first `.waiting` may just be the pending prompt).
- `Models/ShareInbox.swift` + `Views/StagedFilesSheet.swift` — App Group pickup of CrocShare-staged batches (`ShareInbox/batch-<UUID>/` + `manifest.json`). Whole scenePhase refresh gated on `!controller.isActive` (ungated refresh once purged a live batch mid-send — caught by harness). Manifest consumed on user decision; batch files outlive the send; idle-time `purgeStaleBatches`.
- `app/CrocShare/` — iOS-only appex target (pbxproj hand-built, `platformFilters=(ios,)` on dependency + embed keep macOS clean). File-copy staging inside `loadFileRepresentation` handler (~120 MB ext memory cap), never wipes existing batches. Both Info.plists live in `app/Config/` (outside synced folders — avoids generated-plist collision); app's INFOPLIST_FILE is sdk-scoped to iOS.
- Files-app visibility via `INFOPLIST_KEY_UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace` (iOS sdk-scoped); "Open in Files" on receive-done uses `shareddocuments://` (community-standard scheme, no public API; silently no-ops for provider-picked folders).
- App icon: `app/CrocApp/AppIcon.icon` (Icon Composer bundle, synced-folder auto-include, name matches `ASSETCATALOG_COMPILER_APPICON_NAME`) — compiles for both platforms, no pbxproj edit needed.
- Harness additions: AutoVerify `--auto-share-send CODE` (reads inbox, custom-code send) + `scripts/verify-share-sim.sh` (stages via simctl app-group container, marker `SHARE-SIM-OK`). App-group path: `simctl get_app_container <udid> <bundle> groups | awk` (the documented single-group form errors on current simctl).
- Backlog (final-review triage, non-blocking): cancel queued BG request when transfer ends pre-adoption; `backgroundExpired` ignored in `run()` catch copy; manifest-name validation parity with `ReceivedName`; Open-in-Files provider-folder no-op; dup `UIFileSharingEnabled` key; ShareStagingView cancel closure unused; staged sheet only offered on next foregrounding.

## Phase 4 macOS layer

- `Models/AppRouter.swift` — @Observable singleton (`shared`): `path: [Route]` drives HomeView's NavigationStack; `pendingSendURLs` consumed by SendView (`onAppear` + `onChange`, dedup vs pickedURLs, then cleared); `isBusy` mirrors `controller.isActive` (set in ContentView's onChange) so dock drops mid-transfer queue without navigating. Singleton because AppDelegate + Commands sit outside the environment graph.
- Drop entry points, one guard policy: window drop (ContentView, macOS-only) refuses while active + filters `\.isFileURL`; SendView list drop filters too; dock drop (`Platform/AppDelegate.swift` `application(_:open:)`) always queues, navigates only when idle. Dock drop works because `Config/CrocApp-macOS-Info.plist` declares `public.item`/Viewer/rank-None doc types (side effect: app listed in Finder "Open With" for everything; `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace[sdk=macosx*]=YES` required or Xcode auto-injects invalid NO).
- `Views/SettingsView.swift` (macOS Settings scene, ⌘,): output-folder change/reset + Show in Finder. `Views/AppCommands.swift`: Send ⌘1 / Receive ⌘2 (disabled while active), Show Receive Folder ⇧⌘R (macOS). Window: `.defaultSize(560×700)`, content `minWidth 480 / minHeight 560`.
- F7 macOS default = `~/Downloads/CrocApp` (`files.downloads.read-write` entitlement; folder auto-created in `defaultFolder`); `defaultDisplayName` supplies the UI label. Receive-done shows "Show in Finder" (`NSWorkspace.activateFileViewerSelecting`).
- Distribution: `scripts/build-devid.sh` (archive `ARCHS=arm64` → Developer ID export → `codesign --verify` → `syspolicy_check distribution`; `DEVID-PENDING-CERT` until cert installed) + `Config/ExportOptions-{MAS,DevID}.plist`. No extra pbxproj configs (ADR 0011).
- Backlog (final-review triage, non-blocking): queued dock-drop URLs surface invisibly on next Send visit (no badge/route-after-completion); `isBusy` one-cycle mirror lag; SendView drop returns true when all files already staged; createDirectory failure swallowed in `defaultFolder`; duplicated receive-folder guard iOS/macOS doneView branches; in-batch dup gap in pendingSendURLs; AppRouter no reset hook + multi-window path lockstep; ShareInbox staged-sheet send starts transfer without routing to a status view; gate AutoVerify + `forceLocalOnly` behind build flag before Phase 7 store submission; `ExportOptions-MAS.plist` unvalidated until Phase 7.

## Known V1 papercuts (triaged, accepted)

- Cross-flow status bleed: active Send renders on Receive screen (direction-agnostic `isActive`); one-at-a-time still enforced.
- No Cancel during `.incoming` (Decline is the exit; terminal event can lag under croc auto-reconnect).
- `OutputFolderStore.select` silently no-ops if bookmarking fails; List identity by file name; no explicit scanner stopScanning on dismiss.
- Gesture-level flows (drag-drop, camera QR, taps) not machine-verified — no XCUITest by project rule; verify manually.
