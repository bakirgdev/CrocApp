# Glossary

Terms a new contributor or a fresh AI session hits in this repo and cannot infer from the name alone: croc protocol vocabulary, the Go/gomobile bridge, the SwiftUI app, and repo-local jargon. One dense line each; see `docs/knowledge/README.md` for the full-length files these definitions are summarized from.

## croc

| Term | Means |
|---|---|
| `--ask` | croc flag requiring confirmation on both sides before a transfer starts, not just the receiver's normal accept prompt; bridged into the engine via the same fd0 pipe trick as receive (`docs/knowledge/crocmobile-bridge.md`). |
| classic mode | croc's `--classic` flag, the only mode where `--code` accepts a custom secret directly; insecure by design and deliberately unsupported here (F39, `docs/knowledge/features.md`). |
| code phrase / secret | the `word-word-word` string (three random words from the EFF short wordlist) both sides use to find each other and derive the session key; custom via `CROC_SECRET`, min 6 chars (`docs/knowledge/what-is-croc.md`). |
| compression | croc DEFLATE-compresses (HuffmanOnly) file data by default; `--no-compress` disables it (F15). |
| `CROC_SECRET` | env var for a custom code phrase; the only way non-classic croc accepts one, on both send and receive (`docs/knowledge/what-is-croc.md`). |
| curve | the elliptic curve PAKE runs over, default P-256 (`--curve`, `crocmobile.Options.Curve`). |
| hash algorithm | integrity check for transferred files, default xxhash; alternatives imohash, md5, highway via `--hash` (`crocmobile.Options.HashAlgorithm`). |
| `--ignore-stdin` | croc CLI flag needed for non-interactive runs; the Go library equivalent (`Options.IgnoreStdin`) is always set `true` in `crocmobile/session.go`, since the app supplies its own prompt pipe instead of a real terminal. |
| LAN peer discovery | UDP multicast peer discovery (`schollz/peerdiscovery`, ~500 ms window) that lets same-network transfers skip the relay; not guaranteed to work on every network, see `docs/knowledge/what-is-croc.md` §6. |
| `--local` / only-local | forces a transfer to stay on the LAN, refusing the public relay; maps to `crocmobile.Options.OnlyLocal` / `AppSettings.onlyLocal` (F14). |
| PAKE | Password-Authenticated Key Exchange (`github.com/schollz/pake/v3`, Boneh-Shoup construction); turns the weak code phrase into a strong session key without the relay ever learning it (`docs/knowledge/what-is-croc.md`). |
| relay | the rendezvous/transport server both sides connect to when a direct LAN path is not available; sees ciphertext only. With no custom relay the default is croc's public relay pool (`1.getcroc.com:9009` to `4.getcroc.com:9009`), picked by the code; the old single default `croc.schollz.com:9009` survives as `models.DEFAULT_RELAY`, and a relay field equal to it means "not custom". |
| room | the rendezvous channel on the relay, named `SHA-256(selector + "croc")`, where the selector is the first word of a three-word code (the first 4 characters for a legacy code like `NNNN-word`); two codes sharing it on the same relay collide into the same room ("room full"). |
| shared secret prefix collision | the failure mode above: because the room name only hashes the code's selector (first word, or first 4 characters of a legacy code), concurrent transfers or test scripts using codes with the same selector collide (`docs/knowledge/crocmobile-bridge.md`). |
| Tailcat | croc v11's peer-to-peer data path: two native clients carry TCP streams over an in-process userspace WireGuard network that starts on DERP relays and moves to direct UDP when NAT traversal works. Under transport `auto` the sender offers it only for a send of 128 MiB or more and races it against the relay; setup contacts `tailcat.dev` and the `*.ipn.dev` DERP relays. Whether it stays in the build is decided on a physical iPhone (`docs/knowledge/device-test-checklist.md`, `docs/knowledge/crocmobile-bridge.md`). |
| transport / Connection | croc's sender-only `--transport` (`auto`, `relay`, `derp`), shown in the app as the Connection setting: Automatic (`auto`, default) or Relay only (`relay`); the app never offers `derp`. A receive and a local-only send are always `auto` (`crocmobile.Options.Transport`, `CrocKit.Transport`, `AppSettings.transport`, F41). |

## Go bridge

