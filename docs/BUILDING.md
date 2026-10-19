# Building CrocApp from source

The exact toolchain and the steps from a fresh clone to a running app, plus how to lint, test and verify a change. Signing, notarization, Sparkle and App Store uploads are in `RELEASING.md`.

## Prerequisites

| Tool | Required version | Pinned in | Install (macOS) |
|---|---|---|---|
| Host OS | macOS 26 | `CONTRIBUTING.md`, "Setup" | n/a |
| Xcode | the version in `.xcode-version` | `.xcode-version` | Apple Developer downloads, or `xcodes install $(cat .xcode-version)` |
| Go | `>= 1.27.2` | `crocmobile/go.mod` (`go 1.27.2`) | `brew install go` |
| gomobile, gobind | the `golang.org/x/mobile` version in the `tool` block of `crocmobile/go.mod` | `scripts/build-xcframework.sh` rebuilds both into `.tools/` on every run | nothing to install by hand |
| swift-format | bundled with the pinned Xcode (Swift 6.4 toolchain), not versioned separately | `.swift-format` holds the rules | none, run `scripts/format-swift.sh` |
| golangci-lint | `2.x`; CI pins `v2.15.0` | `.github/workflows/reusable-go.yml`; rules in `crocmobile/.golangci.yml` (`version: "2"` schema) | `brew install golangci-lint` |
| govulncheck | the `golang.org/x/vuln` version in the `tool` block of `crocmobile/go.mod` | `.github/workflows/reusable-go.yml` | `cd crocmobile && go tool govulncheck ./...` |
| create-dmg | unpinned | `.github/workflows/release.yml` installs it with `brew` | `brew install create-dmg`; only `scripts/build-dmg.sh` needs it |
| croc CLI | `v11.5.4`, the version the embedded engine uses | `crocmobile/go.mod` (`github.com/schollz/croc/v11`) | `brew install croc` (lands at `$HOMEBREW_PREFIX/bin/croc`, the harnesses' default). `croc --version` must match the pin; if the bottle lags, use `go install github.com/schollz/croc/v11@<pin>` and point `CROC` at it; only `scripts/verify-*.sh` and `crockit-verify` need it |

## First build

Nothing Swift builds before the xcframework exists. `CrocKit/Package.swift` declares:

```swift
.binaryTarget(name: "Croc", path: "Croc.xcframework"),
```

`CrocKit/Croc.xcframework/` is gitignored (gomobile build output), so a fresh clone has no file there and every Swift build fails until one exists. `scripts/build-xcframework.sh` is step one.

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

The shared schemes `CrocApp`, `CrocApp Direct` and `CrocShare` are committed under `app/CrocApp.xcodeproj/xcshareddata/xcschemes/`, so `xcodebuild -scheme CrocApp` works on a fresh clone without opening Xcode.

- `CrocApp` builds the app and tests `CrocAppTests`.
- `CrocApp Direct` is the Developer ID build (`RELEASING.md`, "Release channels"). It has no testables.
- A new target needs its scheme committed there too. Per-user schemes in `xcuserdata/` stay gitignored.

CI builds with these commands (run from `app/`). Add the `SWIFT_TREAT_WARNINGS_AS_ERRORS` and `GCC_TREAT_WARNINGS_AS_ERRORS` flags (see "Build settings that must not change casually") to reproduce a CI failure:

```bash
xcodebuild -scheme CrocApp -destination 'platform=macOS' \
  -derivedDataPath "$TMPDIR/dd" CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme CrocApp -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$TMPDIR/dd" CODE_SIGNING_ALLOWED=NO build
```

The iOS Simulator destination needs the SDK, not an installed simulator runtime. `scripts/verify-app-sim.sh` is the only script that boots a simulator.

## What build-xcframework.sh does

The script builds gomobile and gobind from the `tool` block into `.tools/` (prepended to its own `PATH`), then `cd`s into `crocmobile/`, runs `go mod download`, and runs:

```bash
gomobile bind \
  -target ios,iossimulator,macos/arm64 \
  -iosversion 26.0 -macosversion 26.0 \
  -o "../CrocKit/Croc.xcframework" \
  .
```

- **Targets**: `ios`, `iossimulator`, `macos/arm64`. There is no `macos/amd64` slice.
- **`-iosversion` and `-macosversion`**: both `26.0`, matching the deployment target everywhere else.
- **Output**: `CrocKit/Croc.xcframework`, removed and rebuilt on every run.
- **Why arm64 only on macOS**: [golang/go#73119](https://github.com/golang/go/issues/73119), gomobile cannot produce a multi-arch macOS bind. The xcframework has no `x86_64` slice, so Intel Macs that can otherwise run macOS 26 (the 2019 MacBook Pro 16", 2020 iMac, 2019 Mac Pro) cannot run CrocApp. The pbxproj pins `ARCHS[sdk=macosx*] = arm64` for this reason. Removing that pin does not restore Intel support, it breaks the link.
- **iOS device archives**: [golang/go#66500](https://github.com/golang/go/issues/66500) is a device-slice layout issue that affects App Store archives. x/mobile fixes it (CL 574055 and 575115), and the pinned x/mobile includes the fix. The framework `Info.plist` keeps gomobile's `MinimumOSVersion = 100.0` (an SwiftPM workaround in x/mobile) and App Store Connect accepts it, so the script does not patch it.

If a new x/mobile release regresses the bind, pin `golang.org/x/mobile` to the last good version in `crocmobile/go.mod` and record it in `docs/knowledge/tooling.md`.

## Format and lint

Exact command CI runs, from the repo root:

```bash
scripts/format-swift.sh --lint
```

It is the only Swift lint check CI runs. Locally, run it without the flag to rewrite files first; the script lints afterwards either way:

```bash
scripts/format-swift.sh
```

The script owns the list of paths swift-format covers: `app/CrocApp`, `app/CrocAppDirect`, `app/CrocShare`, `app/CrocAppTests`, `CrocKit/Sources`, `CrocKit/Tests`, `CrocKit/Package.swift` and `scripts/screenshots`. Add a new Swift target there, so CI and every doc pick it up at once. `CrocKit` is listed path by path because a recursive run on it descends into `.build/` and `Croc.xcframework/`.

**Trap**: `format --in-place` does not fix lint-only rules. Several enabled rules only flag and never rewrite (for example `ReplaceForEachWithForLoop`, `OnlyOneTrailingClosureArgument`, `AlwaysUseLowerCamelCase`). A clean `format` run is not evidence that `lint --strict` passes, which is why the script always runs both. The full list is in `docs/knowledge/tooling.md`, "swift-format traps".

Go, from `crocmobile/`:

```bash
go build ./...
go vet ./...
env -u GOOS -u GOARCH go test -race ./...
golangci-lint run ./...
go tool govulncheck ./...
```

Swift unit tests, after `scripts/build-xcframework.sh`:

```bash
swift test --package-path CrocKit
(cd app && xcodebuild test -scheme CrocApp -destination 'platform=macOS')
```

Design and docs, no toolchain needed:

```bash
scripts/verify-design.sh   # token mirrors, contrast, no literals (design/AGENTS.md)
scripts/verify-docs.sh     # links, repo paths and stale markers in the markdown (docs/AGENTS.md)
```

CI runs the Go checks with `GOOS=darwin GOARCH=arm64` set for the whole job, so `go build` and `go vet` analyze the platform the code ships on while running on a cheap Linux runner. Only `go test` unsets them. See "Troubleshooting" for the `go install` trap this causes.

## Tests

Every suite is a unit test with no network. Transfers are proven by the harnesses below.

| Suite | Run with | Covers |
|---|---|---|
| `crocmobile/*_test.go` (Go `testing`, plus `Fuzz*` targets) | `go test -race ./...` in `crocmobile/` | `session_test.go`: option mapping, prompt answers and policy, progress and file-list JSON, name handling. `errors_test.go`: error classification. `network_test.go`: Advanced option validation and the process-global network state. `relay_test.go`: public relay pool and code-to-relay mapping. `store_test.go`: stored transfers (send, receive, revoke, limits) |
| `CrocKit/Tests/CrocKitTests` (Swift Testing) | `swift test --package-path CrocKit` | `CrocOptionsMappingTests`: Swift options to the Go struct. `DelegateBridgeTests`: callbacks to the event stream. `EngineFailureTests`: failure codes. `SendPathValidationTests`: refused send paths. `StoreEngineTests`: the stored-transfer wrappers. Cancel behavior is in `CrocEngineCancelTests` |
| `app/CrocAppTests` (Swift Testing, scheme `CrocApp`) | `xcodebuild test -scheme CrocApp` | Settings persistence and validation, relay-password migration, stored-server validation, `TransferLink` parsing, code hints, friendly failure messages, received names and file location, History upgrade, the stored-transfer vault, the Show in Menu Bar setting, app info |

## Verification harnesses

A green build is not evidence that a transfer works. CI runs only `scripts/verify-interop.sh`, against a local relay (job `interop (local relay)`, see `docs/knowledge/tooling.md`, "CI gotchas"). The other harnesses and the public-pool scenario need a public relay or a device and are flaky on shared runners, so running them is on whoever touched the transfer path.

| Harness | Proves | Needs | Env vars |
|---|---|---|---|
| `scripts/verify-interop.sh` | crocmobile (through its `croctest` CLI) and the croc CLI interoperate, 15 scenarios (list below) | croc CLI, croc v10 CLI (`scripts/croc-v10.version`), outbound network unless `RELAY` is set | `CROC`, `CROC_V10`, `RELAY` |
| `scripts/verify-app-mac.sh` | the macOS app, 12 scenarios (list below) | outbound network (scenario 8 also reaches `tailcat.dev`), croc CLI, a macOS app build | `CROC` |
| `scripts/verify-app-sim.sh` | the iOS simulator, 2 scenarios (list below) | outbound network, croc CLI, an iOS Simulator | `CROC`, `SIM` |
| `crockit-verify` (`swift run --package-path CrocKit crockit-verify send\|receive\|twice ...`) | Swift-layer send and receive, cancel fired mid-wire, and two transfers back to back in one process (proves fd0, stdout, cwd and mutex restoration compose) | outbound network, croc CLI, macOS only | optional `CROC_RELAY`, `CROC_PASS` for a private relay |

**`verify-interop.sh` scenarios**

1. Wrapper sends a file, CLI receives.
2. CLI sends a file, wrapper receives.
3. Folder, both directions.
4. Text, both directions.
5. Decline notifies the sender.
6. Receiver cancels mid-transfer.
7. Sender cancels mid-transfer.
8. Forced relay (LAN off on both sides).
9. LAN only.
10. A croc v10 peer in both directions: crocmobile reports failure code `peerVersion`.
11. Every public pool relay in both directions with LAN off, asserting which relay each side used.
12. Receive file policy: a file onto an existing one with Keep Both and with Replace, answered at the prompt and preset with `-yes`, then a zipped folder received twice with each policy and accept mode.
13. Transport: a 130 MiB send under `auto` and under `relay`, both directions, asserting byte equality. The CLI `--debug` log must show a `tailcat-offer` under `auto` and none under `relay`.
14. Stored transfers against a loopback `croctest store-server`: a wrapper upload downloaded by the CLI, a CLI upload downloaded by the wrapper, a revoke after which the download fails, and an existing name with Keep Both, Replace and a declined preview.
15. Advanced options that change the wire, each against the CLI with the matching flag: curve, hash, base port (with transfers and the sender IP), multicast group, SOCKS5 and HTTP proxy, internal DNS. The curve and hash cases assert which side's setting the other adopts, a mismatch included.

With `RELAY` set, every transfer uses that relay, and scenarios 11, 13, and the proxy and internal DNS parts of 15 are skipped. Scenario 14 and the rest of 15 need no public relay and still run.

**`verify-app-mac.sh` scenarios**

1. CLI to app receive, plus SwiftData history.
2. App to CLI send.
3. `--local`.
4. Custom self-hosted relay.
5. `--no-compress`.
6. `--ask`, both sides confirm.
7. A CLI send onto an existing file, received with `--when-exists keepBoth` and `replace` (prints `MAC-COLLIDE-OK`).
8. A 130 MiB transfer in each direction under `--transport auto` and `--transport relay` (prints `MAC-TRANSPORT-OK`).
9. Stored transfers (prints `MAC-STORE-OK`).
10. A send started through the menu-bar view model, with a file and with clipboard text (prints `MAC-MENUBAR-OK`). It saves and restores the text on the pasteboard.
11. Open at login following `SMAppService.status` (prints `MAC-LOGIN-OK`). It registers the login item and unregisters it again.
12. The three Shortcuts actions run through their `perform()` against the CLI (prints `MAC-INTENT-OK`). The receive saves into the real `~/Downloads/CrocApp` and deletes the file.

In the app-as-sender scenarios the CLI receiver starts only after the app writes `verify-code-ready.txt`.

**`verify-app-sim.sh` scenarios**, each gated on the app's result file and a byte-identical diff:

1. CLI to app through the `--auto-receive` launch argument (prints `SIM-INTEROP-OK`).
2. The share-extension handoff: files staged into the App Group container the way `CrocShare` does, app launched with `--auto-share-send`, received by the CLI (prints `SHARE-SIM-OK`). The receiver starts only after the app writes `verify-code-ready.txt`, because a receiver that joins the room first fails.

**Environment variables**

- `CROC`: the CLI path. Default `$HOMEBREW_PREFIX/bin/croc`, falling back to `/opt/homebrew/bin/croc`.
- `SIM`: the simulator for `verify-app-sim.sh`. Default `iPhone 17 Pro`. List installed devices with `xcrun simctl list devices`.
- `CROC_V10`: the croc v10 binary for `verify-interop.sh` scenario 10. Default `$(go env GOPATH)/bin/croc`. Install it with `go install github.com/schollz/croc/v10@$(cat scripts/croc-v10.version)`. The script fails at start if the binary is not the version in `scripts/croc-v10.version`.
- `RELAY=host:port`: sends every transfer of `verify-interop.sh` through that relay instead of the public pool.

CI raises the local relay's admission limits as a margin, because every connection comes from 127.0.0.1 and a croc v11 relay admits 30 joins a minute per address by default. To do the same locally, use the v11 binary explicitly, because a v10 `croc` first on `PATH` rejects these flags (`docs/known-issues.md`, "Harnesses"):

```bash
"${CROC:-$(brew --prefix)/bin/croc}" relay --host 127.0.0.1 --ports 9309,9310,9311,9312,9313 \
  --source-join-limit 1000 --room-join-limit 1000
RELAY=127.0.0.1:9309 scripts/verify-interop.sh
```

**Signing for local macOS harness builds.** `app/CrocApp/CrocApp.entitlements` carries Associated Domains (`applinks:crocapp.dev`), so a signed local macOS build of `CrocApp` needs a provisioning profile.

- `scripts/verify-app-mac.sh` and `scripts/capture-screenshots.sh` pass `-allowProvisioningUpdates` to their macOS `xcodebuild`.
- Xcode needs an account in team `HBSU359M33`.
- On a new Mac, also pass `-allowProvisioningDeviceRegistration` once, so the Mac is registered as a development device.
- A contributor outside that team cannot sign these builds. Unsigned builds (`CODE_SIGNING_ALLOWED=NO`, what CI does) still work.

**Trap**: a harness case that tests an answer given mid-transfer must start the transfer with the opposite or default setting, or it proves only the start options. `croctest -policy` sets the Options only under `-yes`, and `AutoVerify --when-exists` answers the sheet without touching `settings.whenFileExists`.

Any change to `crocmobile/session.go`, `CrocKit/Sources/` or `TransferController` needs the matching harness run, with its output quoted, not summarized. If a harness could not be run, say "not verified" and why.

## Build settings that must not change casually

- **Swift 6 language mode everywhere.** `SWIFT_VERSION = 6.0` on every target (`CrocApp`, `CrocApp Direct`, `CrocShare`, `CrocAppTests`, all configurations in `app/CrocApp.xcodeproj/project.pbxproj`) and `swift-tools-version: 6.0` in `CrocKit`. Also `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`: types are MainActor-isolated by default, `nonisolated` is the explicit opt-out, and strict concurrency violations are build errors.
- **CI treats compiler warnings as errors.** `ci.yml` passes `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES` to its `xcodebuild` calls and `-Xswiftc -warnings-as-errors` to `swift test`, so a warning fails the PR. The project files leave both off, so a local build with a warning still runs. Pass the same flags before pushing.
- **The deployment target is `26.0` everywhere, never a minor.** `IPHONEOS_DEPLOYMENT_TARGET` and `MACOSX_DEPLOYMENT_TARGET` in the pbxproj, `platforms: [.iOS("26.0"), .macOS("26.0")]` in `CrocKit/Package.swift`, and `-iosversion 26.0 -macosversion 26.0` in `scripts/build-xcframework.sh`. All four move together.
- **macOS is arm64 only.** `"ARCHS[sdk=macosx*]" = arm64` in the pbxproj. The xcframework has no `x86_64` macOS slice (golang/go#73119), so the pin makes an Intel archive fail the link cleanly instead of attempting a link that cannot succeed.
- **One version source, `app/Config/Version.xcconfig`.** It holds `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` and is the base configuration of the project-level Debug and Release configurations, so every target inherits it. Never set either in a target's build settings. `RELEASING.md`, "Each release", covers when to bump them.
- **The Go toolchain pin is `>= 1.27.2` in `crocmobile/go.mod`.** After bumping it, rerun `scripts/build-xcframework.sh` to confirm the bind still works before trusting anything downstream.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `conflicting nullability specifier on return types` warning while building `CrocKit` | gomobile turns any Go func named `New<TypeName>` into a constructor and builds the Objective-C selector from what follows the prefix. A func whose suffix is empty (`NewOptions` on `Options`) yields a bare `- (nullable instancetype)init`, which clashes with `NSObject`'s `nonnull init`. `crocmobile` avoids it with `NewOptionsDefault` (selector `initDefault`) | Should not appear. If it returns, a `New<Type>` func with an empty suffix was added in `crocmobile/`; rename it (`docs/knowledge/tooling.md`, "CI gotchas") |
| Xcode or `xcodebuild` fails immediately: missing binary target, or no such module `Croc` | `CrocKit/Croc.xcframework` does not exist (gitignored, absent on a fresh clone) | Run `scripts/build-xcframework.sh` |
| `scripts/build-xcframework.sh` exits `error: go not installed` | Go is not on `PATH` | `brew install go` |
| `gomobile: command not found` when you run it by hand | The script builds gomobile and gobind into `.tools/` and puts that directory on `PATH` for its own run only | `export PATH="$PWD/.tools:$PATH"` from the repo root, after one run of the script |
| macOS build in CI is unsigned | CI's `build (macOS)` job passes `CODE_SIGNING_ALLOWED=NO` (the runner has no signing identity) | Expected in CI. A local signed build needs a `Mac Development` identity and a provisioning profile (see "Verification harnesses", signing paragraph), so pass `-allowProvisioningUpdates` |
| `go install ...@latest` (for example `gomobile`, `gobind`, `govulncheck`) produces a binary you cannot find or run | `GOOS` and `GOARCH` set in the shell (CI's Go job sets `darwin` and `arm64`) make `go install` write to `$GOPATH/bin/darwin_arm64/` instead of `$GOPATH/bin/` | Install with `env -u GOOS -u GOARCH go install ...`. Better, use the pinned tools: `go tool govulncheck`, or `scripts/build-xcframework.sh` for gomobile (`docs/knowledge/tooling.md`, "CI gotchas") |
| A hand-run `swift-format format --in-place` reports clean, but `lint --strict` (what CI runs) still fails | Several enabled rules are lint-only and never rewrite | Run `scripts/format-swift.sh`, which always lints after formatting (`docs/knowledge/tooling.md`, "swift-format traps") |

## When the toolchain changes

- **Xcode bump**: update `.xcode-version` (a single line). First confirm the `xcode-27` GitHub runner image carries that exact version (`docs/knowledge/tooling.md`, "In use", lists what the image carries). Rerun `scripts/build-xcframework.sh` to confirm gomobile still binds, then the full build matrix, then at least one `verify-*.sh` harness live.
- **Go bump**: update `go 1.x.y` in `crocmobile/go.mod`, then rerun `scripts/build-xcframework.sh`.
- **croc bump**: `go get github.com/schollz/croc/v11@vX.Y.Z` in `crocmobile/` (and `brew upgrade croc` for the test CLI), rebind, then update every place that names the version by hand: the croc table row above, `docs/knowledge/crocmobile-bridge.md`, and any README or CONTRIBUTING text that names it. `docs/knowledge/croc-upgrade-playbook.md` has the full procedure.
- **golangci-lint bump**: change the `version:` input on the `golangci-lint-action` step in `.github/workflows/reusable-go.yml`. Update the schema `version:` in `crocmobile/.golangci.yml` if the new major changes it.
- **gomobile, gobind and govulncheck**: all three are pinned in the `tool` block of `crocmobile/go.mod`. Dependabot does not bump them, because tool requirements are `// indirect`. From `crocmobile/`, `go get golang.org/x/mobile@latest` bumps gomobile and gobind, and `go get tool` bumps every tool in the block. Pin the last good version if a bind regresses, and record it in `docs/knowledge/tooling.md`.
- **Always**: check whether [golang/go#73119](https://github.com/golang/go/issues/73119) (macOS multi-arch bind) is fixed upstream before assuming it still blocks Intel Mac support. It decides real behavior, not just a build warning.
