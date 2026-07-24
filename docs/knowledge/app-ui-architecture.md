# App UI architecture (Phases 2-6)

Facts from Phases 2-6 (2026-07-23/24). Conflict/paste/QR decisions: ADR 0009; iOS platform integration: ADR 0010; macOS platform integration: ADR 0011; settings/trust: ADR 0012; history: ADR 0013. Engine contract: `crocmobile-bridge.md`.

## Structure

```
CrocAppApp owns @State TransferController + OutputFolderStore + LocalNetworkChecker
  + AppRouter.shared → .environment on WindowGroup content
  (macOS Settings scene gets only outputFolder + settings — no router/controller/localNetwork)
HomeView (sole NavigationStack, path: $router.path, value-based links) → SendView | ReceiveView
  each: controller.isActive ? TransferStatusView() : input form
TransferStatusView renders every non-idle phase; IncomingRequestView = accept gate
QRCodeView (cross-platform gen) / QRScannerView.swift (whole file #if os(iOS), VisionKit)
```

## TransferController (@MainActor @Observable, sole CrocKit consumer)

- `Phase`: idle → starting → waiting(code)/connecting → confirmSend | incoming(FileList, conflicts, blocked) → transferring(TransferProgress) → done(Summary, receivedText?) | failed(String). Views switch on it; `reset()` is unconditional (no guard) but only meant to be called from terminal phases — UI only surfaces it there.
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

- `--auto-receive CODE`: receive into Documents, auto-accept via `respond(true)` on `.incoming` (real prompt path). `--auto-send PATH --code CODE`: send with custom code (source must be container-resident on macOS — sandbox). `--local`: sets `settings.onlyLocal` unpersisted (croc onlyLocal). Phase 5 flags: `--relay ADDR` (custom relay + `harnessDisableLocal` to kill the LAN race), `--no-compress`, `--ask` (auto-answers `.confirmSend`). Settings overrides only apply when an `--auto-*` mode is present (`harnessActive` guard) and start from `resetToDefaults()`; `persist = false` first, so real UserDefaults are never touched. Phase 4 gotchas: bare adjacent argv tokens are document-open candidates once CFBundleDocumentTypes exists (AppKit skips creating the default window) — flags only; macOS launches need `-ApplePersistenceIgnoreState YES` or headless runs hang in window restoration. AutoVerify's Documents path is hardcoded (decoupled from `OutputFolderStore.defaultFolder`).
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
- Backlog (final-review triage, non-blocking): queued dock-drop URLs surface invisibly on next Send visit (no badge/route-after-completion); `isBusy` one-cycle mirror lag; SendView drop returns true when all files already staged; createDirectory failure swallowed in `defaultFolder`; duplicated receive-folder guard iOS/macOS doneView branches; in-batch dup gap in pendingSendURLs; AppRouter no reset hook + multi-window path lockstep; ShareInbox staged-sheet send starts transfer without routing to a status view; gate AutoVerify behind build flag before Phase 7 store submission (`forceLocalOnly` itself replaced by the real F14 setting in Phase 5); `ExportOptions-MAS.plist` unvalidated until Phase 7.

## Phase 5 settings + trust layer

- `Models/AppSettings.swift` — @MainActor @Observable, UserDefaults keys `settings.*`, didSet persistence gated by `persist` (harness override channel). Relay strings: `""` = croc default (shown as TextField prompt); `effective*` accessors never hand the engine an empty value; `engineRelayAddresses` blanks the non-customized side (CLI parity, ADR 0012) — never both empty. `relayKind` (publicDefault/custom/localOnly) classifies custom if either address customized. Created BEFORE `TransferController` in `CrocAppApp.init` (controller takes `init(settings:)`); injected into WindowGroup AND macOS Settings scene.
- `TransferController` Phase 5 additions: `baseOptions()` builds EngineOptions from settings; `Phase.confirmSend` (sender + `bothSidesConfirm`, entered at `.connected`, progress-guard like `.incoming`, accept = `respond(true)`, decline = `cancel()`); `autoAcceptActive` skips `.incoming` (unsafe names ⇒ `blockedAutoAccept` cancel with dedicated copy, precedence over backgroundExpired); `activeRelay` captured at start for trust UI; `harnessDisableLocal` (harness-only, not a user setting). Receive passes `autoAccept && !bothSidesConfirm` (Ask wins; engine autoAccept closes prompt pipe ⇒ EOF would decline).
- UI: `PowerSettingsSections` (shared Form sections: relay / transfer toggles / exclusions / confirmation with F18 warning footer) embedded in macOS `SettingsView` and iOS `SettingsScreen` (gear toolbar → `Route.settings`); `Route` grew `settings` + `howItWorks`; `HowItWorksView` (F36 explainer, facts from `what-is-croc.md`); `TrustBadge(relay:)` in waiting/transferring/confirmSend views.
- Verification: `verify-app-mac.sh` directions 4-6 → `MAC-RELAY-OK` (local `croc relay --ports 9021,9022,9023`, `harnessDisableLocal`, non-empty relay log), `MAC-NOCOMP-OK`, `MAC-ASK-OK` (2-file directory, recursive diff — pins the per-file Ask answer regression). Ask direction: CLI receiver must NOT use `--ignore-stdin` and needs an explicit `< file` stdin redirect (bash rebinds backgrounded stdin to /dev/null).
- Backlog (final-review triage, non-blocking): autoAccept + remote `--ask` sender auto-declines with "other side declined" copy (blames wrong side); `blockedAutoAccept` mostly dormant (croc sanitizes names since v10) and tiny transfers can hit `.done` first; iOS relay password TextField lacks `.textInputAutocapitalization(.never)` + `autocorrectionDisabled`; direction-4 `[ -s relay.log ]` passes on banner alone; both-custom relay pair kept (CLI blanks relay6 — intentional divergence); `respond()` sync answer writes could block the actor at ~8k+ files with Ask on; relay password in plaintext UserDefaults (keychain = backlog).

