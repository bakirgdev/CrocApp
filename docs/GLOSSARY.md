# Glossary

Terms a new contributor hits in this repo and cannot infer from the name: croc vocabulary, the Go bridge, the app, and Apple platform and repo terms. Each entry is one or two short sentences plus where to look. Longer detail lives in the file linked from the entry.

## croc

| Term | Means |
| --- | --- |
| `--ask` | croc flag that makes both sides confirm before a transfer starts. The app calls it **Confirm on Both Sides**. It uses the same prompt-pipe trick as receive (`docs/knowledge/crocmobile-bridge.md`). |
| classic mode | croc's `--classic` flag. It is the only mode where `--code` takes a custom secret directly, and it is insecure by design. CrocApp does not support it. |
| code phrase | The `word-word-word` string (three random words from the EFF short wordlist) that both devices use to find each other and derive the session key. A custom one comes from `CROC_SECRET`, at least 6 characters (`docs/knowledge/what-is-croc.md`). croc calls it the "secret"; the UI says only "code phrase" (`design/content.md`, "Terminology"). |
| compression | croc compresses file data with DEFLATE (HuffmanOnly) by default. `--no-compress` turns it off. |
| `CROC_SECRET` | Environment variable that sets a custom code phrase. Outside classic mode it is the only way to do that, for both send and receive. |
| `--ignore-stdin` | croc flag for non-interactive runs. The library option `IgnoreStdin` is always true in `crocmobile/session.go`, because the app supplies its own prompt pipe. |
| LAN peer discovery | Finding a same-network peer by UDP multicast (`schollz/peerdiscovery`, 500 ms cap) so the transfer skips the relay. It does not work on every network (`docs/knowledge/what-is-croc.md`, "Local path"). |
| `--local` / local only | Keeps a transfer on the local network and refuses the public relay. The app setting is **Local Network Only** (`AppSettings.onlyLocal`, `crocmobile.Options.OnlyLocal`). |
| sender IP | Receive-side Advanced setting (`AppSettings.peerIP`, `EngineOptions.peerIP`, croc `--ip`). It is the sender's `ip:port` (IPv4 or bracketed IPv6). The receiver connects straight to the sender's local relay, skipping relays, discovery and the public pool. The trust badge then shows `RelayKind.directToSender`. |
| Advanced settings | The Advanced page for croc's upload limit, multicast address, sender IP and proxies. Code: `AdvancedSettingsView`, keys `settings.advanced.*` (`AppSettings`), proxies in the Keychain. See `docs/knowledge/app-ui-architecture.md`, "Advanced settings". |
| menu-bar quick send | macOS only. A `MenuBarExtra` window (`MenuBarQuickSendView`, driven by `MenuBarQuickSend`) that sends on the one shared `TransferController`. It shows while **Show in Menu Bar** (`AppSettings.showInMenuBar`) is on. `LoginItem` wraps `SMAppService.mainApp` for **Open at login**. See `docs/knowledge/app-ui-architecture.md`, "Menu bar and Shortcuts". |
| App Shortcut / App Intent | `SendFilesIntent`, `SendTextIntent` and `ReceiveIntent` in `app/CrocApp/Intents/`, offered by `CrocAppShortcuts` with Siri and Spotlight phrases. They run in the foreground and reach `TransferController` and `OutputFolderStore` through `AppDependencyManager`. See `docs/knowledge/app-ui-architecture.md`, "Menu bar and Shortcuts". |
| PAKE | Password-Authenticated Key Exchange (`github.com/schollz/pake/v3`). It turns the weak code phrase into a strong session key, and the relay never learns it. |
| relay | The server both sides connect to when no direct local path works. It sees only ciphertext. With no custom relay, croc's public pool is used (`1.getcroc.com:9009` to `4.getcroc.com:9009`), chosen from the code. A relay field equal to croc's single-server default `croc.schollz.com:9009` (`models.DEFAULT_RELAY`) means "not custom". |
| room | The channel on the relay where two peers meet. Its name is a hash of a selector taken from the code (`docs/knowledge/what-is-croc.md`, "Rendezvous"). |
| room collision | Two codes with the same selector on the same relay land in the same room, and the second gets "room full". Concurrent transfers and test scripts must use codes with different selectors (`docs/knowledge/what-is-croc.md`, "Rendezvous"). |
| stored transfer | croc's upload-and-link mode (`croc send --store`, default server `https://getcroc.com`). Files are encrypted on the device, uploaded, and fetched later from `https://<host>/s/<id>#v1.<key>`, where the fragment is the key. There is no peer, relay or code phrase. The app calls it **Send as link** (`docs/knowledge/app-ui-architecture.md`, "Stored transfers"). |
| Tailcat | croc v11's peer-to-peer data path (`docs/knowledge/what-is-croc.md`, "Transport"). CrocApp is built without it (`croc_no_tailcat`), so `auto` means the relay and the LAN (`docs/knowledge/crocmobile-bridge.md`, "Transport").
| transport | croc's sender-only `--transport` (`auto`, `relay`, `derp`). CrocApp has no setting for it: the relay-only build makes `auto` the relay and the LAN, and a CLI sender that asks for `derp` makes a CrocApp receiver fail (`docs/knowledge/crocmobile-bridge.md`, "Transport"). |

