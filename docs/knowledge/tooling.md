# Tooling

What is wired up, what was deliberately skipped, and the traps in each.

## In use

| Tool | Config | Where it runs |
|---|---|---|
| swift-format (Xcode 27 toolchain, Swift 6.4) | `.swift-format` (rules) + `scripts/format-swift.sh` (source set) | local + CI |
| golangci-lint 2.x (CI pins v2.15.0 in `reusable-go.yml`) | `crocmobile/.golangci.yml` | local + CI |
| govulncheck (`tool` block in `crocmobile/go.mod`) | none | CI go job + weekly schedule |
| `go build ./...` + `go vet ./...` | none | CI (go job, alongside lint/vuln) |
| `go test -race ./...` (Go `testing`) | `crocmobile/*_test.go` | local + CI (go job, `GOOS`/`GOARCH` unset) |
| Swift Testing (Xcode's built-in) | `CrocKit/Tests/CrocKitTests/`, `app/CrocAppTests/` (shared `CrocApp` scheme) | local + CI (macOS leg of `build`) |
| xcbeautify | none | CI only (`ci.yml`; `release.yml` does not use it) |
| create-dmg 1.3.0 (Homebrew; CI installs it unpinned with `brew install create-dmg`) | none; called by `scripts/build-dmg.sh` | local + `release.yml` |
| croc v10 CLI (the v10 peer of `verify-interop.sh` scenario 10) | `scripts/croc-v10.version` (read by the script and the `interop` job) | local + CI |
| Node 26.12.0 | `web/docs/.nvmrc` (pinned exact), `engines` in `web/docs/package.json` | docs site, local + CI |
| pnpm 12.14.0 | `packageManager` in `web/docs/package.json` (CI: `pnpm/action-setup` reads it) | docs site, local + CI |
| Docusaurus 3.10, React 19.3, TypeScript 7 | `web/docs/package.json`, `pnpm-lock.yaml`; `pnpm-workspace.yaml` holds `overrides` for transitive advisories | docs site, local + CI (`pnpm run typecheck` in the `site build` job and `github-pages.yml`). `@docusaurus/plugin-client-redirects` writes the old-URL redirects (`docs-site.md`) |
| Sparkle 2.10.1 (SwiftPM, `CrocApp Direct` only; auto-update for the direct-download build) | `Package.resolved` under `app/CrocApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`, minimum in the `XCRemoteSwiftPackageReference` in `project.pbxproj`; Dependabot (`swift`, `/app`) reads the Xcode project's `Package.resolved` and opens the bump | `CrocApp Direct` build, local + CI (unsigned build step) |
| MCP servers `xcode` (`xcrun mcpbridge`) and `gopls` (`gopls mcp`) for AI sessions | `.mcp.json` (Claude Code asks each user to approve them); `gopls` starts in `crocmobile/` because the Go module lives there, not at the repo root | local AI sessions. Use `xcode` to build, run tests, render previews and read diagnostics; it needs the project open in Xcode with MCP enabled, and never replaces the harnesses (`BUILDING.md`, "Verification harnesses"). Use `gopls` for symbol search and references in `crocmobile/` |
| `scripts/verify-design.sh` (pure bash and awk, no toolchain) | none; also lints the landing and docs CSS, `app.js`, `theme-init.js`, `prismTheme.ts` and `site.webmanifest` (the `design` filter in `ci.yml` covers those paths). Holds the token parity, contrast (the ratios `design/colors.md` claims, which must also appear in its Contrast section) and no-literals tables | local + CI (`contrast` job, shown as `design checks`) |
| `cwebp` (Homebrew `webp`) | none; called by `scripts/capture-screenshots.sh --copy-web` to write the web WebP files | local only |
| `scripts/verify-docs.sh` (pure bash and awk) | none; the rules it enforces are in `docs/AGENTS.md` | local + CI (`docs checks`, on every push and pull request, because renaming any file can break a path a doc names) |
| ShellCheck 0.11 (Homebrew locally; preinstalled on `ubuntu-26.04`) | none (`shellcheck -x scripts/*.sh`, default checks) | local + CI (`shellcheck` job) |
| GitHub Actions | `.github/workflows/ci.yml` | push to main, every PR; a `changes` job skips the jobs whose area is untouched (see "CI gotchas"); `interop (local relay)` runs `scripts/verify-interop.sh` on `macos-26` against a local `croc relay` |
| GitHub Actions | `.github/workflows/go-weekly.yml` | Mondays 06:17 UTC + manual |
| GitHub Actions | `.github/workflows/github-pages.yml` | Push to `main` only, on changes to `web/landing/**`, `web/docs/**`, `design/tokens.css`, `scripts/assemble-site.sh` and the workflow file: builds `_site` and deploys. The pre-merge build is the `site build` job in `ci.yml` |
| GitHub Actions | `.github/workflows/release.yml` | `v*` tag publishes; `workflow_dispatch` is a rehearsal that publishes nothing |

- Xcode baseline lives in `.xcode-version` (plain text, one line).
- CI reads it into `maxim-lobanov/setup-xcode`; `xcodes` and `mise` read the same file.
- Jobs that need Xcode 27 run on the `xcode-27` runner label (a public preview; `macos-26` does not carry Xcode 27, not verified here).
- The pin must name a version that image carries (see the `actions/runner-images` toolset file; not verified for the current pin).
- Simulator runtimes on that image depend on the Xcode version (`install_runtimes` in `images/macos/toolsets/toolset-xcode-27.json`; not verified for the current pin).
- CI builds the iOS leg for `generic/platform=iOS Simulator`, which needs the SDK, not a runtime.

The build settings that must not change casually (Swift 6 mode, deployment targets, arm64-only macOS, the version source, the Go pin) are in `../BUILDING.md`, "Build settings that must not change casually".

## CI gotchas

- **`ci.yml` has no workflow-level `paths:`.** A filtered-out workflow never reports, so a required check would stay pending. Jobs skip through `if:` instead (see the next bullet).
- **The `changes` job decides which jobs run.**
  - It diffs the PR base (or the push's `before`) against the head with `git diff --name-only` and sets one output per area: `swift`, `go`, `build`, `design`, `interop`, `scripts` and `site`. Each job gates on its output with `if:`.
  - The regexes in the `changes` job of `ci.yml` are the source of truth for what each area covers; the rule for new files is in `.github/AGENTS.md`.
  - An unknown base (a new branch, a force push) runs everything.
- **Branch protection requires only `ci pass`** (`.github/AGENTS.md`). The reason: a skipped matrix job reports under its unexpanded name and stays pending, while `ci pass` treats `success` and `skipped` as passing.
- **Unit tests ride on existing jobs.**
  - `go test -race` runs in `reusable-go.yml` with `GOOS` and `GOARCH` unset for that step, because the job-level `darwin` would build a test binary the Linux runner cannot run.
  - `swift test` and `xcodebuild test` run on the macOS leg of `build`.
- **The `interop (local relay)` job (`macos-26`) runs `scripts/verify-interop.sh` against a local relay.**
  - It starts `croc relay` on 127.0.0.1 with raised admission limits, because the public relays rate-limit a shared runner address.
  - It installs the v11 CLI with `go install` at the version in `crocmobile/go.mod`, because Homebrew's bottle can lag that pin and the store scenario needs `croc store`. It installs the v10 peer the same way, at the version in `scripts/croc-v10.version`.
  - CI does not run the other harnesses or the public-pool scenario.
- **`go install` under the go job's cross-compile env.** The go job sets `GOOS=darwin GOARCH=arm64` job-wide so `go build` and `go vet` analyze the shipping target.
  - `go install` honours that and drops a darwin binary into `$GOPATH/bin/darwin_arm64/`, which is unrunnable on the Linux host and not where `$(go env GOPATH)/bin/` looks (exit 127).
  - CI therefore builds govulncheck with `env -u GOOS -u GOARCH go build -o "$RUNNER_TEMP/govulncheck" golang.org/x/vuln/cmd/govulncheck`, then runs it with the job env intact so the analysis still targets darwin.
  - Do the same for any other tool you install in that job.
- **The `conflicting nullability specifier on return types` warning is avoided on the Go side, not suppressed.**
  - gomobile treats any func named `New<TypeName>` as a constructor and builds the Objective-C selector from what follows that prefix (`bind/gen.go`, `bind/genobjc.go`).
  - A bare `NewOptions` on type `Options` leaves an empty suffix and emits `- (nullable instancetype)init` on `CrocmobileOptions`, which clashes with `NSObject`'s `nonnull init`.
  - The constructor is named `NewOptionsDefault`, which yields the selector `initDefault`. Do not rename it back, and do not add a `New<Type>` func whose suffix is empty.
- **macOS app build has no signing identity.** The runner has no `Mac Development` cert, so the `build (macOS)` job passes `CODE_SIGNING_ALLOWED=NO` to `xcodebuild`. The iOS Simulator destination never signs, so it needs nothing.
- **A cancelled Pages run strands the `github-pages` environment lock**, and the next push queues behind a deployment that never completes. `github-pages.yml` has an `if: cancelled()` step calling `POST /repos/:repo/pages/deployments/:sha/cancel` to release it, and sets `cancel-in-progress` only for pull requests, so deploys on `main` queue instead of cancelling each other.
- **Scheduled workflows are disabled after 60 days of repo inactivity.** `go-weekly.yml` stops firing silently; `workflow_dispatch` restarts it.

## swift-format traps

- **The config holds only deviations from swift-format's defaults**, and there are two:
  - `indentation: 4`. swift-format defaults to 2, Xcode to 4, and Xcode's editor indents from its own text-editing prefs, not `.swift-format`.
  - `indentConditionalCompilationBlocks: false`. The `#if os(macOS)` bodies all over `Platform/` stay unindented, as Xcode leaves them.
  - Measured when the config was written, pure defaults gave thousands of findings, `indentation: 4` alone about a thousand, and both none.
  - Every other rule and knob is swift-format's default, so `xcrun swift-format dump-configuration` prints the full effective set.
  - Add a key only for a deliberate, agreed deviation; restating a default hides the real decisions and freezes the default against upstream changes on an Xcode bump.
  - The formatter binary itself is pinned by `.xcode-version`, which the CI job reads, so a changed default surfaces as a `lint --strict` failure on that bump, not silently.
- **Several enabled rules are lint-only**: they flag but never rewrite, so `format --in-place` leaves them and they must be fixed by hand.
  - CI runs `lint --strict`, which turns every such warning into a build failure, so none may be left behind.
  - Verified lint-only: `ReplaceForEachWithForLoop` (`.forEach { }` → for-in loop), `OnlyOneTrailingClosureArgument` (a call mixing a closure argument such as `onDismiss:` with a trailing closure → pass the trailing closure as an explicit `content:` argument), `AlwaysUseLowerCamelCase`, `TypeNamesShouldBeCapitalized`, `DontRepeatTypeInStaticProperties`, `NoBlockComments`, `AvoidRetroactiveConformances`.
  - A clean `format` run is not evidence CI will pass; run `lint --strict` too.
- **The source set lives in `scripts/format-swift.sh`, not in the config.** swift-format has no "which files" setting. One script owns the path list, so CI, the PR template and the docs do not each keep a copy. `CrocKit` is listed path by path, because `--recursive` on the directory descends into `.build/` and `Croc.xcframework/`.

## golangci-lint traps

- `errcheck` flags the deliberate ignores in `session.go`: `os.Chdir(origWD)` on cleanup paths and `syscall.Dup2(savedStdinFd, syscall.Stdin)` restoring fd0. These are written as `_ = f()` so intent is visible at the call site rather than hidden in a config blocklist.
- The two `defer func() { recover() }()` guards carry `//nolint:errcheck`. Do not rewrite them as `_ = recover()`: `recover` only works when called directly by the deferred function, and this codepath exists because a goroutine panic kills the gomobile host app.
- `Close`/`Remove` are already in errcheck's default exclusions, which is why the many `pr.Close()` calls are silent.

## Shell and harness traps

These cost real debugging time on this machine. All are environment quirks, not repo bugs.

- **`rtk xcodebuild` truncates its output before shell redirection sees it**, losing the final `BUILD SUCCEEDED` line. Use `rtk proxy xcodebuild` for anything whose log you intend to read. Redirect build logs to a file, never into context.
- **`rtk find | wc -l` mis-truncates** on directories with ~10k entries. Use `/usr/bin/find` when the count has to be right.
- **No GNU `timeout` in a bare zsh here.** `scripts/lib.sh` shims it for the harnesses; ad-hoc zsh one-liners do not, so a hung verify run will hang forever.
- **bash points a background job's stdin at `/dev/null`** unless the job carries an explicit redirect. Any `timeout` shim that backgrounds its command therefore eats a piped answer (`lib.sh` adds `<&0` so a redirect on the `timeout` call still reaches the command), which the `--ask` direction of `verify-app-mac.sh` depends on.
- **zsh's `=word` expansion breaks bare `===` arguments** to `echo` and friends. Quote them.
- **A harness trap must not fail a passing run.** `lib.sh`'s `kill_jobs` runs `kill $pids` on whatever `jobs -p` lists, but `jobs -p` still lists jobs that have already exited, and `kill` fails on those.
  - Under the caller's `set -e`, a failing `kill` aborts the EXIT trap midway, skips the `rm -rf "$TMP"` beside it, and turns a successful run into exit 1.
  - `verify-interop.sh` and `verify-app-sim.sh` both register that trap, so `kill $pids 2>/dev/null || true` must stay.
  - The `interop (local relay)` job trusts these scripts' exit codes.

## Deferred, with the trigger for revisiting

| Tool | Revisit when |
|---|---|
| Periphery | Before a release that wants a dead-code sweep. It can use the committed `CrocApp` scheme, and it false-positives on gomobile bindings and SwiftUI reflection. |
| Tuist or XcodeGen | The first real `.pbxproj` merge conflict (Kintsugi is the lighter answer). |
