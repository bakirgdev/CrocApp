# Tooling

What is wired up, what was deliberately skipped, and the traps in each. Decision record: ADR 0014.

## In use

| Tool | Config | Where it runs |
|---|---|---|
| swift-format 6.3 (toolchain) | `.swift-format` | local + CI |
| golangci-lint 2.x (CI pins v2.12.2) | `crocmobile/.golangci.yml` | local + CI |
| govulncheck | none | CI (`go install` on demand) |
| `go build ./...` + `go vet ./...` | none | CI (go job, alongside lint/vuln) |
| xcbeautify | none | CI only |
| GitHub Actions | `.github/workflows/ci.yml` | push to main, PRs |

Xcode baseline lives in `.xcode-version` (plain text, one line). CI reads it into `maxim-lobanov/setup-xcode`; `xcodes` and `mise` read the same file. The `macos-26` runner image carries 26.0.1 through 26.6, default 26.5, so the pin must name a version that image actually has.

CI gotchas:

- **Docs-only pushes/PRs skip CI** via `paths-ignore` (`**/*.md`, `docs/`, `assets/`, `web/`, `LICENSE`, `.github/FUNDING.yml`), shared by both triggers through a YAML anchor. If CI ever becomes a required check, `paths-ignore` leaves the check pending — switch to a path-filter job that reports success instead.
- **govulncheck under the go job's cross-compile env.** The go job sets `GOOS=darwin GOARCH=arm64` job-wide so vet/build analyse the shipping target. `go install` honours that and drops a darwin binary into `$GOPATH/bin/darwin_arm64/` (unrunnable on the Linux host, and not where `$(go env GOPATH)/bin/…` looks) → exit 127. Install the tool with `env -u GOOS -u GOARCH` so the binary is host-native in `$GOPATH/bin`, then run it with the job env intact so the *analysis* still targets darwin.
- **macOS app build has no signing identity.** The runner has no `Mac Development` cert, so the `build (macOS)` job passes `CODE_SIGNING_ALLOWED=NO` to `xcodebuild`. The iOS Simulator destination never signs, so it needs nothing.

## swift-format traps

- **Default config does not fit this repo.** `indentation: 2` and `indentConditionalCompilationBlocks: true` are the swift-format defaults; both are wrong here. The `#if os(macOS)` bodies all over `Platform/` would gain a level of indent, producing a ~500-warning reformat that also fights Xcode's editor (Xcode indents from its own text-editing prefs, not `.swift-format`). Repo uses 4 spaces, unindented `#if` bodies.
- `ReplaceForEachWithForLoop` and `OnlyOneTrailingClosureArgument` are lint-only: they flag but never rewrite, so `format --in-place` leaves them and they must be fixed by hand. CI runs `lint --strict`, which turns every such warning into a build failure, so none may be left behind: `.forEach { }` → for-in loop; a call mixing a closure argument (e.g. `onDismiss:`) with a trailing closure → pass the trailing closure as an explicit `content:` argument.
- `UseSynthesizedInitializer` is off. It flags hand-written memberwise inits that SwiftData/`@Model` types need.

## golangci-lint traps

- `errcheck` flags the deliberate ignores in `session.go`: `os.Chdir(origWD)` on cleanup paths and `syscall.Dup2(savedStdinFd, syscall.Stdin)` restoring fd0. These are written as `_ = f()` so intent is visible at the call site rather than hidden in a config blocklist.
- The two `defer func() { recover() }()` guards carry `//nolint:errcheck`. Do not rewrite them as `_ = recover()`: `recover` only works when called directly by the deferred function, and this codepath exists because a goroutine panic kills the gomobile host app.
- `Close`/`Remove` are already in errcheck's default exclusions, which is why the many `pr.Close()` calls are silent.

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
