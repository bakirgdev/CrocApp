---
slug: repo-cleanup
phase: test
status: accepted
approved_by: sdlc-gatekeeper
approved_at: 2026-10-27
---

# Test: Repo cleanup: screenshots out of git, assets and .gitignore audit

Checked on the build head `ea650a1` by `sdlc-verifier` (fresh context), then on `fa90f86` (code fixes found here) and the docs commits `84a0f4d` and `18c0894` by the main session. `pr-review-toolkit` `pr-test-analyzer` and `silent-failure-hunter` ran on the branch diff. Real captures ran in this session: the macOS and iOS preflights passed.

## Requirements
| R# | Check | Result | Evidence |
| --- | --- | --- | --- |
| R1 | `git ls-files assets/screenshots` against the spec set | PASS | `R1-OK`, 20 files |
| R2 | `--list`, then `git check-ignore -q` per path | PASS | `scripts/capture-screenshots.sh --list \| awk '/^  /{print $1}' \| wc -l` prints `94` (the verifier expanded `{light,dark}` and checked 138 paths), none `NOT IGNORED`, no `assets/` in the output |
| R2 | real captures `scripts/capture-screenshots.sh mac send-code` and `scripts/capture-screenshots.sh iphone send-code` | PASS | `SHOTS-OK`, `exit 0` each; files only under `build/screenshots/{mac,iphone,app-store/mac,app-store/iphone-6.9}`; `git status --porcelain` empty after both; system appearance restored (`true` before and after) |
| R2 | `verify_outputs` guard: `scripts/capture-screenshots.sh mac settings-advanced` with `build/` absent (a non-store screen, so no `app-store/mac` folder exists) | PASS | `outputs OK (every file present, store files sized and without alpha)`, `SHOTS-OK`, `exit 0`; `find build/screenshots -type f` lists only `mac/settings-advanced-{light,dark}.png`; `git status --porcelain` empty |
| R2 | full-run wipe and `mkdir -p "$OUT"` from a missing `build/screenshots/` | NOT VERIFIED | a full run (every device, simulator and display takeover for a long time) was not run; read in code only |
| R3 | fresh checkout, no `build/`, `--copy-web` | PASS | exit 0, 20 `kept` lines, `refreshed 0 of 20 PNGs in assets/screenshots from build/screenshots`, `rebuilt 18 files in web/docs/screenshots`, `rebuilt 4 files in web/landing/assets/img/screenshots`, tree clean |
| R3 | `--copy-web` after `iphone send-code` | PASS | `refreshed 2 of 20 PNGs`, `rebuilt 18` and `rebuilt 4`, exit 0; `git status --porcelain` listed exactly the two `assets/screenshots/iphone/send-code-*.png` and the two `web/landing/.../iphone/send-code-*.webp`; restored with `git restore` |
| R3 | `--copy-web` after `mac send-code` | FINDING (left) | `FAIL: web/docs/screenshots/mac/send-code-dark.webp is 1120x1400 but assets/screenshots/mac/send-code-dark.png is 1440x1400: the aspect ratio changed ...`. The check is working as designed: the published Mac pair predates the app's 720 pt minimum window width (`app/CrocApp/CrocAppApp.swift:116`). Not caused by this task. Recorded in `docs/known-issues.md`. `sips -g pixelWidth assets/screenshots/mac/*.png`: 1120 px for `history`, `receive-conflict`, `send-code`, `send-files`, `stored-link`; 960 px for `settings`, `settings-advanced`. A fresh `settings-advanced` capture is 960 px, so those two match; `send-code` is 1440 px. The other four 1120 px pairs were not recaptured, so their drift is likely, not shown |
| R4 | `git ls-tree -r -l <rev> assets/screenshots` | PASS | `138 35546221` at `daad96b`, `20 4379114` at HEAD |
| R5 | real tree; `src` and `srcset` mutations in `README.md`; inline-code probe | PASS | `PASS: links, images, repo paths, stale markers and screenshot use in 49 markdown files`; `README.md:66: broken image: assets/screenshots/mac/send-code-nope.png`; `README.md:65: broken image: ...`; `img-probe.md:2: broken image: nope.png` |
| R5 | `src` at the start of a line, and `src='...'`, probe `docs/zz-probe2.md` (`<img` newline `src="nope/missing.png">`, then `<img src='nope/missing2.png'>`) | PASS (after fix) | before (`ea650a1`), the whole output of `scripts/verify-docs.sh` was the finding of the other probe and no `broken image` line for `zz-probe2.md`: `FAIL: 1 finding(s). Fix the doc, or the path it names; never the check.`; after (`fa90f86`): `docs/zz-probe2.md:2: broken image: nope/missing.png` and `docs/zz-probe2.md:3: broken image: nope/missing2.png` |
| R6 | `git add -f` of an unused capture (`git show daad96b:assets/screenshots/ipad/home-light.png`), re-run on `fa90f86`; real tree | PASS | `assets/screenshots/ipad/home-light.png: unused screenshot: no markdown image or web WebP copy shows it. Publish it or git rm it (docs/knowledge/screenshots.md, "Where they are used")`, exit 1; after `git rm`, `PASS: links, images, repo paths, stale markers and screenshot use in 49 markdown files`, exit 0 |
| R6 | a PNG shown only by a markdown `![](...)` image (probe `docs/zz-probe1.md`: `![x](../assets/screenshots/ipad/home-light.png)` with that PNG present) | PASS (after fix) | before (`ea650a1`): `assets/screenshots/ipad/home-light.png: unused screenshot: no markdown image or web WebP copy shows it. Publish it or git rm it (docs/knowledge/screenshots.md, "Where they are used")`, `FAIL: 1 finding(s)`, exit 1 (false fail); after (`fa90f86`), same probe set (plus `zz-probe2.md`): only the two `broken image` lines, no `unused screenshot` |
| R7 | `diff -rq` icon and favicon pairs; `git diff --name-only daad96b -- assets ':!assets/screenshots'` | PASS | `R7-OK`; only `assets/AGENTS.md` listed |
| R8 | `git ls-files -i -c --exclude-standard`; fresh-worktree `scripts/assemble-site.sh`; Playwright on the built docs | PASS | empty; `assemble exit 0`, `_site/docs/img/mascot.webp` 4286 bytes; `.navbar__logo img` `naturalWidth` 128 |
| R9 | `.gitignore` equals the plan block; 19 ignored and 4 not-ignored probes | PASS | `GITIGNORE-MATCHES-PLAN`, no probe on the wrong side |
| R10 | `docs/RELEASING.md` read | PASS (read only) | `REPO=$(git rev-parse --show-toplevel) && cd "$(mktemp -d)" && mkdir feed`; `xcodebuild -project "$REPO/app/CrocApp.xcodeproj" ...`; no other repo path. The `xcodebuild -project ... -list` part ran in the build phase (build.md, R10 block); the verifier's rerun was refused by the harness (SDLC feedback) |
| R10 | the Sparkle update test itself | NOT VERIFIED | needs a Developer ID identity and an Apple ID session |
| R11 | full build in this worktree: `scripts/build-xcframework.sh` and `scripts/verify-swift.sh` (via `$SDLC_VERIFY`), both `xcodebuild` builds, `go build/vet/test -race` with `GOFLAGS=-tags=croc_no_tailcat`, `scripts/assemble-site.sh`, `pnpm --dir web/docs run typecheck`, `verify-docs.sh`, `verify-design.sh`, `shellcheck -x scripts/*.sh` | PASS | `** BUILD SUCCEEDED **` (macOS `CrocApp Direct`), `** BUILD SUCCEEDED **` (iOS Simulator `CrocApp`), `go rc=0`, `assemble rc=0`, `typecheck rc=0`, `SHELLCHECK-OK` |
| R11 | `git status --porcelain` after the build and the two captures | PASS | empty. `git status --porcelain --ignored` listed only `.tools/`, `CrocKit/.build/`, `CrocKit/Croc.xcframework/`, `_site/`, `build/`, `web/docs/.docusaurus/`, `web/docs/build/`, `web/docs/node_modules/`, `web/docs/src/css/tokens.css`, `web/docs/static/`; all in the expected set (`web/docs/static/` holds only `img/mascot.webp`). No `.playwright-mcp/` left |
| R12 | `git grep -n -e 'assets/screenshots/app-store' -e 'Most screenshot pairs are unused' -- ':!sdlc'`; `verify-docs.sh`; `verify-design.sh` | PASS | empty; both pass |