## Phase 6 history + polish layer

- `Models/TransferHistory.swift` — `TransferRecord` @Model (SwiftData; fields per ADR 0013 incl. `statusRaw` string storage for the enum) + `HistoryStore` (@MainActor @Observable, wraps `container.mainContext`; `add/delete/clear/recordCount`). Container built in `CrocAppApp.init` — in-memory when `AutoVerify.isHarnessRun` — injected as `.environment(history)` AND `.modelContainer(history.container)`; controller gets `controller.history = history` post-init.
- `TransferController` capture: `PendingRecord` snapshot set in all three start intents (send: names capped 20, bookmarks all-or-nothing ≤200 built while security scope active; receive: filled from `.fileList`; codeHint backfilled at `.codeReady` for auto codes). `finishRecord(status:summary:)` at `.done`/`.failed`/startup-catch — sets `pendingRecord = nil` first (double-terminal idempotence) and must run while `receivedText` still set (isText backfill). Status mapping: done→completed/failed; failed + cancelRequested→cancelled, declineRequested→declined.
- `Views/HistoryView.swift` (`Route.history`, clock toolbar icon both platforms): @Query sorted date-desc, swipe/context delete, Clear-with-confirmation, "Send Again" (send records with bookmarks) → resolve bookmarks → `router.openSend`. **Both** platform probe branches must `startAccessingSecurityScopedResource()` before `fileExists` (sandbox denies stat on unopened scope; each platform's omission was a caught defect — macOS in task review, iOS in final review).
- Conflict scan is async since Phase 6: `.incoming` shows immediately with `conflicts: []`, `Self.scanConflicts` (Task.detached) stats off-main, write-back only `if case .incoming` and non-empty. 10k-file smokes green both directions (recv 427 s, send 358 s). Guard is shape- not generation-based — backlog.
- Resume hint: `sawTransferBytes` (set on progress with payload bytes) appends "start the same transfer again" copy to non-cancel/non-decline failures.
- Onboarding-lite: `OnboardingView` sheet from ContentView `.task`, gated `!onboardingSeen && !AutoVerify.isHarnessRun`; `onboarding.seen` set in `onDismiss`; staged-files sheet yields to onboarding (`&& !showOnboarding`) and is re-offered on onboarding dismissal. Accent #2BA35A; one `.glassEffect()` (code card in waitingView).
- Store compliance: `PrivacyInfo.xcprivacy` in both synced target folders (app: UserDefaults CA92.1 + FileTimestamp C617.1; extension: empty accessed-API list; both no-tracking/no-collection — bundle inclusion verified in build products), `ITSAppUsesNonExemptEncryption=false` in both Config plists. Audit + reviewer-notes draft: `.superpowers/sdd/appstore-audit.md` (Phase 7 pastes it).
- Harness/env gotchas: `rtk xcodebuild` filter truncates `BUILD SUCCEEDED` (use `rtk proxy xcodebuild`); no GNU `timeout` in plain zsh here (bash harness scripts resolve it, ad-hoc zsh doesn't); `rtk find | wc -l` mis-truncates on 10k-entry dirs (use `/usr/bin/find`); zsh `=word` expansion breaks bare `===` echo args.
- Phase 6 backlog (final-review triage, non-blocking): `HistoryStore.clear()` uses `delete(model:)` — verify live @Query update in manual QA, fallback fetch-and-delete loop; ≤200 sync `bookmarkData` calls on main at send tap; stale-scan generation token; onboarding `onDismiss` re-offer lacks `!controller.isActive` gate; AutoVerify history-write duplication; blockedAutoAccept records as `.cancelled`; `.combine` may hide ProgressView percentage from VoiceOver; resend-condition triplication; BIS/ASC encryption answer must match plist at Phase 7 submission.

## Known V1 papercuts (triaged, accepted)

- Cross-flow status bleed: active Send renders on Receive screen (direction-agnostic `isActive`); one-at-a-time still enforced.
- No Cancel during `.incoming` (Decline is the exit; terminal event can lag under croc auto-reconnect).
- `OutputFolderStore.select` silently no-ops if bookmarking fails; List identity by file name; no explicit scanner stopScanning on dismiss.
- Gesture-level flows (drag-drop, camera QR, taps) not machine-verified — no XCUITest by project rule; verify manually.
