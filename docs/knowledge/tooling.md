# Tooling

What is wired up, what was deliberately skipped, and the traps in each.

## In use

| Tool | Config | Where it runs |
|---|---|---|
| swift-format (Xcode 27 toolchain, Swift 6.4) | `.swift-format` (rules) + `scripts/format-swift.sh` (source set) | local + CI |
| golangci-lint 2.x (CI pins v2.14.0 in `reusable-go.yml`) | `crocmobile/.golangci.yml` | local + CI |
| govulncheck (`tool` block in `crocmobile/go.mod`) | none | CI go job + weekly schedule |
| `go build ./...` + `go vet ./...` | none | CI (go job, alongside lint/vuln) |
| `go test -race ./...` (Go `testing`) | `crocmobile/*_test.go` | local + CI (go job, `GOOS`/`GOARCH` unset) |
| Swift Testing (Xcode's built-in) | `CrocKit/Tests/CrocKitTests/`, `app/CrocAppTests/` (shared `CrocApp` scheme) | local + CI (macOS leg of `build`) |
| xcbeautify | none | CI only (`ci.yml`; `release.yml` does not use it) |
| create-dmg 1.3.0 (Homebrew; CI installs it unpinned with `brew install create-dmg`) | none; called by `scripts/build-dmg.sh` | local + `release.yml` |
| croc v10 CLI (the v10 peer of `verify-interop.sh` scenario 10) | `scripts/croc-v10.version` (read by the script and the `interop` job) | local + CI |
| Node 24 (latest LTS) | `web/docs/.nvmrc` (pinned exact), `engines` in `web/docs/package.json` | docs site, local + CI |
| pnpm 12 | `packageManager` in `web/docs/package.json` (CI: `corepack enable pnpm` reads it) | docs site, local + CI |
| Docusaurus 3.10, React 19.3, TypeScript 7 | `web/docs/package.json`, `pnpm-lock.yaml`; `pnpm-workspace.yaml` holds `overrides` for transitive advisories | docs site, local + CI (`pnpm run typecheck` in `github-pages.yml`) |
| Sparkle 2.10.0 (SwiftPM, `CrocApp Direct` only; auto-update for the direct-download build) | `Package.resolved` under `app/CrocApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`, minimum in the `XCRemoteSwiftPackageReference` in `project.pbxproj`; Dependabot does not cover Xcode-project pins, so bump by hand | `CrocApp Direct` build, local + CI (unsigned build step) |
| MCP servers `xcode` (`xcrun mcpbridge`) and `gopls` (`gopls mcp`) for AI sessions | `.mcp.json` (Claude Code asks each user to approve them); `gopls` starts in `crocmobile/` because the Go module lives there, not at the repo root | local AI sessions |
| GitHub Actions | `.github/workflows/ci.yml` | push to main, every PR; a `changes` job skips the jobs whose area is untouched; `interop (local relay)` runs `scripts/verify-interop.sh` on `macos-26` against a local `croc relay` |
| GitHub Actions | `.github/workflows/go-weekly.yml` | Mondays 06:00 UTC + manual |
| GitHub Actions | `.github/workflows/github-pages.yml` | PRs build only; push to main (`web/landing/**`, `web/docs/**`, `design/tokens.css`) also deploys |
| GitHub Actions | `.github/workflows/release.yml` | `v*` tag publishes; `workflow_dispatch` is a rehearsal that publishes nothing |

Xcode baseline lives in `.xcode-version` (plain text, one line). CI reads it into `maxim-lobanov/setup-xcode`; `xcodes` and `mise` read the same file. Jobs that need Xcode 27 run on the `xcode-27` runner label (a public preview; `macos-26` does not carry Xcode 27). Its image carries 27.0 (default), 27.1 and 27.2 beta, so the pin must name a version that image actually has.

## Build configuration you cannot casually change

- **Swift 6 language mode everywhere.** App and extension are `SWIFT_VERSION = 6.0`, `CrocKit` is swift-tools 6.0. On top of that, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`: types are MainActor-isolated by default and `nonisolated` is the explicit case. Strict concurrency is an error, not a warning.
- **Deployment targets are `26.0` everywhere** — pbxproj, `Package.swift`, and `gomobile -iosversion`/`-macosversion`. Never a minor pin.
- **macOS is arm64 only** (`ARCHS[sdk=macosx*] = arm64`). `Croc.xcframework` has no x86_64 slice because gomobile cannot produce one (golang/go#73119), so Intel Macs cannot run the app. Removing the pin does not add Intel support, it breaks the link.
- **Version numbers live in `app/Config/Version.xcconfig`** (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`), the base configuration of the project-level Debug and Release configurations; no target sets either. `release.yml`'s tag check reads `MARKETING_VERSION` from it.
- **Go toolchain ≥ 1.27.2**, pinned in `crocmobile/go.mod`. `scripts/build-xcframework.sh` builds gomobile and gobind from the `golang.org/x/mobile` version in the same file's `tool` block; pin x/mobile to the last good version if a bind ever regresses.

