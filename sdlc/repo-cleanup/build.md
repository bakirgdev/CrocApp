---
slug: repo-cleanup
phase: build
status: accepted
approved_by: sdlc-gatekeeper
approved_at: 2026-10-27
---

# Build: Repo cleanup: screenshots out of git, assets and .gitignore audit

## Done
- Step 1: `verify-docs.sh` skips `sdlc/**`; `docs/knowledge/tooling.md` says so. Commit 5f21671.
- Step 2: `.gitignore` is the plan's target block; `web/docs/static/img/mascot.webp` untracked (file kept on disk); `tokens` script in `web/docs/package.json` runs `mkdir -p static/img`. Commit 5f21671 (C1).
- Step 3: `scripts/capture-screenshots.sh` writes to `build/screenshots/`; `PUBLISHED=assets/screenshots` used only by `--copy-web`, which refreshes the published PNGs first; `verify_outputs` guard and the full-run `mkdir -p`. Commit 0432f50 (C2).
- Step 4: 118 PNGs removed with `git rm`; 20 stay. Commit 0432f50.
- Step 5: `verify-docs.sh` checks `src`/`srcset` targets (R5) and unused screenshots (R6). Commit 0432f50.
- Step 6: docs (`assets/AGENTS.md`, `design/brand.md`, `docs/knowledge/screenshots.md`, `docs/known-issues.md`, `docs/RELEASING.md`, `docs/AGENTS.md`, `docs/BUILDING.md`). Commit 6d4c8db (C3). `claude-md-management:claude-md-improver` was run on `assets/AGENTS.md` and `docs/AGENTS.md` after the gatekeeper's first FAIL; both files match their directories and need no further edit.
- Step 7: proofs run by the main session and repeated by `sdlc-verifier` (fresh context).
- After the gatekeeper's first run: the image check skips URLs with a scheme (`data:`, `mailto:`, `https:`) and `//host`, and splits on commas only for `srcset`; header wording fixed. Commit 4f0e0a1.

## Deviations from the plan
- One, recorded in plan.md `## Changes` (2026-10-27): the image-check hardening in the last Done line, found by the verifier and fixed instead of documented.

## Verification

Check command, `$SDLC_VERIFY`, run on 6d4c8db (the contrast table, lines 4 to 49 of the output, is omitted here). After it, only `scripts/verify-docs.sh` changed (image-check hardening); its output is below.

```text
PASS: links, images, repo paths, stale markers and screenshot use in 49 markdown files
parity: OK (36 numeric and 14 color mirrors, 115 other shared tokens deliberately not mirrored)
[... contrast table omitted ...]
contrast: OK (44 documented ratios, 34 invariants, 9 alias rules, 2 focus-ring bands, manifest colors)
web literals: OK (11 files)
swift literals: OK (87 files)
OK: mirrors match design/tokens.css, every contrast ratio holds and no literals found
Rebuilding CrocKit/Croc.xcframework (missing or older than crocmobile/)
PASS: CrocKit tests (Test run with 39 tests)
PASS: CrocApp tests
ok  	github.com/bakirgdev/CrocApp/crocmobile	4.871s
?   	github.com/bakirgdev/CrocApp/crocmobile/cmd/croctest	[no test files]
?   	github.com/bakirgdev/CrocApp/crocmobile/internal/relaycache	[no test files]
EXIT 0
```

R4, R7, R9, R10 and R12 grep (main session, on 6d4c8db):

```text
== R4
138 35546221
20 4379114
== R7
R7-OK
assets/AGENTS.md
== R8/R9 tracked-but-ignored
(end)
== R9 plan vs .gitignore
GITIGNORE-MATCHES-PLAN
== R9 probes
(end probes)
== R10
4:REPO=$(git rev-parse --show-toplevel) && cd "$(mktemp -d)" && mkdir feed
16:     xcodebuild -project "$REPO/app/CrocApp.xcodeproj" -scheme 'CrocApp Direct' -configuration Release -destination 'platform=macOS' \
22:        CrocApp Direct
32:        CrocApp Direct
== R12 grep
(end)
```

R2 (`--list`), R3 (fresh worktree of 6d4c8db, `--copy-web`), R8 (fresh worktree, `scripts/assemble-site.sh`, then Playwright on `http://127.0.0.1:8790/docs/`):

```text
paths:       94
assets mentions: 0
0                                    (bash -c guard line)

exit 0                               (--copy-web)
20                                   ("kept" lines)
refreshed 0 of 20 PNGs in assets/screenshots from build/screenshots
rebuilt 18 files in web/docs/screenshots
rebuilt 4 files in web/landing/assets/img/screenshots
status after:                        (empty)

static dir present in fresh checkout: no
assemble exit 0
MASCOT-OK     4286
{ "naturalWidth": 128, "src": "http://127.0.0.1:8790/docs/img/mascot.webp" }
```

