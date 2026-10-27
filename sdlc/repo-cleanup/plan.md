---
slug: repo-cleanup
phase: plan
status: accepted
approved_by: sdlc-gatekeeper
approved_at: 2026-10-27
---

# Plan: Repo cleanup: screenshots out of git, assets and .gitignore audit

Implements spec.md (accepted) as written, with three additions found while planning, each marked **(new)** where it applies and explained under "Decisions recorded":

1. `scripts/verify-docs.sh` skips `sdlc/**`. Today it fails on `sdlc/repo-cleanup/spec.md` (4 findings: `crocmobile/testdata/fuzz`, `notes.md`, `crocmobile/croctest`, `crocmobile/testdata/fuzz/X/y`, run 2026-10-27 on `f2fd501`), and the SDLC commit gate runs `verify-docs.sh` (`SDLC_VERIFY` in `.claude/settings.json`) before every code commit, so no build commit could land. After step 4 the spec's probe `assets/screenshots/ipad/home-light.png` would fail too.
2. `/.playwright-mcp/` joins `.gitignore` ("Local tooling"). Spec concern 2 is resolved: one `browser_navigate` plus one `browser_take_screenshot` without a filename, run from the repo root on 2026-10-27, wrote `.playwright-mcp/page-<timestamp>.yml` and `.png` at the repo root (deleted afterwards).
3. `.env*` gets the comment spec concern 3 asks for.

No app code, no workflow, nothing under `.claude/`, no user-visible change (so no `CHANGELOG.md` entry), no transfer path (no harness applies, `AGENTS.md` "Verification").

## Files that change

- `scripts/verify-docs.sh`
- `docs/knowledge/tooling.md` **(new: the `sdlc/**` skip, step 1)**
- `.gitignore`
- `web/docs/package.json`
- `web/docs/static/img/mascot.webp` (untracked, kept on disk)
- `scripts/capture-screenshots.sh`
- `assets/screenshots/**` (118 files removed)
- `assets/AGENTS.md`
- `design/brand.md`
- `docs/knowledge/screenshots.md`
- `docs/known-issues.md`
- `docs/RELEASING.md`
- `docs/AGENTS.md`
- `docs/BUILDING.md`

No new files.

## Steps

Run in order in the main build session (steps 2, 3 and 4 touch disjoint files and are parallel-safe, but they are small; sequential is cheaper than spawning implementers). Commit points: C1 after step 2, C2 after step 5, C3 after step 6. Every code commit runs `SDLC_VERIFY` (includes `verify-swift.sh`, several minutes), so three commits, not one per step. Commit messages follow Conventional Commits, as `git log main` does (`chore(repo): ...`, `fix(scripts): ...`), with no attribution lines (intent constraint 3).

1. **`verify-docs.sh` skips task records (new, unblocks the commit gate).** In `scripts/verify-docs.sh` line 31, add `':!:sdlc/**'` to the pathspec of the docs list (`$TMP/files`) only; the tracked set on line 36 stays whole, so a doc may still link into `sdlc/`. Header lines 3-5: say it skips `web/docs/content/` (Docusaurus checks it), `.claude/**` and `sdlc/**`. In `docs/knowledge/tooling.md` line 39, extend the sentence "`verify-docs.sh` skips `.claude/**`, ..." with: "and `sdlc/**`, whose task records name paths as they were when written, including paths a task deletes, so a later change would break them". Check: `scripts/verify-docs.sh` exits 0. (D1)
2. **`.gitignore`, mascot copy, docs `tokens` script** (R8, R9). parallel-safe.
   - Replace `.gitignore` with exactly the block under "Target `.gitignore`" below.
   - `git rm --cached -q web/docs/static/img/mascot.webp` (the file stays on disk, now ignored).
   - `web/docs/package.json`, `tokens` script becomes `cp ../../design/tokens.css src/css/tokens.css && mkdir -p static/img && cp ../landing/assets/img/mascot-web.webp static/img/mascot.webp`. Nothing else in the file changes; the lockfile is untouched. `static/img/` held only the mascot, so a fresh clone has no `static/` at all.
   - Commit C1, for example `chore(repo): regroup .gitignore and stop tracking the docs mascot copy`.
