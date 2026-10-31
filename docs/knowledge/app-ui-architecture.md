# App UI architecture

How the SwiftUI app is wired and which of its behaviours are load-bearing. Read the relevant section before editing a view that observes `TransferController`.

Engine contract: `crocmobile-bridge.md`. Open defects: `docs/known-issues.md`.

## Structure

```
CrocAppApp owns @State TransferController + AppSettings + OutputFolderStore
  + HistoryStore + LocalNetworkChecker + AppRouter.shared (+ MenuBarQuickSend on macOS)
  → .environment on the one main scene's content (CrocAppApp.mainContent)
  (macOS Settings scene gets only outputFolder + settings, no router/controller/localNetwork)
ContentView → by horizontal size class (see "Layout by width"):
  compact: HomeView (its NavigationStack, path: $router.path, value-based links)
  regular: RegularLayout (NavigationSplitView: sidebar List, one NavigationStack per row, path: $router.detailPath)
  → SendView | ReceiveView | SettingsScreen | HistoryView | HowItWorksView
  each transfer screen: controller.isActive and a matching direction ? TransferStatusView() : input form
TransferStatusView renders every non-idle phase; IncomingRequestView = accept gate
Shared pieces (Views/): ButtonVariants, DropZone, CodePhraseDisplay, DirectionHeader, ForwardProgressBar, PhoneHaptics; Support/Inflected.swift
QRCodeView (cross-platform gen) / QRScannerView.swift (whole file #if os(iOS), VisionKit)
```

Localization: the app ships in English only, but every user-facing string reaches a String Catalog. See "Localization" below.

Construction order in `CrocAppApp.init` matters: `AppSettings` (on in-memory storage and secrets for a harness run), then the `HistoryStore` container (in memory for a harness run), then `StoredTransferVault`, then `TransferController(settings:vault:)`, then `controller.history = history`.

## Layout by width

`ContentView` reads `@Environment(\.horizontalSizeClass)` and shows `HomeView` for `.compact` and `RegularLayout` for anything else. It never asks the device. The size class changes live, so a window resize or an iPad Split View change swaps the layout. SwiftUI reports `.regular` on macOS (measured on macOS 27), so every Mac window gets the sidebar. The design is `design/principles.md`, "Platform adaptation".

**One path, two readings.** `AppRouter.path` is the only navigation state. `HomeView` hands it to its `NavigationStack`. In regular width its first element is the sidebar row and the rest are the screens pushed in that row's detail:

| Member | Reads |
| --- | --- |
| `selection` | the row the path starts at; **Send** when the path is empty or starts at a route that is no row (How It Works, Advanced settings, **Settings** on the Mac) |
| `detailPath` | the rest of the path, or all of it when the path starts at no row |
| setting `selection` | `path = [row.route]`, which pops the detail |

Every entry point sets `path` and so lands in either layout: `openSend(with:)`, `openSend(text:)`, `openReceive()`, `open(_:)`, the staged-files sheet, the Mac window drop, the Dock drop, App Intents, `crocapp://` links and `AutoVerify`. The busy rule is unchanged: a drop, a link or staged text mid-transfer is kept and moves nobody. The sidebar rows and the menu bar are user actions, so they navigate when a transfer runs. Nothing but the user changes the selection: a request that arrives while History is open leaves History open.

**Files.**
- `Views/RegularLayout.swift`: `NavigationSplitView`, the sidebar `List(selection:)`, `DetailStack` (one `NavigationStack` per row, rebuilt with `.id(selection)`, with the **How It Works** toolbar button) and `Route.destination`, the screen a route pushes. `HomeView` keeps its own copy of that switch, because the views it hosts are owned elsewhere.
- `Views/SidebarRow.swift`: the row and its spoken label.
- `Models/SidebarRowState.swift`: the row's state, derived from the phase and progress. It also holds three `TransferController.Phase` questions: `needsAnswer`, `canCancel` and `shownCode`.

**The sidebar state.** Only the row of the active transfer's direction (`SidebarItem(direction:)`) has one: Connecting, Waiting, a **Review** badge for `.incoming` and `.confirmSend`, or the percent of the whole transfer (the direction word while the total is unknown). A finished or failed transfer leaves every row at rest. The row speaks one label ("Send, 42 percent"), and `RegularLayout` posts an announcement when the state's kind changes, never on a progress tick, because it watches the kind and the percent is not part of it. The trailing view is hidden from VoiceOver and the label sits on the `Label`, so the row stays the system's one selectable element (with `.accessibilityElement(children: .ignore)` an accessibility press from System Events did not select the row on macOS; VoiceOver itself was not run).

**The banner.** `DetailScreen`, applied to the root screen and every pushed screen of a detail, shows the `StatusBanner` for a pending request (`phase.needsAnswer`) unless the gate is on screen: the row of the transfer's direction is selected and nothing is pushed over it. **Review** selects that row. A both-sides confirm on a send uses the strings of the confirm screen, because the Home banner has none for it.

**The cap.** Send, Receive and How It Works cap their own column (`LayoutCap`) and the detail leaves them alone. The detail caps the list and form screens (`Route.isFullWidthList`: History, Settings, Advanced settings) with `safeAreaPadding(.horizontal)` of half the width above the cap, measured with `onGeometryChange`. On iPad that keeps the grouped background full width and the margin is the page. `contentMargins` on a list put it off-centre on iPad (measured), and on macOS it did nothing. On the Mac the list is a column of its own, so the scroll edge under the toolbar is as wide as the column. Do not add a `safeAreaPadding` or a `contentMargins` to a screen that caps itself.

**The Mac window.** The sidebar's default width is 144, which truncates "Receive" beside its Review badge, so the sidebar column takes `min 200, ideal 240, max 320` on macOS ("Windows and keyboard focus", below). The iPad sidebar is the system's.

**Limits.** A screen's `@State` (staged files, typed text) is not kept when the selection changes or when the layout flips, and a pushed screen is not kept when the layout flips (`known-issues.md`).

## TransferController

`@MainActor @Observable`. It is the only code that uses `CrocEngine`. Many other files `import CrocKit` for its types, but only the controller starts and answers transfers.

It reaches the engine through the `TransferEngine` protocol. `init(settings:vault:engine:)` defaults to `CrocEngine()`, so the app passes none. `app/CrocAppTests/TransferControllerTests.swift` passes `FakeTransferEngine`, which emits events one at a time and records every call, and checks the rules below against it. `TransferFailureTests` and `EngineStartTests` check the failure mapping and the engine options with no engine at all. A change to one of these rules needs its test updated in the same change.

`Phase`: `idle` → `starting` → `waiting(code)` / `connecting` → `confirmSend` | `incoming(FileList, conflicts, blocked)` → `transferring` → `done(Summary, receivedText?)` | `stored(StoredReceipt)` | `failed(TransferFailure)`. Views switch on it. `reset()` has no guard, but the UI offers it only from a terminal phase.

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
- **Progress is not part of the phase.** `.transferring` has no payload. Each accepted tick sets `progress` and `speedBytesPerSec`, and only the first one sets the phase. `Phase` is `Equatable`, so whatever reads only the phase (the haptics in `ContentView`, `HomeView`, `AppRouter.isBusy`) does not redraw at the tick rate.

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
- The auto-accept block cancels through `cancelEngineTransfer()`, which leaves `cancelRequested` unset. `TransferFailure.blockedAutoAccept` has `endedByUser` false, so the failure haptic plays: the user tapped nothing.
- Precedence when several conditions apply, highest first: code `engineStuck`, `blockedAutoAccept`, `backgroundExpired`, the auto-accept-versus-remote-`--ask` case, then the user's cancel and decline, then the code. `TransferFailure.Situation` carries the controller's flags, so `handle(.failed)` and the `catch` in `run()` share the one mapping, and a thrown expiry keeps the resume hint.
- `engineStuck` outranks a Cancel tap too. Only a relaunch frees the engine, and every later start fails the same way. It offers no **Try Again**, and `endedByUser` is false.
- `joinedEarly` (a receiver that joined before the sender) says to start the send first. There is no automatic retry and no **Try Again**, because the sender has failed by then too (`../known-issues.md`, "Accepted"), and a generated code changes when it starts again.
- A reset and a new start (**Try Again**) can come before the last event loop ends. The loop releases its security scopes only while `transferGeneration` still matches, so it cannot release the next transfer's.
- `blockedAutoAccept` is checked in `.done` as well as `.failed` (`TransferFailure.blockedAutoAccept`). The block's cancel is fire-and-forget, so a small transfer can finish before the cancellation reaches the engine. Both paths record `.failed`, because the history schema has no blocked case and "Cancelled" reads as a user action.
- `TransferStatusView` shows a "taking longer than usual" hint after 25 s (`slowPhaseThreshold`) in `.starting` or `.connecting`. A `.task(id: isInEarlyPhase)` resets the timer whenever that flips. The clock survives the `.starting` to `.connecting` handoff, because the user sees one stall.

### Code `refused` under auto-accept is not a peer decline

croc forces the receiver prompt whenever the remote sender ran `--ask` (upstream `croc.go`, not re-read here). Engine auto-accept has already closed the prompt pipe, so `GetInput` hits EOF and croc reports its local `refused files`.

`autoAcceptActive && !cancelRequested && failure.code == .refused` identifies this case. The check runs after the `blockedAutoAccept` and `backgroundExpired` branches. `respond()` is never called on the auto-accept path, so `declineRequested` cannot be set.

