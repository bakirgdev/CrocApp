# Glossary

Terms a new contributor or a fresh AI session hits in this repo and cannot infer from the name alone: croc protocol vocabulary, the Go/gomobile bridge, the SwiftUI app, and repo-local jargon. One dense line each; see `docs/knowledge/README.md` for the full-length files these definitions are summarized from.

## croc

| Term | Means |
|---|---|
| `--ask` | croc flag requiring confirmation on both sides before a transfer starts, not just the receiver's normal accept prompt; bridged into the engine via the same fd0 pipe trick as receive (`docs/knowledge/crocmobile-bridge.md`, ADR 0012). |
| classic mode | croc's `--classic` flag, the only mode where `--code` accepts a custom secret directly; insecure by design and deliberately unsupported here (F39, `docs/knowledge/features.md`). |
| code phrase / secret | the `NNNN-word-word-word` string (4-digit PIN + mnemonicode words) both sides use to find each other and derive the session key; custom via `CROC_SECRET`, min 6 chars (`docs/knowledge/what-is-croc.md`). |
| compression | croc DEFLATE-compresses (HuffmanOnly) file data by default; `--no-compress` disables it (F15). |
| `CROC_SECRET` | env var for a custom code phrase; the only way non-classic croc accepts one, on both send and receive (`docs/knowledge/what-is-croc.md`). |
| curve | the elliptic curve PAKE runs over, default P-256 (`--curve`, `crocmobile.Options.Curve`); SIEC was the original default, dropped after cryptographer criticism. |
| hash algorithm | integrity check for transferred files, default xxhash; alternatives imohash, md5, highway via `--hash` (`crocmobile.Options.HashAlgorithm`). |
| `--ignore-stdin` | croc CLI flag needed for non-interactive runs; the Go library equivalent (`Options.IgnoreStdin`) is always set `true` in `crocmobile/session.go`, since the app supplies its own prompt pipe instead of a real terminal. |
| LAN peer discovery | UDP multicast peer discovery (`schollz/peerdiscovery`, ~500 ms window) that lets same-network transfers skip the relay; not guaranteed to work on every network, see `docs/knowledge/what-is-croc.md` §6. |
| `--local` / only-local | forces a transfer to stay on the LAN, refusing the public relay; maps to `crocmobile.Options.OnlyLocal` / `AppSettings.onlyLocal` (F14). |
| PAKE | Password-Authenticated Key Exchange (`github.com/schollz/pake/v3`, Boneh-Shoup construction); turns the weak code phrase into a strong session key without the relay ever learning it (`docs/knowledge/what-is-croc.md`). |
| relay | the rendezvous/transport server both sides connect to when a direct LAN path is not available; sees ciphertext only, default `croc.schollz.com:9009`. |
| room | the rendezvous channel on the relay, named `SHA-256(secret[:4] + "croc")`; two codes sharing their first 4 characters collide into the same room ("room full"). |
| shared secret prefix collision | the failure mode above: because the room name only hashes the first 4 characters of the secret, concurrent transfers or test scripts using codes with the same prefix collide (`docs/knowledge/crocmobile-bridge.md`). |

## Go bridge

| Term | Means |
|---|---|
| `binaryTarget` | the `Package.swift` declaration (`CrocKit/Package.swift`) pointing `CrocKit` at the gitignored `Croc.xcframework`; nothing builds until `scripts/build-xcframework.sh` produces it (ADR 0006). |
| delegate bridge | `DelegateBridge` (`CrocKit/Sources/CrocKit/DelegateBridge.swift`), the `NSObject` implementing gobind's `CrocmobileDelegateProtocol` and turning its callbacks (arrived on arbitrary Go threads) into `AsyncStream<TransferEvent>` yields. |
| event stream | the `AsyncStream<TransferEvent>` returned by `CrocEngine.startSend`/`startReceive`; abandoning it cancels the underlying Go session (`onTermination`, ADR 0008). |
| gobind | the Go tool (part of gomobile) that generates the ObjC/Swift binding layer from the `crocmobile` package; source of the `Crocmobile`-prefixed symbols. |
| gomobile | the Go toolchain used to bind the `crocmobile` package into `Croc.xcframework` for iOS/macOS (`scripts/build-xcframework.sh`, ADR 0006). |
| ObjC symbol prefix `Crocmobile` | gobind derives this from the Go package name `crocmobile`: `CrocmobileOptions`, `CrocmobileTransfer`, `CrocmobileStartSend`/`StartReceive`, protocol `CrocmobileDelegate` → Swift `CrocmobileDelegateProtocol` (`docs/knowledge/crocmobile-bridge.md`). |
| prompt pipe / fd0 dup2 | the mechanism bridging croc's stdin-read accept/decline prompt into Swift: a pipe's read end is `syscall.Dup2`'d onto fd 0 because croc's cached `bufio.Reader` was bound to fd 0 at package init and a plain `os.Stdin` variable swap does not reach it (`crocmobile/session.go`, ADR 0008). |
| session | the Go `session` struct (`crocmobile/session.go`) that owns one active transfer's `croc.Client`, prompt pipe, and cleanup; `crocmobile` allows exactly one at a time via a package-level mutex (ADR 0008). |
| `TransferEvent` | the Swift enum (`CrocKit/Sources/CrocKit/Models.swift`) carrying every event the engine can emit: `.codeReady`, `.connected`, `.fileList`, `.progress`, `.text`, `.done`, `.failed`. |
| xcframework | `CrocKit/Croc.xcframework`, the gomobile build output binding `crocmobile` for iOS, iOS Simulator, and macOS; gitignored, produced by `scripts/build-xcframework.sh`. |

