# App UI architecture

How the SwiftUI app is wired and which of its behaviours are load-bearing. Read the relevant section before editing a view that observes `TransferController`.

Engine contract: `crocmobile-bridge.md`. Open defects are GitHub issues labelled `known`.

## Structure

```
CrocAppApp owns @State TransferController + AppSettings + OutputFolderStore
  + HistoryStore + LocalNetworkChecker + AppRouter.shared (+ MenuBarQuickSend on macOS)
  → .environment on the one main scene's content (CrocAppApp.mainContent)
  (macOS Settings scene gets only outputFolder + settings, no router/controller/localNetwork)
ContentView → one TabView, .tabViewStyle(.sidebarAdaptable), selection: $router.selection (see "Layout and navigation"):
  Send | Receive | History | Settings (iOS only), each tab in its own NavigationStack
  → SendView(draft: router.sendDraft) | ReceiveView(draft: router.receiveDraft) | HistoryView | SettingsScreen (path: $router.settingsPath)
  How It Works: a sheet over any tab (router.showsHowItWorks)
  each transfer screen: controller.isActive and a matching direction ? TransferStatusView() : input form
TransferStatusView renders every non-idle phase; IncomingRequestView = accept gate
Shared pieces (Views/): DropZone, CodePhraseDisplay, DirectionHeader, ForwardProgressBar, PhoneHaptics; Support/Inflected.swift
QRCodeView (cross-platform gen) / QRScannerView.swift (whole file #if os(iOS), VisionKit)
```

Localization: the app ships in English only, but every user-facing string reaches a String Catalog. See `tooling.md`, "Localization".

Construction order in `CrocAppApp.init` matters: `AppSettings` (on in-memory storage and secrets for a harness run), then the `HistoryStore` container (in memory for a harness run), then `StoredTransferVault`, then `TransferController(settings:vault:)`, then `controller.history = history`.

## Layout and navigation

`ContentView` is one `TabView(selection: $router.selection)` with `.tabViewStyle(.sidebarAdaptable)` and four tabs: **Send**, **Receive**, **History** and **Settings**. The system draws a tab bar on iPhone and a sidebar on iPad and Mac, and moves between them as the window changes, so nothing in the app reads the size class or the device. On iPad the sidebar button switches to a floating tab bar and back. A portrait iPad draws the sidebar as a transient overlay that covers the screen (seen on a fresh launch in the simulator), so the default is `.defaultAdaptableTabBarPlacement(isLandscape ? .sidebar : .automatic)`, with `isLandscape` from `onGeometryChange` (width greater than height). The first frame is `.automatic`, and the system followed the flag on launch and on rotation in the simulator, without losing the drafts or overriding a placement the user had chosen. That modifier is iOS only. The design is `design/principles.md`, "Platform adaptation".

