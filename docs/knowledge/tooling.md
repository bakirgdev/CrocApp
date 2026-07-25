# Tooling

What is wired up, what was deliberately skipped, and the traps in each. Decision records: ADR 0014 (style + CI), ADR 0018 (scheduled vuln scan), ADR 0019 (Pages deploy).

## In use

| Tool | Config | Where it runs |
|---|---|---|
| swift-format 6.3 (toolchain) | `.swift-format` | local + CI |
| golangci-lint 2.x (CI pins v2.12.2) | `crocmobile/.golangci.yml` | local + CI |
| govulncheck | none | CI go job + weekly schedule (`go install` on demand) |
| `go build ./...` + `go vet ./...` | none | CI (go job, alongside lint/vuln) |
| xcbeautify | none | CI only |
| GitHub Actions | `.github/workflows/ci.yml` | push to main, PRs (code paths) |
| GitHub Actions | `.github/workflows/govulncheck.yml` | Mondays 06:00 UTC + manual |
| GitHub Actions | `.github/workflows/landing.yml` | push to main (`web/**`, `design/tokens.css`) + manual |

Xcode baseline lives in `.xcode-version` (plain text, one line). CI reads it into `maxim-lobanov/setup-xcode`; `xcodes` and `mise` read the same file. The `macos-26` runner image carries 26.0.1 through 26.6, default 26.5, so the pin must name a version that image actually has.

## Build configuration you cannot casually change