| Term | Means |
|---|---|
| `binaryTarget` | the `Package.swift` declaration (`CrocKit/Package.swift`) pointing `CrocKit` at the gitignored `Croc.xcframework`; nothing builds until `scripts/build-xcframework.sh` produces it. |
| delegate bridge | `DelegateBridge` (`CrocKit/Sources/CrocKit/DelegateBridge.swift`), the `NSObject` implementing gobind's `CrocmobileDelegateProtocol` and turning its callbacks (arrived on arbitrary Go threads) into `AsyncStream<TransferEvent>` yields. |
| event stream | the `AsyncStream<TransferEvent>` returned by `CrocEngine.startSend`/`startReceive`; abandoning it cancels the underlying Go session (`onTermination`). |
| failure code | the `code` in the `{"code","message"}` JSON that `OnError` and failed starts carry (`crocmobile/errors.go`), decoded in Swift as `EngineFailure.Code`; the app picks its copy from the code and never from croc's text (`docs/knowledge/crocmobile-bridge.md`). |
| gobind | the Go tool (part of gomobile) that generates the ObjC/Swift binding layer from the `crocmobile` package; source of the `Crocmobile`-prefixed symbols. |
| gomobile | the Go toolchain used to bind the `crocmobile` package into `Croc.xcframework` for iOS/macOS (`scripts/build-xcframework.sh`). |
| ObjC symbol prefix `Crocmobile` | gobind derives this from the Go package name `crocmobile`: `CrocmobileOptions`, `CrocmobileTransfer`, `CrocmobileStartSend`/`StartReceive`, protocol `CrocmobileDelegate` → Swift `CrocmobileDelegateProtocol` (`docs/knowledge/crocmobile-bridge.md`). |
| prompt pipe / fd0 dup2 | the mechanism bridging croc's stdin-read accept/decline prompt into Swift: a pipe's read end is `syscall.Dup2`'d onto fd 0 because croc's cached `bufio.Reader` was bound to fd 0 at package init and a plain `os.Stdin` variable swap does not reach it (`crocmobile/session.go`). |
| session | the Go `session` struct (`crocmobile/session.go`) that owns one active transfer's `croc.Client`, prompt pipe, and cleanup; `crocmobile` allows exactly one at a time via a package-level mutex. |
| `TransferEvent` | the Swift enum (`CrocKit/Sources/CrocKit/Models.swift`) carrying every event the engine can emit: `.codeReady`, `.connected`, `.fileList`, `.progress`, `.text`, `.done`, `.failed`. |
| xcframework | `CrocKit/Croc.xcframework`, the gomobile build output binding `crocmobile` for iOS, iOS Simulator, and macOS; gitignored, produced by `scripts/build-xcframework.sh`. |

## App