3. **Capture output to `build/screenshots/`** (R2, R3). parallel-safe. In `scripts/capture-screenshots.sh`:
   - Line 48: `OUT=build/screenshots`, and below it `PUBLISHED=assets/screenshots` with a short comment: the tracked, published subset, read and written only by `--copy-web`.
   - Header (lines 2-14, including the `app-store/CLASS` lines): the outputs are under `build/screenshots/` (gitignored); git keeps only the published pairs in `assets/screenshots/`. Line 32: `no arguments    everything, after emptying build/screenshots/`. Line 36: `--copy-web      publish: refresh assets/screenshots/ from build/screenshots/, then rebuild the web WebP copies from it, and exit (needs cwebp)`.
   - `--copy-web` branch (lines 129-159): keep `command -v cwebp ... || fail` first, so a missing `cwebp` changes nothing. Then, before the WebP loop, refresh step: for every `*.png` that `find "$PUBLISHED" -name '*.png' | sort` lists, with `rel=${f#"$PUBLISHED"/}`, if `"$OUT/$rel"` is a file, `cp "$OUT/$rel" "$f"` and count it; otherwise print `kept $f (no capture at $OUT/$rel)`. Feed the loop with `done < <(find ...)`, like the WebP loop, so counters survive. Print `refreshed N of M PNGs in $PUBLISHED from $OUT`. In the WebP loop, `src="$PUBLISHED/${rel%.webp}.png"`; extend the missing-source failure to `fail "$f has no source $src: publish its PNG pair first (docs/knowledge/screenshots.md, \"Where they are used\")"`. Sizes, flags, aspect check and other failures stay as they are.
   - Full-run wipe (line ~829): `mkdir -p "$OUT"` right before `find "$OUT" -mindepth 1 -maxdepth 1 -exec rm -rf {} +` (`find` on a missing folder fails under `set -e`). The per-device `rm -rf` branch needs nothing.
   - `verify_outputs` (line 787): `n=$(find "$OUT/app-store/$(store_class "$d")" -name '*.png' | wc -l)` fails under `set -euo pipefail` when the class folder is missing. That folder used to be tracked, so it always existed; under `build/screenshots/` it is missing on a fresh clone or after a cleanup, and a run of only non-store screens (`onboarding`, `home`, `receive-code`, `receive-conflict`, `settings-advanced`; three of them published) writes no store file. Guard it: add `dir` to the function's `local` line (line 778), then `dir="$OUT/app-store/$(store_class "$d")"; n=0; if [ -d "$dir" ]; then n=$(find "$dir" -name '*.png' | wc -l); fi`.
   - `--list`, `snap` and `store_file` already use `$OUT` and create their folders (`mkdir -p` on lines 580 and 595): no change. Nothing else in the capture logic changes.
4. **Remove the 118 unused PNGs** (R1). parallel-safe.
   ```bash
   printf 'assets/screenshots/%s\n' \
     mac/{send-code,send-files,receive-conflict,stored-link,settings,settings-advanced,history}-{light,dark}.png \
     iphone/{send-code,receive-incoming,onboarding}-{light,dark}.png | LC_ALL=C sort > "$TMPDIR/keep.txt"
   git ls-files assets/screenshots | LC_ALL=C sort | comm -23 - "$TMPDIR/keep.txt" > "$TMPDIR/drop.txt"
   wc -l < "$TMPDIR/drop.txt"            # must print 118
   xargs git rm -q -- < "$TMPDIR/drop.txt"
   ```
   `git rm`, not `--cached`: `assets/screenshots/` is not ignored, so files left on disk would show as untracked. Delete both temp files afterwards.
