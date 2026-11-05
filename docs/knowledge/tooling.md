# Tooling

What is wired up, what was deliberately skipped, the traps in each, and how the String Catalogs are kept in step.

## In use

| Tool | Config | Where it runs |
|---|---|---|
| swift-format (Xcode 27 toolchain, Swift 6.4) | `.swift-format` (rules) + `scripts/format-swift.sh` (source set) | local + CI |
| golangci-lint 2.x (CI pins the version in `reusable-go.yml`) | `crocmobile/.golangci.yml` | local + CI |
| govulncheck (`tool` block in `crocmobile/go.mod`) | none | CI go job + weekly schedule |
| `go build ./...` + `go vet ./...` | none | CI (go job, alongside lint/vuln) |
| `go test -race ./...` (Go `testing`) | `crocmobile/*_test.go` | local + CI (go job, `GOOS`/`GOARCH` unset) |
| Swift Testing (Xcode's built-in) | `CrocKit/Tests/CrocKitTests/`, `app/CrocAppTests/` (shared `CrocApp` scheme) | local + CI (macOS leg of `build`) |
| xcbeautify | none | CI only (`ci.yml`; `release.yml` does not use it) |
| create-dmg (Homebrew locally; `release.yml` downloads the release tarball and checks its SHA-256) | none; called by `scripts/build-dmg.sh` | local + `release.yml` |
| croc v10 CLI (the v10 peer of `verify-interop.sh` scenario 10) | `scripts/croc-v10.version` (read by the script and the `interop` job) | local + CI |
| Node | `web/docs/.nvmrc` (pinned exact), `engines` in `web/docs/package.json` | docs site, local + CI |
| pnpm | `packageManager` in `web/docs/package.json` (CI: `pnpm/action-setup` reads it) | docs site, local + CI |
| Docusaurus, React, TypeScript | `web/docs/package.json`, `pnpm-lock.yaml`; `pnpm-workspace.yaml` holds `overrides` for transitive advisories | docs site, local + CI (`pnpm run typecheck` in the `site build` job and `github-pages.yml`). `@docusaurus/plugin-client-redirects` writes the old-URL redirects (`docs-site.md`) |
| Sparkle (SwiftPM, `CrocApp Direct` only; auto-update for the direct-download build) | `Package.resolved` under `app/CrocApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`, minimum in the `XCRemoteSwiftPackageReference` in `project.pbxproj`; Dependabot (`swift`, `/app`) reads the Xcode project's `Package.resolved` and opens the bump | `CrocApp Direct` build, local + CI (unsigned build step) |
| MCP servers `xcode` (`xcrun mcpbridge`) and `gopls` (`gopls mcp`) for AI sessions | `.mcp.json` (Claude Code asks each user to approve them); `gopls` starts in `crocmobile/` because the Go module lives there, not at the repo root | local AI sessions. Use `xcode` to build, run tests, render previews and read diagnostics; it needs the project open in Xcode with MCP enabled, and never replaces the harnesses (`BUILDING.md`, "Verification harnesses"). Use `gopls` for symbol search and references in `crocmobile/` |
| `scripts/verify-design.sh` (pure bash and awk, no toolchain) | none; also lints the landing and docs CSS, `app.js`, `theme-init.js`, `prismTheme.ts` and `site.webmanifest` (the `design` filter in `ci.yml` covers those paths). Holds the token parity and contrast tables (the ratios must also appear in `design/principles.md`, "Contrast") and the raw-color lint | local + CI (`contrast` job, shown as `design checks`) |
| `cwebp` (Homebrew `webp`) | none; called by `scripts/capture-screenshots.sh --copy-web` to write the web WebP files | local only |
| `scripts/verify-docs.sh` (pure bash and awk) | none; the rules it enforces are in `docs/AGENTS.md` | local + CI (`docs checks`, on every push and pull request, because renaming any file can break a path a doc names) |
| `scripts/release-check.sh` (bash, awk, an authenticated `gh`) | none; mirrors the tag-run checks in `release.yml` | local only, before pushing a `v*` tag (`../RELEASING.md`, "Each release") |
| `scripts/verify-swift.sh` (Xcode 27; Go only to rebuild the xcframework) | none; runs `swift test` on CrocKit and `xcodebuild test` on the `CrocApp` scheme for this Mac | local only, before pushing a Swift change. CI runs the same suites in the macOS leg of `build` |
| ShellCheck 0.11 (Homebrew locally; preinstalled on `ubuntu-26.04`) | none (`shellcheck -x scripts/*.sh`, default checks) | local + CI (`shellcheck` job) |
| shfmt 3.14 (Homebrew locally; CI downloads the pinned binary and checks its SHA-256) | `.editorconfig` (`shfmt -d scripts`; `shfmt -w scripts` fixes) | local + CI (`shellcheck` job) |
| CodeQL (advanced setup; GitHub's default setup is off) | `.github/workflows/codeql.yml`: actions, Go, JavaScript/TypeScript, path-filtered, plus a weekly run | CI. No Swift (`../known-issues.md`, "CodeQL does not analyze Swift") |
| actionlint, zizmor (Homebrew) | `.github/actionlint.yaml` (runner labels newer than actionlint's list) | local, before pushing a workflow change |
| GitHub Actions | `.github/workflows/ci.yml` | push to main, every PR; a `changes` job skips the jobs whose area is untouched (see "CI gotchas"); `interop (local relay)` runs `scripts/verify-interop.sh` on `macos-26`, which starts its own local `croc relay` |
| GitHub Actions | `.github/workflows/go-weekly.yml` | Mondays 06:17 UTC + manual |
| GitHub Actions | `.github/workflows/github-pages.yml` | Push to `main` only, on changes to `web/landing/**`, `web/docs/**`, `design/tokens.css`, `scripts/assemble-site.sh`, `scripts/lib.sh` and the workflow file: builds `_site` and deploys. The pre-merge build is the `site build` job in `ci.yml` |
| GitHub Actions | `.github/workflows/release.yml` | `v*` tag publishes; `workflow_dispatch` is a rehearsal that publishes nothing |

- Xcode baseline lives in `.xcode-version` (plain text, one line).
- CI reads it into `maxim-lobanov/setup-xcode`; `xcodes` and `mise` read the same file.
- Jobs that need Xcode 27 run on the `xcode-27` runner label (a public preview; `macos-26` does not carry Xcode 27, not verified here).
- The pin must name a version that image carries (see the `actions/runner-images` toolset file; not verified for the current pin).
- Simulator runtimes on that image depend on the Xcode version (`install_runtimes` in `images/macos/toolsets/toolset-xcode-27.json`; not verified for the current pin).
- CI builds the iOS leg for `generic/platform=iOS Simulator`, which needs the SDK, not a runtime.

The build settings that must not change casually (Swift 6 mode, deployment targets, arm64-only macOS, the version source, the Go pin) are in `../BUILDING.md`, "Build settings that must not change casually".

## Keeping versions current

Every pin, and what updates it. Dependabot opens its PRs on Mondays, grouped per ecosystem; the weekly pin-watch workflow (`.github/workflows/pin-watch.yml`, running `scripts/pin-watch.sh`) checks the rest and keeps one issue, "Pinned versions to update", open while any of them differs from the newest stable release.

| Pin | Where | Updated by |
|---|---|---|
| GitHub Actions (full SHAs) | `.github/workflows/*.yml` | Dependabot `github-actions` |
| croc, Go modules, gomobile, govulncheck | `crocmobile/go.mod` (`require` and `tool` blocks) | Dependabot `gomod`; a croc bump follows `croc-upgrade-playbook.md` |
| Sparkle | `Package.resolved` in the Xcode project | Dependabot `swift` |
| Docusaurus, React, TypeScript | `web/docs/package.json`, `pnpm-lock.yaml` | Dependabot `npm` |
| Go toolchain | `go` line in `crocmobile/go.mod` | pin-watch |
| Xcode | `.xcode-version` | pin-watch, against the newest stable Xcode on the `xcode-27` runner image (`../BUILDING.md`, "Xcode bump") |
| Node | `web/docs/.nvmrc`, `engines` in `web/docs/package.json` | pin-watch (newest Node 26) |
| pnpm | `packageManager` in `web/docs/package.json` | pin-watch |
| croc v10 test peer | `scripts/croc-v10.version` | pin-watch |
| golangci-lint | `version:` in `.github/workflows/reusable-go.yml` | pin-watch |
| Runner labels (`ubuntu-26.04`, `macos-26`, `xcode-27`) | `runs-on:` in the workflows | pin-watch, against the `actions/runner-images` toolsets |
| shfmt, create-dmg | `*_VERSION` and `*_SHA256` env in `ci.yml` and `release.yml` | pin-watch (bump both values together) |
| xcbeautify | `brew install` in `ci.yml` | unpinned (it only formats logs) |

The Swift language mode (6) and the deployment targets (26.0) are not version pins: they change only by decision (`../BUILDING.md`, "Build settings that must not change casually").

## CI gotchas

- **`ci.yml` has no workflow-level `paths:`.** A filtered-out workflow never reports, so a required check would stay pending. Jobs skip through `if:` instead (see the next bullet).
- **A newer push cancels a superseded pull request run, never a `main` run.** `cancel-in-progress` is true only for `pull_request`, so every commit on `main` gets a result and saves its caches.
- **The `changes` job decides which jobs run.**
  - It diffs the PR base (or the push's `before`) against the head with `git diff --name-only` and sets one output per area: `swift`, `go`, `build`, `design`, `interop`, `scripts` and `site`. Each job gates on its output with `if:`.
  - The regexes in the `changes` job of `ci.yml` are the source of truth for what each area covers; the rule for new files is in `.github/AGENTS.md`.
  - An unknown base (a new branch, a force push) runs everything.
- **Branch protection requires only `ci pass`** (`.github/AGENTS.md`). The reason: a skipped matrix job reports under its unexpanded name and stays pending, while `ci pass` treats `success` and `skipped` as passing.
- **Unit tests ride on existing jobs.**
  - `go test -race` runs in `reusable-go.yml` with `GOOS` and `GOARCH` unset for that step, because the job-level `darwin` would build a test binary the Linux runner cannot run.
  - `swift test` and `xcodebuild test` run on the macOS leg of `build`.
- **The `build` legs cache `Croc.xcframework`.**
  - The key is the leg's slice list, the Xcode version and a hash of `crocmobile/**` and `scripts/build-xcframework.sh`. `crocmobile/go.mod` carries the Go and gomobile pins, so a toolchain bump misses too.
  - A hit skips `setup-go` and the bind, the slowest steps of a cold runner (150 to 176 s before the cache). A miss binds only the leg's slices through `XCFRAMEWORK_TARGETS`: `macos/arm64` on macOS, `ios,iossimulator/arm64` on the iOS leg. The device slice is linked by no CI build, but binding it there makes a change that breaks the device bind fail CI instead of the release.
  - The macOS leg runs `xcodebuild test`, which builds the app first, so it has no separate build step. Both legs pass `COMPILER_INDEX_STORE_ENABLE=NO`.
  - The DerivedData cache (macOS leg only) saves package resolution, not compiles: a fresh checkout gives every source a new mtime, so Xcode recompiles the app. A cache of `CrocKit/.build` would fail the same way, so there is none. The iOS leg has none: its restore took 4 to 20 s with no compile to save, and its entries filled half of the repo's 10 GB cache cap.
- **The `interop (local relay)` job (`macos-26`) runs `scripts/verify-interop.sh` against a local relay.**
  - The script starts `croc relay` on 127.0.0.1 itself, with raised admission limits, because the public relays rate-limit a shared runner address (`scripts/lib.sh`, "The relay a harness sends through"). The job only provides the CLI binaries.
  - It installs the v11 CLI with `go install` at the version in `crocmobile/go.mod`, because Homebrew's bottle can lag that pin and the store scenario needs `croc store`. It installs the v10 peer the same way, at the version in `scripts/croc-v10.version`.
  - Both binaries are cached under one key made of the runner OS and architecture and the two versions, with no fallback key, so a hit means exactly those versions and skips both installs. A version bump in `crocmobile/go.mod` or `scripts/croc-v10.version` misses the cache and installs afresh.
  - CI does not run the other harnesses or the public-pool scenario (`PUBLIC_POOL=1`).
  - It needs macOS: on `ubuntu-26.04` a sender on one multicast group is heard on another, so the multicast-mismatch scenario fails.
- **The go job carries the engine's build tag.** `GOFLAGS=-tags=croc_no_tailcat` is set job-wide in `reusable-go.yml` (and on the fuzz job in `go-weekly.yml`), so build, vet, test, fuzz, govulncheck and golangci-lint all see the croc without Tailcat that ships. A new Go step needs nothing extra. `TestBuildIsRelayOnly` fails a test run that lacks the tag.
- **`go install` under the go job's cross-compile env.** The go job sets `GOOS=darwin GOARCH=arm64` job-wide so `go build` and `go vet` analyze the shipping target.
  - `go install` honours that and drops a darwin binary into `$GOPATH/bin/darwin_arm64/`, which is unrunnable on the Linux host and not where `$(go env GOPATH)/bin/` looks (exit 127).
  - CI therefore builds govulncheck with `env -u GOOS -u GOARCH go build -o "$RUNNER_TEMP/govulncheck" golang.org/x/vuln/cmd/govulncheck`, then runs it with the job env intact so the analysis still targets darwin.
  - Do the same for any other tool you install in that job.
- **The `conflicting nullability specifier on return types` warning is avoided on the Go side, not suppressed.**
  - gomobile treats any func named `New<TypeName>` as a constructor and builds the Objective-C selector from what follows that prefix (`bind/gen.go`, `bind/genobjc.go`).
  - A bare `NewOptions` on type `Options` leaves an empty suffix and emits `- (nullable instancetype)init` on `CrocmobileOptions`, which clashes with `NSObject`'s `nonnull init`.
  - The constructor is named `NewOptionsDefault`, which yields the selector `initDefault`. Do not rename it back, and do not add a `New<Type>` func whose suffix is empty.
- **macOS app build has no signing identity.** The runner has no `Mac Development` cert, so the `build (macOS)` job passes `CODE_SIGNING_ALLOWED=NO` to `xcodebuild`. That app cannot use the Keychain, which no test needs: the suites inject in-memory secret stores (`app/CrocApp/Support/KeychainStore.swift`). The iOS Simulator destination never signs, so it needs nothing.
- **A cancelled Pages run strands the `github-pages` environment lock**, and the next push queues behind a deployment that never completes. `github-pages.yml` has an `if: cancelled()` step calling `POST /repos/:repo/pages/deployments/:sha/cancel` to release it, and sets `cancel-in-progress: false`, so deploys on `main` queue instead of cancelling each other.
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
  - Verified lint-only: `ReplaceForEachWithForLoop` (rewrite `.forEach { }` as a for-in loop), `OnlyOneTrailingClosureArgument` (a call mixing a closure argument such as `onDismiss:` with a trailing closure: pass the trailing closure as an explicit `content:` argument), `AlwaysUseLowerCamelCase`, `TypeNamesShouldBeCapitalized`, `DontRepeatTypeInStaticProperties`, `NoBlockComments`, `AvoidRetroactiveConformances`.
  - A clean `format` run is not evidence CI will pass; run `lint --strict` too.
- **The source set lives in `scripts/format-swift.sh`, not in the config.** swift-format has no "which files" setting. One script owns the path list, so CI, the PR template and the docs do not each keep a copy. `CrocKit` is listed path by path, because `--recursive` on the directory descends into `.build/` and `Croc.xcframework/`.

## golangci-lint traps

- `errcheck` flags the deliberate ignores in `session.go`: `os.Chdir(origWD)` on cleanup paths and `syscall.Dup2(savedStdinFd, syscall.Stdin)` restoring fd0. These are written as `_ = f()` so intent is visible at the call site rather than hidden in a config blocklist.
- The `defer func() { recover() }()` guards in `session.go` carry `//nolint:errcheck`. Do not rewrite them as `_ = recover()`: `recover` only works when called directly by the deferred function, and this codepath exists because a goroutine panic kills the gomobile host app.
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
- **A harness's relay is disowned, so a bare `wait` does not wait on it.** `verify-interop.sh` ends many scenarios in `wait`, which would otherwise block on the relay forever. `start_croc_relay` therefore runs `disown` on it, `jobs -p` no longer lists it, and `kill_jobs` stops it by `RELAY_PID`. Checked on bash 3.2 (`/bin/bash`) and bash 5.3.

## Localization

The app ships in English only and is ready for more languages. The catalogs exist and every user-facing string reaches one. No second language is in them yet, and the project knows only the `en` and `Base` regions. The plan for languages is in `docs/ROADMAP.md`.

| Catalog | Bundle | Holds |
| --- | --- | --- |
| `app/CrocApp/Localizable.xcstrings` | `CrocApp`, `CrocApp Direct` | every string of the app and of `app/CrocAppDirect/`, and the App Intents titles, descriptions and parameter summaries |
| `app/CrocApp/AppShortcuts.xcstrings` | the same | the three Siri phrases of `CrocAppShortcuts` |
| `app/CrocApp/InfoPlist.xcstrings` | the same | the camera and local-network permission texts |
| `app/CrocApp/ServicesMenu.xcstrings` | the macOS and Direct apps | the title of the **Send with CrocApp** Services menu item (`NSMenuItem` in the two Info plists). Edited by hand |
| `app/CrocShare/Localizable.xcstrings` | `CrocShare`, `CrocShare Direct` | the share extension's few strings. An extension is its own bundle, so it has its own catalog |

### What is localized, and how

What a string is used for decides how it is written. Never wrap a literal that SwiftUI already treats as a key.

| The text is | Write |
| --- | --- |
| a literal handed to a SwiftUI view or modifier that takes a key (`Text`, `Button`, `Label`, `navigationTitle`, `accessibilityLabel`, `ContentUnavailableView`) | the literal itself. A parameter that only ever receives literals is typed `LocalizedStringKey` (`DropZone.title`, `CodeField.placeholder`, `AdvancedRow.footnote`), because a `String` parameter shows its text as it is and Xcode never extracts it |
| built in a model or helper, or needed as a `String` (`TransferFailure`, the Settings field errors, the `StatusBanner` and `StatusBlock` title and detail, VoiceOver announcements, the iOS Live Activity text, `NSOpenPanel`) | `String(localized:)`, with `comment:` where the meaning or a placeholder is not obvious. It resolves when it is built, so never keep one past a language change (the system relaunches the app for one) |
| an App Intents title, description, parameter or dialog | a `LocalizedStringResource`, or the literal where the API takes one. Shortcuts resolves it |
| formatted data (`"\(done) / \(total)"` of two file sizes) | `Text(verbatim:)`, or `Text(_:format:)` for a number. Otherwise the build adds a meaningless `%@ / %@` key |
| a count | `^[\(n) file](inflect: true)` in a `Text` or an `AttributedString(localized:)` (`inflected(_:)` turns the result into a `String`), or one plural variation in the catalog (`Received %lld items.`) |

Never localize:

- Code phrases, file names, URLs, relay addresses and croc or Go output. The engine's `EngineFailure.message` is never shown (`TransferFailure`).
- `Logger` messages, test strings and preview-only labels (use `Text(verbatim:)` there, as `ButtonVariants.swift` does).
- The `AutoVerify` markers and the failure copy the harness scripts match, such as "This link no longer works" in `scripts/verify-app-mac.sh`. The harnesses expect English, so run them on an English system.
- The names `CrocApp` and `croc`.

Not localizable yet: `known-issues.md`, "Design system", lists the on-screen strings that still bypass the catalogs.

### Keeping a catalog in step

Apple says Xcode adds new keys to the catalogs on every build in the IDE. `xcodebuild` does not: with Xcode 27.1 a build compiles the strings but leaves the `.xcstrings` files untouched. What the IDE does can be run by hand, because the compiler writes one `.stringsdata` file per source file, and `xcstringstool sync` merges them into a catalog.

The three variants compile different code (`#if os(iOS)`, `#if os(macOS)`, `#if DIRECT`), so build all of them, then sync from every `.stringsdata`. A sync from one variant drops the keys only the others use.

```bash
DD=$(mktemp -d)
FLAGS=(CODE_SIGNING_ALLOWED=NO -derivedDataPath "$DD")
xcodebuild build -project app/CrocApp.xcodeproj -scheme CrocApp -destination platform=macOS "${FLAGS[@]}"
xcodebuild build -project app/CrocApp.xcodeproj -scheme CrocApp -destination 'generic/platform=iOS Simulator' "${FLAGS[@]}"
xcodebuild build -project app/CrocApp.xcodeproj -scheme 'CrocApp Direct' -destination platform=macOS "${FLAGS[@]}"

# One --stringsdata per file; the Direct build's directory has a space in it.
sync() {
  local catalog=$1; shift; local args=() f d
  for d in "$@"; do
    while IFS= read -r f; do args+=(--stringsdata "$f"); done < <(find "$d" -name '*.stringsdata')
  done
  xcrun xcstringstool sync "$catalog" "${args[@]}"
}
B="$DD/Build/Intermediates.noindex/CrocApp.build"
APP=("$B/Debug-iphonesimulator/CrocApp.build" "$B/Debug/CrocApp Direct.build" "$B/Debug/CrocApp.build")
sync app/CrocApp/Localizable.xcstrings "${APP[@]}"
sync app/CrocApp/AppShortcuts.xcstrings "${APP[@]}"
sync app/CrocShare/Localizable.xcstrings "$B/Debug-iphonesimulator/CrocShare.build"
```

The file name is the table name, so each catalog takes only its own table. A sync keeps comments, translations and `shouldTranslate`, and removes an untranslated key no code uses any more.

Three things no build writes, so edit them by hand:

- `ServicesMenu.xcstrings` holds the one `NSServices` menu title. The system looks the plist's `default` title up in the `ServicesMenu` table, which is the file name. Keep the key equal to the plist text. It is not synced from code, so `xcstringstool sync` never touches it.
- `InfoPlist.xcstrings` holds `NSCameraUsageDescription` and `NSLocalNetworkUsageDescription`. Apple's Xcode 16.3 release notes say the IDE extracts Info.plist keys into this catalog on its own. `xcodebuild` writes nothing there (verified), and the IDE was not run, so both keys are seeded with their current text. Keep a changed permission text in step with `app/Config/CrocApp-Info.plist` or the `INFOPLIST_KEY_` setting.
- The plural variation of `Received %lld items.`, which `ReceiveIntent` uses for its dialog. `LocalizationTests` pins that 1 and 3 render as "1 item" and "3 items".

### Adding a language

1. In Xcode, open each catalog and add the language, which also adds it to the project's regions.
2. Translate. Keep every placeholder (`%@`, `%lld`, `${applicationName}`), and move it where the grammar needs it. Give each count key plural variations: `^[%lld file](inflect: true)` only works for the languages Apple's automatic grammar agreement supports (not checked which), and the other languages need explicit variations.
3. Translate the three phrases in `AppShortcuts.xcstrings`, each with `${applicationName}`, and the two permission texts in `InfoPlist.xcstrings`.
4. Test with the scheme's **App Language** option, or the launch argument `-AppleLanguages (xx)`. Check the longest strings against `design/principles.md`: a translation is often longer than the English.
5. The docs site (`web/docs/`), the landing page and the store listing (`app-store-listing.md`) are separate and not in the catalogs.

## Deferred, with the trigger for revisiting

| Tool | Revisit when |
|---|---|
| Periphery | Before a release that wants a dead-code sweep. It can use the committed `CrocApp` scheme, and it false-positives on gomobile bindings and SwiftUI reflection. |
| Tuist or XcodeGen | The first real `.pbxproj` merge conflict (Kintsugi is the lighter answer). |
