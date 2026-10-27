---
slug: repo-cleanup
phase: spec
status: accepted
approved_by: sdlc-gatekeeper
approved_at: 2026-10-27
mock:
---

# Spec: Repo cleanup: screenshots out of git, assets and .gitignore audit

Policy skills applied: `secrets-management` (secret and signing patterns in `.gitignore`). Repo policies applied: `docs/AGENTS.md` (writing rules, one fact one home), `assets/AGENTS.md`, `design/AGENTS.md` (Assets inventory in `design/brand.md`), root `AGENTS.md` ("Docs" table, AGENTS.md edits through `claude-md-management:claude-md-improver`). No design decision is made and nothing a user sees changes, so `apple-design`, `swiftui-expert-skill`, `mobile-ios-design` and `impeccable` do not apply. No UI, so no mock.

No questions went to the owner: every open question in intent.md came with a recommended answer, the owner delegated the layout choice ("the spec picks the simplest layout"), and D9 asks for no stops in this task. Each answer below follows the recommendation or says why it differs.

## Requirements

Screenshots

- R1. Git tracks exactly 20 files under `assets/screenshots/`: `{light,dark}` PNGs of `mac/send-code`, `mac/send-files`, `mac/receive-conflict`, `mac/stored-link`, `mac/settings`, `mac/settings-advanced`, `mac/history`, `iphone/send-code`, `iphone/receive-incoming`, `iphone/onboarding`. Proof: `git ls-files assets/screenshots | wc -l` prints 20, and the list equals the set above.
- R2. `scripts/capture-screenshots.sh` writes every capture, main pairs and the App Store sets alike, under `build/screenshots/` (same layout as before: `mac/`, `iphone/`, `ipad/`, `app-store/<class>/`), which `.gitignore` covers. A capture run never writes under `assets/`. A full run empties `build/screenshots/` first, creating it when missing. `--list` prints the new paths. Proof: `git check-ignore -q` succeeds for every path `--list` prints; after a capture, `git status --porcelain` is empty.
- R3. `scripts/capture-screenshots.sh --copy-web` first refreshes every PNG present under `assets/screenshots/` from the same relative path under `build/screenshots/`, then rebuilds the WebP copies from `assets/screenshots/` exactly as today (same sources, sizes, flags and failures). A tracked PNG with no capture under `build/screenshots/` is kept and named in the output, not an error, so `--copy-web` still works on a fresh clone. Proof: on a fresh checkout with no `build/screenshots/`, `--copy-web` exits 0 and rebuilds all 22 WebP files; after a capture of a published screen, `--copy-web` updates that screen's tracked PNG.
- R4. The PR description reports tracked screenshot size before and after, measured with `git ls-tree -r -l <rev> assets/screenshots`. Before (at `daad96b`): 138 files, 35,546,221 bytes (33.9 MB). Expected after: 20 files, 4,379,114 bytes (4.2 MB), unless a published PNG changes in this task (it should not).
- R5. `scripts/verify-docs.sh` checks image targets in markdown: every URL in an HTML `src="..."` or `srcset="..."` attribute, outside fenced code, resolves like a relative link to a tracked file (http(s) URLs skipped). Proof: pointing one README `<img src>` at a missing file makes it fail with `path:line`; the real tree passes.
- R6. `scripts/verify-docs.sh` fails for a tracked PNG under `assets/screenshots/` that nothing shows: neither a markdown `src`/`srcset` target nor the source of a tracked `.webp` at the same relative path under `web/docs/screenshots/` or `web/landing/assets/img/screenshots/`. The message names the file and points to `docs/knowledge/screenshots.md`, "Where they are used". Proof: `git add -f` of an unused capture makes it fail; the real tree passes.

Assets

- R7. Every other tracked file in `assets/` stays: each is used (audit in Design). `assets/CrocAppIcon.icon/` equals `app/CrocApp/AppIcon.icon/` and `assets/favicons/` equals `web/landing/assets/img/favicon/` (`diff -rq` clean), and stays so.
- R8. `web/docs/static/img/mascot.webp` is no longer tracked: it is a build-time copy that `.gitignore` already names. The `tokens` script in `web/docs/package.json` creates `static/img/` before copying (`mkdir -p`), so `pnpm --dir web/docs run build` and `start` work on a fresh clone. Proof: `git ls-files -i -c --exclude-standard` prints nothing; `scripts/assemble-site.sh` passes from a clean checkout and the built navbar shows the mascot.