5. **`verify-docs.sh` image and unused-screenshot checks** (R5, R6). After step 4, or R6 fails on the tree.
   - R5, extraction: in the candidate awk (lines 41-62), on the line after inline code spans are stripped (the `gsub` on line 57), match `src="..."` and `srcset="..."` attributes preceded by whitespace (so `data-src=` does not match). For `srcset`, split the value on commas and take the first whitespace-separated word of each candidate. Emit each URL as kind `image`. Fenced code is already skipped; inline code is skipped because the stripped line is used.
   - R5, resolution: in the resolver awk, kind `image`: skip `^https?:`; drop anything from the first `#` or `?`; resolve with `normalize(dir "/" path)` and `have()`, exactly like a relative link; missing prints `file<TAB>line<TAB>broken image: <url>`. For every image target (found or not) also print `file<TAB>line<TAB>@<target>`; the result loop sends `@` lines to `$TMP/shown` and counts nothing for them (add the `@*)` case before `*)`).
   - R6: after the result loop, add to `$TMP/shown` every tracked or new `.webp` under `web/docs/screenshots/` and `web/landing/assets/img/screenshots/` (`git ls-files --cached --others --exclude-standard 'web/docs/screenshots/*.webp' 'web/landing/assets/img/screenshots/*.webp'`; a pathspec `*` matches `/`, as the existing `'*.md'` relies on), mapped to `assets/screenshots/<rel>.png`. Then every PNG from `git ls-files --cached --others --exclude-standard 'assets/screenshots/*.png'` that exists on disk and is not in `$TMP/shown` is a finding, printed as `<png>: unused screenshot: no markdown image or web WebP copy shows it. Publish it or git rm it (docs/knowledge/screenshots.md, "Where they are used")`. Tracked plus new, not ignored, matches how the script already treats docs. Read every loop from a file or `< <(...)`, never a pipe, so `findings` keeps counting.
   - Header: add check 4 (image targets in `src`/`srcset`, http(s) skipped) and check 5 (unused screenshots), and a known limit: an attribute whose value spans lines is not checked. PASS line: `PASS: links, images, repo paths, stale markers and screenshot use in N markdown files`.
   - `shellcheck -x scripts/verify-docs.sh scripts/capture-screenshots.sh` clean.
   - Commit C2, for example `chore(repo): keep only published screenshots in git and check that each is shown`.
6. **Docs** (R7, R10, R12). In `assets/`, only `assets/AGENTS.md` and the step-4 removals change; every other asset stays byte for byte (R7). Wording below is the content to carry; match each file's voice and `docs/AGENTS.md` writing rules (no dates, no planning IDs, no section numbers). Use `claude-md-management:claude-md-improver` for the two `AGENTS.md` files (root `AGENTS.md` rule).
   - `assets/AGENTS.md`: row `screenshots/...` becomes `screenshots/{mac,iphone}/<screen>-{light,dark}.png`: full-resolution captures of only the screens something shows (list: `docs/knowledge/screenshots.md`, "Where they are used"), published from `build/screenshots/` by `scripts/capture-screenshots.sh --copy-web`; used by the README and as sources of the web copies. Drop the `screenshots/app-store/...` row; one line says the App Store upload sets are not here: the capture script writes them to `build/screenshots/app-store/<class>/` (gitignored) for each submission. Rules: screenshots come only from the script, which writes every capture to `build/screenshots/`; `--copy-web` refreshes the published PNGs here, then the WebPs; to publish a new screen, copy its pair from `build/screenshots/` into `screenshots/`, run `cwebp` once into the web folder at the page's size, and reference it; `scripts/verify-docs.sh` fails on a PNG here that nothing shows. The intro ("nothing here is build output") stays true.
   - `design/brand.md` lines 74-75: Screenshots row path `assets/screenshots/{mac,iphone}/<screen>-{light,dark}.png` (published pairs only), use "README; sources of the docs and landing WebP copies". App Store screenshots row path `build/screenshots/app-store/<class>/NN-<screen>-{light,dark}.png`, use "App Store Connect; generated by `scripts/capture-screenshots.sh` at submission, not committed".
   - `docs/knowledge/screenshots.md`: line 3 says the script writes to `build/screenshots/` (gitignored) and git keeps only the published pairs in `assets/screenshots/`; the layout block (lines 5-11) is rooted at `build/screenshots/`; "Running it": `# everything; empties build/screenshots/ first`, and `--copy-web` described as "publish the pairs git keeps, then refresh the web copies; no display needed"; the `--copy-web` bullets gain a first one: it first copies each PNG in `assets/screenshots/` from the same path under `build/screenshots/` when a capture is there, keeps and names one that has none, so it runs on a fresh clone; line 34 (publish a new shot) gains the copy into `assets/screenshots/`. "App Store sizes": one sentence that a submission starts with a capture and uploads from `build/screenshots/app-store/<class>/`. "Where they are used", line 178: git keeps these ten pairs in `assets/screenshots/` and nothing else; every other capture and the App Store sets stay in `build/screenshots/`, and any capture makes them again; `scripts/verify-docs.sh` fails on a tracked PNG nothing shows. The cross-reference to `../known-issues.md`, "Docs site" goes.
   - `docs/known-issues.md`: delete the "Most screenshot pairs are unused" bullet and its three sub-bullets under "Docs site" (lines 120-123).
   - `docs/RELEASING.md`, "Testing a Sparkle update locally": the scratch-directory sentence gains the commands, run from inside the checkout: `REPO=$(git rev-parse --show-toplevel) && cd "$(mktemp -d)" && mkdir feed`. Step 2 reads "Build twice, as build 1 and build 2, from the scratch directory:" and the `xcodebuild` line gains `-project "$REPO/app/CrocApp.xcodeproj"`. Every other step already works on relative paths in the scratch directory (`key.pem`, `priv.b64`, `pub.b64`, `dd1`, `dd2`, `feed/`, `apps/`).
   - `docs/AGENTS.md` line 34: `scripts/verify-docs.sh` checks every relative link, image and repo path in the markdown docs, and that every PNG in `assets/screenshots/` is shown somewhere; CI runs it.
   - `docs/BUILDING.md` line 122: comment `# links, images, repo paths, stale markers, unused screenshots (docs/AGENTS.md)`.
   - `scripts/verify-docs.sh`, `scripts/verify-design.sh` pass. Commit C3, for example `docs: describe where screenshots are captured and published`.
