---
slug: repo-cleanup
phase: deploy
status: draft
approved_by:
approved_at:
---

# Deploy: Repo cleanup: screenshots out of git, assets and .gitignore audit

PR: https://github.com/bakirgdev/CrocApp/pull/82

Risk: high. The plan set `medium`. The diff edits `assets/AGENTS.md` and `docs/AGENTS.md`, which are this repo's agent context files (root `AGENTS.md` stands in for CLAUDE.md), so the tier was raised. No app, transfer, signing, workflow or release code changes.

## Review findings
35 findings: 1 Important, 32 Nit, 2 Pre-existing. Rounds: 3. Duplicates across reviewers are counted once.

Round 1 sources: `sdlc-reviewer` (opus, find), `/code-review max` (15 findings plus 13 cut for its cap; its `capture-screenshots.sh:146,165` finding is split into a fixed row and a Pre-existing row, so 16 rows name it), `/security-review` (no findings: parsed image values reach no `eval`, unquoted expansion, `rm` or `cp`; `.gitignore` only adds rules). A fresh `sdlc-reviewer` (verify) checked the Important candidates and Pre-existing in rounds 1 and 2. Round 1 verify confirmed 6 of 8 as Nit or Pre-existing, none Important; it dropped the WebP mapping and the `sdlc/**` skip as recorded decisions.