Under auto-accept the pipe is not empty. `crocmobile` queues a batch of `n` answers for croc's other prompts (empty folder, unzip member) and then closes it (`crocmobile-bridge.md`, "Engine behavior invariants"). The forced remote-`--ask` prompt reads the first `n` answers and ends as `refused` under either file policy. The batch is `n` even for Replace for that reason. A manual accept behaves the same, because a croc v11 reconnect re-runs the accept prompt (`scripts/verify-interop.sh` checks it).

### Options, security scope, progress

- `EngineStart(_:settings:disableLocal:)` builds the engine call and its `EngineOptions` or `StoredSendOptions` from the request and `AppSettings`. Receive also passes `whenFileExists` (`AppSettings.whenFileExists`, key `settings.whenFileExists`, default Keep Both; an unknown stored value reads as Keep Both).
- Receive passes `autoAccept && !bothSidesConfirm`, so confirmation wins. Engine auto-accept closes the prompt pipe, which croc reads as a decline.
- `start(_:)` opens security scope on send URLs and on the user-picked output folder (`SecurityScopes`), and releases it at stream end or on reset. `startAccessingSecurityScopedResource() == false` is fine for non-scoped drops. Keep the call anyway.
- Speed (`TransferSpeed`) is an exponential moving average (0.25 new, 0.75 old) over `bytesFinished + fileSent` deltas, sampled at most every 0.2 s. Overall progress is `(bytesFinished + fileSent) / totalSize`. `fileSent` is per current file.
- `activeRelay` is captured at start, for the trust badge.
- `harnessDisableLocal`, `harnessShownRelay` and `harnessShownLinkOrigin` are harness-only, not user settings, and exist only in Debug builds.

### History capture

- `start(_:)` sets a `HistoryDraft` from the request. Send: names capped at 20, bookmarks all-or-nothing up to 200, built while the security scope is held. Receive: `offer(_:)` fills it from `.fileList`. `codeHint` is backfilled at `.codeReady` for generated codes.
- `finishRecord(status:summary:)` runs at `.done`, `.failed` and the startup `catch`. It sets `pendingRecord = nil` first, so a double terminal event is harmless, and returns right after that while **Save Transfer History** is off. It must run while `receivedText` is still set, so `isText` backfills (`HistoryDraft.record(status:summary:receivedText:)`).
- A receive's names come from the sender and `ReceivedName.isUnsafe` runs only after `offer(_:)`, so the draft stores them in their shown form (`ReceivedName.shown`: every scalar `isSpoofingScalar` flags is written as `\u{XXXX}`), never raw. `FileRow` and the progress line draw the same form. `HistoryDraftTests` and `ReceivedNameTests` pin it.
- Status mapping: `done` becomes completed or failed per the summary. `failed` plus `cancelRequested` becomes cancelled. `failed` plus `declineRequested` becomes declined.

## Settings and trust

`Models/AppSettings.swift` is `@MainActor @Observable`. `AppSettings(storage:secrets:)` takes two injected stores:

| Store | Protocol | App | Harness run and tests |
| --- | --- | --- | --- |
| Values | `SettingsStorage` (`object(forKey:)`, `set(_:forKey:)`), `Support/SettingsStorage.swift` | `UserDefaults.standard`, which already conforms | `MemorySettingsStorage` |
| Secrets | `SecretStore`, `Support/KeychainStore.swift` | `KeychainStore` | `MemorySecretStore` (app), `FakeSecretStore` (tests) |

Each setting has its own key, starting with `settings.`, and a `didSet` writes just that key. There is no `Codable` blob: a synthesized `Codable` struct resets every field to its default when a build adds one. A key that is absent, or holds another type, reads as the setting's default, and the keys are part of the contract with saved preferences, so never rename one. `AppSettingsPersistenceTests` pins them.

A harness run is decided in `CrocAppApp.init` (`AutoVerify.isHarnessRun`), which builds `AppSettings` on `MemorySettingsStorage` and `MemorySecretStore`. Its overrides start from the defaults and reach neither `UserDefaults` nor the Keychain, so a manual run's settings cannot bleed into a harness run, and a harness run cannot blank a real stored password. Every test suite does the same: a `UserDefaults(suiteName:)` writes a `CrocAppTests.*.plist` into the sandbox container's `Library/Preferences` that `removePersistentDomain` does not delete.

`relayPassword` is the one setting that is not in `storage`. It lives in `secrets` (the Keychain). Its `didSet` goes through `persistRelayPassword()`, which deletes the item instead of storing a blank.

A failed settings write to `secrets` is never silent. This covers the relay password and the proxies only: a failed receipt write in `StoredTransferVault` is logged and nothing more ("Stored transfers"). `persistRelayPassword()` and `persistProxy` put the setting in `unsavedSecrets` (`.relayPassword`, `.socks5Proxy`, `.httpProxy`) when the store's `set` or `delete` returns false, and take it out on that setting's next successful write. The property keeps the edit for this launch, but the next launch reads what the store still holds. While a setting is in the set, its field shows an error `StatusBanner` (`AppSettings.secretNotSavedTitle` and `secretNotSavedDetail`), which never names the value: the relay **Password** in `PowerSettingsSections`, the proxies through `AdvancedRow` in `AdvancedSettingsView`. `FakeSecretStore.failWrites` fails both `set` and `delete` for the tests.

**Not behind the injected storage:** `OutputFolderStore` (`UserDefaults.standard`, key `outputFolderBookmark`) and `@AppStorage("onboarding.seen")` in `ContentView`. Neither a unit test nor a verify script writes them: `OutputFolderStore` writes only from **Change…** and **Reset**, and the first-run flag only when the onboarding sheet is dismissed (a `--screen onboarding` capture run, by hand).

**Save Transfer History** (`saveTransferHistory`, key `settings.saveTransferHistory`, default on). `TransferController.finishRecord` returns before it builds the record while the setting is off, so a finished, failed, cancelled or declined transfer leaves nothing in History. Records already there stay until the user deletes them. A **Send as Link** upload made while it is off has no History row, so it cannot be revoked from History: the receipt stays in the Keychain vault until it expires. `HistoryView` shows "History is off" with **Open Settings** instead of the empty list while the setting is off and no records exist (`design/components.md`, "HistoryRow").

**Show History in Spotlight** (`indexHistoryInSpotlight`, key `settings.indexHistoryInSpotlight`, default **off**). Off by default because the Spotlight index puts file names outside the app, so it needs its own visible switch next to Save Transfer History (`docs/THREAT-MODEL.md`, "Privacy"). It also needs Save Transfer History on: `GeneralSettingsSections` disables the row while that is off, and `HistoryEntityStore` indexes only while both are on. Turning either off empties the index; turning Spotlight on (with history on) indexes every record. It does not gate Shortcuts, which follows Save Transfer History alone.

**Haptics** (`haptics`, key `settings.haptics`, default on, iPhone only). `phoneHaptic` (`Views/PhoneHaptics.swift`) is the one place that checks it, together with the iPhone idiom, so every call site honors it. The modifier reads `AppSettings` from the environment on iOS, so a view that uses `phoneHaptic` needs it there (the WindowGroup provides it). `Views/GeneralSettingsSections.swift` holds the two rows, shared by the macOS General tab and the iOS `SettingsScreen`; the Haptics row only exists on iPhone.

Relay strings use `""` for "croc default" (the `TextField` prompt reads "Public relay pool") and reach the engine as stored, password included. Go resolves them (`crocmobile/relay.go`): blank means croc's default, and with no custom relay and Local Network Only off, the relay comes from upstream's public pool by code.

`relayKind` is display-only: `publicDefault`, `custom`, `localOnly` or `directToSender`. It is `custom` if either address is set to something other than `RelayDefaults` (CrocKit, read from Go). `receiveRelayKind` returns `directToSender` when a sender IP is set.

`Views/PowerSettingsSections.swift` holds the shared `Form` sections: relay, Send as link, transfer toggles, exclusions, and confirmation with the **Auto-Accept Transfers** warning footer. Both the macOS `SettingsView` (Settings scene, ⌘,) and the iOS `SettingsScreen` (gear toolbar, `Route.settings`) embed these sections.

`TrustBadge(relay:)` appears in the waiting, transferring and confirm-send views. `HowItWorksView` is the plain-language explainer. Its facts come from `what-is-croc.md`.

**About and privacy link.** `Views/AboutSection.swift` is the last `Form` section of the macOS General tab and of the iOS `SettingsScreen`. It shows the version (`CFBundleShortVersionString` and `CFBundleVersion`) and **Privacy Policy** and **Support** links. The URLs and the version string live in `Support/AppInfo.swift`, and `AppInfoTests` pins their scheme, host and path.

On macOS, `AppCommands` replaces the `.appInfo` group with an **About CrocApp** button. It calls `NSApplication.orderFrontStandardAboutPanel(options:)` with a linked "Privacy Policy" `.credits` string. The Direct build's `UpdateCommands` still attaches after that group.