7. **Build-phase checks** (R1-R10, R12). Run the Proof commands for R1-R10 and R12 through `sdlc-verifier` and record the output in build.md, including both R4 measurements, which `/sdlc-deploy` copies into the PR description.
8. **Test phase** (R2 capture, R3 publish, R11). The spec's "Full build" steps 1-8 from a clean checkout, the capture runs in the R2 proof with `--copy-web` right after the `mac send-code` capture (R3), the clean-tree check, then the spec's cleanup list. If the capture preflight fails in a background session, report those parts "not verified" and ask the owner to run `scripts/capture-screenshots.sh mac send-code` followed by `git status --porcelain` (spec concern 1).

### Target `.gitignore`

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
# A committed template (.env.example, .envrc.example) needs a ! line after .env*.
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
/.playwright-mcp/
.claude/settings.local.json
.claude/worktrees/
```

This is the spec's target plus the `.env*` comment line and `/.playwright-mcp/`.

## Proof

Run from the repo root of the task branch. `TMPDIR` stands for any scratch directory outside the repo.

- R1: `git ls-files assets/screenshots | LC_ALL=C sort | diff - <(printf 'assets/screenshots/%s\n' mac/{send-code,send-files,receive-conflict,stored-link,settings,settings-advanced,history}-{light,dark}.png iphone/{send-code,receive-incoming,onboarding}-{light,dark}.png | LC_ALL=C sort) && echo R1-OK` prints only `R1-OK`; `git ls-files assets/screenshots | wc -l` prints 20.
- R2: `scripts/capture-screenshots.sh --list | awk '/^  /{print $1}' | while IFS= read -r p; do git check-ignore -q "$p" || echo "NOT IGNORED: $p"; done` prints nothing, and `! scripts/capture-screenshots.sh --list | grep -q assets/` succeeds. Capture runs (test phase, spec concern 1), each starting with `rm -rf build/screenshots`: `scripts/capture-screenshots.sh mac send-code` and `scripts/capture-screenshots.sh iphone send-code` end with `SHOTS-OK` and write `build/screenshots/mac/send-code-light.png` and `build/screenshots/app-store/mac/02-send-code-dark.png` (and the iPhone equivalents); `scripts/capture-screenshots.sh mac settings-advanced` (a non-store screen, so no class folder exists) ends with `SHOTS-OK`, which proves the `verify_outputs` guard; `git status --porcelain` is empty after each. The full-run `mkdir -p` is proven by a full run from a missing `build/screenshots/` only if the preflight passes and time allows. Whatever cannot run is "not verified", and both guards are then proven by a code read plus `bash -c 'set -euo pipefail; d=/nonexistent; n=0; if [ -d "$d" ]; then n=$(find "$d" -name "*.png" | wc -l); fi; echo "$n"'` printing `0`.
- R3: fresh checkout: `git worktree add --detach "$TMPDIR/rc-fresh" HEAD`, then in it `scripts/capture-screenshots.sh --copy-web` exits 0, prints 20 `kept` lines, `refreshed 0 of 20 PNGs`, `rebuilt 18 files in web/docs/screenshots` and `rebuilt 4 files in web/landing/assets/img/screenshots`; then `git worktree remove --force "$TMPDIR/rc-fresh"`. Right after the test-phase capture of `mac send-code` (before the next capture wipes `build/screenshots/`), `--copy-web` prints `refreshed 2 of 20` (plus the iPhone pair if captured) and `git status --porcelain` lists `assets/screenshots/mac/send-code-{light,dark}.png` and their WebPs as modified; restore them with `git restore assets/screenshots web/docs/screenshots web/landing/assets/img/screenshots`.
- R4: `git ls-tree -r -l daad96b assets/screenshots | awk '{n++; s+=$4} END {print n, s}'` prints `138 35546221`; the same at the branch head prints `20 4379114`. Both numbers go into the PR description (deploy).
- R5: `scripts/verify-docs.sh` passes on the real tree. Mutations, each reverted with `git checkout README.md`: change README line 66 `send-code-light.png` to `send-code-nope.png`, expect `README.md:66: broken image: assets/screenshots/mac/send-code-nope.png` and exit 1; the same on the `srcset` of line 65, expect `README.md:65: ...`. A new untracked `img-probe.md` holding line 1 `` `<img src="nope.png">` `` and line 2 `<img src="nope.png">` yields exactly one finding, `img-probe.md:2: broken image: nope.png`; delete the file.
- R6: `mkdir -p assets/screenshots/ipad && git show daad96b:assets/screenshots/ipad/home-light.png > assets/screenshots/ipad/home-light.png && git add -f assets/screenshots/ipad/home-light.png` (the `ipad/` folder is gone after step 4), then `scripts/verify-docs.sh` exits 1 naming `assets/screenshots/ipad/home-light.png: unused screenshot: ...` and `docs/knowledge/screenshots.md`; then `git rm -q --cached assets/screenshots/ipad/home-light.png && rm -r assets/screenshots/ipad`, and it passes again.
- R7: `diff -rq assets/CrocAppIcon.icon app/CrocApp/AppIcon.icon && diff -rq assets/favicons web/landing/assets/img/favicon && echo R7-OK`; `git diff --name-only daad96b -- assets ':!assets/screenshots'` prints only `assets/AGENTS.md`.
- R8: `git ls-files -i -c --exclude-standard` prints nothing. Fresh checkout (`git worktree add --detach "$TMPDIR/rc-site" HEAD`, no `web/docs/static/` in it): `scripts/assemble-site.sh` exits 0 and `test -s _site/docs/img/mascot.webp`. Playwright check: serve that `_site` with `python3 -m http.server 8790 --bind 127.0.0.1`, open `http://127.0.0.1:8790/docs/`, and `document.querySelector('.navbar__logo img').naturalWidth > 0` is true. Then stop the server and `git worktree remove --force "$TMPDIR/rc-site"` (takes its `node_modules`, `_site` and `build` with it).
- R9: `git ls-files -i -c --exclude-standard` prints nothing; `awk '/^```gitignore$/{f=1;next} f&&/^```$/{exit} f' sdlc/repo-cleanup/plan.md | diff - .gitignore` prints nothing; for each path in `build/screenshots/app-store/mac/01-send-files-light.png web/docs/build/x web/docs/.docusaurus/x web/docs/node_modules/x _site/x dist/x .tools/x CrocKit/Croc.xcframework/x CrocKit/.build/x CrocKit/.swiftpm/x crocmobile/croctest crocmobile/cmd/croctest/croctest app/CrocApp.xcodeproj/xcuserdata/x key.pem AuthKey_X.p8 .envrc .vscode/x a.swp web/docs/static/img/mascot.webp .playwright-mcp/x`, `git check-ignore -q --no-index` succeeds; for each of `assets/screenshots/mac/send-code-light.png assets/screenshots/ipad/home-light.png crocmobile/cmd/croctest/main.go crocmobile/testdata/fuzz/X/y`, it fails. A loop prints any path on the wrong side; expected output: nothing.
- R10: the step's commands, read in `docs/RELEASING.md`, name no repo path except `"$REPO/app/CrocApp.xcodeproj"`; from a scratch directory, `xcodebuild -project "$REPO/app/CrocApp.xcodeproj" -list` lists the scheme `CrocApp Direct`; `scripts/verify-docs.sh` passes. The Sparkle update test itself is not run (doc procedure only): "not verified".
- R11: test phase. The spec's "Full build" steps 1-8 from a clean checkout of the task branch, then `git status --porcelain` prints nothing except the PNGs and WebPs `--copy-web` refreshed on purpose (listed, then `git restore`d), and `git status --porcelain --ignored` shows only the spec's expected set plus `.playwright-mcp/` if a Playwright check ran there. Then the spec's cleanup list.
- R12: `scripts/verify-docs.sh` and `scripts/verify-design.sh` pass; `git grep -n -e 'assets/screenshots/app-store' -e 'Most screenshot pairs are unused' -- ':!sdlc'` prints nothing; the reviewer checks each file in step 6 against the root `AGENTS.md` "Docs" table.
- D1 (step 1): `scripts/verify-docs.sh` passes on the task branch with `sdlc/repo-cleanup/*.md` present.