.gitignore

- R9. `.gitignore` holds the patterns in Design, grouped and commented, and nothing else. Proof: `git ls-files -i -c --exclude-standard` prints nothing (no tracked file matches a rule); `git check-ignore -v --no-index` matches each path in the Design probe list as stated there.
- R10. The documented Sparkle update test in `docs/RELEASING.md` keeps every output (key files, `dd1`, `dd2`, `feed/`, `apps/`) in its scratch directory: the build step passes `-project <repo>/app/CrocApp.xcodeproj` from the scratch directory instead of running from `app/`. Proof: the step's commands name no path inside the repo except the project; `scripts/verify-docs.sh` passes.
- R11. Clean tree after a full build and a capture. Run, from a clean checkout of the task branch, the commands in "Full build" below. Then `git status --porcelain` prints nothing, except the published PNGs and WebPs that `--copy-web` refreshed on purpose, which are listed and then restored with `git restore`. `git status --porcelain --ignored` lists no ignored path outside this expected set: `.tools/`, `CrocKit/Croc.xcframework/`, `CrocKit/.build/`, `build/`, `_site/`, `web/docs/node_modules/`, `web/docs/.docusaurus/`, `web/docs/build/`, `web/docs/src/css/tokens.css`, `web/docs/static/img/mascot.webp`, plus local state that predates the run (`xcuserdata/`, `.claude/settings.local.json`, `.claude/worktrees/`). Anything else is a finding.

Docs

- R12. The docs match the new state, per the root `AGENTS.md` "Docs" table and `docs/AGENTS.md` rules: `assets/AGENTS.md`, `design/brand.md` (Assets), `docs/knowledge/screenshots.md`, `docs/known-issues.md`, `docs/RELEASING.md`, `docs/AGENTS.md` and `docs/BUILDING.md` (what `verify-docs.sh` checks). Details in Changes. `scripts/verify-docs.sh` and `scripts/verify-design.sh` pass.

## Design

### Screenshot layout

```
build/screenshots/                       gitignored capture output (by the existing `build/` rule)
  mac/ iphone/ ipad/                     every screen, both appearances
  app-store/<class>/NN-<screen>-<mode>.png   upload sets, used at submission
assets/screenshots/                      tracked, published sources only (R1)
  mac/<screen>-{light,dark}.png          7 pairs
  iphone/<screen>-{light,dark}.png       3 pairs
web/docs/screenshots/, web/landing/assets/img/screenshots/   tracked WebP copies, unchanged
```

Flow: `capture-screenshots.sh [...]` writes `build/screenshots/`. `--copy-web` publishes: it copies the captures of the already-published screens into `assets/screenshots/`, then rebuilds the WebPs from there. Publishing a new screen stays a one-time manual step, as today for WebPs: copy its pair from `build/screenshots/` into `assets/screenshots/`, run `cwebp` once into the web folder at the size the page needs, reference it; later `--copy-web` runs keep both fresh. R6 makes the reverse drift (a tracked capture nothing shows) fail in CI.

Why this over a `.gitignore` allow-list (`/assets/screenshots/**/*.png` plus ten `!` lines, tested and working with git 2.54): with the allow-list, every capture rewrites the tracked PNGs in place (the code phrase is random per run), so `git status` is dirty after any capture and the done-when check fails; the allow-list also duplicates the "Where they are used" list. A separate output folder keeps captures out of git with no new ignore line, and `assets/` keeps "nothing here is build output" true.

Script changes in `scripts/capture-screenshots.sh`: `OUT=build/screenshots`; a second variable for the tracked folder (`assets/screenshots`) used only by `--copy-web`; `mkdir -p "$OUT"` before the full-run wipe (`find "$OUT" ...` fails on a missing folder under `set -e`); header, usage and the `--copy-web` error text updated. Nothing else in the capture logic changes.

The 118 unused PNGs are removed with `git rm` (not `--cached`): `assets/screenshots/` is no longer ignored, so leaving them on disk would show them as untracked. They stay in history until T13 (D2) and are regenerated by any capture.