`Phase.confirmSend` is the sender side of croc `--ask`. It is entered at `.connected` when **Confirm on Both Sides** is on, and it is progress-guarded like `.incoming`. Accept is `respond(true)`, decline is `cancel()`, and its Cancel button is `.destructiveTinted`.

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
- `TransferStatusView`: `Phase.stored(receipt)` renders `StoredLinkView`: "Link ready", expiry and download count, QR, link text, **Copy Link** (`copySecret`, `thisDeviceOnly: true`), **Share Link**, a `StatusBanner` while `storedReceiptSaved` is false, **Revoke Link** (confirmation dialog, then a neutral "Link revoked" block) and **Done**. **Revoke Link** and **Done** are disabled while a revoke runs.
- `DirectionHeader` reads Sending or Receiving for stored transfers too, never Uploading or Downloading. The view shows a caption instead of `TrustBadge` when `isStoredTransfer`.
- `ReceiveView`: `router.pendingReceive` carrying `.stored(url)` sets `storedLink`. That replaces the code field with a **Receive from Link** row (the server host underneath) and a **Clear** button. **Receive** then starts `.storedReceive`.
- `HistoryView`: stored rows add a "Link expires", "Link expired" or "Link revoked" line. **Revoke Link** (context menu) and **Revoke** (swipe on iOS) sit behind a confirmation dialog, with an alert on failure. Deleting such a row asks whether to revoke first (see History).
- `PowerSettingsSections`: a "Send as link" section (the header really reads that way, in sentence case) with the Link Server field, an inline `storedServerError` banner, and a **Reset** button shown only when the value differs from the default.

`Models/StoredTransferVault.swift` keeps receipts (id, origin, upload token, link, expiry) in the Keychain, all in one item (`storedReceipts`, a JSON array), because `SecretStore` cannot list accounts. Expired receipts are purged when the vault opens, which is each launch. A failed Keychain write is logged, never lost silently, and leaves the receipts already stored untouched. The new receipt then lasts until the app quits. Harness runs and previews use `MemorySecretStore`.

History never holds the token or the link. A stored record's `codeHint` is the server host (`CodeHint.storedLink(_:)`).

### Advanced settings

croc's own options are edited in `Views/AdvancedSettingsView.swift`. iOS pushes it from `SettingsScreen` (`Route.advancedSettings`, `--screen advanced`). macOS Settings is a `TabView` with **General**, **Relay** and **Advanced** tabs, because the Advanced controls and their footnotes would double a form that already scrolls.

- `AppSettings` has one property per control under `settings.advanced.<name>`: `throttleUpload`, `multicastAddress`, `peerIP`. Defaults come from `EngineOptions()`, so they are croc's. The curve, hash, ports, connection count, multiplexing and DNS are not settings (`crocmobile-bridge.md`, "Advanced options on the wire").
- `resetAdvancedToDefaults()` backs the **Reset to Defaults** button and persists.
- **The two proxies are Keychain-only.** The `SecretStore` accounts are `advanced.socks5Proxy` and `advanced.httpProxy`. They are deleted when blank, like `relayPassword`.
- Proxies can carry credentials. `ProxySettings`, `EngineOptions` and `StoredSendOptions` describe themselves without the value. The Go engine never quotes a proxy in an error, and nothing logs them. `AppSettingsAdvancedTests` asserts that `UserDefaults` holds no proxy key or value.
- `Models/AdvancedSettingsValidation.swift` holds the inline checks: `socks5ProxyError`, `httpProxyError`, `multicastAddressError`, `senderIPError`, `throttleError`. The app keeps no rules of its own. Each one asks the engine through CrocKit's `EngineSetting.validate(_:)` (`ValidateSetting` in `crocmobile/network.go`, the check a transfer start runs) and returns only the field's plain-words text on a refusal. `storedServerError` works the same way. Blank means the default, except for the link server. The value tables live in `network_test.go`, and `SettingsValidationTests` checks that each field reaches the engine.
- One message per field, so the sender IP text names the port range too and the link server text covers the scheme and the host-only rule.
- `EngineStart` passes every setting. A receive adds `peerIP`. Store send, store receive and revoke pass `ProxySettings`.
- Multicast reaches the engine on every platform. iOS needs the multicast entitlement for it, which `CrocApp-iOS.entitlements` carries (`apple-platform-constraints.md`, "LAN discovery and multicast").
- The engine reports a bad proxy, upload limit, port, multicast address or sender IP as `invalidSetting` (`validateNetworkOptions` in `crocmobile/network.go`). The `invalidSetting` failure points at Settings > Advanced, and its **Open Settings** opens Advanced settings.
- A receive with a sender IP shows `RelayKind.directToSender` in the trust badge (`AppSettings.receiveRelayKind`), never the public pool.

### Relay hosting and the health check