## Go bridge

| Term | Means |
| --- | --- |
| `binaryTarget` | The `CrocKit/Package.swift` declaration that points `CrocKit` at the gitignored `Croc.xcframework`. Nothing builds until `scripts/build-xcframework.sh` produces it. |
| delegate bridge | `DelegateBridge` (`CrocKit/Sources/CrocKit/DelegateBridge.swift`). It implements gobind's `CrocmobileDelegateProtocol` and turns callbacks from Go threads into `AsyncStream<TransferEvent>` yields. |
| event stream | The `AsyncStream<TransferEvent>` that `CrocEngine.startSend` and `startReceive` return. Letting it end (`onTermination`) cancels the Go session. |
| failure code | The `code` in the `{"code","message"}` JSON that `OnError` and failed starts carry (`crocmobile/errors.go`). Swift decodes it as `EngineFailure.Code`. The app picks its wording from the code, never from croc's text. |
| gobind | The gomobile tool that generates the Objective-C and Swift binding layer from the `crocmobile` package. It is the source of the `Crocmobile`-prefixed symbols. |
| gomobile | The Go toolchain that binds `crocmobile` into `Croc.xcframework` (`scripts/build-xcframework.sh`). |
| `Crocmobile` prefix | gobind adds it to the Go package name `crocmobile`: `CrocmobileOptions`, `CrocmobileTransfer`, `CrocmobileStartSend`. The Go interface `Delegate` is the Objective-C protocol `CrocmobileDelegate`, imported in Swift as `CrocmobileDelegateProtocol`. |
| prompt pipe / fd0 dup2 | How the app answers croc's accept prompt, which reads stdin. A pipe's read end is `syscall.Dup2`'d onto fd 0, because croc's cached `bufio.Reader` is tied to fd 0 and swapping `os.Stdin` would not reach it (`crocmobile/session.go`). |
| session | The Go `session` struct (`crocmobile/session.go`). It owns one transfer's `croc.Client`, prompt pipe and cleanup. A package-level mutex allows one at a time. |
| `TransferEvent` | The Swift enum in `CrocKit/Sources/CrocKit/Models.swift` for everything the engine reports: `.codeReady`, `.connected`, `.fileList`, `.progress`, `.text`, `.stored`, `.done`, `.failed`. |
| xcframework | `CrocKit/Croc.xcframework`, the gomobile output that binds `crocmobile` for iOS, iOS Simulator and macOS. Gitignored. Built by `scripts/build-xcframework.sh`, the required first build step on a fresh clone. |

## App