### Asset audit (`git grep`, `diff -rq`, at `daad96b`)

| File | Used by | Verdict |
| --- | --- | --- |
| `mascot.png` | source of every mascot derivative (`design/brand.md`, Mascot) | keep |
| `CrocAppIcon.icon/` | mirrored to `app/CrocApp/AppIcon.icon/` (identical) | keep |
| `favicons/` | source set; served copy `web/landing/assets/img/favicon/` (identical) | keep |
| `dmg-background.tiff` | `scripts/build-dmg.sh` | keep |
| `github-social-preview.png` | GitHub Settings, uploaded by hand | keep |
| `screenshots/` | see R1 | 20 of 138 kept |

Every tracked image outside `assets/screenshots/`, the asset catalogs and the icon packages is referenced by name somewhere in the repo; none is dropped.

### .gitignore (target content)

```gitignore
# macOS
.DS_Store
._*

# Editors (Xcode keeps its per-user state in xcuserdata/)
xcuserdata/
.vscode/
.idea/
*.swp
*~

# Secrets and signing material
.env*
*.pem
*.p8
*.p12
*.cer
*.certSigningRequest
*.mobileprovision
*.provisionprofile

# Xcode and Swift Package Manager
DerivedData/
.build/
.swiftpm/

# Go and gomobile
/.tools/
CrocKit/Croc.xcframework/
/crocmobile/croctest
/crocmobile/cmd/croctest/croctest

# Node and Docusaurus
node_modules/
.docusaurus/

# Build output: web/docs/build/, build/screenshots/, the Pages artifact, release DMGs
build/
/_site/
/dist/

# Copies of tracked files: made by the docs build, or by hand for a local landing preview
web/landing/tokens.css
web/docs/src/css/tokens.css
web/docs/static/img/mascot.webp

# Local tooling
*.log
/buildServer.json
.claude/settings.local.json
.claude/worktrees/
```

Changes from today, each with its reason:

| Change | Reason |
| --- | --- |
| Editors group: `.vscode/`, `.idea/`, `*.swp`, `*~`; `xcuserdata/` moves into it | the owner asked for editors; these are the per-user state folders and swap or backup files of the common editors |
| `*.pem` | private key files: `docs/RELEASING.md` makes `key.pem` in its Sparkle test, and a PEM is the usual export format for any key |
| `/crocmobile/croctest` | `go build ./cmd/croctest` run in `crocmobile/` writes the binary there; the existing line only covers a build inside `cmd/croctest/` |
| comments on `build/` and the copies group | say what lands there; `web/landing/tokens.css` is a by-hand preview copy (`docs/knowledge/landing-page.md`), not a build-time one |
| `web/docs/static/img/mascot.webp` stays, file untracked (R8) | the rule was right, the file was committed before it |