| Round | Source | Severity | File:line | Class | Finding | Outcome | Reason or commit |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | code-review, sdlc-reviewer | Nit | `scripts/capture-screenshots.sh:146` | Stale or partial publish | `--copy-web` copies every capture with no freshness or light/dark pair check, so a leftover or half-finished run publishes a stale or mismatched pair and exits 0 | intentional | Spec R3 asks for an unconditional refresh; plan.md "Risks" accepts it and "Alternatives" rejects an `-nt` check. Tracked files, so `git status` shows it |
| 1 | code-review | Nit | `scripts/capture-screenshots.sh:147` | Non-atomic publish | PNGs and some WebPs are rewritten before the aspect and `cwebp` checks; the documented undo `git restore assets/screenshots` missed the WebPs | fixed | `2581547`: undo is `git restore assets/screenshots web`; `4c30625`: bad captures fail before any copy. Copying before the aspect check stays, like the WebP loop on main |
| 1 | code-review | Nit | `scripts/capture-screenshots.sh:146` | Bad input accepted | An empty or non-image capture (a failed `snap()` leaves one) overwrote the tracked PNG | fixed | `4c30625`, message `4b90864`; probes under "Fix probes" |
| 1 | code-review | Pre-existing | `scripts/capture-screenshots.sh:165` | Bad input accepted | A `<nil>` `sips` value makes `$(( ))` fail with `arithmetic syntax error`, then the script reports `FAIL: unknown argument '--copy-web'` | deferred-intent | `copy-web-sips-nil`. The arithmetic is unchanged from main; the new pre-copy check keeps unreadable captures out, but a bad tracked PNG or WebP still hits it |
| 1 | sdlc-reviewer, code-review | Pre-existing | `scripts/verify-docs.sh:40` | Silent gate exit | `[ -f "$f" ] && echo "$f"` ends the loop; when the last sorted `.md` is deleted but unstaged the script exits 1 with no output | deferred-intent | `verify-docs-silent-exit`. Blame `696081f`, on main; recorded in `docs/known-issues.md` |
| 1 | code-review | Nit | `scripts/verify-docs.sh:67` | Check accuracy | The unused-screenshot check misses `![a](p "title")`, reference-style images and `?raw=true` (false "unused"), and `<img SRC=`, `src = `, unquoted `src` broken images pass | unimportant | No such form in the tree; a false finding fails loudly in CI. Plan risk "the new image check misreads an unusual attribute" |
| 1 | code-review | Nit | `scripts/verify-docs.sh:194` | Check coverage | Each tracked WebP counts as showing its PNG without checking the PNG exists | intentional | plan.md "Alternatives" rejects it: `--copy-web` fails on it; not in the spec. Verify dropped it |
| 1 | code-review | Nit | `.github/pull_request_template.md:38` | Stale instruction | "Screenshots recaptured" no longer leads to anything to commit; publishing needs `--copy-web` | fixed | `2581547` |
| 1 | code-review | Nit | `scripts/verify-docs.sh:130` | Check accuracy | A markdown link, an `<img>` in an HTML comment or any tracked WebP counts as "shown" | unimportant | Looser than the header says; errs toward passing, never toward deleting a used file |
| 1 | code-review | Nit | `scripts/verify-docs.sh:195` | Index vs disk | The image and WebP checks read the git index, so an unstaged deletion passes locally and fails in CI | unimportant | CI catches it; same model as the existing link check |
| 1 | code-review | Nit | `scripts/verify-docs.sh:81` | Parsing edge cases | A `src` with a space, a `data:` URL in `srcset`, and a root-relative `src` are misparsed | unimportant | None in the tree; documented one-line limit |
| 1 | code-review | Nit | `docs/knowledge/screenshots.md:84` | Docs claim stale | "A window capture is typically 1120x1400" contradicts the 720 pt minimum width | fixed | `2581547`, corrected in round 2 and 3 |
| 1 | code-review | Nit | `scripts/verify-docs.sh:200` | Output format | The unused finding prints `path: msg` with no line number, points at "Where they are used" (no publish steps there), and says `git rm` for untracked files | unimportant | The finding names the file and the fix; the section lists what shows each shot |
| 1 | code-review | Nit | `scripts/verify-docs.sh:113` | Duplication | The image branch re-implements the link branch, and the two treat schemes and `?query` differently | unimportant | Refactor beyond this task |
| 1 | code-review | Nit | `scripts/verify-docs.sh:39` | Check scope | `':!:sdlc/**'` removes task records from every check, not only inline-code paths | intentional | Plan D1 (accepted); the narrower skip was rejected because task-record links rot after renames. Verify dropped it |
| 1 | code-review, sdlc-reviewer | Nit | `docs/known-issues.md:132` | Docs labelling | "likely stale" instead of "inferred"; `settings` claimed to match a fresh capture without one; no "why it was left" | fixed | `2581547` |
| 1 | code-review (cut for cap) | Nit | `scripts/verify-docs.sh`, `.gitignore`, `docs/` (13 items) | Mixed | One `grep` per PNG (about 60 ms); protocol comments not updated for the `image` kind; WebP-to-PNG mapping written twice; `assets/AGENTS.md:27` restates publish steps; `/.playwright-mcp/` anchored to the root; `.env*` comment; `GIT_GLOB_PATHSPECS=1`; `/crocmobile/croctest` not excluded in `verify-swift.sh:31`; no minimum-size check; `RELEASING.md` `mktemp -d` path; long `tooling.md:39` bullet; `normalize()` clamps `..`; "any capture makes them again" | unimportant | Each low impact; listed so none is lost |
| 2 | sdlc-reviewer | Important | `docs/knowledge/screenshots.md:84` | Docs claim does not match code | Round 1's fix stated a fixed 1440x1400 Mac capture, but the code sets only a 880x700 pt default and a 720 pt minimum, and a saved frame wins; same claim at `docs/known-issues.md:129` | fixed | `4b90864` (verify confirmed it Important) |
| 2 | sdlc-reviewer | Nit | `scripts/capture-screenshots.sh:146` | Validation weaker than message | The pre-copy check accepts any image `sips` reads while the message said "not a PNG" | fixed | `4b90864`: "not a readable image" |
| 3 | sdlc-reviewer | Nit | `docs/knowledge/screenshots.md:84` | Doc accuracy | "some published main-window pairs are 1120 px wide": all are | fixed | `882d33c` |
| 3 | sdlc-reviewer | Nit | `docs/knowledge/screenshots.md:84` | One fact, one home | The window sizes repeat `docs/knowledge/app-ui-architecture.md` | fixed | `882d33c`: links "One main window" |
| 3 | sdlc-reviewer | Nit | `docs/knowledge/screenshots.md:84` | Doc accuracy | "Settings opens 480 pt wide" stated without the saved-frame caveat | fixed | `882d33c`: sizes moved to their home doc |
| 3 | sdlc-reviewer | Nit | `docs/knowledge/screenshots.md:84` | One idea per sentence | Three ideas chained; the "dishonest" clause reads as about the 1120 px pairs | fixed | `882d33c` |