| Term | Means |
| --- | --- |
| `AppRouter` | `@Observable` singleton (`app/CrocApp/Models/AppRouter.swift`). It holds the navigation path, URLs dropped on the window or Dock, and a pending receive link (`pendingReceive`). It is a singleton because `AppDelegate` and menu commands sit outside the SwiftUI environment. |
| App Group | `group.com.bakirgdev.CrocApp`, the shared container where the iOS share extension stages files for the app (`ShareInbox/batch-<UUID>/` plus `manifest.json`). App side: `app/CrocApp/Models/ShareInbox.swift`. |
| `AutoVerify` harness | `app/CrocApp/Support/AutoVerify.swift`. Launch arguments (`--auto-receive`, `--auto-send`, `--ask` and others) drive the real `TransferController`, so verification scripts take the path users take. |
| `BGContinuedProcessingTask` | The iOS 26 API that keeps a transfer running in the background and shows a system Live Activity. Code: `app/CrocApp/Platform/BackgroundCoordinator.swift`. macOS has no equivalent (`docs/knowledge/apple-platform-constraints.md`). |
| `CrocApp Direct` / `DIRECT` | The macOS Developer ID target for the direct download: bundle ID `com.bakirgdev.CrocApp.direct`, arm64 only. It builds `app/CrocApp/` plus `app/CrocAppDirect/` (the Sparkle updater) under the Swift condition `DIRECT`. Its product is `CrocApp.app`, the same name as the App Store target. See `docs/RELEASING.md`, "Direct download (Developer ID)". |
| output folder store | `OutputFolderStore` (`app/CrocApp/Models/OutputFolderStore.swift`). It tracks the receive folder and its security-scoped bookmark. Default: `~/Downloads/CrocApp` on macOS, the app's Documents folder on iOS. |
| Keep Both / Replace | The receive policy for a file whose name is taken (`CrocKit.FilePolicy`, `AppSettings.whenFileExists`, Go `PolicyKeepBoth` and `PolicyReplace`). Keep Both saves `name (1).ext` (croc `--rename`). Replace overwrites and resumes (croc `--overwrite`). The user picks on the incoming sheet, or the setting applies under auto-accept. |
| `Phase` | The enum on `TransferController` that every view switches on (cases: `docs/ARCHITECTURE.md`, "TransferController"). |
| security-scoped resource | A sandboxed URL (from `fileImporter` or a bookmark) that needs `startAccessingSecurityScopedResource()` before use. `TransferController` and `HistoryView` both call it. |
| share extension (appex) | `CrocShare` (`app/CrocShare/`), the iOS-only extension that stages shared files in the App Group. Memory cap about 120 MB, no long work. |
| receipt | `StoredReceipt` (CrocKit): what a stored upload returns (id, origin, upload token, link, expiry, download count). Only `StoredTransferVault` (Keychain) holds it. History keeps just the id, host and expiry. |
| revoke | Deleting a stored upload from its server with the upload token (`TransferController.revoke`, **Revoke Link** in History). A server that no longer has it counts as success. Possible only while the receipt is in the vault. |
| `StoredTransferVault` | The Keychain store of stored-upload receipts (`app/CrocApp/Models/StoredTransferVault.swift`). It holds the upload token and link that History needs to revoke and must never hold itself. |
| `TransferRecord` | The SwiftData `@Model` (`app/CrocApp/Models/TransferHistory.swift`) for one finished or failed transfer in the local-only history. It never stores file contents or the full code phrase. |
| `TransferLink` | The one parser (`app/CrocApp/Models/TransferLink.swift`) for every form a code or link arrives in: bare code, stored link, `crocapp://receive?code=`, `croc://<code>`, `https://crocapp.dev/r/#<code>`, `https://getcroc.com/?code=`. `TransferLink.webURL(forCode:)` builds the `crocapp.dev/r/` link. Opening a link fills in Receive and never connects. |
| trust badge | The `TrustBadge` view (`app/CrocApp/Views/TrustBadge.swift`). It shows how the transfer is routed and that it is end-to-end encrypted, on Home, How It Works and the waiting, confirm, incoming and transferring screens. It reads `TransferController.activeRelay`, captured when the transfer starts. |
| web link / link page | `https://crocapp.dev/r/#<code>`, the payload of the waiting-screen QR code and **Share Link** (page: `web/landing/r/index.html`). The code is in the fragment, so browsers do not send it to a server, and the page makes no network request. It offers Open in CrocApp, the App Store, the DMG, and Receive in your browser (croc's own web app at getcroc.com). |
| `TransferController` | `@MainActor @Observable` (`app/CrocApp/Models/TransferController.swift`). The only caller of `CrocEngine`. It owns `Phase` and handles every engine event. |

## Apple platform

| Term | Means |
| --- | --- |
| entitlement | A capability grant in a `.entitlements` file: `app/CrocApp/CrocApp.entitlements`, `CrocApp-iOS.entitlements`, `app/CrocAppDirect/CrocAppDirect.entitlements`, `app/CrocShare/CrocShare.entitlements`. Example: `files.downloads.read-write` for the default Mac output folder. |
| MAS vs Developer ID | The two macOS distribution paths. Mac App Store: sandbox required. Developer ID: a notarized DMG you host yourself. Export options live in `app/Config/ExportOptions-MAS.plist` and `ExportOptions-DevID.plist`; iOS has `ExportOptions-iOS.plist` (`docs/RELEASING.md`, "Release channels"). |
| notarization | Apple's malware scan, required before a Developer ID build opens without warnings on a fresh Mac. `scripts/build-devid.sh` submits the app and the disk image with `notarytool submit --wait`. |
| `PrivacyInfo.xcprivacy` | Apple's privacy manifest. The app's declares the API categories it uses (UserDefaults, FileTimestamp, SystemBootTime), no tracking and no collected data. `CrocShare`'s declares none of those. |
| Sparkle | The macOS auto-update framework (2.10.1, SwiftPM), linked into `CrocApp Direct` only. It reads `SPARKLE_FEED_URL` for an appcast signed with an Ed25519 key (`SPARKLE_PUBLIC_ED_KEY`, the public half). |
| stapling | Attaching Apple's notarization ticket to a build (`xcrun stapler staple`) so first launch works offline. `scripts/build-devid.sh` staples the app and the disk image. |

## Repo conventions

| Term | Means |
| --- | --- |
| design token | A named value (color, spacing, type, motion) in `design/`. It is the only allowed source of such values in app or web code: no raw hex or px (`design/AGENTS.md`). |
| harness | A script or tool that proves a real transfer works against the croc command: `scripts/verify-interop.sh`, `scripts/verify-app-mac.sh`, `scripts/verify-app-sim.sh` and `crockit-verify`. A green build alone is not evidence. `docs/BUILDING.md`, "Verification harnesses". |
| verify script | Any `scripts/verify-*.sh`. The transfer ones need outbound network to the public relay plus a `croc` command. CI runs `verify-interop.sh` against a local relay and `verify-design.sh`, which needs no network (`docs/knowledge/tooling.md`, `CONTRIBUTING.md`). |