## Risks and rollback

Risk tier: medium, because the change edits a CI gate script (`scripts/verify-docs.sh`, run by the `docs checks` job and the SDLC commit gate), the secret and signing ignore rules and the screenshot pipeline; it touches no app code, workflow, release script or "Always human" path in `REVIEW.md`. The owner's standing approval for medium-risk merges (intent constraint 1, D9) applies.

- The capture script cannot be run end to end from a background session (spec concern 1): a regression in the capture path could reach main unproven. Mitigation: the change to the capture path is three small hunks (`OUT`, `mkdir -p`, the `verify_outputs` guard), every write already goes through `$OUT`, `--list` proves the paths, and the test phase runs `mac send-code` and `iphone send-code` or hands the owner one command. Rollback: revert the script hunk; captures go back to `assets/screenshots/`.
- An App Store submission now starts with a capture: the upload sets are in `build/screenshots/app-store/<class>/`, not in git, and `iphone-duo-outer` stays not upload-ready (spec concern 5). Owner: the Stage 2 submission task, which reads `docs/knowledge/screenshots.md`. Rollback: none needed; a capture regenerates the sets.
- Code in the capture script that assumed a tracked folder exists fails under `set -e` now that output can be missing (found: `verify_outputs`, guarded in step 3; the full-run wipe, `mkdir -p` in step 3). Rollback: revert the script hunk.
- `--copy-web` copies a stale capture over a newer tracked PNG (a capture left in `build/screenshots/`, then newer PNGs pulled from elsewhere). Single owner, single Mac, and a full run empties the folder, so unlikely; `git status` shows it and `git restore` undoes it.
- R6 fails a future change that adds a capture without showing it. Intended (D22); the message names the fix.
- The new image check (R5) misreads an unusual attribute and blocks CI with a false finding. Mitigation: the inline-code probe in R5's proof; values on one line only, documented as a known limit. Rollback: revert the R5 hunk of `verify-docs.sh`.
- Skipping `sdlc/**` hides a broken link in a task record (D1). Accepted: task records are frozen and never rendered as docs.
- A `.gitignore` rule hides a file that should be committed (spec concern 3 for `.env*`). Mitigation: `git ls-files -i -c --exclude-standard` is empty and the not-ignored probes pass; the `.env*` comment names the fix. Rollback: revert `.gitignore`.
- Removing the mascot copy breaks the docs build on a fresh clone. Mitigation: `mkdir -p` and the fresh-checkout `assemble-site.sh` proof (R8); CI's `site build` job runs on this PR because `web/docs/package.json` changes. Rollback: `git checkout daad96b -- web/docs/static/img/mascot.webp` and revert `package.json`.
- Removing the 118 PNGs loses something needed. They stay in history until T13 and every capture regenerates them. Rollback: `git checkout daad96b -- assets/screenshots`.
- Whole change: revert the squash-merge commit on `main`.