## UI against the mock
No mock.

## Fixes
- `pr-test-analyzer` and `silent-failure-hunter` (both) found that a screenshot shown only by a markdown `![](...)` image is reported unused (false R6 failure whose message tells the author to remove a used file); reproduced above. Fix `fa90f86`.
- `silent-failure-hunter`: `src` at the start of a line or in single quotes was not checked, so a broken image passed (R5 vacuous for the multi-line `<img>` style); reproduced above. Fix `fa90f86`.
- `silent-failure-hunter`: `--copy-web` with `assets/screenshots/` missing failed late with a misleading `refreshed 0 of 0` line; now fails first. Run with `assets/screenshots` renamed away. Before (`ea650a1`): `find: assets/screenshots: No such file or directory`, `refreshed 0 of 0 PNGs in assets/screenshots from build/screenshots`, `FAIL: web/docs/screenshots/iphone/onboarding-dark.webp has no source assets/screenshots/iphone/onboarding-dark.png: publish its PNG pair first (...)`. After (`fa90f86`): `FAIL: assets/screenshots is missing: the published PNGs are tracked, restore them with git`. Fix `fa90f86`.
- Deviation from test-first: the repository has no test harness for its shell scripts, and adding one needs the owner's approval (CLAUDE.md), so no reproducing test was committed ahead of the fix. Each defect was reproduced with a throwaway probe and the failing line is quoted above. Suggested harness: see SDLC feedback.