CI gotchas:

- **`ci.yml` has no workflow-level `paths:`.** A filtered-out workflow never reports, so a required check would stay pending. Instead a `changes` job diffs the PR base (or the push's `before`) against the head with plain `git diff --name-only` and sets one output per area (`swift`, `go`, `build`, `design`, `interop`); each job gates on its output with `if:`. A skipped job counts as passed. Adding a file CI *does* consume (a new script, a new dotfile config) means adding it to the matching regex in the `changes` job. An unknown base (new branch, force push) runs everything. A skipped matrix job reports under its unexpanded name and stays pending, so branch protection requires only the `ci pass` aggregate job, never the individual jobs. Unit tests ride on existing jobs: `go test -race` in `reusable-go.yml` (with `GOOS`/`GOARCH` unset for that step, since the job-level `darwin` would build a test binary the Linux runner cannot run), and `swift test` plus `xcodebuild test` on the macOS leg of `build`. The `interop (local relay)` job (`macos-26`) runs `scripts/verify-interop.sh` against a `croc relay` on 127.0.0.1 with raised admission limits (the public relays rate-limit a shared runner address); it installs the v11 CLI with `go install` at the version in `crocmobile/go.mod` (Homebrew's bottle lagged at 11.5.0, which has no `croc store`) and the v10 peer with `go install` at the version in `scripts/croc-v10.version`. The other harnesses and the public-pool scenario are not run by CI.
- **govulncheck under the go job's cross-compile env.** The go job sets `GOOS=darwin GOARCH=arm64` job-wide so vet/build analyse the shipping target. `go install` honours that and drops a darwin binary into `$GOPATH/bin/darwin_arm64/` (unrunnable on the Linux host, and not where `$(go env GOPATH)/bin/…` looks) → exit 127. Install the tool with `env -u GOOS -u GOARCH` so the binary is host-native in `$GOPATH/bin`, then run it with the job env intact so the *analysis* still targets darwin.
- **`conflicting nullability specifier on return types` was fixed on the Go side, not suppressed.** It used to fire on every macOS/iOS build: gomobile treats any `New<TypeName>` func as a constructor and builds the ObjC selector from whatever *follows* that prefix (`bind/gen.go`, `bind/genobjc.go`), so `NewOptions` on type `Options` left an empty suffix and emitted a bare `- (nullable instancetype)init` on `CrocmobileOptions`, clashing with `NSObject`'s `nonnull init`. Renaming the Go constructor to `NewOptionsDefault` keeps it recognised and yields `initDefault`. Do not rename it back, and do not add a `New<Type>` func whose suffix is empty.
- **macOS app build has no signing identity.** The runner has no `Mac Development` cert, so the `build (macOS)` job passes `CODE_SIGNING_ALLOWED=NO` to `xcodebuild`. The iOS Simulator destination never signs, so it needs nothing.
- **A cancelled Pages run strands the `github-pages` environment lock**, and the next push queues behind a deployment that never completes. `github-pages.yml` has an `if: cancelled()` step calling `POST /repos/:repo/pages/deployments/:sha/cancel` to release it, and sets `cancel-in-progress` only for pull requests, so deploys on `main` queue instead of cancelling each other.
- **Scheduled workflows are disabled after 60 days of repo inactivity.** `go-weekly.yml` stops firing silently; `workflow_dispatch` restarts it.