### Fix probes
`4c30625`, before the fix, with an empty `build/screenshots/iphone/send-code-light.png`: `--copy-web` output (non-`kept` lines), exit code, then `wc -c < assets/screenshots/iphone/send-code-light.png`:

```text
rc=1
rebuilt 18 files in web/docs/screenshots
Warning: assets/screenshots/iphone/send-code-light.png not a valid file - skipping
Warning: assets/screenshots/iphone/send-code-light.png not a valid file - skipping
FAIL: cwebp failed on assets/screenshots/iphone/send-code-light.png
       0
```

After the fix, the same empty file, plus `not a png` in `build/screenshots/mac/history-light.png`. Then `git status --porcelain`, then the junk file alone:

```text
FAIL: build/screenshots/iphone/send-code-light.png is empty or not a PNG: capture that screen again, nothing was copied
rc=1
 M scripts/capture-screenshots.sh
FAIL: build/screenshots/mac/history-light.png is empty or not a PNG: capture that screen again, nothing was copied
rc=1
```

A valid capture (a copy of the tracked `iphone/onboarding-dark.png`):

```text
refreshed 1 of 20 PNGs in assets/screenshots from build/screenshots
rebuilt 18 files in web/docs/screenshots
rebuilt 4 files in web/landing/assets/img/screenshots
```

The `4b90864` wording ("not a readable image") was rechecked by `sdlc-verifier` on `cbadd69` (under `## Checks`).

## SDLC feedback
Issues A, B and C go to `bakirgdev/ai-native-sdlc`, one issue per theme: A is autonomous mode and the harness, B is gate and review agent checklists, C is skill text and templates.

| Artifact | Feedback | Outcome | URL, slug or reason |
| --- | --- | --- | --- |
| intent | Background sessions stall on MCP tool approvals; the plan gate blocks the untracked `.claude/settings.local.json` | issue | A |
| intent | Gatekeeper does not spot-check repo facts in the intent | issue | B |
| spec | Harness worktree isolation conflicts with committing on `sdlc/<slug>`; isolated subagents' Bash refused | issue | A |
| spec | `/sdlc-spec` step 4 grills in autonomous mode | issue | A |
| spec | Gatekeeper does not check handed-on commands against the documented invocation | issue | B |
| spec | Gatekeeper spec item lacks "policy skills applied" and repo-fact spot-checks | issue | B |
| plan | Accepted spec failed `verify-docs.sh` in the commit gate; setup should skip `sdlc/**`, gatekeeper should run the check command | issue | B, C |
| plan | Autonomous phases need a per-task worktree (repeat) | issue | A |
| plan | Gatekeeper misses relocated paths in "no change needed" claims | issue | B |
| plan | Gatekeeper should spot-check line numbers and run read-only proofs | issue | B |
| plan | `/sdlc-plan` step 5 grills in autonomous mode | issue | A |
| build | Worktree guard refuses compound git commands; plan proofs should be single commands | issue | A |
| build | Commit gate does not fire on a detached HEAD (repeat of the worktree item) | issue | A |
| build | build.md template `## Deviations` vs plan.md `## Changes` | issue | C |
| build | build.md template has no slot for literal requirement proofs | issue | C |
| build | Gatekeeper build item misses behavior deviations inside named files | issue | B |
| build | Gatekeeper build item misses process steps the plan requires | issue | B |
| test | Worktree guard refuses ordinary compound commands | issue | A |
| test | `/sdlc-test` should enter a worktree only after `sdlc-verifier` returns | issue | A |
| test | Test-first needs a probe alternative when no harness exists | issue | C |
| test | This project has no test harness for its shell scripts | task | `shell-script-tests` |
| test | `sdlc-verifier` runs no hostile inputs against new checks | issue | B |
| deploy (reviewer) | Scripts CI runs on Linux (`awk`, `sed`) are probed only on macOS; REVIEW.md should require a CI or GNU/mawk run | task | `review-md-tuning` |
| deploy (reviewer) | `sdlc-reviewer` find mode re-reports tradeoffs already decided in test.md and plan.md | issue | B |
| deploy (reviewer) | `sdlc-reviewer` verify mode: severity for findings that arrive without one, `REJECTED` vs `DROPPED` | issue | B |
| deploy (reviewer) | Gatekeeper test item does not cross-check recovery commands between docs and artifacts | issue | B |
| deploy (reviewer) | `/sdlc-deploy` should require quoting probe output for a fixed script finding | issue | C |
| deploy (reviewer) | REVIEW.md Docs row: a measured value stated as fixed should rate Important | task | `review-md-tuning` |
| deploy (reviewer) | REVIEW.md Docs row: a fact restated outside its home should rate Nit | task | `review-md-tuning` |
| deploy (noise) | Two "Check accuracy" findings on `verify-docs.sh` (`:67`, `:130`) ended `unimportant`: extractor edge cases for markdown forms the repo does not use. REVIEW.md should rate those Nit unless a tracked file uses the form | task | `review-md-tuning` |
| deploy | `/sdlc-deploy` step 2 names `CLAUDE.md` but not `AGENTS.md` or nested context files; the guess set the tier to `high` | issue | C |
| deploy | A `/code-review max` finder ran `git checkout -q -- .` in the live checkout (tree was clean, nothing lost) | issue | C |
| deploy (gatekeeper) | Step 3's "fix test-first" cannot apply to a docs-only Important finding; say a quoted read of the corrected text is the proof | issue | C |
| deploy (gatekeeper) | "Run `sdlc-verifier` again" should say after the last commit that changes code, scripts included | issue | B, C |
| deploy (gatekeeper) | Gatekeeper Bash allows only `git`/`ls`, but the deploy check needs read-only `gh pr view`/`gh pr checks` | issue | B |
| deploy (gatekeeper) | Worktree guard refused `git diff $(git merge-base ...)` (repeat) | issue | A |
| deploy (gatekeeper) | The deploy gate flags outcomes still waiting on the owner on every run; run it after the grilling round, or allow `proposed` outcomes while `status: draft` | issue | C |