Kept although no script writes them, because a standard workflow can: `._*` (Finder and archive tools on non-APFS volumes), `DerivedData/` (Xcode's "Relative" DerivedData location), `.swiftpm/` (Xcode opening `CrocKit/` as a package), `*.mobileprovision` and the other signing types (downloaded or exported by hand during signing setup, `docs/RELEASING.md`), `*.log` (package-manager debug logs), `/buildServer.json` (sourcekit-lsp setup). Not added, with reason: Xcode archives, IPAs, PKGs and result bundles (every script writes them under `$TMPROOT`); Go test binaries and coverage files (no script uses `-c` or `-coverprofile`; fuzz failures under `crocmobile/testdata/fuzz/` are meant to be committed); `notes.md` and `results.sarif` (written only on CI runners by `release.yml` and `scorecard.yml`; an ignore would hide a real file); `*.keychain-db` (only in `$RUNNER_TEMP`).

Probe list for R9 (`git check-ignore -v --no-index`): ignored: `build/screenshots/app-store/mac/01-send-files-light.png`, `web/docs/build/x`, `web/docs/.docusaurus/x`, `web/docs/node_modules/x`, `_site/x`, `dist/x`, `.tools/x`, `CrocKit/Croc.xcframework/x`, `CrocKit/.build/x`, `CrocKit/.swiftpm/x`, `crocmobile/croctest`, `crocmobile/cmd/croctest/croctest`, `app/CrocApp.xcodeproj/xcuserdata/x`, `key.pem`, `AuthKey_X.p8`, `.envrc`, `.vscode/x`, `a.swp`, `web/docs/static/img/mascot.webp`. Not ignored: `assets/screenshots/mac/send-code-light.png`, `assets/screenshots/ipad/home-light.png`, `crocmobile/cmd/croctest/main.go`, `crocmobile/testdata/fuzz/X/y`.

Playwright MCP: its default output folder is not documented (context7, `/microsoft/playwright-mcp`: `--output-dir` has no stated default; named files resolve against the workspace root). The build phase takes one `browser_take_screenshot` without a filename from this repo's root; if the file lands inside the repo, it adds that folder (expected `/.playwright-mcp/`) to "Local tooling" and the probe list. Named screenshots in later phases go to `$CLAUDE_JOB_DIR/tmp` or another path outside the repo.

### Full build (answers intent open question 1)

Run from a clean checkout of `sdlc/repo-cleanup`, in this order. Scheme names are the shared schemes in `app/CrocApp.xcodeproj` (`CrocApp` is the App Store scheme for iOS, iPadOS and macOS; `CrocApp Direct` is the macOS Developer ID scheme); one iOS build covers iPhone and iPad.

1. `scripts/build-xcframework.sh`
2. `scripts/verify-swift.sh` (CrocKit `swift test`, then `xcodebuild test` of `CrocApp` on macOS)
3. `xcodebuild -project app/CrocApp.xcodeproj -scheme 'CrocApp Direct' -destination 'platform=macOS' -derivedDataPath "$TMPDIR/dd-repo-cleanup" CODE_SIGNING_ALLOWED=NO build`
4. `xcodebuild -project app/CrocApp.xcodeproj -scheme CrocApp -destination 'generic/platform=iOS Simulator' -derivedDataPath "$TMPDIR/dd-repo-cleanup" CODE_SIGNING_ALLOWED=NO build`
5. From `crocmobile/`, as `docs/BUILDING.md` documents (the tag must reach every command, or `TestBuildIsRelayOnly` fails): `export GOFLAGS=-tags=croc_no_tailcat`, then `go build ./...`, `go vet ./...`, `env -u GOOS -u GOARCH go test -race ./...`
6. `scripts/assemble-site.sh`, then `pnpm --dir web/docs run typecheck`
7. A screenshot capture (see concern 1), then `scripts/capture-screenshots.sh --copy-web`
8. `scripts/verify-docs.sh`, `scripts/verify-design.sh`, `shellcheck -x scripts/*.sh`

Left out, with reason: `scripts/build-appstore.sh` and `scripts/build-devid.sh` need signing identities or an Apple ID session and write only to `$TMPROOT` and `dist/` (both read from the scripts, `dist/` probed in R9). Afterwards, per ground rule 5: delete `$TMPDIR/dd-repo-cleanup`, the `derived_data` folders the scripts made, `_site/`, `web/docs/build/`, `web/docs/node_modules/` if this task created it, `build/screenshots/` and `CrocKit/Croc.xcframework` if rebuilt here.

## How each constraint is met

| Constraint (from intent.md) | Met by |
| --- | --- |
| 1. Standing approval, fully autonomous (D9) | no owner questions; decisions recorded here; nothing needs physical access, a login, a force push or a tag (screenshot capture permissions: concern 1) |
| 2. Few, short owner questions with a recommended answer | none asked: every intent question had a recommendation, applied below |
| 3. No attribution to Claude in git, PRs, issues, releases | every commit and the PR omit `Co-Authored-By` and generated-by footers, agents' commits included |
| 4.1 Nothing is fixed | also fixes what the audit found: the tracked-but-ignored `mascot.webp` (R8), the Sparkle test writing into `app/` (R10), unchecked README images (R5) |
| 4.2 Production-ready quality bar (D26) | no app code changes; the script change keeps every existing failure check of `--copy-web` and the capture; new checks R5, R6 |
| 4.3 Latest stable versions, Node 26 | no versions touched (constraint 8: T3); `package.json` changes only the `tokens` script, not dependencies or the lockfile |
| 4.4 Speed and economy | one `.gitignore` line covers all capture output; audits delegated to `sonnet` subagents; no repeated audit |
| 4.5 Disk budget, end clean | 118 PNGs (29.7 MB) leave the tree; the full-build cleanup list above; capture output deleted after the test phase |
| 4.6 Proof over claims | every requirement has a stated proof command; no transfer path changes, so no transfer harness applies (`AGENTS.md`, "Verification") |
| 4.7 Design applies everywhere | no visual change; screenshots stay untouched captures from the script (`assets/AGENTS.md` rules hold) |
| 4.8 iPhone 16 Plus for on-device checks | not needed: no app change |
| 4.9 Simplest solution | separate capture folder instead of an allow-list (one line, and the only layout that keeps `git status` clean after a capture); no new script or tool |
| 5. D2: no history rewrite here | only `git rm` of current files; history untouched until T13 |
| 5. D9 | constraint 1 row |
| 5. D22: git keeps only used screenshots; App Store sets generated at submission, gitignored | R1, R2, R6; App Store sets land in `build/screenshots/app-store/` |
| 6. Ground truth (gitleaks, sizes) | no secret is tracked (`git ls-files` grep: only `KeychainStore.swift`, `FakeSecretStore.swift`, `HardwareKeyboard.swift` match); sizes re-measured in R4 |
| 7. Every README, docs and landing image keeps rendering; `--copy-web` keeps producing WebPs | all 10 shown pairs stay tracked (R1); R3 keeps `--copy-web`'s sources and output; R5 checks README image targets in CI; R11 runs `assemble-site.sh` |
| 8. Out of scope beats rules 1 and 3: no version bumps (T3), no CI changes (T4) | no workflow file changes: the `docs checks` CI job already runs `verify-docs.sh` on every push and PR, so R5 and R6 need none |

## Open questions from the intent

- What is "a full build"? The eight steps under "Full build", with the two signed release builds left out for the reason given.
- Should unused main pairs stay capturable by default? Yes: the script still captures every screen on every device; all output goes to the gitignored `build/screenshots/`, and only the published pairs are copied into `assets/screenshots/` by `--copy-web`.
- Which files in `assets/` are unused? None outside the 118 screenshots (audit table). `github-social-preview.png` stays.
- Should the "unused captures" note stay in `docs/known-issues.md`? No: the "Most screenshot pairs are unused" bullet under "Docs site" is deleted, since unused captures are no longer in git. Its reason for keeping them ("re-capturing a deleted one is not" cheap) no longer applies: D22 decides that git keeps only used shots, and every capture run regenerates the rest into `build/screenshots/`. `docs/knowledge/screenshots.md`, "Where they are used" stops citing it.

## Concerns

1. A screenshot capture takes over the display, flips the system appearance and needs Screen Recording, Accessibility and Automation permissions for the process that runs it; whether a background `claude --bg` session has them is unknown. The test phase runs `scripts/capture-screenshots.sh mac send-code` and `scripts/capture-screenshots.sh iphone send-code` at least (both write main and App Store files), a full run if the preflight passes. If the preflight fails, R11's capture step is reported "not verified" and the owner is asked to run `scripts/capture-screenshots.sh mac send-code` once, followed by `git status --porcelain`. Owner: test phase, then the owner.
2. Playwright MCP's default output folder is undocumented (Design, ".gitignore"). Owner: build phase, by the one-screenshot check.
3. `.env*` would also hide a future `.env.example` or `.envrc.example` template. None exists, so no `!` line is added now; the build phase puts a one-line comment above `.env*` in `.gitignore` saying a template needs a `!` line. Owner: the task that adds the first template (the reviewer of that PR checks it).
4. The repository history still carries about 81% of `.git` in old screenshot blobs; this task only stops carrying them forward. Owner: T13 (D2).
5. An App Store submission (Stage 2) now starts with a capture: upload from `build/screenshots/app-store/<class>/`. `iphone-duo-outer` stays not upload-ready (`docs/knowledge/screenshots.md`, "Known soft spots"). Owner: Stage 2 submission task.

## Files changed

| File | Change |
| --- | --- |
| `.gitignore` | target content above |
| `assets/screenshots/**` | `git rm` the 118 files outside R1 |
| `scripts/capture-screenshots.sh` | `OUT=build/screenshots`, tracked folder variable, `mkdir -p`, `--copy-web` refresh step, header, usage and messages (R2, R3) |
| `scripts/verify-docs.sh` | `src`/`srcset` targets (R5), unused-screenshot check (R6), header lists both |
| `web/docs/package.json` | `tokens` script: `mkdir -p static/img` before the mascot copy (R8) |
| `web/docs/static/img/mascot.webp` | `git rm --cached` (R8) |
| `assets/AGENTS.md` | via `claude-md-improver`: Layout rows for `screenshots/` (only published pairs, sources of the web copies and README) and the store set (generated into `build/screenshots/app-store/`, not in git); intro still true; Rules: capture writes `build/screenshots/`, `--copy-web` publishes, how to publish a new screen |
| `design/brand.md` | Assets rows: Screenshots path and use, App Store screenshots now `build/screenshots/app-store/...`, generated, not committed |
| `docs/knowledge/screenshots.md` | layout block, "Running it" (output folder, full-run wipe, `--copy-web` refresh step), App Store sets' location, "Where they are used" (tracked set, how to publish, no known-issues cross-reference) |
| `docs/known-issues.md` | delete "Most screenshot pairs are unused" under "Docs site" |
| `docs/RELEASING.md` | Sparkle update test: build from the scratch directory with `-project` (R10) |
| `docs/AGENTS.md`, `docs/BUILDING.md` | what `verify-docs.sh` checks (images, unused screenshots); `docs/AGENTS.md` via `claude-md-improver` |

No change: app code, `CrocKit/`, `crocmobile/`, workflows, `CHANGELOG.md` (nothing a user sees), `docs/knowledge/tooling.md` and the `cwebp` rows of `docs/BUILDING.md` (still true), `docs/knowledge/app-store-listing.md` (points at `screenshots.md`, no committed-set claim), `docs/knowledge/docs-site.md` (already says the mascot copy is gitignored and never committed; R8 makes that true).

## Changes

## SDLC feedback

- This background session was told by the harness to isolate in a worktree before any edit, while the SDLC flow commits on `sdlc/<slug>` in the root checkout and `next.sh` starts the next phase there. Workaround: a detached worktree at the branch head, then a fast-forward of `sdlc/repo-cleanup` in the root checkout. Worse, once the session was isolated, every Bash call of its Explore subagents was refused (their cwd resolved to the shared checkout), so two audits came back partial and were redone in the main session. Why it hurts: wasted subagent runs, and a phase can stall on an edit the harness rejects. Suggested change: `.claude/sdlc-scripts/next.sh` starts autonomous phases in a per-task worktree (`git worktree add .claude/worktrees/<slug> sdlc/<slug>`, `claude --bg` from there), and `.claude/rules/sdlc.md` says phases run there; until then, `.claude/rules/sdlc.md` tells sessions to spawn subagents only before isolating, or not to isolate.
- `/sdlc-spec` step 4 ("Grill the user ... in one round") assumes someone answers; in `run_mode: autonomous` nobody does, and D9 says to stop only for high-stakes decisions. Why it hurts: a strict reading blocks the background session on a prompt. Suggested change: in `.claude/skills/sdlc-spec/SKILL.md` step 4, when `run_mode: autonomous`, record each choice with its recommended answer in spec.md and ask only for decisions the intent marks as the owner's or that are high-stakes.
- From `sdlc-gatekeeper`: its spec item does not ask it to check that the shell commands a spec hands to later phases actually work; here an env-prefix scope bug (`GOFLAGS=... go build && go vet && go test`) would have reached the test phase. Suggested change: add "commands the spec gives later phases match the documented invocation (`docs/BUILDING.md`, CI workflows)" to the spec item in `.claude/agents/sdlc-gatekeeper.md`.
- From `sdlc-gatekeeper`: its spec checklist lacks "policy skills applied" (required by `.claude/skills/sdlc-spec/SKILL.md` step 2) and "repo facts the spec quotes are spot-checked"; the caller had to add both to the prompt. Suggested change: add both to the spec item in `.claude/agents/sdlc-gatekeeper.md`.