| Term | Means |
|---|---|
| `AppRouter` | `@Observable` singleton (`app/CrocApp/Models/AppRouter.swift`) holding the navigation path (both platforms), pending drop/dock URLs and a pending receive link (`pendingReceive`), needed because `AppDelegate` and menu commands sit outside the SwiftUI environment graph. |
| App Group | `group.com.bakirgdev.CrocApp`, the shared container the iOS share extension stages files into (`ShareInbox/batch-<UUID>/` + `manifest.json`) for the main app to pick up (`app/CrocApp/Models/ShareInbox.swift`). |
| `AutoVerify` harness | `app/CrocApp/Support/AutoVerify.swift`, launch-argument-driven code path (`--auto-receive`, `--auto-send`, `--ask`, etc.) that drives the real `TransferController` state machine instead of the engine directly, so verify scripts exercise the path users actually take. |
| `BGContinuedProcessingTask` | iOS 26+ API wrapping a transfer so it survives backgrounding and gets a system Live Activity; `app/CrocApp/Platform/BackgroundCoordinator.swift`, no macOS equivalent (`docs/knowledge/apple-platform-constraints.md`). |
| `CrocApp Direct` / `DIRECT` | the Developer ID (DMG) macOS target, bundle ID `com.bakirgdev.CrocApp.direct`, arm64 only; builds the `app/CrocApp/` sources plus `app/CrocAppDirect/` (Sparkle updater) under the Swift condition `DIRECT`. Product is `CrocApp.app`, same name as the App Store target (`docs/BUILDING.md` section 7). |
| output folder store | `OutputFolderStore` (`app/CrocApp/Models/OutputFolderStore.swift`), tracks the receive destination folder and its security-scope bookmark; defaults to `~/Downloads/CrocApp` on macOS, app Documents on iOS. |
| Keep Both / Replace | the receive file policy (`CrocKit.FilePolicy`, `AppSettings.whenFileExists`, Go consts `PolicyKeepBoth`/`PolicyReplace`) for a file whose name is taken: Keep Both saves the new one as `name (1).ext` (croc `--rename`), Replace overwrites and resumes (croc `--overwrite`). Chosen on the incoming sheet, or by the setting under auto-accept (`docs/knowledge/crocmobile-bridge.md`). |
| `Phase` | the enum on `TransferController` driving every view: `idle` → `starting` → `waiting`/`connecting` → `confirmSend` or `incoming` → `transferring` → `done` or `failed` (`app/CrocApp/Models/TransferController.swift`). |
| security-scoped resource | an Apple sandbox URL (from `fileImporter` or a bookmark) that needs `startAccessingSecurityScopedResource()` before use; both `TransferController` and `HistoryView` call it before touching a URL. |
| share extension (appex) | `CrocShare`, the iOS-only app extension (`app/CrocShare/`) that stages shared files into the App Group for later send; ~120 MB memory cap, no long-running work (`docs/knowledge/app-ui-architecture.md`). |
| `SwiftData` `TransferRecord` | the `@Model` type (`app/CrocApp/Models/TransferHistory.swift`) persisting one finished/failed transfer for local-only history (F12); never stores file contents or the full code phrase. |
| `TransferLink` | the one parser (`app/CrocApp/Models/TransferLink.swift`) for every form a code arrives in: bare code, `crocapp://receive?code=`, `croc://<code>`, `https://crocapp.dev/r/#<code>`, `https://getcroc.com/?code=`. `TransferLink.webURL(forCode:)` builds the `crocapp.dev/r/` link. Opening one prefills Receive and never connects. |
| trust badge | `TrustBadge` view (`app/CrocApp/Views/TrustBadge.swift`), shown in waiting/transferring/confirm-send screens, reading `TransferController.activeRelay` captured at transfer start (F36). |
| web link / link page | `https://crocapp.dev/r/#<code>`, the waiting-screen QR and Share Link payload, served by `web/landing/r/index.html`. The code sits in the fragment, so browsers never send it to a server; the page makes no network request. It offers Open in CrocApp, the App Store, the DMG, and Receive in your browser (croc's own web app at getcroc.com, which serves the JavaScript that decrypts). |
| `TransferController` | `@MainActor @Observable` (`app/CrocApp/Models/TransferController.swift`), the sole consumer of `CrocKit` in the app; owns `Phase` and all engine event handling. |

## Apple platform

| Term | Means |
|---|---|
| entitlement | an Apple capability grant declared in a `.entitlements` file (`app/CrocApp/CrocApp.entitlements`, `CrocApp-iOS.entitlements`, `app/CrocAppDirect/CrocAppDirect.entitlements`, `app/CrocShare/CrocShare.entitlements`); e.g. `network.client`/`network.server` for the sandboxed Mac build, `files.downloads.read-write` for the default output folder. |
| MAS vs Developer ID | the two macOS distribution paths: Mac App Store (sandbox mandatory) vs. direct-download Developer ID (notarized DMG, sandbox optional); separate `Config/ExportOptions-{MAS,DevID}.plist` (iOS has its own `ExportOptions-iOS.plist`; `scripts/build-appstore.sh` uses the iOS and MAS ones). |
| notarization | Apple's malware scan required before a Developer ID build runs without warnings on a fresh Mac; `scripts/build-devid.sh` submits the app and the disk image with `notarytool submit --wait` (`docs/BUILDING.md`, section 7). |
| `PrivacyInfo.xcprivacy` | Apple's required privacy manifest, present in both `app/CrocApp/` and `app/CrocShare/`; declares accessed API categories (UserDefaults, FileTimestamp, SystemBootTime) and no tracking/collection. |
| Sparkle | the macOS auto-update framework (2.10.0, SwiftPM), linked into `CrocApp Direct` only; checks `SPARKLE_FEED_URL` for an appcast signed with an Ed25519 key (`SPARKLE_PUBLIC_ED_KEY`, the owner's release public key). |
| stapling | attaching Apple's notarization ticket to a build (`xcrun stapler staple`) so first launch works offline; `scripts/build-devid.sh` staples the app and the disk image. |

## Repo conventions

| Term | Means |
|---|---|
| design token | a named value (color, spacing, type, motion) in `design/`, the only source of such values allowed in app or web code; no raw hex/px (`design/CLAUDE.md`). |
| harness | one of the `scripts/verify-*.sh` scripts, or `crockit-verify`; proves a real transfer works against the croc CLI, since a green build alone is not evidence. |
| self-heal | the end-of-session rule (root `CLAUDE.md`, "Session end report") that `docs/knowledge/` and `docs/known-issues.md` are updated to match reality before a session ends. |
| verify script | any `scripts/verify-*.sh` harness; needs outbound network to the public relay plus a `croc` CLI; CI runs only `verify-interop.sh`, against a local relay (`docs/knowledge/tooling.md`, `CONTRIBUTING.md`). |
| xcframework build step | `scripts/build-xcframework.sh`, the required first build step on a fresh clone: Go compile + gomobile bind into `CrocKit/Croc.xcframework`. |
