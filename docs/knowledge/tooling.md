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

## swift-format traps

- **Default config does not fit this repo.** `indentation: 2` and `indentConditionalCompilationBlocks: true` are the swift-format defaults; both are wrong here. The `#if os(macOS)` bodies all over `Platform/` would gain a level of indent, producing a ~500-warning reformat that also fights Xcode's editor (Xcode indents from its own text-editing prefs, not `.swift-format`). Repo uses 4 spaces, unindented `#if` bodies.
- `ReplaceForEachWithForLoop` and `OnlyOneTrailingClosureArgument` are lint-only: they warn, they never rewrite. Two known warnings survive `format --in-place` and are left alone deliberately.
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