## swift-format traps

- **The config holds only deviations from swift-format's defaults**, and there are two: `indentation: 4` (swift-format defaults to 2, Xcode to 4, and Xcode's editor indents from its own text-editing prefs, not `.swift-format`) and `indentConditionalCompilationBlocks: false` (the `#if os(macOS)` bodies all over `Platform/` stay unindented, as Xcode leaves them). Measured against the 77 files in the source set: pure defaults give 7,940 findings, `indentation: 4` alone 1,362, both 0. Every other rule and knob is swift-format's default, so `xcrun swift-format dump-configuration` prints the full effective set. Add a key only for a deliberate, agreed deviation; restating a default hides the real decisions and freezes the default against upstream changes on an Xcode bump. The formatter binary itself is pinned by `.xcode-version`, which the CI job reads, so a changed default surfaces as a `lint --strict` failure on that bump, not silently.
- **Several enabled rules are lint-only**: they flag but never rewrite, so `format --in-place` leaves them and they must be fixed by hand. CI runs `lint --strict`, which turns every such warning into a build failure, so none may be left behind. Verified lint-only: `ReplaceForEachWithForLoop` (`.forEach { }` → for-in loop), `OnlyOneTrailingClosureArgument` (a call mixing a closure argument such as `onDismiss:` with a trailing closure → pass the trailing closure as an explicit `content:` argument), `AlwaysUseLowerCamelCase`, `TypeNamesShouldBeCapitalized`, `DontRepeatTypeInStaticProperties`, `NoBlockComments`, `AvoidRetroactiveConformances`. A clean `format` run is not evidence CI will pass; run `lint --strict` too.
- **The source set lives in `scripts/format-swift.sh`, not in the config.** swift-format has no "which files" setting, so the path list used to be copy-pasted into CI, the PR template, `README.md`, `CONTRIBUTING.md` and here — and drifted: `CrocKit/Package.swift` was never linted by any of them. One script now owns it. `CrocKit` is enumerated file-by-file rather than passed as a directory, because `--recursive` there descends into `.build/` and `Croc.xcframework/`.

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
- **A passing harness used to exit 1.** `lib.sh`'s `kill_jobs` ran `kill $pids` on whatever `jobs -p` listed, but `jobs -p` still lists jobs that have already exited, and `kill` fails on those. Under the caller's `set -e`, that failing `kill` aborted the EXIT trap mid-way, skipping the `rm -rf "$TMP"` beside it, so a successful run leaked its temp dir *and* returned 1, indistinguishable from a real failure. `verify-interop.sh` and `verify-app-sim.sh` both register that trap, so both reported failure on every successful run until `kill $pids 2>/dev/null || true` fixed it. The `interop (local relay)` job trusts these scripts' exit codes, so know their history: a green run and this bug looked identical from the outside.

## Deferred, with the trigger for revisiting

| Tool | Revisit when |
|---|---|
| Periphery | pre-1.0 dead-code sweep. Can use the committed `CrocApp` scheme; false-positives on gomobile bindings + SwiftUI reflection |
| Danger | after main is PR-only |
| Tuist / XcodeGen | first real `.pbxproj` merge conflict (Kintsugi is the lighter answer) |
| fastlane | App Store / TestFlight upload. Notarization stays a separate step, but the credentials can be shared: `notarytool` accepts an App Store Connect API key via `--key` / `--key-id` / `--issuer`, alongside `--apple-id`/`--password` and `--keychain-profile` |