Outcomes are proposed and wait for the owner's yes; issue URLs are added when the issues are filed.

## Checks
PR #82 on `cbadd69`, `gh pr checks 82`: every check passes or skips by area, no review comments, `mergeStateStatus: CLEAN`. The `docs checks` job runs `verify-docs.sh` on `ubuntu-26.04`, so the new awk constructs work outside macOS awk.

```text
Analyze (actions)	pass
Analyze (go)	pass
Analyze (javascript-typescript)	pass
CodeQL	pass
changes	pass
ci pass	pass
design checks	pass
docs checks	pass
shellcheck	pass
site build	pass
build (${{ matrix.platform }})	skipping
go	skipping
interop (local relay)	skipping
swift-format	skipping
```

`sdlc-verifier` reran on `cbadd69`, the last code commit, and every check passed. `go test` came from the cache: the diff changes no Go code, and the earlier run on `2581547` was not cached (`5.226s`). Output, last lines of each command:

```text
PASS: links, images, repo paths, stale markers and screenshot use in 49 markdown files
OK: mirrors match design/tokens.css, every contrast ratio holds and no literals found
PASS: CrocKit tests (Test run with 39 tests)
PASS: CrocApp tests
ok  	github.com/bakirgdev/CrocApp/crocmobile	(cached)
?   	github.com/bakirgdev/CrocApp/crocmobile/cmd/croctest	[no test files]
?   	github.com/bakirgdev/CrocApp/crocmobile/internal/relaycache	[no test files]
```

`shellcheck -x scripts/*.sh`: no output, exit 0. R3 `--copy-web` with no `build/`: exit 0, `refreshed 0 of 20 PNGs in assets/screenshots from build/screenshots`, tree unchanged. With an empty capture, it exits 1 and changes no tracked file:

```text
FAIL: build/screenshots/iphone/send-code-light.png is empty or not a readable image: capture that screen again, nothing was copied
```

## Release
None: this change ships no app build. Releases follow `docs/RELEASING.md` on a `v*` tag.
