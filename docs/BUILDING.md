# Building CrocApp from source

Deep reference for the exact toolchain and the exact steps from a fresh clone to a running app. `README.md` ("Build from source") and `CONTRIBUTING.md` ("Setup") carry the short version and link here for detail; this file grounds every version, flag, and path they use, it does not restate them.

## 1. Prerequisites

| Tool | Required version | Pinned in | Install (macOS) |
|---|---|---|---|
| Host OS | macOS 26 | README, CONTRIBUTING.md | — |
| Xcode | `26.6` | `.xcode-version` | Apple Developer downloads, or `xcodes install 26.6` |
| Go | `>= 1.26.5` | `crocmobile/go.mod` (`go 1.26.5`) | `brew install go` |
| gomobile / gobind | unpinned, `@latest` | `scripts/build-xcframework.sh` installs both on first run if missing | nothing to install by hand; the script runs `go install golang.org/x/mobile/cmd/gomobile@latest` and `.../cmd/gobind@latest` into `$(go env GOPATH)/bin` |
| swift-format | ships with the Xcode 26.6 toolchain (`docs/knowledge/tooling.md` records the bundled version as 6.3) | `.swift-format` (formatting rules; the binary itself is not separately versioned in this repo) | none, invoke via `xcrun swift-format` |
| golangci-lint | `2.x`; CI pins `v2.12.2` exactly | `.github/workflows/ci.yml` (`golangci-lint-action@v9`, `version: v2.12.2`); rule config in `crocmobile/.golangci.yml` (`version: "2"` schema) | `brew install golangci-lint` |
| govulncheck | unpinned, `@latest` | `.github/workflows/ci.yml` (go job) and `.github/workflows/govulncheck.yml` | `go install golang.org/x/vuln/cmd/govulncheck@latest` |
| create-dmg | unpinned | `.github/workflows/release.yml` installs it with `brew` | `brew install create-dmg`. Needed only by `scripts/build-dmg.sh`, not for a plain build |
| croc CLI | `v10.5.0`, to match the embedded engine | `crocmobile/go.mod` (`github.com/schollz/croc/v10 v10.5.0`, indirect) | `go install github.com/schollz/croc/v10@v10.5.0` (lands at `~/go/bin/croc`, the harnesses' default) or `brew install croc`. Needed only for `scripts/verify-*.sh` and `crockit-verify`, not for a plain build |

## 2. First build from a fresh clone

Nothing Swift builds before the xcframework exists. `CrocKit/Package.swift` declares:

```swift
.binaryTarget(name: "Croc", path: "Croc.xcframework"),
```

`CrocKit/Croc.xcframework/` is gitignored (`.gitignore`, "gomobile build output: xcframework not committed"), so a fresh clone has no file there and every Swift build fails until one exists. `scripts/build-xcframework.sh` is step one, not optional.

```bash
# from the repo root
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

No scheme is committed: `xcuserdata/` is gitignored, and CLAUDE.md notes Xcode autocreates schemes on open. Open the project in Xcode at least once (the `open` command above does this) before driving builds from the command line — `xcodebuild -scheme CrocApp` needs a scheme to already exist, and nothing in this repo generates one ahead of time.

Command-line builds, exactly as CLAUDE.md and CI run them:

```bash
# from app/
xcodebuild -scheme CrocApp -destination 'platform=macOS' -derivedDataPath /tmp/dd-mac build
xcodebuild -scheme CrocApp -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath /tmp/dd-sim build
```

`SIM` defaults to `iPhone 17 Pro` (used the same way in `scripts/verify-app-sim.sh`, `scripts/verify-share-sim.sh`, and CLAUDE.md). List installed runtimes with `xcrun simctl list devices`.

## 3. What build-xcframework.sh actually does

From the repo root, the script `cd`s into `crocmobile/`, runs `go mod download`, then:

```bash
gomobile bind \
  -target ios,iossimulator,macos/arm64 \
  -iosversion 26.0 -macosversion 26.0 \
  -o "../CrocKit/Croc.xcframework" \
  .
```

- **Targets**: `ios`, `iossimulator`, `macos/arm64`. Only an arm64 macOS slice, no `macos/amd64`.
- **`-iosversion` / `-macosversion`**: both `26.0`, matching the deployment target everywhere else in the repo (section 6).
- **Output**: `CrocKit/Croc.xcframework`, removed and rebuilt on every run (`rm -rf "$OUT"` before binding).
- **Why arm64-only on macOS**: [golang/go#73119](https://github.com/golang/go/issues/73119), gomobile cannot currently produce a multi-arch macOS bind. `Croc.xcframework` therefore has no `x86_64` slice, and Intel Macs that can otherwise run macOS 26 (the 2019 MacBook Pro 16", 2020 iMac, and 2019 Mac Pro) cannot run CrocApp. The pbxproj pins `ARCHS[sdk=macosx*] = arm64` for this reason; removing that pin does not restore Intel support, it just breaks the link.
- **Open note on iOS device archives**: [golang/go#66500](https://github.com/golang/go/issues/66500) is a device-slice layout issue that affects App Store archives specifically, not simulator or local device builds. Still open; revisit before the first store submission.

`gomobile`/`gobind` are installed at `@latest`, unpinned. If a future gomobile release ever regresses the bind, pin the version in this script and record it in `docs/knowledge/tooling.md`.

## 4. Format and lint

Exact commands CI runs, from the repo root:

```bash
xcrun swift-format lint --recursive --parallel --strict app/CrocApp app/CrocShare CrocKit/Sources
```

That is the only Swift check the `swift-format` CI job runs. Locally, run the in-place formatter first for convenience, then lint separately:

```bash
xcrun swift-format format --in-place --recursive --parallel app/CrocApp app/CrocShare CrocKit/Sources
xcrun swift-format lint --recursive --parallel --strict app/CrocApp app/CrocShare CrocKit/Sources
```

**Trap**: `format --in-place` does not fix lint-only rules, several enabled rules only flag and never rewrite (for example `ReplaceForEachWithForLoop`, `OnlyOneTrailingClosureArgument`, `AlwaysUseLowerCamelCase`). A clean `format` run is not evidence `lint --strict` will pass; always run both. Full list and rationale: `docs/knowledge/tooling.md`.

Go, from `crocmobile/`:

```bash
go build ./...
go vet ./...
golangci-lint run ./...
govulncheck ./...
```

`go build`/`go vet` are what CI's go job runs alongside lint and vuln, under `GOOS=darwin GOARCH=arm64` (the job analyzes the platform the code ships on, on a cheap Linux runner). If you install `govulncheck` yourself in a shell that already has `GOOS`/`GOARCH` set, see the troubleshooting table below, `go install` will silently misplace the binary.

## 5. Verification harnesses

A green build is **not** evidence a transfer works. CI deliberately does not run any of these (`docs/knowledge/tooling.md`: they need a public relay and are flaky on shared runners), so running them is on whoever touched the transfer path.

| Harness | Proves | Needs | Env vars |
|---|---|---|---|
| `scripts/verify-interop.sh` | 9 scenarios, crocmobile (via its `croctest` CLI) ↔ croc CLI: file/folder/text both directions, decline, cancel both directions, forced relay, LAN-only | outbound network (public relay), croc CLI | `CROC` |
| `scripts/verify-app-mac.sh` | macOS app, 6 directions: CLI→app receive (plus SwiftData history), app→CLI send, `--local`, custom self-hosted relay, `--no-compress`, `--ask` (both sides confirm) | outbound network, croc CLI, a macOS app build | `CROC` |
| `scripts/verify-app-sim.sh` | iOS simulator, CLI→app via the `--auto-receive` launch argument, gated on a byte-identical diff | outbound network, croc CLI, an iOS Simulator | `CROC`, `SIM` |
| `scripts/verify-share-sim.sh` | Share-extension handoff: files staged into the App Group container the way `CrocShare` does, app launched with `--auto-share-send`, received by the croc CLI | outbound network, croc CLI, an iOS Simulator | `CROC`, `SIM` |
| `crockit-verify` (run via `swift run --package-path CrocKit crockit-verify send\|receive\|twice ...`) | Swift-layer send/receive, cancel fired mid-wire, and two transfers back-to-back in one process (proves fd0/stdout/cwd/mutex restoration composes) | outbound network, croc CLI, macOS only | optional `CROC_RELAY`, `CROC_PASS` to point at a private relay |

`CROC` overrides the CLI path (default `~/go/bin/croc`); `SIM` picks the simulator (default `iPhone 17 Pro`).

Any change to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController` needs the matching harness run, its output quoted, not summarized. If a harness could not be run, say "not verified" and why.

## 6. Build settings that must not be casually changed

- **Swift 6 language mode everywhere.** `SWIFT_VERSION = 6.0` on both targets (`CrocApp`, `CrocShare`, all build configurations, `app/CrocApp.xcodeproj/project.pbxproj`) and `CrocKit`'s `swift-tools-version: 6.0`. On top of that, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`: types are MainActor-isolated by default, `nonisolated` is the explicit opt-out, and strict concurrency violations are build errors, not warnings.
- **Deployment target is `26.0` everywhere, never a minor.** `IPHONEOS_DEPLOYMENT_TARGET = 26.0` and `MACOSX_DEPLOYMENT_TARGET = 26.0` in the pbxproj, `platforms: [.iOS("26.0"), .macOS("26.0")]` in `CrocKit/Package.swift`, and `-iosversion 26.0 -macosversion 26.0` in `scripts/build-xcframework.sh`. All four must move together.
- **macOS is arm64-only.** `"ARCHS[sdk=macosx*]" = arm64` in the pbxproj. `Croc.xcframework` has no `x86_64` macOS slice (golang/go#73119, section 3), so this pin exists to fail the link cleanly rather than let an Intel archive attempt one that cannot succeed.
- **Go toolchain pin, `>= 1.26.5` in `crocmobile/go.mod`.** Bumping it means rerunning `scripts/build-xcframework.sh` to confirm the bind still works on the new toolchain before trusting anything downstream.

## 7. Distribution builds

Not implemented: real notarization. `scripts/build-devid.sh` archives the macOS app (`xcodebuild ... archive ARCHS=arm64`), checks for a "Developer ID Application" signing identity in the login keychain, and if one is missing, prints `DEVID-PENDING-CERT` and exits 0 (creating that identity at developer.apple.com is an owner action, not something the script can do). If the identity exists, it exports via `Config/ExportOptions-DevID.plist`, runs `codesign --verify --strict --deep`, then `syspolicy_check distribution` on the exported `.app`. `syspolicy_check` is Apple's pre-submission dry-run checker; it catches signing, entitlement, and hardened-runtime problems that notarization or Gatekeeper would otherwise reject, but it is **not** notarization. There is no `xcrun notarytool submit --wait` and no `xcrun stapler staple` anywhere in this repo (`docs/known-issues.md`, "Blocking release").

Two export channels, both under `app/Config/`:

| File | `method` | Channel |
|---|---|---|
| `ExportOptions-DevID.plist` | `developer-id` | Direct-download DMG, exercised by `scripts/build-devid.sh` |
| `ExportOptions-MAS.plist` | `app-store-connect` | Mac App Store; committed but never exercised, first real MAS export will be its first test (`docs/known-issues.md`) |

Both plists share `teamID` `HBSU359M33` and `destination` `export`.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `conflicting nullability specifier on return types` warning while building `CrocKit` | gomobile-generated `Croc.framework/Headers/Crocmobile.objc.h` declares `- (nullable instancetype)init;` on `CrocmobileOptions`, clashing with `NSObject`'s `nonnull init` | Expected, ignorable. Regenerated on every `build-xcframework.sh` run, cannot be fixed in Swift (`docs/knowledge/tooling.md`) |
| Xcode or `xcodebuild` fails immediately, missing binary target / no such module `Croc` | `CrocKit/Croc.xcframework` does not exist (gitignored, absent on a fresh clone) | Run `scripts/build-xcframework.sh` first |
| `xcodebuild -scheme CrocApp` fails with "scheme does not exist" on a brand-new clone | No `.xcscheme` is committed; Xcode autocreates one only after the project is opened | Run `open app/CrocApp.xcodeproj` once, let Xcode autocreate the scheme, then use `xcodebuild` |
| `scripts/build-xcframework.sh` exits `error: go not installed` | Go not on `PATH` | `brew install go` |
| `gomobile: command not found` right after the script claims to have installed it | `$(go env GOPATH)/bin` not on this shell's `PATH` | The script exports it only for its own run; for a direct `gomobile` invocation afterward, `export PATH="$PATH:$(go env GOPATH)/bin"` |
| macOS build in CI is unsigned | CI's `build (macOS)` job passes `CODE_SIGNING_ALLOWED=NO` (no signing identity on the runner) | Expected in CI. Locally, a build signs normally with a `Mac Development` identity in your keychain |
| `go install .../cmd@latest` (gomobile, gobind, govulncheck) produces a binary you cannot find or run | `GOOS`/`GOARCH` set in the shell (as CI's go job sets `darwin`/`arm64`) makes `go install` drop the binary at `$GOPATH/bin/darwin_arm64/…` instead of `$GOPATH/bin/…` | Install with `env -u GOOS -u GOARCH go install ...`, then run the tool with the original env intact if the analysis itself needs to target darwin (`docs/knowledge/tooling.md`) |
| `swift-format format --in-place` reports clean, but `lint --strict` (what CI runs) still fails | Several enabled rules are lint-only and never rewrite | Always run `lint --strict` after `format --in-place`; see the rule list in `docs/knowledge/tooling.md` |

## 9. When the toolchain changes

- **Xcode bump**: update `.xcode-version` (single line). Confirm the `macos-26` GitHub runner image actually carries that exact version first (`docs/knowledge/tooling.md` notes the image has spanned `26.0.1`-`26.6`, default `26.5`). Rerun `scripts/build-xcframework.sh` to confirm gomobile still binds clean, then the full build matrix, then at least one `verify-*.sh` harness live.
- **Go bump**: update `go 1.x.y` in `crocmobile/go.mod`, rerun `scripts/build-xcframework.sh`.
- **croc bump**: `go get github.com/schollz/croc/v10@vX.Y.Z` in `crocmobile/`, rebind, then update every place that names the version by hand: `README.md` FAQ, `CONTRIBUTING.md`'s croc-install line, this file's prerequisites table, and `docs/knowledge/crocmobile-bridge.md`. Check `docs/knowledge/croc-upgrade-playbook.md` for the full procedure.
- **golangci-lint bump**: change the `version:` input on the `golangci-lint-action` step in `.github/workflows/ci.yml`; update `crocmobile/.golangci.yml`'s schema `version:` if the new major changes it.
- **gomobile/gobind**: unpinned by design (`@latest`). If a bind ever regresses on a new release, pin it explicitly in `scripts/build-xcframework.sh` and record the pin in `docs/knowledge/tooling.md`.
- Whatever changed, re-check whether [golang/go#73119](https://github.com/golang/go/issues/73119) (macOS multi-arch bind) or [golang/go#66500](https://github.com/golang/go/issues/66500) (iOS device archive layout) have been fixed upstream before assuming either still blocks Intel Mac support or App Store archives; both are live gates on real behavior, not just build warnings.