R5 and R6 (main session, before the hardening; `sdlc-verifier` repeated them):

```text
README.md:66: broken image: assets/screenshots/mac/send-code-nope.png
README.md:65: broken image: assets/screenshots/mac/send-code-nope.png
img-probe.md:2: broken image: nope.png
assets/screenshots/ipad/home-light.png: unused screenshot: no markdown image or web WebP copy shows it. Publish it or git rm it (docs/knowledge/screenshots.md, "Where they are used")
```

After the hardening, a probe file with `data:`, `//host`, `https:`, `data-src`, a `srcset` with a missing second candidate and a `src` with `?raw=1#x`, then the real tree:

```text
img-probe.md:5: broken image: nope-2x.png
img-probe.md:6: broken image: nope.png?raw=1#x
FAIL: 2 finding(s). Fix the doc, or the path it names; never the check.
PASS: links, images, repo paths, stale markers and screenshot use in 49 markdown files
```

Summary of the `sdlc-verifier` report (its literal output matches the blocks above), on 6d4c8db: R1 (`R1-OK`, 20 files), R2, R4, R5, R6, R7, R9, R10, R12, `scripts/verify-design.sh` and `shellcheck -x scripts/*.sh` all pass; `git status --porcelain` empty at the end.

Not verified (build phase): a real capture run (`mac send-code`, `iphone send-code`, `mac settings-advanced`, full run from a missing `build/screenshots/`), R3 after a capture, R11 (full build from a clean checkout), and the Sparkle update test itself. These belong to the test phase; the `verify_outputs` guard and the `mkdir -p` are covered by a code read (also by the gatekeeper) and the guard line above only.

## Notes for the test phase
- Run the capture proofs of the plan (R2 captures, R3 after a capture, R11 full build). If the capture preflight fails in a background session, report them "not verified" and ask the owner to run `scripts/capture-screenshots.sh mac send-code` then `git status --porcelain`.
- The build ran in the detached worktree `.claude/worktrees/repo-cleanup-build`; `sdlc/repo-cleanup` in the root checkout is moved to the build head by a fast-forward. That worktree holds ignored build output (`CrocKit/Croc.xcframework/`, `CrocKit/.build/`, `.tools/`); remove the worktree when the task ends.

## SDLC feedback
- The harness's worktree guard refuses compound git commands in a worktree-isolated session (`;`/`&&` chains, loops that call git, brace expansion in `git rm`, `xargs git`, even a file name containing `.git`), so the plan's proof loops (R2, R9) and the 118-file removal could not run verbatim. Why it hurts: extra rounds, and proofs rewritten by hand. Suggested change: write plan proofs as single commands (`git check-ignore --stdin` over a path list, `git rm` with quoted pathspecs), in `.claude/skills/sdlc-plan/SKILL.md`.
- Repeated from plan and spec: autonomous phases need a per-task worktree started by `.claude/sdlc-scripts/next.sh`; this build worked in a detached worktree and fast-forwarded the branch, and the commit gate hook does not apply on a detached HEAD, so `$SDLC_VERIFY` was run by hand.
- From `sdlc-gatekeeper`: the build.md template (`.claude/skills/sdlc-build/SKILL.md`) has a `## Deviations from the plan` section while step 6 sends deviations to plan.md `## Changes`, which invites "None" in one place and nothing in the other. Suggested change: the template line reads "None, or see plan.md `## Changes`".
- From `sdlc-gatekeeper`: the build.md template has a literal slot only for `$SDLC_VERIFY`, so sessions summarize the per-requirement proofs. Suggested change: add a "Requirement proofs (literal output per R#)" slot, in `.claude/skills/sdlc-build/SKILL.md`.
- From `sdlc-gatekeeper`: its build item asks for a recorded deviation only for a file outside the plan, not for behavior that differs from a step's stated design inside a named file. Suggested change: add "behavior that differs from a step's stated design, in a named file, is recorded under plan.md `## Changes`" to the build item, in `.claude/agents/sdlc-gatekeeper.md`.
- From `sdlc-gatekeeper`: its build item compares only the diff with the plan, so process steps a plan requires (a named skill, `sdlc-verifier`) leave no trace and go unchecked. Suggested change: add "process steps the plan requires are confirmed or recorded as deviations" to the build item, in `.claude/agents/sdlc-gatekeeper.md`.