## App

| Term | Means |
|---|---|
| `AppRouter` | `@Observable` singleton (`app/CrocApp/Models/AppRouter.swift`) holding the macOS navigation path and pending drop/dock URLs, needed because `AppDelegate` and menu commands sit outside the SwiftUI environment graph. |
| App Group | `group.com.bakirgdev.CrocApp`, the shared container the iOS share extension stages files into (`ShareInbox/batch-<UUID>/` + `manifest.json`) for the main app to pick up (`app/CrocApp/Models/ShareInbox.swift`, ADR 0010). |
| `AutoVerify` harness | `app/CrocApp/Support/AutoVerify.swift`, launch-argument-driven code path (`--auto-receive`, `--auto-send`, `--ask`, etc.) that drives the real `TransferController` state machine instead of the engine directly, so verify scripts exercise the path users actually take. |
| `BGContinuedProcessingTask` | iOS 26+ API wrapping a transfer so it survives backgrounding and gets a system Live Activity; `app/CrocApp/Platform/BackgroundCoordinator.swift`, no macOS equivalent (`docs/knowledge/apple-platform-constraints.md`). |
| output folder store | `OutputFolderStore` (`app/CrocApp/Models/OutputFolderStore.swift`), tracks the receive destination folder and its security-scope bookmark; defaults to `~/Downloads/CrocApp` on macOS, app Documents on iOS. |
| `Phase` | the enum on `TransferController` driving every view: `idle` → `starting` → `waiting`/`connecting` → `confirmSend` or `incoming` → `transferring` → `done` or `failed` (`app/CrocApp/Models/TransferController.swift`). |
| security-scoped resource | an Apple sandbox URL (from `fileImporter` or a bookmark) that needs `startAccessingSecurityScopedResource()` before use; both `TransferController` and `HistoryView` call it before touching a URL. |
| share extension (appex) | `CrocShare`, the iOS-only app extension (`app/CrocShare/`) that stages shared files into the App Group for later send; ~120 MB memory cap, no long-running work (`docs/knowledge/app-ui-architecture.md`). |
| `SwiftData` `TransferRecord` | the `@Model` type (`app/CrocApp/Models/TransferHistory.swift`) persisting one finished/failed transfer for local-only history (F12, ADR 0013); never stores file contents or the full code phrase. |
| trust badge | `TrustBadge` view (`app/CrocApp/Views/TrustBadge.swift`), shown in waiting/transferring/confirm-send screens, reading `TransferController.activeRelay` captured at transfer start (F36, ADR 0012). |
| `TransferController` | `@MainActor @Observable` (`app/CrocApp/Models/TransferController.swift`), the sole consumer of `CrocKit` in the app; owns `Phase` and all engine event handling. |

## Apple platform

| Term | Means |
|---|---|
| entitlement | an Apple capability grant declared in a `.entitlements` file (`app/CrocApp/CrocApp.entitlements`, `CrocApp-iOS.entitlements`, `app/CrocShare/CrocShare.entitlements`); e.g. `network.client`/`network.server` for the sandboxed Mac build, `files.downloads.read-write` for the default output folder. |
| MAS vs Developer ID | the two macOS distribution paths: Mac App Store (sandbox mandatory) vs. direct-download Developer ID (notarized DMG, sandbox optional); separate `Config/ExportOptions-{MAS,DevID}.plist` (ADR 0007, ADR 0011). |
| notarization | Apple's malware scan required before a Developer ID build runs without warnings on a fresh Mac; `scripts/build-devid.sh` currently only runs the `syspolicy_check distribution` dry run, not the real `notarytool submit --wait` (`docs/knowledge/tooling.md`). |
| `PrivacyInfo.xcprivacy` | Apple's required privacy manifest, present in both `app/CrocApp/` and `app/CrocShare/`; declares accessed API categories (UserDefaults, FileTimestamp) and no tracking/collection. |
| stapling | attaching Apple's notarization ticket to a build (`xcrun stapler staple`) so first launch works offline; not yet implemented, blocking the Homebrew cask channel (ADR 0007, `docs/knowledge/tooling.md`). |

## Repo conventions

| Term | Means |
|---|---|
| ADR | Architecture Decision Record, `docs/decisions/NNNN-slug.md`; a reversed decision gets a new ADR marked `Status: superseded by NNNN` on the old one rather than an edit (`docs/decisions/README.md`). |
| design token | a named value (color, spacing, type, motion) in `design/`, the only source of such values allowed in app or web code; no raw hex/px (`design/README.md`, ADR 0015). |
| harness | one of the `scripts/verify-*.sh` scripts, or `crockit-verify`; proves a real transfer works against the croc CLI, since a green build alone is not evidence. |
| self-heal | the end-of-session rule (root `CLAUDE.md`) that ADRs, `docs/knowledge/`, and `docs/known-issues.md` are updated to match reality before a session ends. |
| verify script | any `scripts/verify-*.sh` harness; needs outbound network to the public relay plus a `croc` CLI, and is not run by CI (`docs/knowledge/tooling.md`, `CONTRIBUTING.md`). |
| xcframework build step | `scripts/build-xcframework.sh`, the required first build step on a fresh clone: Go compile + gomobile bind into `CrocKit/Croc.xcframework`. |