**Hosting (macOS only, both targets).** `Models/RelayHostController.swift` (`@MainActor @Observable`, `#if os(macOS)`) owns the relay this Mac runs through CrocKit's `RelayHost`. `init(settings:starter:stopsAtQuit:)` takes the starter as a closure, so `RelayHostControllerTests` passes a fake `RelayHandle`. `State` is `stopped`, `running(ports:)` or `failed(TransferFailure)`.
- It never starts by itself. `CrocAppApp.init` calls `startAtLaunchIfWanted()`, which starts only when `AppSettings.relayHostAtLaunch` (**Start Relay at Launch**, default off) is on, and never in a harness run. The controller stops the relay on `NSApplication.willTerminateNotification`. Each start has a generation number that its stop callback carries, so a callback from a stopped relay is ignored by a newer one.
- Settings: `relayHostPort` (`settings.relayHostPort`, default croc's 9009), `relayHostPassword` (Keychain account `relayHostPassword`, deleted when blank, never in `UserDefaults`; separate from `relayPassword`, which this device uses to join a relay) and `relayHostAtLaunch`. `relayHostPortError` takes its range from the engine (`RelayHost.basePortRange`). A blank password means croc's default, which the footer says anyone can use.
- `Views/RelaySettingsView.swift` is the **Relay** tab of the Settings window (`AppRouter.SettingsTab.relay`): the **Run a Relay** switch, port, password and launch switch (port and password are disabled while the relay runs, because a change would not apply), and, while running, `LocalAddresses.current()` rendered as the addresses to enter on the other device (IPv6 in brackets, link-local and loopback left out). The menu-bar window carries the same **Run a Relay** switch under a divider.
- A start that fails shows `TransferFailure` words. The engine's `portInUse` code has its own copy ("That port is already in use") and no button: only the relay raises it.
- Both macOS targets carry `network.server` already (`CrocApp.entitlements`, `CrocAppDirect.entitlements`), so no entitlement changed.

**Health check (all platforms).** `Views/RelayHealthView.swift` is a sheet opened by **Check Relay…** (`RelayHealthButton`), next to the relay fields in `PowerSettingsSections` and in the Mac Relay tab. `Models/RelayHealth.swift` builds one row per relay address and IP version, runs them in parallel through CrocKit's `RelayCheck` and keeps no password: it passes the Keychain-backed `relayPassword` straight to the engine.
- Targets: the custom `relayAddress` and `relayAddress6` when they differ from croc's defaults, else the four public pool relays (`RelayDefaults.publicPool`, because the one a code phrase picks is not known beforehand). With **Local Network Only** on it checks no relay and says so.
- `advice` words the failures with `TransferFailure` (`badPassword`, `relayUnreachable`) plus one string of its own for a listener that is not a croc relay. An address with one working IP version is healthy: the other failing is not advice.
- It dials directly, so it shows this device's own address to every relay it probes. With an Advanced proxy set (`usesProxy`) the sheet does not run on open: it warns and offers **Check Anyway**. A `busy` verdict (the relay answered "rate limited" or refused the room after taking the password) says so and advises trying again, not that the address is wrong.
- The local-network row reads `LocalNetworkChecker` (the Mac Settings scene gets it as an environment object too) and reuses `TransferStatusView.localNetworkDeniedDetail`.

### Menu bar and Shortcuts

Neither surface owns transfer state. Both drive the one `TransferController`, so they show and respect a transfer started anywhere. A second start is refused while `isActive`.

**Menu bar (macOS).**
- `CrocAppApp` declares a `MenuBarExtra` in window style, inserted while `AppSettings.showInMenuBar` is on (`settings.showInMenuBar`, default true). The toggle is **Show in Menu Bar**.
- `Views/MenuBarQuickSendView.swift` switches on `controller.phase`. A failure shows its title and detail in an error `StatusBanner`, with **Done**. `Models/MenuBarQuickSend.swift` holds the actions (`send(urls:)`, `sendClipboardText()`, `chooseFiles()`, `receive(_:)`) and a `notice` string. Sends use a generated code. `receive(_:)` parses with `TransferLink` and starts into `OutputFolderStore`, as `ReceiveIntent` does.
- `chooseFiles()` uses a modal `NSOpenPanel`, because the window-style extra closes when focus moves to a SwiftUI file importer's sheet.
- `.incoming` shows **Open CrocApp to Accept**, a button that opens the main window, because the accept prompt lives there.
- The label of the `MenuBarExtra` is `MenuBarIcon(phase:progress:)`, a pure mapping tested for real SF Symbols.
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
- `ReceivedFileLocator` finds what a receive wrote. croc keeps the sender's modification dates, so it tells new files apart by creation date: `name.ext`, or its Keep Both copy `name (n).ext`, created since the action started. `controller.offeredFileNames` gives the names.
- `IntentStaging` writes files that arrive without a usable file URL, and a received text as `Received text.txt`, under `ShortcutsFiles` in the temporary directory. A send outlives its action, so nothing is deleted on return. `SendFilesIntent` sweeps the folder at the start of the next send.
- A shortcut does not answer the accept prompt. Auto-accept applies as usual, and Keep Both or Replace follows the setting.

**History entities and Spotlight.**
- `Intents/HistoryEntity.swift` is the `AppEntity` and `IndexedEntity` for a record: name, direction, status, date, file names, size. Never the code phrase or code hint. `HistoryEntityQuery` answers Shortcuts (by id, by name, and a Find Transfers action with date, direction, status and name filters). `OpenTransferIntent` opens History (the list, not the record: no route carries a record yet, `known-issues.md`, "History entities").
- `Models/HistoryEntityStore.swift` is the one object both read. It is registered with `AppDependencyManager` and set as `HistoryStore.observer`, which tells it after each saved add, delete, prune and clear. A change that fails to save is never announced (`HistoryStore.saveOverride` lets a test force one).
- The index is changed by one queued operation at a time. It is rebuilt in full (remove all, index all) at launch and whenever Save Transfer History or Show History in Spotlight changes. A failed index call sets `needsRebuild`, and the next change rebuilds in full instead of applying a delta.
- `Models/HistorySpotlightIndex.swift` wraps a named `CSSearchableIndex` (`CrocAppHistory`) behind `HistoryIndexing`, which the tests replace. Under a unit-test host and in a harness run the store gets no index, so the developer's Spotlight is never written.
- The entity id is the JSON of the record's SwiftData `PersistentIdentifier` (`HistoryEntityID`). It survives a relaunch, not a reinstall or a reset store (`known-issues.md`).

**Send with CrocApp (Services menu, macOS).**
- `Platform/SendServicesProvider.swift` is `NSApp.servicesProvider`, set in `AppDelegate`. `sendFiles` and `sendText` are the `NSMessage` values of the two `NSServices` entries in `Config/CrocApp-macOS-Info.plist` and `CrocApp-Direct-Info.plist`; `SendServicesRegistrationTests` ties both plists to the selectors. They stage through `AppRouter.openSend(with:)` and `openSend(text:)`, so a service never starts a transfer and never navigates during one.
- Text is capped at `maxTextBytes` (1 MiB of UTF-8); a larger selection is refused with a message. The menu title is localized by `ServicesMenu.xcstrings`.

**Menu bar commands.**
- `Views/AppCommands.swift` is the menu bar on the Mac and the hardware-keyboard menu bar on iPad. Anything a toolbar button does has an item with a shortcut (the commands are below), and right-click menus are additive.
- File: **Send…** (⌘1), **Send Clipboard Text…** (⌥⌘1), **Receive…** (⌘2), **Paste Code…** (⌥⌘2), **History** (⌘3) and the Show Receive Folder item (⇧⌘R). Transfer: **Cancel Transfer** (⌘.) and **Copy Code** (⇧⌘C). Help: **How It Works** (⌘?). iPad adds **Settings…** (⌘,) to the app menu; the Mac's comes from the Settings scene.
- **Send…**, **Send Clipboard Text…**, **Receive…** and **Paste Code…** are disabled while a transfer is active. **Cancel Transfer** is enabled while `phase.canCancel`, which excludes the accept gate, and **Copy Code** while `phase.shownCode` is set. **History**, **Settings…** and **How It Works** always work and navigate through `AppRouter.showHistory()`, `showSettings()` and `showHowItWorks()` (the last pushes on what is open). A screen pushed on what is open goes through `AppRouter.push(_:)`: in regular width a path that does not start at a row (the empty path at launch) first takes the row the sidebar shows, so a pushed Settings never replaces the screen it came from.
- **Send Clipboard Text…** reads the pasteboard text and calls `openSend(text:)`; **Paste Code…** parses the pasteboard with `TransferLink.parse` and calls `open(_:)`. Neither starts a transfer. Reading the pasteboard from a menu command is a programmatic read, so iOS shows its Allow Paste prompt (not verified on a device).
- On macOS the Show Receive Folder item is **Show Receive Folder in Finder**.
- On iPadOS it is **Show Receive Folder in Files**. It opens `shareddocuments://` plus the percent-encoded receive-folder path with `UIApplication.open`, which is the Files app's scheme for a local folder.
- The iPad hand-off is not verified on a device. A user-picked provider folder (such as iCloud Drive) is expected to do nothing, because that scheme resolves local paths only.

## Accept gate

The incoming request is a phase of the transfer screen, not a sheet or an alert, so it cannot be dismissed by accident. It shows the direction header, the trust badge pill, the file list, a banner for each overwrite conflict and blocked-unsafe item, then **Decline** (destructive) and **Accept** (prominent; **Keep Both** and **Replace** when a name is taken). Nothing auto-advances and nothing is preselected.

| Exit | What the other device learns | What the app does |
| --- | --- | --- |
| Decline | that you said no | responds, then the terminal phase |
| Accept | that you said yes | responds, then the transfer |
| Navigating away | nothing | nothing: the request stays live |

- There is no Cancel and no "Not now": either would answer the sender on the user's behalf or promise a deferral the protocol cannot deliver. Only the sender's own timeout ends the wait. Navigating away never responds, not on backgrounding either.
- A live request is never lost. While one is pending and the user is elsewhere, an info banner with **Review** sits on Home, and in regular width on every detail screen except the gate, next to the **Review** badge on the sidebar row. A both-sides confirm on a send is the same question and gets the same treatment. The banner is persistent, never a toast.
- Decline is worded as telling the other device no. Nothing describes leaving as an action.
- Auto-accept skips the gate. It is off by default on every platform, and only the user turns it on.

## System surfaces

What the app puts outside its windows. **On any glanceable surface, never show** a code phrase (it is the whole secret), a link (its `#` fragment is the key), the contents of a file or text, or a history record's code hint. A glanceable surface is one a bystander can read: a notification, a widget, a control, the Live Activity, the menu bar and the Dock. Styling is the system's: system chrome and text styles, the accent only as a fill or a glyph tint, never a custom glass or shadow. The rule is also a security requirement (`THREAT-MODEL.md`, "Privacy").

| Surface | iPhone | iPad | Mac |
| --- | --- | --- | --- |
| Notification | yes | yes | yes |
| Home Screen and Lock Screen widget, Control Center control | yes | yes | no |
| Live Activity (the system draws it while a transfer runs in the background: title, file name, progress, Cancel) | yes | yes | no |
| Menu bar icon, Dock tile | no | no | yes |

**Notifications** are local only (`Models/TransferNotifier.swift`, `Platform/SystemNotificationCenter.swift`).
- `TransferNotifier` observes the controller's phase with `Observations`, so `TransferController` knows nothing about it. `TransferNotifier.notice(for:)` decides which phase notifies and what it says; a fake `NotificationPosting` tests it.
- Notifies for `.done`, `.stored`, `.failed` (not the user's own cancel or decline), `.incoming` and `.confirmSend`. Posted only while the app is not active, replaces the one on screen, and is removed when the phase leaves it.
- Two settings: **Notifications** (on by default; the system prompt comes with the first transfer, or when the switch is turned on) and **Show File Names in Notifications** (off by default; the title is generic and a failure body is the failure's title, which names no file).
- Interruption level is active, never time sensitive or critical, and there is no sound. The `transfer` category carries `hiddenPreviewsBodyPlaceholder`, so a body with names is hidden when the user hides previews.
- A tap sets `AppRouter.path` to the Send or Receive screen of the transfer. There are no notification actions: the accept gate must be on screen before a yes.
- Denied permission is not read back: the switch stays on and nothing is delivered. The footer says CrocApp asks the system, and System Settings owns the answer.

**Dock tile (Mac).** `TransferNotifier` also sets `NSApp.dockTile.badgeLabel`: the percent while `.transferring` with a known total, "1" while `phase.needsAnswer`, nil otherwise. A badge label needs no permission and no custom view. It has no switch.

**Widgets.** Two, in the system container with system text styles. **Quick Actions** (small) offers Send and Receive, each opening its screen and starting nothing. **Recent Transfers** (medium) lists up to three records with direction glyph, name or count and relative date, and a tap opens the record in History. Only direction, status, display name or count and date cross to the widget, and file names are marked private so the system redacts them while the device is locked. With no transfers, or with Save Transfer History off, the widget shows its empty line. Direction glyphs join the accented group.

**Control Center controls.** **Send** and **Receive**, also placeable on the Lock Screen and the Action button. A tap opens the app on that screen with nothing prefilled and nothing started, because a control that started a transfer would send or open a receive without a look. No state, number or code.

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
| Widget, no transfers | No transfers yet | |
| Widget, Save Transfer History off | History is off | |
| Widget and control labels | Send, Receive | |

### Settings copy

A row's label names the thing, in Title Case, as a noun phrase, never "Enable" or "Allow". A footer is one sentence in sentence case that says what the row changes.

| Row | Footer |
| --- | --- |
| **Save Transfer History** | Finished transfers are listed in History, which stays on this device. |
| **Show History in Spotlight** (off by default; disabled while Save Transfer History is off) | Spotlight on this device can find past transfers by their file names. |
| Section "Notifications": **Incoming Transfers**, **Finished Transfers** | Shown only while CrocApp is in the background. |
| **Haptics** (iPhone only) | A short tap when you copy or scan a code, and when a transfer finishes, fails or needs your answer. |

When the system has notifications off for CrocApp, both Notifications rows are disabled and the footer reads "Notifications are off for CrocApp in Settings." ("System Settings" on a Mac) with an **Open Settings** button. "Incoming" appears only in the label **Incoming Transfers** and the notification kind it names, because nothing is being received before the user says yes.

## Windows and keyboard focus

One main window on Mac and one scene on iPad: the transfer is app-wide and runs one at a time, so a second window could only mirror the first. The Mac main window is a single-instance `Window` scene and iPad turns multiple scenes off (`UIApplicationSupportsMultipleScenes` NO), so the sidebar selection and each detail's path live in `AppRouter.shared`. Closing the Mac window leaves the app running: the menu bar item stays and a running transfer finishes. A Dock click, a receive link or **Open CrocApp** brings the window back. The main window opens at 880×700 (minimum 720×560), Settings at 480×780 (minimum 480×420), and the Mac menu bar window is 300 wide.

On arrival, a Mac and an iPad with a hardware keyboard put the caret in the first text field (Receive's code field); Send's screen takes keyboard focus instead so ⌘V reaches it. An iPad without a keyboard and an iPhone focus nothing, because the software keyboard covers half the screen. `HardwareKeyboard.isExpected` answers the question in code. A focus target that exists only to catch a paste hides its own ring and never the ring of the controls inside it. Macs have no camera, QR scan or local-network prompt: those are absent, not disabled.

## Transfer screen presentation

The shared views route onto `design/`. A screen picks one of these instead of styling ad hoc.

- `Views/ButtonVariants.swift`: `.buttonVariant(_:)` with `prominent`, `secondary`, `destructive`, `destructiveTinted`, `plain` (`design/components.md`, "Button"; `design/implementation.md`, "Components"). It is a `PrimitiveButtonStyle`, so the label color sits on the label itself. `prominent` fills with `Color.accentSolid`, not `Color.accent`, so the white label clears 4.5:1 in light mode (`design/principles.md`, Contrast). The pending-count badge on Home uses it too. Disabled buttons get only the system dimming, never an extra opacity on the label. The same file holds `.hitTarget()`, the 44 pt iOS hit area for bare text buttons (`design/principles.md`, "Accessibility"); use it instead of a private copy.
- Filled `.destructive` is for Decline on the accept gate and the Clear History confirmation only. Cancel (waiting, transferring, confirm-send, menu bar) and Discard (`StagedFilesSheet`) are `.destructiveTinted`.
- `DropZone`, `CodePhraseDisplay` (eyebrow, code, **Copy Code**; `compact` for the 300-wide menu bar column), `DirectionHeader` (arrow plus Sending or Receiving).
- `ForwardProgressBar` never moves backwards, and `resetKey` snaps it when the measured thing changes (`design/principles.md`, "Motion").
- `Support/Inflected.swift` resolves `^[3 file](inflect: true)` markup into a plain `String`.
- **Accept gate.** `.incoming` offers Decline only, with no Cancel. Cancel would answer the sender on the user's behalf, so `TransferStatusView.showsCancel` is false there (`design/components.md`, "AcceptGate"). Leaving the screen answers nothing and stays silent.
- `HomeView` shows a "Files are waiting for your answer" `StatusBanner` with **Review** (`router.path = [.receive]`) while the phase is `.incoming`, so a live request is never lost. The banner enters with the Insert transition and the container animates on `hasPendingRequest`, both `nil`/`.identity` under Reduce Motion (`design/principles.md`, "Motion"). The transition expression is private to `HomeView`; hoist it into `Motion` when a second view needs it.
- **Home is a grouped `Form`.** The badge, banner and the two actions are one row with a clear background, no separator and zero insets, so the actions keep their 100 pt minimum height (`actionMinHeight`) and the page scrolls at large text. `RecentTransfersSection` is the section below it (`design/components.md`, "Home").
- **Recent transfers** (`Views/RecentTransfersSection.swift`): Home exists only at compact width (`ContentView.layout`), so the section never shows on the Mac or in a regular-width iPad window, where History is a sidebar row. `@Query` with a `FetchDescriptor` whose `fetchLimit` is 3 (newest first), so Home never loads the whole history. With **Save Transfer History** off it draws nothing, even when older records exist. With it on and no records it draws the EmptyState. Each row is a `NavigationLink(value: AppRouter.Route.history)` that opens the History list; it does not open the record's detail, which needs a route that carries the record. `RecentTransferSummary` holds the wording (title, status word, date, spoken label) and is unit tested. Its date reads relative inside a week and as a short absolute date after (`design/voice.md`, "Dates"), unlike `HistoryRow`, which still uses the relative style for every age. Each row rebuilds its summary inside a `TimelineView(.everyMinute)`, so a relative date stays current while Home is open. `RecentTransfersSection.content(saveHistory:recordCount:)` decides hidden, empty or rows and is unit tested with the fetch limit and order (`RecentTransfersSectionTests`).
- **Done.** `doneView` builds its `StatusBlock` with `StatusBlock(summary:receivedText:direction:)`: a summary croc did not mark successful becomes `TransferFailure.finishedWithProblems`. A receive then lists `ReceivedFilesList`: `ReceivedItems.locate` runs off the main actor over `offeredFileNames` and `startedAt`, and returns a folder once and a file at the name it was saved under (the newest Keep Both copy created since `startedAt`, as `ReceivedFileLocator` resolves one, through the shared `ReceivedFileLocator.keepBothOriginal`). A row is `FileRow(received:)`: tap for Quick Look, a share control, a context menu (**Quick Look**, **Share**, **Show in Finder** or **Show in Files**) and drag-out on Mac and iPad. A folder row has only the reveal action. A user-picked folder is read under its security scope, which the list takes itself because the controller released it. The name is drawn in its shown form.
- **`StatusBlock` kinds.** `.success`, `.error` and `.neutral`. `.neutral` (grey fill, `slash.circle`) is the user's own Cancel or Decline (`TransferFailure.endedByUser`) and a revoked link, which are not failures (`design/voice.md`, "Errors").
- **Failure.** `failedView` shows a `TransferFailure` as a `StatusBlock` title and detail, then its actions stacked, large and full width: **Try Again** (`retry()`) or **Open Settings**, prominent, with **Done** secondary, or **Done** alone (`design/components.md`, "StatusBlock").
- **Open Settings** goes to the failure's `SettingsPlace`. On macOS it sets `AppRouter.settingsTab`, which `SettingsView`'s tabs follow, and calls `openSettings`. On iOS it pushes `.settings` (and `.advancedSettings`) onto `router.path`, so Back returns to the result. A system permission opens the system Settings, as the local network banner does.
- **Phase cross-fade.** `TransferStatusView` animates on `phaseKind` (the phase case without its payload), not on progress ticks, so only a real phase change cross-fades. It is `nil` under Reduce Motion (`design/principles.md`, "Motion").
- **Haptics.** Phase haptics live in `ContentView`: one `.phoneHaptic(trigger: TransferHaptic(controller.phase))` on the root. `TransferHaptic` has three cases (completed, failed, incoming), and a failure whose `endedByUser` is set (the user's own Cancel or Decline) stays silent. The fourth event, `.selection` for a copied or scanned code, fires from `CodePhraseDisplay` and `ReceiveView`. iPhone only, and silent while the **Haptics** setting is off (`phoneHaptic` checks both; `design/principles.md`, "Haptics").
- **Wording.** Status titles are sentence case ("Link ready"). Controls are Title Case (**Send as Link**, **Local Network Only**, **Auto-Accept Transfers**). Section headers, footers and descriptions stay sentence case (`design/voice.md`, "Capitalization"). A stored transfer still reads Sending or Receiving, never Uploading or Downloading, and "incoming" is not user-facing (`design/voice.md`, "Terminology").

## History

`Models/TransferHistory.swift`: `TransferRecord` is a SwiftData `@Model` (including `statusRaw`, a string storage for the enum). Stored sends add optional `storedID`, `expiresAt` and `revokedAt`. They are optional so a store written by an older build opens without a migration step.

Caps: a record keeps at most 20 names (`maxNames`) and 200 bookmarks (`maxBookmarks`), and the store keeps at most 300 records (`maxRecords`). `HistoryStore.add()` deletes the oldest records beyond that.

`HistoryStore` is `@MainActor @Observable` and wraps `container.mainContext`. It exposes `add`, `delete`, `clear`, `recordCount`, `record(storedID:)` and `markRevoked`. `delete` and `markRevoked` return early for a record whose `modelContext` is nil, because a record that a prune or a delete removed must not be written to or deleted again (a revoke that finishes after its record is gone is the case). The container is in memory when `AutoVerify.isHarnessRun`. It is injected twice: as `.environment(history)` and as `.modelContainer(history.container)`.

`Views/HistoryView.swift` (`Route.history`, clock toolbar icon on both platforms):
- `@Query` sorted newest first.
- With no records, "No transfers yet" with **Send** and **Receive**, or "History is off" with **Open Settings** while **Save Transfer History** is off (`openSettings` on macOS, `Route.settings` pushed on iOS).
- A row opens `HistoryDetailView` (push by `NavigationLink`; on macOS double-click or Return, via `navigationDestination(item:)`, which resets `opened` when its record is gone). The detail is a grouped `Form` of status, rows, file names and the actions. It renders nothing for a record with no `modelContext` and dismisses, so a prune past 300 while it is open cannot crash it.
- `HistoryActions` (`Models/HistoryActions.swift`) is the state both screens share: which revokes run, `revoke` and `resend`. `RecordDialogs` (in `HistoryView.swift`) holds the Revoke confirmation and failure alert, the Delete confirmation and the Send Again alert for every path: swipe, context menu, the macOS Delete key and the detail button.
- **Delete** is immediate, except for a record whose link can still be revoked (`controller.canRevoke`): then a dialog offers **Revoke Link and Delete**, **Delete and Keep Link** or Cancel. A failed revoke keeps the record. Delete is disabled while that record's revoke runs.
- On macOS the Delete key, the context menu and `record(in:)` use only the rows in `shown`, the selection is cleared when the search changes, and the menu appears for one row only.
- Code hints are `.privacySensitive()`. Relative dates and the link expiry text sit in `TimelineView(.everyMinute)`, so "yesterday" and Expires or Expired stay current.
- **Clear** behind a confirmation.
- **Send Again** for send records that carry bookmarks: resolve the bookmarks, then `router.openSend`.

**Both platform probe branches must call `startAccessingSecurityScopedResource()` before `fileExists`.** The sandbox denies `stat` on an unopened scope.

## Support helpers

- `Support/SecurityScopedBookmark.swift`: bookmark create, resolve and resolveIfReachable. `OutputFolderStore` and `HistoryView`'s resend path share it. `resolveIfReachable` starts the security scope before the existence probe, for the reason above.
- `Support/SendStaging.swift` is the scratch folder for what Send is handed as bytes (Photos picks, dropped or pasted images), one folder per item so original names survive. Cleanup is by owner, never by timer: a row's removal, the Send screen going away with no transfer running, and a sweep on the first Send screen of a launch. **Deleting is guarded**: `slotFolder(for:under:)` is the one answer for both `isStaged` and `discard`. It resolves the root once, takes only the slot name from the caller's path, rebuilds the target from the resolved root, refuses a symlink in the slot's place, and needs a slot plus an item below it, so the root and a bare slot are never deleted. `SendLoading.load` brings a Photos pick in from a `.task(id:)` and discards what it staged when the task is cancelled. `SendReadiness` holds the Send button's rules, and a pick that is still loading blocks it.
- `Support/EngineConstraints.swift`: `minCodeLength = 6`, mirroring `minCodeLength` in `crocmobile/crocmobile.go` (also used in `session.go`). The Go side counts bytes and Swift counts characters, so the UI check is the stricter one for non-ASCII codes. It exists for inline feedback before a doomed send or receive start. There is no shared source of truth across the Go/Swift boundary, so keep the two in sync by hand.
- `Support/Clipboard.swift`: two copy paths.
  - `Clipboard.copy(_)` is a plain copy with no expiry, for **Copy Received Text** and **Copy Text**.
  - `Clipboard.copySecret(_, thisDeviceOnly:)` is for a credential. It leaves the pasteboard after `Clipboard.secretLifetime` (5 minutes).
  - **Copy Code** uses it with Universal Clipboard on, because copying on a Mac and pasting on an iPhone is a core use. **Copy Link** uses it with `thisDeviceOnly: true`, because the link's fragment is the key.
  - iOS: `UIPasteboard.setItems(_:options:)` with `.expirationDate`, plus `.localOnly` for the link. `Clipboard.secretOptions(thisDeviceOnly:now:)` builds the options, so a unit test can read them.
  - macOS has no expiry. The copy carries `org.nspasteboard.ConcealedType` (clipboard managers that follow nspasteboard.org skip it) and uses `.currentHostOnly` for the link.
  - The macOS clear runs in the app, after the lifetime, only while the app is running, and only if `changeCount` has not moved, so a later copy is never wiped.
  - Not verified on hardware: the expiry on a device, the link staying off Universal Clipboard, a clipboard manager honoring the marker, and whether the code also expires on the other device. `device-test-checklist.md`, "Clipboard", lists the checks. `ClipboardTests` cover the options and the macOS clear against a private `NSPasteboard`.
- `Support/DesignTokens.swift`: the app's routing layer onto `design/`. It holds `Spacing`, `Radius`, `BorderWidth`, `ControlHeight`, `IconSize`, `LayoutCap`, `Opacity`, `Tracking`, `ComponentMetrics`, `Motion` and `Shadow`, plus `Color` aliases. Where a system semantic already matches a token exactly, the alias routes there instead of duplicating an asset-catalog entry.

## Conflict scan

The scan is asynchronous. `.incoming` is shown immediately with `conflicts: []`. `Self.scanConflicts` runs in `Task.detached` and stats off the main actor. The write-back happens only when the result is non-empty, only `if case .incoming`, and only if `transferGeneration` still matches the value captured at `.fileList`.

The shape check alone is not enough: a scan can outlive a whole fast transfer and land on the next one's `.incoming`. A synchronous scan froze the accept UI on large file lists.

With conflicts, the sheet offers Decline, Replace and Keep Both (Keep Both prominent) and a banner. Without conflicts, or while the scan runs, it offers a single Accept, which means Keep Both. A zipped folder arrives as one `.zip` name, so the scan sees none of its members (`docs/known-issues.md`, "Accepted").

A file send's bookmark capture (`HistoryDraft.bookmarks(for:)`, up to 200 `bookmarkData` calls) runs off the main actor the same way and writes back into `pendingRecord`, under the same `transferGeneration` check, so a capture that outlives its send cannot land on the next transfer's record. If a transfer terminates first, `pendingRecord` is already nil and the record carries no bookmarks, so **Send Again** hides instead of breaking. `SecurityScopedBookmark.create` is `nonisolated` for this.

## Receive links

- `Models/TransferLink.swift` is the one parser. `TransferLink.parse(_:)` takes a bare code, `crocapp://receive?code=`, `https://crocapp.dev/r/#<code>` or `https://getcroc.com/?code=`, and yields `.code`.
- It also parses a stored-transfer link `https://<host>/s/<id>#v1.<key>` into `.stored(URL)`. `http` is accepted only for `localhost`, `127.0.0.1` and `::1`. `ReceiveView` takes it (see "Stored transfers").
- `TransferLink.webURL(forCode:)` builds the `crocapp.dev/r/` link.
- `AppRouter.open(_:)` stores the link in `pendingReceive` and calls `openReceive()` unless `isBusy`. Mid-transfer the link is kept and the user is not moved.
- `ReceiveView` consumes `pendingReceive` (`onChange(initial: true)` on the form) and fills `code`. Opening a link never starts a receive: the user taps **Receive**.
- Entry points all go through `TransferLink.parse` and then `router.open`: the QR scan sheet (iOS), the **Paste** button, typed or pasted text containing `://` in the code field, `.onOpenURL` in `CrocAppApp` (iOS universal links and `crocapp://`), and `AppDelegate.application(_:open:)` on macOS (file URLs still go to Send). On macOS a link reaches both the delegate and `.onOpenURL` (measured), which is harmless because `router.open` is idempotent.
- The `crocapp` scheme is in the iOS, macOS and Direct Info plists in `app/Config/`.
- Universal links for `crocapp.dev/r/*` need the Associated Domains entitlement (all three app entitlements files carry it) and `web/landing/.well-known/apple-app-site-association`, which lists both app IDs.
- `TransferStatusView.waitingView` encodes the QR as `TransferLink.webURL(forCode:)` and adds a **Share Link** button.
- `browserReceiveNote` adds a caption when the active relay is custom or local-only, because croc's browser client knows only the default relays.

## Platform layer, iOS

- `Platform/BackgroundCoordinator.swift` is a cross-platform class with `#if os(iOS)` bodies (no-ops on macOS). It wraps a transfer in a `BGContinuedProcessingTask` and holds `isIdleTimerDisabled`.
- Controller hooks: `transferStarted` in `run()`, `progressChanged` inside the accepted `.progress` path only (the `.incoming` guard stays untouched), and `transferEnded` at `.done`, `.failed` and the startup `catch`. `transferEnded` is idempotent.
- Expiration sets `backgroundExpired` and cancels, which produces the dedicated "iOS paused the transfer…" copy. A generation token rejects stale late task launches.
- `Platform/LocalNetworkChecker.swift` is cross-platform. It is a Bonjour self-probe on `_crocapp._tcp`: seeing its own service means access is granted, and a browser stuck in `.waiting` means denied.
- `checkIfNeeded()` probes once per process, triggered by `ContentView.onChange(controller.isActive)`.
- `recheckIfDenied()` re-probes from `.denied` when `scenePhase` goes `.active` (for example after the user granted access in Settings). It never re-probes `.granted` or unresolved states and never stacks a second in-flight probe.
- Denial shows a banner plus **Open Settings** in `TransferStatusView`. Denial only resolves at the 8 s timeout, because a first `.waiting` may just be the pending permission prompt.
- Testing a macOS denial is awkward (`docs/known-issues.md`, "Accepted").
- `Models/ShareInbox.swift` and `Views/StagedFilesSheet.swift` pick up batches staged by the share extension from the App Group (`ShareInbox/batch-<UUID>/` plus `manifest.json`). The group ID, directory and file names, the `Manifest` type and the batch-name generator and validator are `app/Shared/ShareHandoff.swift`, compiled with `app/Shared/ReceivedName.swift` into `CrocApp`, `CrocApp Direct` and `CrocShare` (a synchronized folder group listed on all three targets), so the writer and the reader cannot drift. The group ID is also in the entitlements files, which cannot import Swift. `ShareInbox` treats a manifest as untrusted data: one it cannot decode, or whose batch is not `batch-` and a UUID, is logged (category `share`) and treated as absent, so the batch name is never joined to a path, and a file name `ReceivedName.isUnsafe` rejects is dropped. It also logs any file removal that fails, and stays best effort. `ShareInbox.refresh(in:)` takes the inbox directory so `ShareInboxTests` can use a temp directory instead of the App Group container. The manifest is consumed on the user's decision, the batch files outlive the send, and `purgeStaleBatches` runs at idle.
- The whole `scenePhase` refresh is gated on `!controller.isActive`. An ungated refresh once purged a live batch mid-send.
- `app/CrocShare/` is an iOS-only app extension. The pbxproj entry is hand-built, and `platformFilter = ios` on the dependency and the embed keeps macOS clean.
- File-copy staging happens inside the `loadFileRepresentation` handler, because of the roughly 120 MB extension memory cap. It never wipes existing batches.
- The Info plists live in `app/Config/`, outside the synced folders, to avoid a generated-plist collision. The app's `INFOPLIST_FILE` is sdk-scoped.
- **One scene on iPad.** `app/Config/CrocApp-Info.plist` sets `UIApplicationSceneManifest` with `UIApplicationSupportsMultipleScenes` NO. The generated manifest (`INFOPLIST_KEY_UIApplicationSceneManifest_Generation`) is documented as "an entry suitable for a multi-window application" and builds `UIApplicationSupportsMultipleScenes = YES`, so the target leaves that setting out. Measured on an iPad simulator (iOS 27.0 runtime): `UIApplication.shared.supportsMultipleScenes` read true with the manifest YES and false with NO, and the app launches and renders either way. `WindowGroup` stays the iOS scene, because `Window` is not an iOS scene (Apple lists macOS and visionOS only).
- Files-app visibility comes from `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace`. **The two do not behave the same way**, although both are declared as sdk-scoped `INFOPLIST_KEY_*` settings in the pbxproj.
- `LSSupportsOpeningDocumentsInPlace` is injected into the built `Info.plist` from the build setting alone. `UIFileSharingEnabled` is not, and only lands because `app/Config/CrocApp-Info.plist` also declares it literally.
- Measured with Xcode: delete the two plist lines and `plutil -p` on the built `CrocApp.app/Info.plist` shows `UIFileSharingEnabled` gone, while `LSSupportsOpeningDocumentsInPlace` and `NSLocalNetworkUsageDescription` survive. `xcodebuild -showBuildSettings` still resolves `INFOPLIST_KEY_UIFileSharingEnabled = YES`.
- So the plist declaration is load-bearing and the pbxproj key is inert for that one setting. Do not deduplicate by deleting the plist lines: that silently removes the app from the Files app.
- **Open in Files** on the receive-done screen uses the `shareddocuments://` scheme, which is a community convention with no public API. The button is shown only when the receive folder is the app's own default folder, because the scheme resolves only paths inside the app container.

## Platform layer, macOS

- `Models/AppRouter.swift` is an `@Observable` singleton (`shared`). `path: [Route]` is the one navigation state: `HomeView`'s `NavigationStack` path in compact width, the sidebar row plus the detail's pushed screens in regular width ("Layout by width").
- `pendingSendURLs` is consumed by `SendView` (`onAppear` plus `onChange`, deduplicated against `pickedURLs`, then cleared).
- `pendingSendText` (set by `openSend(text:)`) is consumed the same way: `SendView` switches to text mode and appends it to any typed text. Both only stage; nothing sends until the user taps Send.
- `isBusy` reads `controller.isActive` through a weak controller reference that `CrocAppApp.init` attaches with `attach(controller:)`, so a dock drop mid-transfer queues without navigating.
- It is a singleton because `AppDelegate` and `Commands` sit outside the environment graph.
- Three drop entry points, one guard policy:
  - The window drop (`ContentView`, macOS only) refuses while active and filters `\.isFileURL`.
  - The `SendView` list drop filters too.
  - The dock drop (`Platform/AppDelegate.swift`, `application(_:open:)`) always queues and navigates only when idle.
- The dock drop works because `Config/CrocApp-macOS-Info.plist` declares `public.item` document types with the Viewer role and rank None.
- Side effect: the app is listed in Finder's "Open With" for everything. `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace[sdk=macosx*]=YES` is required, or Xcode auto-injects an invalid `NO`.
- `Views/SettingsView.swift` has a **General** tab (output-folder **Change…** and **Reset**, **Show in Finder**, the menu bar section, the power sections, About) and an **Advanced** tab.
- `Views/AppCommands.swift` provides the File, Transfer and Help commands ("Menu bar and Shortcuts").
- **One main window.** `CrocAppApp.mainScene` is a single-instance `Window("CrocApp", id: "main")` with `.defaultSize(880×700)`, content `minWidth 720` and `minHeight 560` (the sidebar layout, "Windows and keyboard focus"). A frame saved by an earlier build (`NSWindow Frame main` in the app's defaults) wins over the default size, and the minimum clamps it. One transfer runs at a time, so a second window could only mirror the first with a navigation path of its own; `AppRouter.shared` is the one path.
- Apple's `Window` quits the app when it closes. `AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns false, so a running transfer and the menu-bar item outlive the window. Measured on macOS 27: with the delegate method missing, `performClose` on the window ended the process; with it, the process stayed and the window was `isVisible == false`.
- The window comes back from a reopen (`open -a`, the event a Dock click sends; the Dock click itself was not tried), from a link, and from **Open CrocApp** in the menu-bar window. `openWindow(id:)` opens a closed `Window` scene and orders an open one to the front (Apple's `OpenWindowAction`), so `MenuBarQuickSendView.openMainWindow` is `NSApp.activate()` plus `openWindow(id:)`. Measured with the window closed: `open -a` and a link each made it visible again, and `openWindow(id:)` called from the menu-bar scene did too. With it open there was still one window. The menu-bar button itself was not clicked.
- The old `.handlesExternalEvents(preferring: [], allowing: ["*"])` is gone, because a `Window` is never duplicated by an opened URL.
- `CrocApp Direct` only (`#if DIRECT`, `app/CrocAppDirect/AppUpdater.swift`): a **Check for Updates…** item in the app menu right after **About CrocApp**, backed by Sparkle's `SPUStandardUpdaterController`. The App Store target has no such item.
- The default output folder is `~/Downloads/CrocApp`. It needs the `files.downloads.read-write` entitlement. The folder is auto-created in `defaultFolder`, and `defaultDisplayName` supplies the UI label. The receive-done screen offers **Show in Finder** via `NSWorkspace.activateFileViewerSelecting`.
- Build and release scripts are described in `docs/RELEASING.md`.

## Onboarding and store compliance

- `OnboardingView` is a sheet from `ContentView.task`. It is shown when `!onboardingSeen && !AutoVerify.isHarnessRun`, or when a harness run asks for it with `--screen onboarding` (`AutoVerify.forcesOnboarding`). `onboarding.seen` is written in `onDismiss`.
- `OnboardingView` is a `ScrollView` (`.scrollBounceBehavior(.basedOnSize)`, `.defaultScrollAnchor(.center, for: .alignment)`), so content that fits stays centered and large text scrolls instead of clipping. At accessibility sizes each bullet's glyph (`--icon-size-lg` through `@ScaledMetric`) sits above its text; `HowItWorksView` does the same through `ParagraphLabelStyle`. Beside the text the glyph frame is `minWidth` 1.25 times the glyph, so every bullet's text starts at one x.
- The staged-files sheet yields to onboarding (`&& !showOnboarding`) and is offered again when onboarding dismisses.
- Onboarding also primes the two system permission prompts its copy names. On iOS, `onDismiss` awaits `CameraPermission.requestIfNeeded()` and then calls `localNetwork.checkIfNeeded()`. They run in sequence so the user never sees two system prompts stacked. Neither is requested during an `AutoVerify` harness run.
- `Platform/CameraPermission.swift` (iOS only) wraps `AVCaptureDevice.authorizationStatus` and `requestAccess(for: .video)`.
- `QRScannerSheet` resolves its own authorization first, as a gate separate from `DataScannerViewController.isSupported`, and renders distinct copy for all four `AVAuthorizationStatus` cases. `.authorized` shows the scanner. `.notDetermined` requests access, then re-reads the status. `.denied` offers **Open Settings**. `.restricted` does not, because Settings cannot fix a restriction.
- `PrivacyInfo.xcprivacy` sits in both synced target folders. The app declares UserDefaults CA92.1, FileTimestamp C617.1 and 3B52.1, and SystemBootTime 35F9.1 (the Go engine's `stat` family and `mach_absolute_time` imports). The extension declares an empty accessed-API list. Both declare no tracking and no collection.
- `ITSAppUsesNonExemptEncryption` is set in `CrocApp-Info.plist` (iOS) and `CrocApp-macOS-Info.plist`, the two plists App Store builds use. The value, the reason and the open decisions are in `docs/RELEASING.md`, "Export compliance".
- Two `.glassEffect()` call sites exist: the code card in `CodePhraseDisplay`, which `waitingView` uses, and the macOS-only **Drop to Send** full-window overlay in `ContentView` (`design/components.md`, "DropZone").

## Localization

The app ships in English only and is ready for more languages. The catalogs exist and every user-facing string reaches one. No second language is in them yet, and the project knows only the `en` and `Base` regions. The plan for languages is in `docs/ROADMAP.md`.

| Catalog | Bundle | Holds |
| --- | --- | --- |
| `app/CrocApp/Localizable.xcstrings` | `CrocApp`, `CrocApp Direct` | every string of the app and of `app/CrocAppDirect/`, and the App Intents titles, descriptions and parameter summaries |
| `app/CrocApp/AppShortcuts.xcstrings` | the same | the three Siri phrases of `CrocAppShortcuts` |
| `app/CrocApp/InfoPlist.xcstrings` | the same | the camera and local-network permission texts |
| `app/CrocApp/ServicesMenu.xcstrings` | the macOS and Direct apps | the title of the **Send with CrocApp** Services menu item (`NSMenuItem` in the two Info plists). Edited by hand |
| `app/CrocShare/Localizable.xcstrings` | `CrocShare` | the share extension's few strings. An extension is its own bundle, so it has its own catalog |

### What is localized, and how

What a string is used for decides how it is written. Never wrap a literal that SwiftUI already treats as a key.

| The text is | Write |
| --- | --- |
| a literal handed to a SwiftUI view or modifier that takes a key (`Text`, `Button`, `Label`, `navigationTitle`, `accessibilityLabel`, `ContentUnavailableView`) | the literal itself. A parameter that only ever receives literals is typed `LocalizedStringKey` (`DropZone.title`, `CodeField.placeholder`, `AdvancedRow.footnote`), because a `String` parameter shows its text as it is and Xcode never extracts it |
| built in a model or helper, or needed as a `String` (`TransferFailure`, the Settings field errors, the `StatusBanner` and `StatusBlock` title and detail, VoiceOver announcements, the iOS Live Activity text, `NSOpenPanel`) | `String(localized:)`, with `comment:` where the meaning or a placeholder is not obvious. It resolves when it is built, so never keep one past a language change (the system relaunches the app for one) |
| an App Intents title, description, parameter or dialog | a `LocalizedStringResource`, or the literal where the API takes one. Shortcuts resolves it |
| formatted data (`"\(done) / \(total)"` of two file sizes) | `Text(verbatim:)`, or `Text(_:format:)` for a number. Otherwise the build adds a meaningless `%@ / %@` key |
| a count | `^[\(n) file](inflect: true)` in a `Text` or an `AttributedString(localized:)` (`inflected(_:)` turns the result into a `String`), or one plural variation in the catalog (`Received %lld items.`) |

Never localize:

- Code phrases, file names, URLs, relay addresses and croc or Go output. The engine's `EngineFailure.message` is never shown (`TransferFailure`).
- `Logger` messages, test strings and preview-only labels (use `Text(verbatim:)` there, as `ButtonVariants.swift` does).
- The `AutoVerify` markers and the failure copy the harness scripts match, such as "This link no longer works" in `scripts/verify-app-mac.sh`. The harnesses expect English, so run them on an English system.
- The names `CrocApp` and `croc`.

Not localizable yet: `known-issues.md`, "Design system", lists the on-screen strings that still bypass the catalogs.

### Keeping a catalog in step

Apple says Xcode adds new keys to the catalogs on every build in the IDE. `xcodebuild` does not: with Xcode 27.1 a build compiles the strings but leaves the `.xcstrings` files untouched. What the IDE does can be run by hand, because the compiler writes one `.stringsdata` file per source file, and `xcstringstool sync` merges them into a catalog.

The three variants compile different code (`#if os(iOS)`, `#if os(macOS)`, `#if DIRECT`), so build all of them, then sync from every `.stringsdata`. A sync from one variant drops the keys only the others use.

```bash
DD=$(mktemp -d)
FLAGS=(CODE_SIGNING_ALLOWED=NO -derivedDataPath "$DD")
xcodebuild build -project app/CrocApp.xcodeproj -scheme CrocApp -destination platform=macOS "${FLAGS[@]}"
xcodebuild build -project app/CrocApp.xcodeproj -scheme CrocApp -destination 'generic/platform=iOS Simulator' "${FLAGS[@]}"
xcodebuild build -project app/CrocApp.xcodeproj -scheme 'CrocApp Direct' -destination platform=macOS "${FLAGS[@]}"

# One --stringsdata per file; the Direct build's directory has a space in it.
sync() {
  local catalog=$1; shift; local args=() f d
  for d in "$@"; do
    while IFS= read -r f; do args+=(--stringsdata "$f"); done < <(find "$d" -name '*.stringsdata')
  done
  xcrun xcstringstool sync "$catalog" "${args[@]}"
}
B="$DD/Build/Intermediates.noindex/CrocApp.build"
APP=("$B/Debug-iphonesimulator/CrocApp.build" "$B/Debug/CrocApp Direct.build" "$B/Debug/CrocApp.build")
sync app/CrocApp/Localizable.xcstrings "${APP[@]}"
sync app/CrocApp/AppShortcuts.xcstrings "${APP[@]}"
sync app/CrocShare/Localizable.xcstrings "$B/Debug-iphonesimulator/CrocShare.build"
```

The file name is the table name, so each catalog takes only its own table. A sync keeps comments, translations and `shouldTranslate`, and removes an untranslated key no code uses any more.

Three things no build writes, so edit them by hand:

- `ServicesMenu.xcstrings` holds the one `NSServices` menu title. The system looks the plist's `default` title up in the `ServicesMenu` table, which is the file name. Keep the key equal to the plist text. It is not synced from code, so `xcstringstool sync` never touches it.
- `InfoPlist.xcstrings` holds `NSCameraUsageDescription` and `NSLocalNetworkUsageDescription`. Apple's Xcode 16.3 release notes say the IDE extracts Info.plist keys into this catalog on its own. `xcodebuild` writes nothing there (verified), and the IDE was not run, so both keys are seeded with their current text. Keep a changed permission text in step with `app/Config/CrocApp-Info.plist` or the `INFOPLIST_KEY_` setting.
- The plural variation of `Received %lld items.`, which `ReceiveIntent` uses for its dialog. `LocalizationTests` pins that 1 and 3 render as "1 item" and "3 items".

### Adding a language

1. In Xcode, open each catalog and add the language, which also adds it to the project's regions.
2. Translate. Keep every placeholder (`%@`, `%lld`, `${applicationName}`), and move it where the grammar needs it. Give each count key plural variations: `^[%lld file](inflect: true)` only works for the languages Apple's automatic grammar agreement supports (not checked which), and the other languages need explicit variations.
3. Translate the three phrases in `AppShortcuts.xcstrings`, each with `${applicationName}`, and the two permission texts in `InfoPlist.xcstrings`.
4. Test with the scheme's **App Language** option, or the launch argument `-AppleLanguages (xx)`. Check the longest strings against `design/principles.md`: a translation is often longer than the English.
5. The docs site (`web/docs/`), the landing page and the store listing (`app-store-listing.md`) are separate and not in the catalogs.

## SwiftUI and Xcode API facts

Checked against the Xcode 26 SDK:

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
- `--relay ADDR` sets only the relay, so the LAN route stays on. `--disable-local` sets `harnessDisableLocal`, to kill the LAN race: the custom-relay scenario of `verify-app-mac.sh` and `capture-screenshots.sh` pass it. It has no value, so on macOS it goes last (`crocmobile-bridge.md`, "`scripts/verify-app-mac.sh`").
- `--when-exists` is the policy `AutoVerify` answers the incoming sheet with. The setting itself stays Keep Both, so the late answer must reach croc.
- The screenshot flags (`--screen`, `--stage`, `--seed-history`, `--hold`) are documented in `screenshots.md`.

`AutoVerify`'s bodies are `#if DEBUG`. In Release, `isHarnessRun` is a hardcoded `false` and `runIfRequested` is a no-op, so the harness cannot run in a store build. The type still exists in Release because `CrocAppApp.swift` and `ContentView.swift` call it unconditionally. The verify scripts build Debug.

`isHarnessRun` is true for any `--auto-*` mode or `--screen`. Settings overrides apply in any harness run. `CrocAppApp.init` builds `AppSettings` on `MemorySettingsStorage` and `MemorySecretStore` for it ("Settings and trust"), so the overrides start from the defaults and real `UserDefaults` and the Keychain are never touched.

Result files, all written to the container's Documents folder (hardcoded, independent of `OutputFolderStore.defaultFolder`):

| File | Content |
|---|---|
| `verify-result.txt` | `ok success=<bool>`, or `error <title>. <detail>` for a failure (`TransferFailure.text`; `scripts/verify-app-mac.sh` matches the expired-link title) |
| `verify-code-ready.txt` | `ready`, written once when the phase first reaches `.waiting` (a send has its code); both verify scripts wait for it |
| `verify-code.txt` | the generated or custom code |
| `verify-history.txt` | `records=N`, written when the transfer is done or failed (`scripts/verify-app-mac.sh` reads it) |
| `verify-phase.txt` | the current phase label; `transferring percent=N` reads `controller.progress` |
| `verify-ready.txt` | written once a `--screen` request has settled |

The result contract is shared by `scripts/verify-app-sim.sh` and `scripts/verify-app-mac.sh`.

Launch gotchas, both macOS:

- Once `CFBundleDocumentTypes` exists, bare adjacent argv tokens are document-open candidates and AppKit skips creating the default window. Use flag-style arguments only.
- Scripted launches need `-ApplePersistenceIgnoreState YES` or they hang in window restoration.
- A plain launch can come up with no window when the bundle ID carries leftover restoration state (`known-issues.md`, "A plain Mac launch can open with no window"). Test window behavior on a fresh bundle ID or pass the flag.

On the CLI side of a verify run, a receiving `croc` needs `CROC_SECRET=` in the environment instead of a positional code. croc refuses custom positional codes in non-classic mode for receive as well as send.