## Verification
`$SDLC_VERIFY` run on the worktree with the `fa90f86` changes applied (committed right after). The two later docs-only commits, `84a0f4d` and `18c0894`, were re-checked with `scripts/verify-docs.sh` (`PASS: links, images, repo paths, stale markers and screenshot use in 49 markdown files`, run on `18c0894`). The contrast table is omitted:

```text
PASS: links, images, repo paths, stale markers and screenshot use in 49 markdown files
parity: OK (36 numeric and 14 color mirrors, 115 other shared tokens deliberately not mirrored)
contrast: OK (44 documented ratios, 34 invariants, 9 alias rules, 2 focus-ring bands, manifest colors)
web literals: OK (11 files)
swift literals: OK (87 files)
OK: mirrors match design/tokens.css, every contrast ratio holds and no literals found
PASS: CrocKit tests (Test run with 39 tests)
PASS: CrocApp tests
ok  	github.com/bakirgdev/CrocApp/crocmobile	5.209s
?   	github.com/bakirgdev/CrocApp/crocmobile/cmd/croctest	[no test files]
?   	github.com/bakirgdev/CrocApp/crocmobile/internal/relaycache	[no test files]
EXIT 0
```

## Remaining risks
- Publishing from a Mac capture is blocked until the Mac pairs are republished: `--copy-web` after a full Mac capture stops at the aspect check for at least `send-code` (shown) and likely `history`, `receive-conflict`, `send-files`, `stored-link` (1120 px published; widths in the R3 row). The iPhone pairs work (shown above). Known issue recorded; not this task's scope.
- The `verify-docs.sh` fix counts the target of any markdown link, not only `![](...)` images, as showing a screenshot (R6), so a plain `[x](a.png)` link also satisfies it. Looser than R6's wording; recorded in plan.md `## Changes`.
- Cleanup: removed the task's derived data, `_site/`, `web/docs/{build,node_modules,.docusaurus,static}`, `build/` and `CrocKit/.build/` from this worktree. `CrocKit/Croc.xcframework/` and `.tools/` stay (rebuilt here by `verify-swift.sh`; the worktree is removed with the task). Before each capture `build/screenshots/` was absent (first capture) or removed by hand; the plan's `rm -rf build/screenshots` step was only applied before `mac settings-advanced`.
- Not verified: a full `capture-screenshots.sh` run from a missing `build/screenshots/` (the `mkdir -p` and `verify_outputs` guard are code-read only), and the Sparkle update test.
- `--copy-web` is not atomic: it copies the PNGs before the aspect check and `cwebp` run, so a later failure leaves refreshed PNGs and some rebuilt WebPs in the tree (`git restore assets/screenshots web` undoes it). It also copies whatever is under `build/screenshots/`, so a partial or aborted earlier run can publish a half-new pair (a new light with an old dark). Spec R3 asks for "kept, not an error" for missing captures; a pair or freshness check would deviate from it. Left for the owner; deploy review should decide.
- `scripts/capture-screenshots.sh` (unchanged logic): a run of only non-store screens on a device prints `SHOTS-OK` having verified nothing, `simctl io ... screenshot 2>/dev/null` hides its error, and a screen-subset run does not delete the previous file before capturing. Pre-existing, not in this diff.
- `verify-docs.sh` R5 does not handle root-relative `src="/..."`, percent-encoded paths, unquoted values or an HTML comment; R6 counts a tracked WebP as showing its PNG even if no page uses it. Within the spec's scope.
- The first capture of the session failed with `FAIL: mac send-code light: the app opened no window` (30 s poll after a fresh build) and passed on the immediate retry with nothing changed; likely a slow first launch.
- Two defects found and left are in `docs/known-issues.md`: the stale published Mac Send pair, and `verify-docs.sh` exiting 1 silently when the last markdown file in sort order is deleted but unstaged.

## SDLC feedback
- Harness: a worktree-isolated session refuses many ordinary compound commands (`$VAR` paths, pipes into `grep`, `git` mixed with `mv`/`rm`), so single steps took several attempts and proof commands were split. Same cause as the plan and build entries; suggested change: `.claude/sdlc-scripts/next.sh` starts autonomous phases in a per-task worktree and `.claude/rules/sdlc.md` documents the single-command style.
- Subagent `sdlc-verifier` was isolated into the worktree I entered later in the session and its last proof (`xcodebuild -list`) was refused. Suggested change: in `.claude/skills/sdlc-test/SKILL.md`, enter the worktree (if any) after step 2 returns, not before.
- `/sdlc-test` step 4 requires a failing test first; for shell scripts and docs checks the repo has no harness. Suggested change: `.claude/skills/sdlc-test/SKILL.md` step 4 allows a recorded probe run as the reproduction when the project has no test harness for the changed file, and `/sdlc-setup` offers one (for example a `scripts/test/` bash runner for `verify-docs.sh`).
- `pr-test-analyzer` and `silent-failure-hunter` found the two real defects here that `sdlc-verifier` did not, because the verifier runs the plan's proofs and not hostile inputs. Suggested change: `.claude/agents/sdlc-verifier.md` adds "for each new check, try one input that should fail and one that should pass outside the plan's examples".