- **Availability.** `.sidebarAdaptable` and `TabContent.badge` are iOS 18 and macOS 15. `defaultAdaptableTabBarPlacement` and `AdaptableTabBarPlacement.sidebar` are iOS 18 and unavailable on macOS. Read in the iPhoneOS 27.2 SDK's `.swiftinterface`.
- **No Settings tab on the Mac.** The `Settings` scene (⌘,) stays, with its General and Advanced tabs, so the tab is compiled out there (`#if os(iOS)`). The menu bar extra is unchanged.
- **One stack per tab.** A pushed screen (a History record) stays with its tab.
- **The cap.** Send, Receive and How It Works cap their own column at 480 pt. History and Settings fill the width, as grouped lists do, and have no cap of their own.
- **Actions at the bottom** (issue #126). `Views/ActionScreen.swift` is the one layout of Send, Receive, every `TransferStatusView` phase and `StoredLinkView`: a `ScrollView` with the content top-aligned in the 480 pt column, and the screen's buttons in `.safeAreaInset(edge: .bottom)` on a `.bar` background, so the content scrolls under them. The inset sits above the tab bar, and moves up with the keyboard. It is not a `.bottomBar` toolbar: that placement is the tab bar's own place on iPhone. The row is a `ViewThatFits` of an `HStack` (equal widths, the prominent button last) and a `VStack` (accessibility text sizes), so Accept, Decline and Cancel never leave the screen. Each button is `resultAction` or `destructiveAction`, large and full width, so the row is one height in every state. One `.glassProminent` at most, never two. The pages above the row never use a height-capped inner scroll view for a file list: the page scrolls.

**Selection.** `AppRouter.selection` (`AppRouter.Screen`: send, receive, history, settings) is the one navigation state. Two small ones sit beside it: `settingsPath`, the pages pushed in the Settings tab (so a failure can open Advanced), and `showsHowItWorks`. Every entry point sets the selection: `openSend(with:)`, `openSend(text:)`, `openReceive()`, `open(_:)`, `openHistory()`, `openHistory(record:)`, `showSettings(advanced:)`, the staged-files sheet, the Mac window drop, the Dock drop, App Intents, `crocapp://` links, notification taps and `AutoVerify`. The busy rule: a drop, a link or staged text mid-transfer fills its draft and moves nobody. The menu commands and the tabs are user actions, so they navigate when a transfer runs.

**The drafts.** `SendDraft` (mode, staged files, typed text, the code and link options) and `ReceiveDraft` (the code, a stored link) are `@Observable` objects that `AppRouter` owns, above the tab view. `SendView` and `ReceiveView` take them as `@Bindable`. Switching tabs, or flipping between tab bar and sidebar, therefore loses nothing, and an entry point can fill a screen that is not on display: it only stages, and Send and Receive stay the user's buttons. `AppRouterTests` holds the retention test (`SendDraftTests` and `ReceiveDraftTests` the draft rules). The drafts live in memory, so a relaunch starts empty.

**The tab state.** `TransferTabState` (`Models/TransferTabState.swift`) derives the badge of the active transfer's tab from the phase: **Connecting**, **Waiting**, **Review** for `.incoming` and `.confirmSend`, **Sending** or **Receiving**. A finished or failed transfer leaves every tab at rest, because the result is on the screen and in a notification. The state carries no percent, so the tab view does not redraw at each step, and the one VoiceOver announcement ("Send, connecting") is posted when the kind changes, never on a progress tick. The `TransferController.Phase` questions (`needsAnswer`, `canCancel`, `shownCode`) and `Phase.kind`, the case without its payload, live on `Phase` in `TransferController.swift`.

**A request that needs an answer** brings its own tab forward: `ContentView` sets `selection` to the transfer's direction when `phase.needsAnswer` turns true, and the tab keeps its **Review** badge if the user then goes elsewhere. There is no separate banner.

**How It Works** is a sheet (a `NavigationStack` around `HowItWorksView`, with a **Done** button), so it opens over any tab. It is reached from the **How It Works** row at the top of the About section in Settings, from the Help menu on the Mac, and with `--screen howItWorks`.

## TransferController

`@MainActor @Observable`. It is the only code that uses `CrocEngine`. Many other files `import CrocKit` for its types, but only the controller starts and answers transfers.

It reaches the engine through the `TransferEngine` protocol. `init(settings:vault:engine:)` defaults to `CrocEngine()`, so the app passes none. `app/CrocAppTests/TransferControllerTests.swift` passes `FakeTransferEngine`, which emits events one at a time and records every call, and checks the rules below against it. `TransferFailureTests` and `EngineStartTests` check the failure mapping and the engine options with no engine at all. A change to one of these rules needs its test updated in the same change.

`Phase`: `idle` → `starting` → `waiting(code)` / `connecting` → `confirmSend` | `incoming(FileList, conflicts, blocked)` → `transferring` → `done(Summary, receivedText?)` | `stored(StoredReceipt)` | `failed(TransferFailure)`. Views switch on it. `reset()` has no guard, but the UI offers it only from a terminal phase. The controller's per-transfer state (end reason, tasks, transfer ID, scopes, output folder, history draft) is one private `Run` that `start(_:)` and `reset()` replace. `currentCode`, `offeredFileNames` and `storedReceiptSaved` stay outside it, because a Shortcuts action reads them after the transfer ends, and `run()` clears them.

The controller is the one `@Observable` the views use. Its pure pieces live in their own files under `Models/`:

| File | Holds |
| --- | --- |
| `TransferRequest.swift` | what a transfer starts from: a file send, a text send, a receive, a stored send or a stored receive |
| `EngineStart.swift` | the engine call and its options, built from a request and `AppSettings` |
| `TransferFailure.swift` | every failure's title, detail and remedy, and the precedence that picks one |
| `HistoryDraft.swift` | the history record of the transfer in flight, and `ReceivedName.shown`, the form in which a sender's name is drawn and recorded |
| `ReceivedItems.swift` | `ReceivedItems.locate`: the top-level items a finished receive wrote, for the result screen |
| `CodeHint.swift`, `SecurityScopes.swift`, `TransferSpeed.swift` | the code hint, the security-scope bookkeeping, the speed smoothing |

- **One start.** `start(_ request: TransferRequest)` starts every kind of transfer. While one is active it does nothing and returns false. It stamps `startedAt` (the result screen tells a file this receive wrote from an older one by it), and keeps the request, and `retry()` runs it again, only from a failure whose remedy is `.tryAgain`. `retry()` resets first, so the start is not refused as busy.
- **Progress is not part of the phase.** `.transferring` has no payload. Each accepted tick sets `progress` and `speedBytesPerSec`, and only the first one sets the phase. `Phase` is `Equatable`, so whatever reads only the phase (the haptics in `ContentView`, `HomeView`, `AppRouter.isBusy`) does not redraw at the tick rate. What shows only the percent (`RegularLayout`'s sidebar, the Dock badge, the menu-bar label) reads `progressPercent`, which moves at most 101 times a transfer. What shows bytes (`TransferStatusView`, the menu-bar window) places them inside `ProgressTick`, a leaf view that reads `progress` itself, so the tick redraws the bars and byte lines and nothing around them.

### Event handling

- **`.progress` ticks (about 10 Hz) keep arriving while the accept prompt is unanswered, and must not clobber `.incoming`.** If they do, croc blocks in `GetInput` forever. The same guard protects `.confirmSend`. Ticks with `step == "waiting"` are ignored.
- **A failure is picked by `EngineFailure.code`, never by text.** `TransferFailure(_:situation:)` checks the user's own cancel ("Transfer cancelled") and decline ("You declined the transfer") first, then maps the code. Those two set `endedByUser` and have no detail, because a cancel or decline the user made is not a failure (`design/voice.md`, "Errors").
- It never shows `failure.message`: croc's wording changes per release, and a recovered panic carries a stack trace.
- Each failure has a `remedy`: `.tryAgain`, `.openSettings(SettingsPlace)`, or nil when retrying would not help (`design/components.md`, "StatusBlock"). `TransferFailureTests` pins the remedy of every code.
- When payload bytes moved, the resume hint replaces the detail. A stored transfer, which cannot resume, and the user's own cancel or decline never get it.
- A peer's decline arrives as `.declined` ("The other device declined or cancelled"). A peer's cancel looks the same. This side's own decline, or a prompt that hits EOF, arrives as `.refused`.
- **No automatic retry on `transferActive`.** The engine is free once a terminal event arrives (`crocmobile-bridge.md`, "Engine behavior invariants"), so a start after `.done` or `.failed` succeeds. `transferActive` means a transfer really runs. Its failure offers **Try Again**, for once that one ends.
- `handle(.failed)` does not call the engine. The stream's `onTermination` cancels and clears the transfer by its ID.
- `TransferController` keeps that `transferID`. Every cancel (user, background expiry, auto-accept block) targets it.
- A cancel before the ID exists cancels `startTask`, the task awaiting the engine's start, and `CrocEngine` then cancels the start in Go (`CrocmobileCancelStart`). The start runs in its own task because cancelling `streamTask` would also end the event loop. `run()` still cancels by ID once a start returns, in case it finished first.
- The auto-accept block cancels with `cancel(reason: .unsafeName)`, not the user's `.cancelled`. `TransferFailure.blockedAutoAccept` has `endedByUser` false, so the failure haptic plays: the user tapped nothing.
- Why a transfer ended besides its result is one `TransferController.EndReason` (`declined`, `cancelled`, `backgroundExpired`, `unsafeName`), kept in the controller's private `Run`. When several apply, the later case in that order wins, so a Cancel tap after the block still reads as the block. The History status follows `EndReason.recordStatus`.
- Failure precedence, highest first: code `engineStuck`, `unsafeName`, `backgroundExpired`, the auto-accept-versus-remote-`--ask` case, then `cancelled` and `declined`, then the code. `TransferFailure.Situation` carries the end reason, so `handle(.failed)` and the `catch` in `run()` share the one mapping, and a thrown expiry keeps the resume hint. `engineStuck` shows its copy over a Cancelled record.
- `engineStuck` outranks a Cancel tap too. Only a relaunch frees the engine, and every later start fails the same way. It offers no **Try Again**, and `endedByUser` is false.
- `textTooLong` (croc refused a text offer over its 1 MiB limit) asks the sender to send it as a file, with no **Try Again**: the same text would fail again.
- `joinedEarly` (a receiver that joined before the sender) says to start the send first. There is no automatic retry and no **Try Again**, because the sender has failed by then too, and a generated code changes when it starts again.
- A reset and a new start (**Try Again**) can come before the last event loop ends. The loop releases its security scopes only while `Run.token` still matches, so it cannot release the next transfer's.
- `unsafeName` is checked in `.done` as well as `.failed` (`TransferFailure.blockedAutoAccept`). The block's cancel is fire-and-forget, so a small transfer can finish before the cancellation reaches the engine. Both paths record `.failed`, because the history schema has no blocked case and "Cancelled" reads as a user action.
- `TransferStatusView` shows a "taking longer than usual" hint after 25 s (`slowPhaseThreshold`) in `.starting` or `.connecting`. A `.task(id: isInEarlyPhase)` resets the timer whenever that flips. The clock survives the `.starting` to `.connecting` handoff, because the user sees one stall.

### Code `refused` under auto-accept is not a peer decline

croc forces the receiver prompt whenever the remote sender ran `--ask` (upstream `croc.go`, not re-read here). Engine auto-accept has already closed the prompt pipe, so `GetInput` hits EOF and croc reports its local `refused files`.

`autoAcceptActive && endReason != .cancelled && failure.code == .refused` identifies this case. The check runs after the `unsafeName` and `backgroundExpired` branches. `respond()` is never called on the auto-accept path, so the end reason cannot be `declined`.

Under auto-accept the pipe is not empty. `crocmobile` queues a batch of `n` answers for croc's other prompts (empty folder, unzip member) and then closes it (`crocmobile-bridge.md`, "Engine behavior invariants"). The forced remote-`--ask` prompt reads the first `n` answers and ends as `refused` under either file policy. The batch is `n` even for Replace for that reason. A manual accept behaves the same, because a croc v11 reconnect re-runs the accept prompt (`scripts/verify-interop.sh` checks it).

### Options, security scope, progress

- `EngineStart(_:settings:)` builds the engine call and its `EngineOptions` or `StoredSendOptions` from the request and `AppSettings`. A sender gets `workDir` (the Go side reads it only on a send), a receiver does not. The throttle, the sender IP and the proxies pass as typed, because the engine trims them; the stored-transfer server is the one value Swift still trims. Receive also passes `whenFileExists` (`AppSettings.whenFileExists`, key `settings.whenFileExists`, default Keep Both; an unknown stored value reads as Keep Both).
- Receive passes `autoAccept && !bothSidesConfirm`, so confirmation wins. Engine auto-accept closes the prompt pipe, which croc reads as a decline.
- `start(_:)` opens security scope on send URLs and on the user-picked output folder (`SecurityScopes`), and releases it at stream end or on reset. `startAccessingSecurityScopedResource() == false` is fine for non-scoped drops. Keep the call anyway.
- Speed (`TransferSpeed`) is an exponential moving average (0.25 new, 0.75 old) over `bytesFinished + fileSent` deltas, sampled at most every 0.2 s. Overall progress is `(bytesFinished + fileSent) / totalSize`. `fileSent` is per current file.
- While croc moves a batch of small files (`TransferProgress.isBundling`, engine step `bundling`) no byte count is current (`crocmobile-bridge.md`, "Small-file bundles"). `TransferStatusView.bundleView` and the menu-bar window show "A batch of small files" with an indeterminate bar on macOS and a spinner on iOS (whose indeterminate linear `ProgressView` is a still, empty track), `TransferProgress.percent` is nil (so the sidebar, menu bar label and Dock badge show no percent), and the iOS background task gets a negative completed count, which makes its progress indeterminate.
- `activeRelay` is captured at start, for the waiting screen's browser-receive note.
- `harnessShownRelay` and `harnessShownLinkOrigin` are harness-only, not user settings, and exist only in Debug builds.

### History capture

- `start(_:)` sets a `HistoryDraft` from the request. Send: names capped at 20, bookmarks all-or-nothing up to 200, built while the security scope is held. Receive: `offer(_:)` fills it from `.fileList`. `codeHint` is backfilled at `.codeReady` for generated codes.
- `finishRecord(status:summary:)` runs at `.done`, `.failed` and the startup `catch`. It sets `pendingRecord = nil` first, so a double terminal event is harmless, and returns right after that while **Save Transfer History** is off. It must run while `receivedText` is still set, so `isText` backfills (`HistoryDraft.record(status:summary:receivedText:)`).
- A receive's names come from the sender and `ReceivedName.isUnsafe` runs only after `offer(_:)`, so the draft stores them in their shown form (`ReceivedName.shown`: every scalar `isSpoofingScalar` flags is written as `\u{XXXX}`), never raw. `FileRow` and the progress line draw the same form. `HistoryDraftTests` and `ReceivedNameTests` pin it.
- Status mapping: `done` becomes completed or failed per the summary. `failed` becomes `EndReason.recordStatus`: cancelled for `cancelled`, declined for `declined`, failed for `backgroundExpired`, `unsafeName` or no reason.

## Settings and trust

`Models/AppSettings.swift` is `@MainActor @Observable`. `AppSettings(storage:secrets:)` takes two injected stores:

| Store | Protocol | App | Harness run and tests |
| --- | --- | --- | --- |
| Values | `SettingsStorage` (`object(forKey:)`, `set(_:forKey:)`), `Support/SettingsStorage.swift` | `UserDefaults.standard`, which already conforms | `MemorySettingsStorage` |
| Secrets | `SecretStore`, `Support/KeychainStore.swift` | `KeychainStore` | `MemorySecretStore` (app), `FakeSecretStore` (tests) |

Each setting has its own key, starting with `settings.`, typed once in `AppSettings.Key`, and a `didSet` writes just that key. There is no `Codable` blob: a synthesized `Codable` struct resets every field to its default when a build adds one. A key that is absent, or holds another type, reads as the setting's default, and the keys are part of the contract with saved preferences, so never rename one. `AppSettingsPersistenceTests` pins them.

`LaunchMode.current` (`Support/LaunchMode.swift`) decides once whether a launch is the app, a harness run (`AutoVerify.isHarnessRun`) or a hosted unit-test run (`XCTestConfigurationFilePath` is set). Only `.app` is live: `CrocAppApp.init` builds the other two on `MemorySettingsStorage`, `MemorySecretStore`, an in-memory history and an in-memory receive-folder bookmark (`OutputFolderStore`), and starts neither the notifier, the snapshot writer nor the Spotlight purge. `ContentView` reads `LaunchMode.current` for the onboarding check. For a harness run, the app builds `AppSettings` on `MemorySettingsStorage` and `MemorySecretStore`. Its overrides start from the defaults and reach neither `UserDefaults` nor the Keychain, so a manual run's settings cannot bleed into a harness run, and a harness run cannot blank a real stored password. Every test suite does the same: a `UserDefaults(suiteName:)` writes a `CrocAppTests.*.plist` into the sandbox container's `Library/Preferences` that `removePersistentDomain` does not delete.

The relay password (`relayPassword`) and the two proxies are the settings that are not in `storage`. They live in `secrets` (the Keychain). Their `didSet` calls `secretEdited(_:)`: the new value applies at once, and the write waits until 500 ms pass with no further edit (`secretWriteDelay`), so typing is one Keychain write, not one per keystroke. `flushSecrets()` writes what is pending now. It runs from `resetAdvancedToDefaults()`, when the main window's scene phase leaves active (`ContentView`) and on `willTerminateNotification` (`CrocAppApp`, macOS). A test that checks the store calls it after editing. `persistRelayPassword()` deletes the item instead of storing a blank. `AppSettings.init` also deletes what 1.2.x left from the removed relay this Mac ran: the `settings.relayHostPort` and `settings.relayHostAtLaunch` keys and the `relayHostPassword` Keychain item (`launchRemovesWhatTheRemovedRelayHostLeftBehind`).

A failed settings write to `secrets` is never silent. This covers the relay password and the proxies only: a failed receipt write in `StoredTransferVault` is logged and nothing more ("Stored transfers"). `flushSecrets()` (through `persistRelayPassword()` and `persistProxy`) puts the setting in `unsavedSecrets` (`.relayPassword`, `.socks5Proxy`, `.httpProxy`) when the store's `set` or `delete` returns false, and takes it out on that setting's next successful write. The property keeps the edit for this launch, but the next launch reads what the store still holds. While a setting is in the set, its field shows an error `StatusBanner` (`AppSettings.secretNotSavedTitle` and `secretNotSavedDetail`), which never names the value: the relay **Password** in `PowerSettingsSections`, the proxies through `AdvancedRow` in `AdvancedSettingsView`. `FakeSecretStore.failWrites` fails both `set` and `delete` for the tests.

**Not behind the injected storage:** `OutputFolderStore` (`UserDefaults.standard` by default, key `outputFolderBookmark`) and `@AppStorage("onboarding.seen")` in `ContentView`. `OutputFolderStore` takes a `UserDefaults` in its initializer, and `OutputFolderStoreTests` passes a throwaway suite, so no test writes the real key. The app writes it from **Change…** and **Reset**, and when a stale bookmark is refreshed at launch. A pick whose bookmark cannot be made leaves the folder as it was and sets `selectionFailed`, which Receive and the Mac Settings show as an error `StatusBanner`. The first-run flag is written only when the onboarding sheet is dismissed (a `--screen onboarding` capture run, by hand).

**Save Transfer History** (`saveTransferHistory`, key `settings.saveTransferHistory`, default on). `TransferController.finishRecord` returns before it builds the record while the setting is off, so a finished, failed, cancelled or declined transfer leaves nothing in History. Records already there stay until the user deletes them. A **Send as Link** upload made while it is off has no History row, so it cannot be revoked from History: the receipt stays in the Keychain vault until it expires. `HistoryView` shows "History is off" with **Open Settings** instead of the empty list while the setting is off and no records exist (`design/components.md`, "HistoryRow").

**Haptics** (`haptics`, key `settings.haptics`, default on, iPhone only). `phoneHaptic` (`Views/PhoneHaptics.swift`) is the one place that checks it, together with the iPhone idiom, so every call site honors it. The modifier reads `AppSettings` from the environment on iOS, so a view that uses `phoneHaptic` needs it there (the WindowGroup provides it). `Views/GeneralSettingsSections.swift` holds the two rows, shared by the macOS General tab and the iOS `SettingsScreen`; the Haptics row only exists on iPhone.

### User controls

Every automatic or stored behavior has a visible switch in Settings, or a stated reason it needs none. A default stores and shows the least that keeps the feature useful. A surface that can show a transfer name outside the app has its own switch, off by default, and never carries a code phrase, a relay password or a stored-link key (`design/principles.md`, "Bans"). This table is the audit (D23); a new automatic behavior adds a row. Keys are `settings.<name>` unless the row says otherwise.

| Behavior | Switch (Settings label) | Default | Lives in |
| --- | --- | --- | --- |
| Transfer history kept on this device, capped at 300 records | **Save Transfer History** (`saveTransferHistory`) | on | SwiftData store (`HistoryStore`); a record keeps a code hint, never the code |
| History offered to Shortcuts and Siri (Find Transfers) | follows **Save Transfer History**; the actions are the user's own, so no second switch | on with history | `HistoryEntityStore` |
| Notifications when CrocApp is in the background | **Notifications** (`notificationsEnabled`); the system asks for permission at the first transfer | on | `TransferNotifier` |
| File names in notifications | **Show File Names in Notifications** (`notificationsShowFileNames`) | off | `TransferNotifier.notice` |
| Names in widgets, Control Center and the Live Activity | **Show File Names on the Lock Screen and in Widgets** (`systemSurfacesShowFileNames`) | off | `TransferSnapshotWriter`, `BackgroundCoordinator` |
| Last-transfer widget data (direction, outcome, time) | follows **Save Transfer History**: the file is deleted while it is off. A widget exists only once the user adds it | on with history | App Group file (`TransferSnapshotStore`) |
| iOS Live Activity during a background transfer (direction and progress) | the system's per-app Live Activities switch in iOS Settings. It ends with the transfer, and shows no name unless the switch above is on | system | `BackgroundCoordinator` |
| Dock badge, macOS: the percent while bytes move, "1" while a request waits | **Show Progress in the Dock** (`showDockBadge`) | on | `TransferNotifier` |
| Menu bar item, macOS | **Show in Menu Bar** (`showInMenuBar`) | on | `MenuBarExtra(isInserted:)` |
| Open at login, macOS | **Open at Login** | off | the system's login-item list (`LoginItem`, `SMAppService`), not our defaults |
| Saved codes | none: added only by **Add Saved Code**, deleted in Settings. They never leave the Keychain | empty | Keychain item `savedCodes` |
| Accepting without asking | **Auto-Accept Transfers** (`autoAccept`), with the warning footer; **When a File Already Exists** applies under it | off | `AppSettings` |
| Update check, Direct build only | **Check for Updates Automatically**, which is Sparkle's own setting | off until the user answers Sparkle's prompt | Sparkle's defaults (`AppUpdater`). The App Store build has no check |
| Receive folder | **Save Received Files To** (Change, Reset) | `~/Downloads/CrocApp`, or the app's Documents | bookmark in `UserDefaults` (`OutputFolderStore`) |
| Haptics, iPhone | **Haptics** (`haptics`) | on | `phoneHaptic` |
| Copied code or link leaves the pasteboard after 5 minutes (macOS clears it while the app runs; iOS sets an expiry) | none: it protects a secret and discards the user's data only if the user has not copied anything since | always | `Clipboard.copySecret` |
| Staged copies of shared files and photos | none: deleted with the row, the screen or the next launch's sweep. Only the user's own staged files | n/a | `SendStaging` |
| Receipt of a Send as Link upload, kept until the link expires so it can be revoked | none: the user started the upload, and the receipt is the only way to revoke it | n/a | Keychain (`StoredTransferVault`) |
| Screen stays awake during a transfer, iOS | none: a transfer stops when the device sleeps | during a transfer | `BackgroundCoordinator` |
| The croc relay pool and LAN discovery | **Local Network Only**, **Skip Local Network**, a custom relay (Settings > Relay and Advanced) | public pool plus LAN | `EngineStart` |

Relay strings use `""` for "croc default" (the `TextField` prompt reads "Public relay pool") and reach the engine as stored, password included. Go resolves them (`crocmobile/relay.go`): blank means croc's default, and with no custom relay and Local Network Only off, the relay comes from upstream's public pool by code.

`relayKind` is display-only: `publicDefault`, `custom`, `localOnly` or `directToSender`. It is `custom` if either address is set to something other than `RelayDefaults` (CrocKit, read from Go). `receiveRelayKind` returns `directToSender` when a sender IP is set.

`Views/PowerSettingsSections.swift` holds the shared `Form` sections: relay, Send as link, transfer toggles, exclusions, and confirmation with the **Auto-Accept Transfers** warning footer. Both the macOS `SettingsView` (Settings scene, ⌘,) and the iOS `SettingsScreen` (gear toolbar, `Route.settings`) embed these sections.

`TrustBadge(relay:)` appears once, on `HowItWorksView`, the plain-language explainer. The transfer screens do not repeat it. Its facts come from `what-is-croc.md`.

**Review request** (App Store builds only, `#if !DIRECT` in `ContentView`). `TransferController` calls `AppSettings.recordSuccessfulTransfer()` at `.done` with a successful summary and at `.stored`, never on a failure; the count (`settings.successfulTransfers`) and the version last asked in (`settings.lastReviewPromptVersion`) persist through `SettingsStorage`. `ContentView` runs a `.task` keyed on the count: 2 seconds after a success it checks that the phase is still `.done` (a stored link screen has a revoke dialog, so it never asks), no sheet is up and the scene is active, asks `ReviewPrompt.shouldAsk` (3rd success or later, not yet asked in `AppInfo.marketingVersion`), stores the version and calls `@Environment(\.requestReview)`. The system shows the prompt at most 3 times in 365 days and never in TestFlight (Apple's StoreKit documentation), so the app's rules only narrow it. It is not called from a button.

**About and privacy link.** `Views/AboutSection.swift` is the last `Form` section of the macOS General tab and of the iOS `SettingsScreen`. It shows the version (`CFBundleShortVersionString` and `CFBundleVersion`), **Privacy Policy**, **Support** and **croc License** links, then **Rate CrocApp** (App Store builds, `#if !DIRECT`) or **Support CrocApp** (disk image build, `#if DIRECT`), and a footer with the attribution croc's MIT license requires (`design/brand.md`, "Attribution and legal"). The app and Direct targets also set `NSHumanReadableCopyright`. The URLs and the version string live in `Support/AppInfo.swift`, and `AppInfoTests` checks that each link is a well-formed https URL.

On macOS, `AppCommands` replaces the `.appInfo` group with an **About CrocApp** button. It calls `NSApplication.orderFrontStandardAboutPanel(options:)` with a linked "Privacy Policy" `.credits` string. The Direct build's `UpdateCommands` still attaches after that group.

`Phase.confirmSend` is the sender side of croc `--ask`. It is entered at `.connected` when **Confirm on Both Sides** is on, and it is progress-guarded like `.incoming`. Accept is `respond(true)`, decline is `cancel()`, and its Cancel button is a destructive `.glass` button.

### Stored transfers

`isStoredTransfer` marks a transfer that goes through a stored-transfer server instead of a croc peer. It reuses `run()`, `handle(_:)`, the `BGContinuedProcessingTask` wrap and the history record.

- `start(.storedSend(urls:downloads:lifetimeSeconds:))` uploads to `AppSettings.storedServer` (key `settings.storedServer`, default `https://getcroc.com`).
- The engine sends `.progress`, then `.stored(receipt)` just before `.done`. The controller puts the receipt in the vault, keeps its id and expiry for the record, and turns `.done` into `Phase.stored(receipt)`.
- `start(.storedReceive(link:folder:folderIsScoped:))` takes the same path as a live receive: `.incoming` with the conflict scan, then `respond(accept:policy:)`. Auto-accept never applies, and the engine always waits.
- `AppSettings.storedServerError(_:)` asks the engine (`EngineSetting.storeServer`): `https`, or `http` on loopback only, and nothing after the host. Blank is refused. `TransferLink.parse` accepts a stored link only over `https`, or `http` on loopback. The engine checks the id and key lengths.
- A stored transfer cannot resume, so no failure offers the resume hint. A background expiry reads "Sending was interrupted" or "Receiving was interrupted", and its detail says to keep CrocApp open and try again, or open the link again. Both offer **Try Again**.
- A failure whose situation `isStored` names the link server for `relayUnreachable` and `connectionLost`, which is how a store call reports a network failure.
- `revoke(_ record:)` (throws `EngineFailure`) calls `CrocEngine.revokeStored`, which needs no free engine slot. It then drops the receipt and sets `revokedAt`. `canRevoke(_:)` is true for an unexpired, unrevoked record whose receipt this device still holds.
- `revoke(_ receipt:)` is the same call for the link screen. It needs no record, so a link sent with Save Transfer History off can be revoked. It marks the record `HistoryStore.record(storedID:)` finds, if any, and leaves the vault and the record alone when the engine throws.
- `storedReceiptSaved` is the result of `vault.add` for the receipt on screen, and `start` sets it back to true. When it is false the screen warns that revoke works only until the app quits.
- The Camera app does not open CrocApp for a stored link. The Associated Domains entitlement and the apple-app-site-association file cover only `crocapp.dev/r/*`. Receiving in the app means **Paste** or **Scan QR Code**.

Views for stored transfers:

- `SendView`: a **Send as Link** toggle, disabled with a reason line for text or a staged folder. With it on, the screen shows a **Link Lasts** picker (1 hour, 1 day by default, 7 days), a downloads stepper (1 to 100, default 1) and a server note. The custom code field is hidden and the primary button reads **Send as Link**. The screen blocks sending when `storedServerError` reports an invalid server.
- `TransferStatusView`: `Phase.stored(receipt)` renders `StoredLinkView`, a screen of its own (an `ActionScreen`, because Revoke and Done act on state it keeps): "Link ready", expiry and download count, QR, link text, **Copy Link** (`copySecret`, `thisDeviceOnly: true`), **Share Link** and a `StatusBanner` while `storedReceiptSaved` is false, with **Revoke Link** (confirmation dialog, then a neutral "Link revoked" block) and **Done** in the actions row. **Revoke Link** and **Done** are disabled while a revoke runs.
- `DirectionHeader` reads Sending or Receiving for stored transfers too, never Uploading or Downloading. The send header shows a caption about the link server when `isStoredTransfer`.
- `ReceiveView`: `ReceiveDraft.apply` of a `.stored(url)` link sets `storedLink`. That replaces the code field with a **Receive from Link** row (the server host underneath) and a **Clear** button. **Receive** then starts `.storedReceive`.
- `HistoryView`: stored rows add a "Link expires", "Link expired" or "Link revoked" line. **Revoke Link** (context menu) and **Revoke** (swipe on iOS) sit behind a confirmation dialog, with an alert on failure. Deleting such a row asks whether to revoke first (see History).
- `PowerSettingsSections`: a "Send as link" section (the header really reads that way, in sentence case) with the Link Server field, an inline `storedServerError` banner, and a **Reset** button shown only when the value differs from the default.

`Models/StoredTransferVault.swift` keeps receipts (id, origin, upload token, link, expiry) in the Keychain, all in one item (`storedReceipts`, a JSON array), because `SecretStore` cannot list accounts. Expired receipts are purged when the vault opens, which is each launch. A failed Keychain write is logged, never lost silently, and leaves the receipts already stored untouched. The new receipt then lasts until the app quits. Harness runs and previews use `MemorySecretStore`.

History never holds the token or the link. A stored record's `codeHint` is the server host (`CodeHint.storedLink(_:)`).

### Advanced settings

croc's own options are edited in `Views/AdvancedSettingsView.swift`. iOS pushes it from `SettingsScreen` (`SettingsPage.advanced`, `--screen advanced`). macOS Settings is a `TabView` with **General** and **Advanced** tabs, because the Advanced controls and their footnotes would double a form that already scrolls.

- `AppSettings` has one property per control under `settings.advanced.<name>`: `throttleUpload`, `peerIP` and `disableLocal` (**Skip Local Network**). Defaults come from `EngineOptions()`, so they are croc's. The curve, hash and ports are not settings, and `features.md`, "Skipped", says why. The harness's `--disable-local` sets `disableLocal` on its in-memory settings.
- `resetAdvancedToDefaults()` backs the **Reset to Defaults** button and persists. Each section's footer says what its fields share: the Keychain note once under the proxies, never per field. `AppSettings.init` deletes the stored values of the options 1.3.0 removed (`settings.advanced.multicastAddress`, `internalDNS`, `noMultiplexing`, `excludePaths`), as it does for the relay host and Spotlight settings. The `excludePaths` lines are first appended to `excludePatterns` (those not already there), so a file the user kept out of folder sends stays out.
- **The two proxies are Keychain-only.** The `SecretStore` accounts are `advanced.socks5Proxy` and `advanced.httpProxy`. They are deleted when blank, like `relayPassword`.
- Proxies can carry credentials. `ProxySettings`, `EngineOptions` and `StoredSendOptions` describe themselves without the value. The Go engine never quotes a proxy in an error, and nothing logs them. `AppSettingsAdvancedTests` asserts that `UserDefaults` holds no proxy key or value.
- `Models/AdvancedSettingsValidation.swift` holds the inline checks: `socks5ProxyError`, `httpProxyError`, `senderIPError`, `throttleError`. The app keeps no rules of its own. Each one asks the engine through CrocKit's `EngineSetting.validate(_:)` (`ValidateSetting` in `crocmobile/network.go`, the check a transfer start runs) and returns only the field's plain-words text on a refusal. `storedServerError` works the same way. Blank means the default, except for the link server. The value tables live in `network_test.go`, and `SettingsValidationTests` checks that each field reaches the engine.
- One message per field, so the sender IP text names the port range too and the link server text covers the scheme and the host-only rule.
- `EngineStart` passes every setting. A receive adds `peerIP`. Store send, store receive and revoke pass `ProxySettings`.
- iOS needs the multicast entitlement for croc's LAN discovery, which `CrocApp-iOS.entitlements` carries (`apple-platform-constraints.md`, "LAN discovery and multicast").
- The engine reports a bad proxy, upload limit or sender IP as `invalidSetting` (`validateNetworkOptions` in `crocmobile/network.go`). The `invalidSetting` failure points at Settings > Advanced, and its **Open Settings** opens Advanced settings.
- **Skip Local Network** and **Local Network Only** (`onlyLocal`, in `PowerSettingsSections`) exclude each other. Each toggle is disabled while the other is on, with its footnote naming the other one. The engine refuses the pair too, so a stored pair (a harness override on top of **Local Network Only**) fails as `invalidSetting`.
- A receive with a sender IP shows `RelayKind.directToSender` in the trust badge (`AppSettings.receiveRelayKind`), never the public pool.

### Saved codes

`Models/SavedCodes.swift` (`@MainActor @Observable`, injected as `.environment(savedCodes)` into the main window and the macOS Settings scene) holds the `SavedCode` values (`id`, `name`, `code`) and persists them through the injected `SecretStore`: one Keychain item, `savedCodes`, a JSON array, because `SecretStore` cannot list accounts. A harness run uses `MemorySecretStore`. `save(_:)` trims both fields, refuses a blank name or a code shorter than `EngineConstraints.minCodeLength`, and replaces an entry with the same `id` (a rename). A failed Keychain write sets `saveFailed`, which `SavedCodesSection` shows as an error banner; the change then lasts until the app quits, like the vault. A Keychain read that fails (`SecretStore.load` throws, for example before first unlock) sets `loadFailed`: the section shows an error banner with **Try Again** (`reload()`), **Add Saved Code** is disabled, and `save` and `remove` do nothing until a load succeeds, so a later write cannot replace the stored list with an empty one. An item that reads but is not valid JSON loads as empty and the next write replaces it. Nothing logs a name or code. A transfer sent with a custom code, or received with a saved one, stores no code hint in History (`HistoryDraft.keepsNoHint`, `TransferController.savedCodes`).

`Views/SavedCodesViews.swift`: `SavedCodesSection` (a `Form` section in the macOS General tab and the iOS `SettingsScreen`, after the History, Notifications and Haptics rows), `SavedCodeEditor` (a sheet, with the reuse warning as a `StatusBanner`) and `SavedCodePicker` (a horizontal row of buttons under the code field of Send and Receive, empty until a code exists). The list never shows a code, only the editor does.

### Menu bar and Shortcuts

Neither surface owns transfer state. Both drive the one `TransferController`, so they show and respect a transfer started anywhere. A second start is refused while `isActive`.

**Menu bar (macOS).**
- `CrocAppApp` declares a `MenuBarExtra` in window style, inserted while `AppSettings.showInMenuBar` is on (`settings.showInMenuBar`, default true). The toggle is **Show in Menu Bar**.
- `Views/MenuBarQuickSendView.swift` switches on `controller.phase`. A failure shows its title and detail in an error `StatusBanner`, with **Done**. `Models/MenuBarQuickSend.swift` holds the actions (`send(urls:)`, `sendClipboardText()`, `chooseFiles()`, `receive(_:)`) and a `notice` string. Sends use a generated code. `receive(_:)` parses with `TransferLink` and starts into `OutputFolderStore`, as `ReceiveIntent` does.
- `chooseFiles()` uses a modal `NSOpenPanel`, because the window-style extra closes when focus moves to a SwiftUI file importer's sheet.
- `.incoming` shows **Open CrocApp to Accept**, a button that opens the main window, because the accept prompt lives there.
- The label of the `MenuBarExtra` is `MenuBarIcon(phase:percent:)`, a pure mapping tested for real SF Symbols. It takes `TransferController.progressPercent`, not `progress`, so the label redraws when the percent moves, not at the tick rate.
- A drop lands only on the open window, never on the status item.

**Open at Login.**
- `Models/LoginItem.swift` wraps `SMAppService.mainApp` behind the `LoginItemService` protocol, which tests inject.
- The **Open at Login** toggle reads `status`, never a stored copy, because the user can change it in System Settings > General > Login Items. `SettingsView` refreshes on appear and when the app becomes active.
- For `.requiresApproval` it shows an **Open Settings** button (`SMAppService.openSystemSettingsLoginItems()`).

**Intents.**
- `Intents/` holds `SendFilesIntent`, `SendTextIntent`, `ReceiveIntent`, `OpenTransferIntent`, the History entity and its query, and `CrocAppShortcuts`. Every intent sets `supportedModes: .foreground`, because a transfer outlives the roughly 30 s iOS gives a background action.
- The intents take `TransferController` (and, for receive, `OutputFolderStore`) with `@Dependency`. `CrocAppApp.init` registers both in `AppDependencyManager.shared` before any window, because an action can run right after launch.
- `TransferController.wait(for:)` (`TransferIntentSupport.swift`) checks the controller every 100 ms until a check yields a value, and returns nil once the action is cancelled. It polls instead of observing, so it ends on cancellation at once.
- `awaitCode()` ends at `.waiting`, so the send actions return there and not at the end of the transfer. `awaitReceive()` ends at `.done`. `.failed` becomes `TransferIntentError.failed` with the failure's title and detail.
- The action finds what a receive wrote with `ReceivedItems.locateFiles`, the files behind every offered name (folders expanded), resolved as `ReceivedItems.locate` resolves a file. croc keeps the sender's modification dates, so it tells new files apart by creation date: `name.ext`, or its Keep Both copy `name (n).ext`, created since the action started. `controller.offeredFileNames` gives the names.
- `IntentStaging` writes files that arrive without a usable file URL, and a received text as `Received text.txt`, under `ShortcutsFiles` in the temporary directory. A send outlives its action, so nothing is deleted on return. `SendFilesIntent` sweeps the folder at the start of the next send.
- A shortcut does not answer the accept prompt. Auto-accept applies as usual, and Keep Both or Replace follows the setting.

**History entities.**
- `Intents/HistoryEntity.swift` is the `AppEntity` for a record: name, direction, status, date, file names, size. Never the code phrase or code hint. `HistoryEntityQuery` answers Shortcuts (by id, by name, and a Find Transfers action with date, direction, status and name filters). `OpenTransferIntent` opens History (the list, not the record: no route carries a record yet, #126).
- `Models/HistoryEntityStore.swift` is the one object the query reads. It is registered with `AppDependencyManager` and reads the history store on demand, so it keeps no state in step.
- CrocApp adds nothing to the system search index. `Support/SpotlightPurge.swift` empties the named index `CrocAppHistory` that 1.2 filled, at every live launch (a downgrade can refill it), so file names an earlier build indexed do not stay there.
- The entity id is the JSON of the record's SwiftData `PersistentIdentifier` (`HistoryEntityID`). It survives a relaunch, not a reinstall or a reset store (#224).

**Send with CrocApp (Services menu, macOS).**
- `Platform/SendServicesProvider.swift` is `NSApp.servicesProvider`, set in `AppDelegate`. `sendFiles` and `sendText` are the `NSMessage` values of the two `NSServices` entries in `Config/CrocApp-macOS-Info.plist` and `CrocApp-Direct-Info.plist`; `SendServicesRegistrationTests` ties both plists to the selectors. They stage through `AppRouter.openSend(with:)` and `openSend(text:)`, so a service never starts a transfer and never navigates during one.
- Text is capped at `maxTextBytes` (1 MiB of UTF-8); a larger selection is refused with a message. The menu title is localized by `ServicesMenu.xcstrings`.

**Menu bar commands.**
- `Views/AppCommands.swift` is the menu bar on the Mac and the hardware-keyboard menu bar on iPad. Anything a toolbar button does has an item with a shortcut (the commands are below), and right-click menus are additive.
- File: **Send…** (⌘1), **Send Clipboard Text…** (⌥⌘1), **Receive…** (⌘2), **Paste Code…** (⌥⌘2), **History** (⌘3), **Clear History…** and the Show Receive Folder item (⇧⌘R). Transfer: **Cancel Transfer** (⌘.) and **Copy Code** (⇧⌘C). Help: **How It Works** (⌘?). iPad adds **Settings…** (⌘,) to the app menu; the Mac's comes from the Settings scene.
- **Send…**, **Send Clipboard Text…**, **Receive…** and **Paste Code…** are disabled while a transfer is active. **Cancel Transfer** is enabled while `phase.canCancel`, which excludes the accept gate, and **Copy Code** while `phase.shownCode` is set. **History**, **Settings…** and **How It Works** always work and navigate through `AppRouter.showHistory()`, `showSettings()` and `showHowItWorks()` (the last pushes on what is open). A screen pushed on what is open goes through `AppRouter.push(_:)`: in regular width a path that does not start at a row (the empty path at launch) first takes the row the sidebar shows, so a pushed Settings never replaces the screen it came from.
- **Send Clipboard Text…** reads the pasteboard text and calls `openSend(text:)`; **Paste Code…** parses the pasteboard with `TransferLink.parse` and calls `open(_:)`. Neither starts a transfer. Reading the pasteboard from a menu command is a programmatic read, so iOS shows its Allow Paste prompt (not verified on a device).
- On macOS the Show Receive Folder item is **Show Receive Folder in Finder**.
- On iPadOS it is **Show Receive Folder in Files**. It opens `shareddocuments://` plus the percent-encoded receive-folder path with `UIApplication.open`, which is the Files app's scheme for a local folder.
- The iPad hand-off is not verified on a device. A user-picked provider folder (such as iCloud Drive) is expected to do nothing, because that scheme resolves local paths only.

## Accept gate

The incoming request is a phase of the transfer screen, not a sheet or an alert, so it cannot be dismissed by accident. It shows the direction header, the file list, a banner for each overwrite conflict and blocked-unsafe item, and in the actions row at the bottom **Decline** (destructive) and **Accept** (prominent; **Keep Both** and **Replace** when a name is taken). Nothing auto-advances and nothing is preselected.

| Exit | What the other device learns | What the app does |
| --- | --- | --- |
| Decline | that you said no | responds, then the terminal phase |
| Accept | that you said yes | responds, then the transfer |
| Navigating away | nothing | nothing: the request stays live |

- There is no Cancel and no "Not now": either would answer the sender on the user's behalf or promise a deferral the protocol cannot deliver. Only the sender's own timeout ends the wait. Navigating away never responds, not on backgrounding either.
- A live request is never lost. It brings its own tab forward, and that tab carries a **Review** badge while the request waits and the user is elsewhere. A both-sides confirm on a send is the same question and gets the same treatment. The badge is persistent, never a toast.
- Decline is worded as telling the other device no. Nothing describes leaving as an action.
- Auto-accept skips the gate. It is off by default on every platform, and only the user turns it on.

## System surfaces

What the app puts outside its windows. **On any glanceable surface, never show** a code phrase (it is the whole secret), a link (its `#` fragment is the key), the contents of a file or text, or a history record's code hint. A glanceable surface is one a bystander can read: a notification, a widget, a control, the Live Activity, the menu bar and the Dock. Styling is the system's: system chrome and text styles, the accent only as a fill or a glyph tint, never a custom glass or shadow. The rule is also a security requirement (`THREAT-MODEL.md`, "Privacy").

| Surface | iPhone | iPad | Mac |
| --- | --- | --- | --- |
| Notification | yes | yes | yes |
| Home Screen and desktop widget, Control Center control | yes | yes | yes |
| Live Activity (the system draws it while a transfer runs in the background: title, progress, Cancel, and the file name only with the switch below) | yes | yes | no |
| Menu bar icon, Dock tile | no | no | yes |

**Notifications** are local only (`Models/TransferNotifier.swift`, `Platform/SystemNotificationCenter.swift`).
- `TransferNotifier` observes the controller's phase with `Observations`, so `TransferController` knows nothing about it. `TransferNotifier.notice(for:)` decides which phase notifies and what it says; a fake `NotificationPosting` tests it.
- Notifies for `.done`, `.stored`, `.failed` (not the user's own cancel or decline), `.incoming` and `.confirmSend`. Posted only while the app is not active, replaces the one on screen, and is removed when the phase leaves it.
- Two settings: **Notifications** (on by default; the system prompt comes with the first transfer, or when the switch is turned on) and **Show File Names in Notifications** (off by default; the title is generic and a failure body is the failure's title, which names no file).
- Interruption level is active, never time sensitive or critical, and there is no sound. The `transfer` category carries `hiddenPreviewsBodyPlaceholder`, so a body with names is hidden when the user hides previews.
- A tap selects the Send or Receive tab of the transfer (`AppRouter.selection`). There are no notification actions: the accept gate must be on screen before a yes.
- Denied permission is not read back: the switch stays on and nothing is delivered. The footer says CrocApp asks the system, and System Settings owns the answer.

**Dock tile (Mac).** `TransferNotifier` also sets `NSApp.dockTile.badgeLabel`: the percent while `.transferring` with a known total, "1" while `phase.needsAnswer`, nil otherwise. A badge label needs no permission and no custom view. It has no switch.

**Widgets and controls** live in the `CrocWidgets` extension (`app/CrocWidgets/`; `CrocWidgets Direct` for the Direct app). It reads one file, `last-transfer.json`, in the App Group container (`ShareHandoff.groupID`).
- `TransferSnapshotWriter` observes the controller like `TransferNotifier` and writes a `TransferSnapshot` (direction, outcome done, failed or stopped, item count, date, and a name) only when a transfer ends, then reloads the timelines. A running transfer is never written, so a killed app cannot leave a stale "in progress". The code phrase and link never enter the type.
- **Last Transfer** (small, medium): state, date and the count; the medium size adds **Send** and **Receive** buttons. With no file, or with **Save Transfer History** off (the writer deletes the file), it says "No recent transfer".
- A name is stored only for a single item and only with **Show File Names on the Lock Screen and in Widgets** (off by default). It is one switch for the widget and the Live Activity, separate from **Show File Names in Notifications** because a widget stays on screen and a notification does not. Turning it off rewrites the file without the name.
- The buttons run `OpenSendIntent` and `OpenReceiveIntent` (`Shared/OpenScreenIntents.swift`), which select the Send or Receive tab and start nothing. The Shortcuts actions in `Intents/` need files, text or a code, so a one-tap button cannot run them. The intents are not discoverable in Shortcuts.
- On the Mac, a widget or control button, a notification tap and an opened `crocapp://` link or file all end in `AppRouter.showMainWindow()`. The main window's content gives the router its `openWindow` action at launch, and the action still works after the user closed the window (checked by hand: close the window, `open -a CrocApp.app "crocapp://receive?code=..."`, the window returns). Without it the router asks the system to reopen the app.
- Clearing History or deleting a record deletes `last-transfer.json` (`TransferSnapshotWriter` is a `HistoryChangeObserver`); a deletion cannot say whether it was the newest record, so any user deletion clears it. A send's count comes from `Summary.files` and its name from the request's URLs, never from a text payload.
- **Control Center controls**: **Send** and **Receive** (`ControlWidgetButton`, iOS 26 and macOS 26) run the same two intents. They show no state, number or code.
- **Live Activity.** The system draws it for the `BGContinuedProcessingTask` (`BackgroundCoordinator`); the SDK header says it shows the task's `progress`, so there is no ActivityKit activity. The title names the direction. The subtitle is the file name only with the switch on (captured when the transfer starts), otherwise "Transferring…".

**Menu bar icon (Mac).** One monochrome template glyph with no animation: `arrow.up.arrow.down.circle` at rest, its `.fill` while starting, waiting, connecting or transferring (with the tabular integer percent beside it when the total is known), `ellipsis.circle.fill` while waiting for the other device, `exclamationmark.circle.fill` when a request waits for an answer, a transfer failed or finished with errors, and `checkmark.circle` once a transfer is done and not yet dismissed. The accessibility label is "CrocApp" and the state in words, never a code phrase.

**Received files.** After a completed receive the files list below the result as file rows. Quick Look is the primary action (a tap, or Space with a keyboard), and the app never opens, runs or interprets a received file itself. Each row has a trailing `ShareLink` and drags out as a copy of the file on iPad and Mac (iPhone has no drag between apps). A folder has no Quick Look: its action is the folder button. A text payload is not a row but a selectable text block with **Copy Text** and **Share**. Every action is also in the row's context menu.

**Copy.** Titles and bodies for these surfaces. A notification says its result generically and never shows file names unless **Show File Names in Notifications** is on, because a name is the first thing a bystander reads on a Lock Screen. With it on, the body is the file's name, or the count for several (`3 files`); sizes are not shown.

| Surface | Title | Body |
| --- | --- | --- |
| Notification: a request waits | Files are waiting for your answer | the file name or count, if the switch is on |
| Notification: both-sides confirm on a send | The other device is waiting for you to send | |
| Notification: a transfer finished | Transfer complete, or Transfer finished with errors | the file name or count of a receive, if the switch is on |
| Notification: a link is ready | Link ready | |
| Notification: a transfer failed | Transfer failed | the failure's title |
| any notification, previews hidden | | Transfer update |
| Widget, no transfer or History off | No recent transfer | |
| Widget, last transfer | Sent, Received, Send failed, Receive failed, Send stopped, Receive stopped | the name (switch on, one item) or the count, and the time since |
| Widget and control labels | Send, Receive | |
| Live Activity, file names hidden | Sending with CrocApp, Receiving with CrocApp | Transferring… |

### Settings copy

A row's label names the thing, in Title Case, as a noun phrase, never "Enable" or "Allow". A footer is one sentence in sentence case that says what the row changes.

| Row | Footer |
| --- | --- |
| **Save Transfer History** | Finished transfers are listed in History, which stays on this device. |
| **Notifications**, **Show File Names in Notifications** (the second is disabled while the first is off) | When CrocApp is in the background, a transfer that finishes, fails or needs your answer sends a notification. It never shows a code phrase or link, and shows file names only if you turn that on. CrocApp asks the system for permission when you start your first transfer. |
| **Haptics** (iPhone only) | A short tap when you copy or scan a code, and when a transfer finishes, fails or needs your answer. |
| Section "Saved codes": **Add Saved Code**, one row per name | A saved code is kept in this device's Keychain and never synced. Using it again means it is no longer single-use: anyone who learns it and connects first can receive your next transfer. |

When the system has notifications off for CrocApp, both Notifications rows are disabled and the footer reads "Notifications are off for CrocApp in Settings." ("System Settings" on a Mac) with an **Open Settings** button. "Incoming" appears in no label, because nothing is being received before the user says yes.

## Windows and keyboard focus

One main window on Mac and one scene on iPad: the transfer is app-wide and runs one at a time, so a second window could only mirror the first. The Mac main window is a single-instance `Window` scene and iPad turns multiple scenes off (`UIApplicationSupportsMultipleScenes` NO), so the tab selection and the drafts live in `AppRouter.shared`. Closing the Mac window leaves the app running: the menu bar item stays and a running transfer finishes. A Dock click, a receive link or **Open CrocApp** brings the window back. The main window opens at 880×700 (minimum 720×560), Settings at 480×780 (minimum 480×420), and the Mac menu bar window is 300 wide.

On arrival, a Mac and an iPad with a hardware keyboard put the caret in the first text field (Receive's code field); Send's screen takes keyboard focus instead so ⌘V reaches it. An iPad without a keyboard and an iPhone focus nothing, because the software keyboard covers half the screen. `HardwareKeyboard.isExpected` answers the question in code. A focus target that exists only to catch a paste hides its own ring and never the ring of the controls inside it. Macs have no camera, QR scan or local-network prompt: those are absent, not disabled.

## Transfer screen presentation

The shared views route onto `design/`. A screen picks one of these instead of styling ad hoc.

- Buttons are the system's (`design/principles.md`, "Controls"): the one primary action of a screen is `.buttonStyle(.glassProminent)`, every other button `.buttonStyle(.glass)`, and a bare text action `.borderless`. Cancel, Decline and Revoke are `role: .destructive` on a `.glass` button whose label has `.foregroundStyle(.red)`: a `.glass` destructive label is drawn in the primary color, and `.tint(.red)` would fill the button red on macOS. `resultAction` and `destructiveAction` (`ActionScreen.swift`) are the full-width large form of the same buttons, for every button of the actions row. iOS gets 44 pt targets from `.controlSize(.large)`, which `touchTargets()` applies on iOS only, and the two icon-only buttons in `FileRow` set a 44 pt frame themselves. The system `PasteButton` ignores it, and Send's segmented `Picker` keeps its 32 pt height so the form still fits a small phone.
- Colors are the system's too: `.primary`, `.secondary`, system red, green and orange for status, `.separator`, and `Color.accentColor` for the accent. `AccentColor` in `Assets.xcassets` is the only color set and the global accent of every app target, so no scene sets `.tint`. The widgets and the share extension have no asset catalog, so they draw the system accent.
- Spacing, shapes, sizes and motion are the system's as well: default stack and form spacing, text styles and `.imageScale` for sizes, `.default` animations that are `nil` under Reduce Motion. The app has no token file; a measurement one view needs (the 480 pt column cap, the QR size) is a literal or a private constant in that view. `FileRow` is a bare row: a `GroupBox` (with `Divider`s) or a `List` supplies the card.
- `DropZone`, `CodePhraseDisplay` (eyebrow, code, **Copy Code**; `compact` for the 300-wide menu bar column), `DirectionHeader` (arrow plus Sending or Receiving).
- `ForwardProgressBar` never moves backwards, and `resetKey` snaps it when the measured thing changes (`design/principles.md`, "Motion").
- `Support/Inflected.swift` resolves `^[3 file](inflect: true)` markup into a plain `String`.
- **Accept gate.** `.incoming` offers Decline only, with no Cancel. Cancel would answer the sender on the user's behalf, so `TransferStatusView.actions` offers no Cancel there (`design/components.md`, "AcceptGate"). Leaving the screen answers nothing and stays silent.
- **Done.** `doneView` builds its `StatusBlock` with `StatusBlock(summary:receivedText:direction:)`: a summary croc did not mark successful becomes `TransferFailure.finishedWithProblems`. A receive then lists `ReceivedFilesList`: `ReceivedItems.locate` runs off the main actor over `offeredFileNames` and `startedAt`, and returns a folder once and a file at the name it was saved under (the newest Keep Both copy created since `startedAt`, through `ReceivedItems.keepBothOriginal`). A row is `FileRow(received:)`: tap for Quick Look, a share control, a context menu (**Quick Look**, **Share**, **Show in Finder** or **Show in Files**) and drag-out on Mac and iPad. A folder row has only the reveal action. A user-picked folder is read under its security scope, which the list takes itself because the controller released it. The name is drawn in its shown form.
- **`StatusBlock` kinds.** `.success`, `.error` and `.neutral`. `.neutral` (grey `slash.circle` glyph) is the user's own Cancel or Decline (`TransferFailure.endedByUser`) and a revoked link, which are not failures (`design/voice.md`, "Errors").
- **Failure.** `failedView` shows a `TransferFailure` as a `StatusBlock` title and detail, then its actions stacked, large and full width: **Try Again** (`retry()`) or **Open Settings**, prominent, with **Done** secondary, or **Done** alone (`design/components.md`, "StatusBlock").
- **Open Settings** goes to the failure's `SettingsPlace`. On macOS it sets `AppRouter.settingsTab`, which `SettingsView`'s tabs follow, and calls `openSettings`. On iOS it calls `router.showSettings(advanced:)`, which selects the Settings tab and pushes Advanced when the fix lives there. The transfer's own tab stays as it was. A system permission opens the system Settings, as the local network banner does.
- **Phase cross-fade.** `TransferStatusView` animates on `phaseKind` (the phase case without its payload), not on progress ticks, so only a real phase change cross-fades. It is `nil` under Reduce Motion (`design/principles.md`, "Motion").
- **Haptics.** Phase haptics live in `ContentView`: one `.phoneHaptic(trigger: TransferHaptic(controller.phase))` on the root. `TransferHaptic` has three cases (completed, failed, incoming), and a failure whose `endedByUser` is set (the user's own Cancel or Decline) stays silent. The fourth event, `.selection` for a copied or scanned code, fires from `CodePhraseDisplay` and `ReceiveView`. iPhone only, and silent while the **Haptics** setting is off (`phoneHaptic` checks both; `design/principles.md`, "Haptics").
- **Wording.** Status titles are sentence case ("Link ready"). Controls are Title Case (**Send as Link**, **Local Network Only**, **Auto-Accept Transfers**). Section headers, footers and descriptions stay sentence case (`design/voice.md`, "Capitalization"). A stored transfer still reads Sending or Receiving, never Uploading or Downloading, and "incoming" is not user-facing (`design/voice.md`, "Terminology").

## History

`Models/TransferHistory.swift`: `TransferRecord` is a SwiftData `@Model` (including `statusRaw`, a string storage for the enum). Stored sends add optional `storedID`, `expiresAt` and `revokedAt`. They are optional so a store written by an older build opens without a migration step.

Caps: a record keeps at most 20 names (`maxNames`) and 200 bookmarks (`maxBookmarks`), and the store keeps at most 300 records (`maxRecords`). `HistoryStore.add()` deletes the oldest records beyond that.

`HistoryStore` is `@MainActor @Observable` and wraps `container.mainContext`. It exposes `add`, `delete`, `clear`, `recordCount`, `record(storedID:)` and `markRevoked`. `delete` and `markRevoked` return early for a record whose `modelContext` is nil, because a record that a prune or a delete removed must not be written to or deleted again (a revoke that finishes after its record is gone is the case). The container is in memory unless `LaunchMode.current` is `.app`. It is injected twice: as `.environment(history)` and as `.modelContainer(history.container)`.

`Views/HistoryView.swift` (the History tab):
- `@Query` sorted newest first.
- Names are drawn through `ReceivedName.shown` (`TransferRecord.shownNames`), so a record an earlier build stored raw still shows the safe form.
- `HistoryView` publishes its Clear dialog flag as the scene focused value `confirmClearHistory` (a `Binding<Bool>`, nil while the list is empty). `AppCommands` reads it with `@FocusedBinding` for **Clear History…**, which is enabled only while History is shown and not empty and opens the same dialog as the toolbar button.
- With no records, "No transfers yet" with **Send** and **Receive**, or "History is off" with **Open Settings** while **Save Transfer History** is off (`openSettings` on macOS, `router.showSettings()` on iOS).
- A row opens `HistoryDetailView` (push by `NavigationLink`; on macOS double-click or Return, via `navigationDestination(item:)`, which resets `opened` when its record is gone). The detail is a grouped `Form` of status, rows, file names and the actions. It renders nothing for a record with no `modelContext` and dismisses, so a prune past 300 while it is open cannot crash it.
- `HistoryActions` (`Models/HistoryActions.swift`) is the state both screens share: which revokes run, `revoke` and `resend`. `RecordDialogs` (in `HistoryView.swift`) holds the Revoke confirmation and failure alert, the Delete confirmation and the Send Again alert for every path: swipe, context menu, the macOS Delete key and the detail button.
- **Delete** is immediate, except for a record whose link can still be revoked (`controller.canRevoke`): then a dialog offers **Revoke Link and Delete**, **Delete and Keep Link** or Cancel. A failed revoke keeps the record. Delete is disabled while that record's revoke runs.
- On macOS the Delete key, the context menu and `record(in:)` use only the rows in `shown`, the selection is cleared when the search changes, and the menu appears for one row only.
- Code hints are `.privacySensitive()`. Relative dates and the link expiry text sit in `TimelineView(.everyMinute)`, so "yesterday" and Expires or Expired stay current.
- **Clear History** behind a confirmation, whose button is **Clear All**. While any record's link can still be revoked, the message adds that such links stay active until they expire. There is no revoke-all.
- `HistoryView` and `HistoryDetailView` hold a `now` that `minuteClock` refreshes once a minute and pass it to `canRevoke(_:now:)`, so Revoke leaves a link that expires while the screen is open.
- `AppRouter.openedRecord` is the record whose detail History pushes, on both platforms. A double-click on the Mac and **Open Transfer** in Shortcuts (`openHistory(record:)`, under the busy rule) set it.
- **Send Again** for send records that carry bookmarks: resolve the bookmarks, then `router.openSend`.

**Both platform probe branches must call `startAccessingSecurityScopedResource()` before `fileExists`.** The sandbox denies `stat` on an unopened scope.

## Support helpers

- `Support/SecurityScopedBookmark.swift`: bookmark create, resolve and resolveIfReachable. `OutputFolderStore` and `HistoryView`'s resend path share it. `resolveIfReachable` starts the security scope before the existence probe, for the reason above. `resolve` returns a stale bookmark's URL with `isStale`: `OutputFolderStore` re-creates the bookmark from it under its scope and falls back to the default folder only when resolution fails, which sets `bookmarkWasReset` and shows a banner in Settings (macOS) for that launch. `resolveIfReachable` still treats a stale bookmark as gone. A failed create or resolve is logged (category `bookmark`) with the error domain and code only, never the path.
- `ReceivedFilesList` holds the scope of the folder it lists in `heldScope`, so a new folder releases the old scope and starts the new one, and `onDisappear` releases only a scope it started.
- `Support/SendStaging.swift` is the scratch folder for what Send is handed as bytes (Photos picks, dropped or pasted images), one folder per item so original names survive. Cleanup is by owner, never by timer: a row's removal, the Send screen going away with no transfer running, and a sweep on the first Send screen of a launch. **Deleting is guarded**: `slotFolder(for:under:)` is the one answer `discard` deletes by. It resolves the root once, takes only the slot name from the caller's path, rebuilds the target from the resolved root, refuses a symlink in the slot's place, and needs a slot plus an item below it, so the root and a bare slot are never deleted. `SendLoading.load` brings a Photos pick in from a `.task(id:)` and discards what it staged when the task is cancelled. `SendReadiness` holds the Send button's rules, and a pick that is still loading blocks it.
- `Support/EngineConstraints.swift`: `minCodeLength`, read from `EngineLimits.minCodeLength` in CrocKit, which reads Go's exported `MinCodeLength` (`crocmobile/crocmobile.go`, also used in `session.go`). The Go side counts bytes and Swift counts characters, so the UI check is the stricter one for non-ASCII codes. It exists for inline feedback before a doomed send or receive start; `isValidCode(_:)` is the one length check every field, link parser and saved-code form calls.
- `Support/Clipboard.swift`: two copy paths.
  - `Clipboard.copy(_)` is a plain copy with no expiry, for **Copy Received Text** and **Copy Text**.
  - `Clipboard.copySecret(_, thisDeviceOnly:)` is for a credential. It leaves the pasteboard after `Clipboard.secretLifetime` (5 minutes).
  - **Copy Code** uses it with Universal Clipboard on, because copying on a Mac and pasting on an iPhone is a core use. **Copy Link** uses it with `thisDeviceOnly: true`, because the link's fragment is the key.
  - iOS: `UIPasteboard.setItems(_:options:)` with `.expirationDate`, plus `.localOnly` for the link. `Clipboard.secretOptions(thisDeviceOnly:now:)` builds the options, so a unit test can read them.
  - macOS has no expiry. The copy carries `org.nspasteboard.ConcealedType` (clipboard managers that follow nspasteboard.org skip it) and uses `.currentHostOnly` for the link.
  - The macOS clear runs in the app, after the lifetime, only while the app is running, and only if `changeCount` has not moved, so a later copy is never wiped.
  - Not verified on hardware: the expiry on a device, the link staying off Universal Clipboard, a clipboard manager honoring the marker, and whether the code also expires on the other device. `device-test-checklist.md`, "Clipboard", lists the checks. `ClipboardTests` cover the options and the macOS clear against a private `NSPasteboard`.

## Conflict scan

The scan is asynchronous. `.incoming` is shown immediately with `conflicts: []`. `Self.scanConflicts` runs in `Task.detached` and stats off the main actor. The write-back happens only when the result is non-empty, only `if case .incoming`, and only if `Run.token` still matches the value captured at `.fileList`.

The shape check alone is not enough: a scan can outlive a whole fast transfer and land on the next one's `.incoming`. A synchronous scan froze the accept UI on large file lists.

With conflicts, the sheet offers Decline, Replace and Keep Both (Keep Both prominent) and a banner. Without conflicts, or while the scan runs, it offers a single Accept, which means Keep Both. A zipped folder arrives as one `.zip` name, so the scan sees none of its members (#225).

A file send's bookmark capture (`HistoryDraft.bookmarks(for:)`, up to 200 `bookmarkData` calls) runs off the main actor the same way and writes back into `pendingRecord`, under the same `Run.token` check, so a capture that outlives its send cannot land on the next transfer's record. If a transfer terminates first, `pendingRecord` is already nil and the record carries no bookmarks, so **Send Again** hides instead of breaking. `SecurityScopedBookmark.create` is `nonisolated` for this.

## Receive links

- `Models/TransferLink.swift` is the one parser. `TransferLink.parse(_:)` takes a bare code, `crocapp://receive?code=`, `https://crocapp.dev/r/#<code>` or `https://getcroc.com/?code=`, and yields `.code`.
- It also parses a stored-transfer link `https://<host>/s/<id>#v1.<key>` into `.stored(URL)`. `http` is accepted only for `localhost`, `127.0.0.1` and `::1`. `ReceiveView` takes it (see "Stored transfers").
- `TransferLink.webURL(forCode:)` builds the `crocapp.dev/r/` link.
- `AppRouter.open(_:)` applies the link to `receiveDraft` and calls `openReceive()` unless `isBusy`. Mid-transfer the link is kept in the draft and the user is not moved.
- `ReceiveDraft.apply` fills `code`, or `storedLink` for a stored-transfer link. Opening a link never starts a receive: the user taps **Receive**.
- Entry points all go through `TransferLink.parse` and then `router.open`: the QR scan sheet (iOS), the **Paste** button, typed or pasted text containing `://` in the code field, `.onOpenURL` in `CrocAppApp` (iOS universal links and `crocapp://`), and `AppDelegate.application(_:open:)` on macOS (file URLs still go to Send). On macOS a link reaches both the delegate and `.onOpenURL` (measured), which is harmless because `router.open` is idempotent.
- The `crocapp` scheme is in the iOS, macOS and Direct Info plists in `app/Config/`.
- Universal links for `crocapp.dev/r/*` need the Associated Domains entitlement (all three app entitlements files carry it) and `web/landing/.well-known/apple-app-site-association`, which lists both app IDs.
- `TransferStatusView.waitingView` encodes the QR as `TransferLink.webURL(forCode:)` and adds a **Share Link** button.
- `browserReceiveNote` adds a caption when the active relay is custom or local-only, because croc's browser client knows only the default relays.

## Platform layer, iOS

- `Platform/BackgroundCoordinator.swift` is a cross-platform class with `#if os(iOS)` bodies (no-ops on macOS). It wraps a transfer in a `BGContinuedProcessingTask` and holds `isIdleTimerDisabled`.
- Controller hooks: `transferStarted` in `run()`, `progressChanged` inside the accepted `.progress` path only (the `.incoming` guard stays untouched), and `transferEnded` at `.done`, `.failed` and the startup `catch`. `transferEnded` is idempotent.
- Expiration calls `cancel(reason: .backgroundExpired)`, which produces the dedicated "iOS paused the transfer…" copy. A generation token rejects stale late task launches.
- `Platform/LocalNetworkChecker.swift` is cross-platform. It is a Bonjour self-probe on `_crocapp._tcp`: seeing its own service means access is granted, and a browser stuck in `.waiting` means denied.
- `checkIfNeeded()` probes once per process, triggered by `ContentView.onChange(controller.isActive)`.
- `recheckIfDenied()` re-probes from `.denied` when `scenePhase` goes `.active` (for example after the user granted access in Settings). It never re-probes `.granted` or unresolved states and never stacks a second in-flight probe.
- Denial shows a banner plus **Open Settings** in `TransferStatusView`. Denial only resolves at the 8 s timeout, because a first `.waiting` may just be the pending permission prompt.
- Testing a macOS denial is awkward: enforcement reportedly engages only for builds resident in `/Applications` (one developer-forum thread, not Apple documentation; inferred), so a Debug build launched from DerivedData can read as falsely granted. Copy the app to `/Applications` before trying to reproduce a denial.
- `Models/ShareInbox.swift` and `Views/StagedFilesSheet.swift` pick up batches staged by the share extension from the App Group (`ShareInbox/batch-<UUID>/`, each with its own `manifest.json`, written after its files). The group ID, directory and file names, the `Manifest` type, the batch-name generator and validator, and the extension's staging rules (`stagedName`, `batchText`, `copyFits`, which tests cannot reach in the extension target) are `app/Shared/ShareHandoff.swift`, compiled with `app/Shared/ReceivedName.swift` into `CrocApp`, `CrocApp Direct` and `CrocShare` (a synchronized folder group listed on all three targets), so the writer and the reader cannot drift. The group ID (team-prefixed on macOS, and different for Direct) is also in the entitlements files, which cannot import Swift. `ShareInbox` treats the inbox as untrusted data: it lists only directories named `batch-` and a UUID (a symlink is not one), a manifest it cannot decode is logged (category `share`) and treated as absent, and a file name `ReceivedName.isUnsafe` rejects is dropped. Several batches can wait: `refresh` offers the oldest with a manifest (`batch`). `ContentView` offers the next on **Discard** and whenever `controller.isActive` turns false, and on each foreground as before. It also logs any file removal that fails, and stays best effort. `ShareInbox.refresh(in:)` takes the inbox directory so `ShareInboxTests` can use a temp directory instead of the App Group container. Shared text and web links travel in `Manifest.text` (set only when `files` is empty, so files win in a mixed share; capped at `ShareHandoff.maxTextBytes`, 1 MiB, the same cap as `SendServicesProvider`; never logged). `ShareStager.loadText` reads a non-file `public.url` as its absolute string or `public.plain-text` as is. `ShareInbox.text` exposes it, and `ContentView.offerStagedFiles` discards the batch and calls `AppRouter.openSend(text:)` with no sheet, so the Send screen is where the user presses Send.
- The batch's life: **Send** in `StagedFilesSheet` is disabled while a transfer runs (a Shortcut, the menu bar or a drop can start one while the sheet is open), and the share stays staged. Send starts the transfer first and consumes the batch (`consume` deletes its manifest) only when the start succeeds. **Discard** deletes the batch at once. A sent batch is deleted when its transfer reaches `.done` or `.stored` (`sendFinished`, from `ContentView`'s phase observer), and kept after `.failed`, because Try Again reuses its file URLs; **Send Again** in History then has no files for that entry. The purge at idle deletes only a batch that never got its manifest (after `stagingGrace`, as the extension may still be copying) and any directory with another name.
- The whole `scenePhase` refresh is gated on `!controller.isActive`. An ungated refresh once purged a live batch mid-send.
- `app/CrocShare/` is a multiplatform app extension (iOS and macOS). The pbxproj entry is hand-built; `SDKROOT = auto` with per-sdk `INFOPLIST_FILE` and `CODE_SIGN_ENTITLEMENTS`. `CrocApp` embeds it on both platforms. `CrocShare Direct` is a second, macOS-only target over the same sources with its own bundle ID and entitlements. `ShareViewController` is an `NSViewController` on macOS and a `UIViewController` on iOS. On macOS a successful stage opens the host app at once and closes the extension (no confirm screen); only a failure shows a **Done** button. `StagedFilesSheet` computes row sizes once, off the main thread (`FileSize` in `app/Shared/`, which also feeds the extension's free-space check). `ContentView` also refreshes the inbox on `NSApplication.didBecomeActiveNotification` on macOS, because `scenePhase` stays `.active` while the window is open.
- File-copy staging never reads payload into memory, because of the roughly 120 MB extension memory cap (iOS: inside the `loadFileRepresentation` handler; macOS: `copyItem` of the Finder URL). It never wipes existing batches.
- The Info plists live in `app/Config/`, outside the synced folders, to avoid a generated-plist collision. The app's `INFOPLIST_FILE` is sdk-scoped.
- **One scene on iPad.** `app/Config/CrocApp-Info.plist` sets `UIApplicationSceneManifest` with `UIApplicationSupportsMultipleScenes` NO. The generated manifest (`INFOPLIST_KEY_UIApplicationSceneManifest_Generation`) is documented as "an entry suitable for a multi-window application" and builds `UIApplicationSupportsMultipleScenes = YES`, so the target leaves that setting out. Measured on an iPad simulator (iOS 27.0 runtime): `UIApplication.shared.supportsMultipleScenes` read true with the manifest YES and false with NO, and the app launches and renders either way. `WindowGroup` stays the iOS scene, because `Window` is not an iOS scene (Apple lists macOS and visionOS only).
- Files-app visibility comes from `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. **The two do not behave the same way** as sdk-scoped `INFOPLIST_KEY_*` settings in the pbxproj, so only `LSSupportsOpeningDocumentsInPlace` is declared there.
- `LSSupportsOpeningDocumentsInPlace` is injected into the built `Info.plist` from the build setting alone. `UIFileSharingEnabled` is not, so `app/Config/CrocApp-Info.plist` declares it literally.
- Measured with Xcode: delete the two plist lines and `plutil -p` on the built `CrocApp.app/Info.plist` shows `UIFileSharingEnabled` gone, while `LSSupportsOpeningDocumentsInPlace` and `NSLocalNetworkUsageDescription` survive. `xcodebuild -showBuildSettings` still resolved `INFOPLIST_KEY_UIFileSharingEnabled = YES`, which is why that setting was removed.
- So the plist declaration is load-bearing and the pbxproj key is inert for that one setting. Do not deduplicate by deleting the plist lines: that silently removes the app from the Files app.
- **Open in Files** on the receive-done screen uses the `shareddocuments://` scheme, which is a community convention with no public API. The button is shown only when the receive folder is the app's own default folder, because the scheme resolves only paths inside the app container.

## Platform layer, macOS

- `Models/AppRouter.swift` is an `@Observable` singleton (`shared`). `selection` is the one navigation state ("Layout and navigation").
- `sendDraft` and `receiveDraft` hold what a drop, a share, a Services selection or a link staged. `SendView` and `ReceiveView` edit them directly, so there is no consume-and-clear step. `openSend(text:)` appends to any typed text and switches to text mode. Both only stage; nothing sends until the user taps Send.
- `isBusy` reads `controller.isActive` through a weak controller reference that `CrocAppApp.init` attaches with `attach(controller:)`, so a dock drop mid-transfer stages without navigating.
- It is a singleton because `AppDelegate` and `Commands` sit outside the environment graph.
- Three drop entry points, one guard policy:
  - The window drop (`ContentView`, macOS only) refuses while active and filters `\.isFileURL`.
  - The `SendView` list drop filters too.
  - The dock drop (`Platform/AppDelegate.swift`, `application(_:open:)`) always stages and navigates only when idle.
- The dock drop works because `Config/CrocApp-macOS-Info.plist` declares `public.item` document types with the Viewer role and rank None.
- Side effect: the app is listed in Finder's "Open With" for everything. `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace[sdk=macosx*]=YES` is required, or Xcode auto-injects an invalid `NO`.
- `Views/SettingsView.swift` has a **General** tab (output-folder **Change…** and **Reset**, **Show in Finder**, the menu bar section, the power sections, About) and an **Advanced** tab.
- `Views/AppCommands.swift` provides the File, Transfer and Help commands ("Menu bar and Shortcuts").
- **One main window.** `CrocAppApp.mainScene` is a single-instance `Window("CrocApp", id: "main")` with `.defaultSize(880×700)`, content `minWidth 720` and `minHeight 560` (room for the sidebar, "Windows and keyboard focus"). A frame saved by an earlier build (`NSWindow Frame main` in the app's defaults) wins over the default size, and the minimum clamps it. One transfer runs at a time, so a second window could only mirror the first with a selection of its own; `AppRouter.shared` is the one selection.
- Apple's `Window` quits the app when it closes. `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns false, so a running transfer and the menu-bar item outlive the window. Measured on macOS 27: with the delegate method missing, `performClose` on the window ended the process; with it, the process stayed and the window was `isVisible == false`.
- The window comes back from a reopen (`open -a`, the event a Dock click sends; the Dock click itself was not tried), from a link, and from **Open CrocApp** in the menu-bar window. `openWindow(id:)` opens a closed `Window` scene and orders an open one to the front (Apple's `OpenWindowAction`), so `MenuBarQuickSendView.openMainWindow` is `NSApp.activate()` plus `openWindow(id:)`. Measured with the window closed: `open -a` and a link each made it visible again, and `openWindow(id:)` called from the menu-bar scene did too. With it open there was still one window. The menu-bar button itself was not clicked.
- The old `.handlesExternalEvents(preferring: [], allowing: ["*"])` is gone, because a `Window` is never duplicated by an opened URL.
- `CrocApp Direct` only (`#if DIRECT`, `app/CrocAppDirect/AppUpdater.swift`): a **Check for Updates…** item in the app menu right after **About CrocApp**, backed by Sparkle's `SPUStandardUpdaterController`, and **Check for Updates Automatically** in the General tab (`UpdateSettingsSection`), which reads and writes `SPUUpdater.automaticallyChecksForUpdates` (Sparkle persists it). The App Store target has neither.
- The default output folder is `~/Downloads/CrocApp`. It needs the `files.downloads.read-write` entitlement. The folder is auto-created in `defaultFolder`, and `defaultDisplayName` supplies the UI label. The receive-done screen offers **Show in Finder** via `NSWorkspace.activateFileViewerSelecting`.
- Build and release scripts are described in `docs/RELEASING.md`.

## Onboarding and store compliance

- `OnboardingView` is a sheet from `ContentView.task`. It is shown when `!onboardingSeen` in a live launch (`LaunchMode.current.isLive`), or when a harness run asks for it with `--screen onboarding` (`AutoVerify.forcesOnboarding`). `onboarding.seen` is written in `onDismiss`.
- `OnboardingView` is a `ScrollView` (`.scrollBounceBehavior(.basedOnSize)`), top-aligned: a centered anchor opened it scrolled at accessibility sizes and hid the welcome. Large text scrolls instead of clipping. At accessibility sizes each bullet's glyph (28 pt through `@ScaledMetric`) sits above its text; `HowItWorksView` does the same through `ParagraphLabelStyle`. Beside the text the glyph frame is `minWidth` 1.25 times the glyph, so every bullet's text starts at one x.
- The staged-files sheet yields to onboarding (`&& !showOnboarding`) and is offered again when onboarding dismisses.
- Onboarding also primes the two system permission prompts its copy names. On iOS, `onDismiss` awaits `CameraPermission.requestIfNeeded()` and then calls `localNetwork.checkIfNeeded()`. They run in sequence so the user never sees two system prompts stacked. Neither is requested during an `AutoVerify` harness run.
- `Platform/CameraPermission.swift` (iOS only) wraps `AVCaptureDevice.authorizationStatus` and `requestAccess(for: .video)`.
- `QRScannerSheet` resolves its own authorization first, as a gate separate from `DataScannerViewController.isSupported`, and renders distinct copy for all four `AVAuthorizationStatus` cases. `.authorized` shows the scanner. `.notDetermined` requests access, then re-reads the status. `.denied` offers **Open Settings**. `.restricted` does not, because Settings cannot fix a restriction.
- `PrivacyInfo.xcprivacy` sits in both synced target folders. The app declares UserDefaults CA92.1, FileTimestamp C617.1 and 3B52.1, and SystemBootTime 35F9.1 (the Go engine's `stat` family and `mach_absolute_time` imports). The extension declares an empty accessed-API list. Both declare no tracking and no collection.
- `ITSAppUsesNonExemptEncryption` is set in `CrocApp-Info.plist` (iOS) and `CrocApp-macOS-Info.plist`, the two plists App Store builds use. The value, the reason and the open decisions are in `docs/RELEASING.md`, "Export compliance".
- Two `.glassEffect()` call sites exist: the code card in `CodePhraseDisplay`, which `waitingView` uses, and the macOS-only **Drop to Send** full-window overlay in `ContentView` (`design/components.md`, "DropZone").

## SwiftUI and Xcode API facts

Checked against the iOS and macOS 26 SDKs:

- `fileImporter` without `allowsMultipleSelection:` gives the completion a `Result<URL, Error>`. With it, at any value, the completion gets a `Result<[URL], Error>`. Code that mixes the two does not compile.
- `PasteButton`'s closure is `nonisolated`. Hop to the main actor before touching `@State`.
- The `.qr` symbology needs `import Vision` alongside VisionKit.
- `DataScannerViewController.isSupported` is `false` on the simulator, so the sheet shows a fallback. `startScanning` failures surface through `onStartFailure` as "Camera unavailable".
- QR generation: `CIFilter.qrCodeGenerator` with a static shared `CIContext`. Cache the `CGImage` in `@State` keyed by `.task(id: content)`, and render it with `Image(decorative:scale:).interpolation(.none)`.
- Using a type across files in the same module still needs a per-file `import CrocKit`.
- The camera key is a literal in `Config/CrocApp-Info.plist`, which only the iOS SDKs use, so it covers Debug and Release at once. The macOS builds (`CrocApp` and `CrocApp Direct`) carry none: the scanner is `#if os(iOS)`, and Apple requires the key only for an app that uses camera APIs. Do not move it back to an `INFOPLIST_KEY_` setting: scoped to iOS it still lands in the macOS `Info.plist` as an empty string.
- `app/CrocApp/AppIcon.icon` is an Icon Composer bundle. Synced-folder auto-include picks it up as long as its name matches `ASSETCATALOG_COMPILER_APPICON_NAME`. It compiles for both platforms with no pbxproj edit.

## AutoVerify harness

Launch arguments drive the real controller, not the engine directly, so the verified path is the one users take.

`AutoVerify.swift`'s header comment lists every flag. Keep it complete when adding one. Behaviours the header does not spell out:

- `--auto-send PATH --code CODE` needs both flags. Without `--code`, nothing happens.
- On macOS the `--auto-send` source must be container-resident (sandbox).
- The `.confirmSend` auto-answer happens in every harness mode, with or without `--ask`.
- `--relay ADDR` sets only the relay, so the LAN route stays on. `--disable-local` sets `settings.disableLocal` (in memory, so Advanced shows it on), to kill the LAN race: the custom-relay scenario of `verify-app-mac.sh` and `capture-screenshots.sh` pass it. It has no value, so on macOS it goes last (`scripts/verify-app-mac.sh`, `run_app`).
- `--when-exists` is the policy `AutoVerify` answers the incoming sheet with. The setting itself stays Keep Both, so the late answer must reach croc.
- The screenshot flags (`--screen`, `--stage`, `--seed-history`, `--hold`) are documented in `screenshots.md`.

`AutoVerify`'s bodies are `#if DEBUG`. In Release, `isHarnessRun` is a hardcoded `false` and `runIfRequested` is a no-op, so the harness cannot run in a store build. The type still exists in Release because `LaunchMode.swift` and `ContentView.swift` call it unconditionally. The verify scripts build Debug.

`isHarnessRun` is true for any `--auto-*` mode or `--screen`. Settings overrides apply in any harness run. `LaunchMode.makeSettings()` builds `AppSettings` on `MemorySettingsStorage` and `MemorySecretStore` for it ("Settings and trust"), so the overrides start from the defaults and real `UserDefaults` and the Keychain are never touched.

Result files, all written to the container's Documents folder (hardcoded, independent of `OutputFolderStore.defaultFolder`):

| File | Content |
|---|---|
| `verify-result.txt` | `ok success=<bool>`, or `error <title>. <detail>` for a failure (`TransferFailure.text`; `scripts/verify-app-mac.sh` matches the expired-link title) |
| `verify-code-ready.txt` | `ready`, written once when the phase first reaches `.waiting` (a send has its code); both verify scripts wait for it |
| `verify-code.txt` | the generated or custom code |
| `verify-history.txt` | `records=N`, written when the transfer is done or failed (`scripts/verify-app-mac.sh` reads it) |
| `verify-phase.txt` | the current phase label; `transferring percent=N` reads `controller.progress`, and `transferring bundling` replaces it during a batch of small files |
| `verify-ready.txt` | written once a `--screen` request has settled |

The result contract is shared by `scripts/verify-app-sim.sh` and `scripts/verify-app-mac.sh`.

Launch gotchas, both macOS:

- Once `CFBundleDocumentTypes` exists, bare adjacent argv tokens are document-open candidates and AppKit skips creating the default window. Use flag-style arguments only.
- Scripted launches need `-ApplePersistenceIgnoreState YES` or they hang in window restoration.
- A plain launch can come up with no window when the bundle ID carries leftover restoration state (#222). Test window behavior on a fresh bundle ID or pass the flag.

On the CLI side of a verify run, a receiving `croc` needs `CROC_SECRET=` in the environment instead of a positional code. croc refuses custom positional codes in non-classic mode for receive as well as send.