## Alternatives not taken

- `.gitignore` allow-list for `assets/screenshots/` (`/assets/screenshots/**/*.png` plus ten `!` lines): every capture rewrites the tracked PNGs in place (codes are random per run), so `git status` is dirty after any capture and the done-when check fails; it also duplicates the "Where they are used" list. Rejected in the spec; still holds.
- Editing `sdlc/repo-cleanup/spec.md` to drop the inline-code probe paths, instead of D1: changes an accepted artifact and only fixes this task; every later rename would break an old record again.
- Skipping only the repo-path check (not links) in `sdlc/**`: links in task records rot the same way after later renames.
- Copying a capture only when it is newer than the tracked PNG (`-nt`) in `--copy-web`: guards the stale-capture case above, but adds a condition for a case a single-owner repo does not hit (ground rule 9).
- Also failing on a tracked WebP whose PNG source is missing: `--copy-web` already fails on it; not in the spec.
- Parallel `sdlc-implementer` worktrees for steps 2-4: the steps are a few lines each, and the spec phase saw subagents lose Bash once a session is isolated in a worktree.

## Decisions recorded

Not asked of the owner (D9: stop only for high-stakes decisions; each follows the simplest working option):

- D1: `scripts/verify-docs.sh` skips `sdlc/**` (step 1). Recommended answer, taken: yes.
- D2: `/.playwright-mcp/` is ignored, since Playwright MCP writes there from the repo root. Recommended answer, taken: yes.
- D3: R6 also counts a new, not-ignored PNG in `assets/screenshots/` (not only staged or committed ones), matching how the script treats new docs. Recommended answer, taken: yes.