- **Swift 6 language mode everywhere.** App and extension are `SWIFT_VERSION = 6.0`, `CrocKit` is swift-tools 6.0. On top of that, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`: types are MainActor-isolated by default and `nonisolated` is the explicit case. Strict concurrency is an error, not a warning.
- **Deployment targets are `26.0` everywhere** — pbxproj, `Package.swift`, and `gomobile -iosversion`/`-macosversion`. Never a minor pin (ADR 0003).
- **macOS is arm64 only** (`ARCHS[sdk=macosx*] = arm64`). `Croc.xcframework` has no x86_64 slice because gomobile cannot produce one (golang/go#73119), so Intel Macs cannot run the app. Removing the pin does not add Intel support, it breaks the link.
- **Go toolchain ≥ 1.26.5**, pinned in `crocmobile/go.mod`. `scripts/build-xcframework.sh` auto-installs gomobile and gobind at `@latest` — unpinned, worth pinning if a bind ever regresses.

CI gotchas:

- **`ci.yml` triggers on a `paths` allowlist**, not `paths-ignore`, shared by both triggers through a YAML anchor: `app/**`, `CrocKit/**`, `crocmobile/**`, `scripts/build-xcframework.sh`, `.swift-format`, `.xcode-version`, `.github/workflows/ci.yml`. The earlier ignore-list rotted — `design/` and `.claude/` were not on it and each paid for a full macOS matrix. An allowlist fails closed: a new non-code directory costs nothing until someone adds it. Adding a file CI *does* consume (a new script, a new dotfile config) means adding it here. If CI ever becomes a required check, a filtered-out PR leaves the check pending — switch to a change-detection job that reports success instead.
- **govulncheck under the go job's cross-compile env.** The go job sets `GOOS=darwin GOARCH=arm64` job-wide so vet/build analyse the shipping target. `go install` honours that and drops a darwin binary into `$GOPATH/bin/darwin_arm64/` (unrunnable on the Linux host, and not where `$(go env GOPATH)/bin/…` looks) → exit 127. Install the tool with `env -u GOOS -u GOARCH` so the binary is host-native in `$GOPATH/bin`, then run it with the job env intact so the *analysis* still targets darwin.
- **`conflicting nullability specifier on return types` is expected noise.** Every macOS/iOS build job emits it while compiling `CrocKit`. Source is gomobile's generated header, not repo code: `Croc.framework/Headers/Crocmobile.objc.h` declares `- (nullable instancetype)init;` for `CrocmobileOptions` (the Go constructor `NewOptions`), which clashes with `NSObject`'s `nonnull init`. Regenerated on every `build-xcframework.sh` run, so it cannot be patched away. Ignore it; do not "fix" it in Swift.
- **macOS app build has no signing identity.** The runner has no `Mac Development` cert, so the `build (macOS)` job passes `CODE_SIGNING_ALLOWED=NO` to `xcodebuild`. The iOS Simulator destination never signs, so it needs nothing.
- **A cancelled Pages run strands the `github-pages` environment lock**, and the next push queues behind a deployment that never completes. `landing.yml` has an `if: cancelled()` step calling `POST /repos/:repo/pages/deployments/:sha/cancel` to release it, and uses `cancel-in-progress: false` so deploys queue instead of cancelling each other.
- **Scheduled workflows are disabled after 60 days of repo inactivity.** `govulncheck.yml` stops firing silently; `workflow_dispatch` restarts it.

## swift-format traps

- **Default config does not fit this repo.** `indentation: 2` and `indentConditionalCompilationBlocks: true` are the swift-format defaults; both are wrong here. The `#if os(macOS)` bodies all over `Platform/` would gain a level of indent, producing a ~500-warning reformat that also fights Xcode's editor (Xcode indents from its own text-editing prefs, not `.swift-format`). Repo uses 4 spaces, unindented `#if` bodies.
- `ReplaceForEachWithForLoop` and `OnlyOneTrailingClosureArgument` are lint-only: they flag but never rewrite, so `format --in-place` leaves them and they must be fixed by hand. CI runs `lint --strict`, which turns every such warning into a build failure, so none may be left behind: `.forEach { }` → for-in loop; a call mixing a closure argument (e.g. `onDismiss:`) with a trailing closure → pass the trailing closure as an explicit `content:` argument.
- `UseSynthesizedInitializer` is off. It flags hand-written memberwise inits that SwiftData/`@Model` types need.

## golangci-lint traps

- `errcheck` flags the deliberate ignores in `session.go`: `os.Chdir(origWD)` on cleanup paths and `syscall.Dup2(savedStdinFd, syscall.Stdin)` restoring fd0. These are written as `_ = f()` so intent is visible at the call site rather than hidden in a config blocklist.
- The two `defer func() { recover() }()` guards carry `//nolint:errcheck`. Do not rewrite them as `_ = recover()`: `recover` only works when called directly by the deferred function, and this codepath exists because a goroutine panic kills the gomobile host app.
- `Close`/`Remove` are already in errcheck's default exclusions, which is why the many `pr.Close()` calls are silent.

## Shell and harness traps

These cost real debugging time on this machine. All are environment quirks, not repo bugs.

- **`rtk xcodebuild` truncates its output before shell redirection sees it**, losing the final `BUILD SUCCEEDED` line. Use `rtk proxy xcodebuild` for anything whose log you intend to read. Redirect build logs to a file, never into context.
- **`rtk find | wc -l` mis-truncates** on directories with ~10k entries. Use `/usr/bin/find` when the count has to be right.
- **No GNU `timeout` in a bare zsh here.** `scripts/lib.sh` shims it for the harnesses; ad-hoc zsh one-liners do not, so a hung verify run will hang forever.
- **bash points a background job's stdin at `/dev/null`** unless the job carries an explicit redirect. Any `timeout` shim that backgrounds its command therefore eats a piped answer — `lib.sh` adds `<&0` so a redirect on the `timeout` call still reaches the command (the `--ask` direction of `verify-app-mac.sh` depends on this).
- **zsh's `=word` expansion breaks bare `===` arguments** to `echo` and friends. Quote them.

## Deferred, with the trigger for revisiting

| Tool | Revisit when |
|---|---|
| SwiftLint | more than one person writes Swift here |
| Periphery | pre-1.0 dead-code sweep. Needs a committed scheme (none exist today) and false-positives on gomobile bindings + SwiftUI reflection |
| Danger | after main is PR-only |
| Tuist / XcodeGen | first real `.pbxproj` merge conflict (Kintsugi is the lighter answer) |
| fastlane | App Store / TestFlight upload. Note ASC API keys cannot authenticate `notarytool`, so it does not remove that step |

## Not done yet: real notarization

`scripts/build-devid.sh` stops at `syspolicy_check`, which is a dry run. There is no `xcrun notarytool submit --wait` and no `xcrun stapler staple`. Consequence: **Homebrew made codesigning + notarization mandatory for official casks on 2026-09-01**, and non-compliant casks are removed from the tap, so the cask channel in ADR 0007 is blocked until this lands. Without stapling, first launch on a fresh Mac also needs network for Gatekeeper.