## Changes

- 2026-10-27, build, step 5: the image check skips every URL with a scheme (`data:`, `mailto:`, `https:`) and `//host`, not only `^https?:`, and splits on commas only for `srcset`. The verifier found false findings on a `data:` URI and `mailto:` in probes. R5 still holds. Commit 4f0e0a1.
- 2026-10-27, test, step 5 and step 3: `verify-docs.sh` also treats the target of a markdown link or `![](...)` image as showing a screenshot (R6; before, a PNG shown only by `![](...)` was a false "unused" finding), and matches `src`/`srcset` at the start of a line and in single quotes (R5). `capture-screenshots.sh --copy-web` fails first when `assets/screenshots/` is missing. R5 and R6 still hold. Commit fa90f86.

## SDLC feedback

- The spec phase's accepted `spec.md` fails `scripts/verify-docs.sh` (inline-code probe paths that do not exist on purpose), and `SDLC_VERIFY` runs that script in the commit gate, so the build phase could not have committed any code; neither the spec gatekeeper nor `/sdlc-spec` runs the project's check command over the new artifact. Why it hurts: a build session stalls on a gate failure caused by the SDLC's own files. Suggested changes: `/sdlc-setup` (`.claude/skills/sdlc-setup/SKILL.md`) makes the project's doc checker skip `sdlc/**` when it installs `SDLC_VERIFY`, and `.claude/agents/sdlc-gatekeeper.md` runs `$SDLC_VERIFY` (or at least the doc checks) on every artifact it gates.
- This background session must isolate in a worktree before writing `plan.md` (harness rule), while the flow commits on `sdlc/<slug>` in the root checkout; the spec phase reported the same. Repeated so it is not lost: `.claude/sdlc-scripts/next.sh` should start autonomous phases in a per-task worktree.
- From `sdlc-gatekeeper`: the plan item in `.claude/agents/sdlc-gatekeeper.md` does not ask it to check a plan's "no change needed" claims for code that reads a path the change moves; here such a claim hid a `set -e` failure in `verify_outputs`. Suggested change: add "unchanged code that reads a relocated path or an assumed-existing folder is checked for missing-folder behavior" to the plan item.
- From `sdlc-gatekeeper`: the caller had to list the plan's repo-fact and proof-command spot-checks in the prompt. Suggested change: add "spot-check quoted line numbers and run read-only proof commands" to the plan item in `.claude/agents/sdlc-gatekeeper.md`, matching the spec-phase feedback.
- `/sdlc-plan` step 5 ("Grill the user") has the same autonomous-mode conflict as `/sdlc-spec` step 4: nobody answers in `run_mode: autonomous`. Choices are recorded under "Decisions recorded" instead. Suggested change: `.claude/skills/sdlc-plan/SKILL.md` step 5 says to record choices with their recommended answers when `run_mode: autonomous` and ask only high-stakes ones.
