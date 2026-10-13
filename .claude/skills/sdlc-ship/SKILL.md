---
name: sdlc-ship
description: Stage 5 (Deploy) of the AI-native SDLC pipeline. Commits a reviewed change, opens a PR that carries its intent, spec, plan, and review record, and babysits it until checks are green, then merges only on the user's explicit yes for that PR. Never releases.
argument-hint: "[sdlc/<change> directory]"
disable-model-invocation: true
---

# Ship to the gate (Stage 5: Deploy)

The agent does everything up to the production gate and nothing past it. Merging, tagging, and releasing stay human decisions.

## Find the change

Use the directory given in the arguments. Otherwise pick the change under `sdlc/` that has a `review.md` and no `PR:` line in `plan.md`; ask if none or several match.

## Preconditions

- `review.md` is newer than every file in the diff, so it reviewed what ships. If anything changed after it, run `/sdlc-review` again.
- `review.md` has no open Important finding, unless the user explicitly accepted each remaining one.
- The Proof checks from `plan.md` pass now. Run them again; earlier output does not count.

If any fails, stop and say which.

## Steps

1. If anything is still uncommitted, draft its commit message following the repo's convention (read `git log` first) and stage only this change's files. If `/sdlc-build` already committed everything, skip the commit; the branch's commits are the record. `sdlc/` is gitignored, so the artifacts never land in a commit.
2. Draft the PR. The artifacts are not committed, so the PR body is the audit record. Carry the chain:
   - **Intent**: problem and outcome, two lines.
   - **Requirements**: each `R#` and where it is met.
   - **Plan deviations**: what changed from `plan.md` and why, or "None".
   - **Review**: the counts, and any Important finding accepted rather than fixed, with the reason.
   - **Verification**: the commands run and their results, and anything not verified.
3. Autonomous build phase (`.claude/CLAUDE.md`): no approval needed. Print the commit message, PR title, and PR body for the record, then proceed: if still on the default branch, create a branch named after the change slug; commit whatever `/sdlc-build` left uncommitted, push, and run `gh pr create`. Add `PR: <url>` under the `Status:` line of `plan.md`.
4. Babysit the PR. Watch checks with `gh pr checks <n> --watch` in the background. For each failure, read the log (`gh run view <id> --log-failed`), say whether it looks flaky or real, fix real ones, and commit in the same convention and push. Address review comments the same way (`gh pr view <n> --comments`; inline ones via `gh api repos/{owner}/{repo}/pulls/<n>/comments`), and say what changed with `gh pr comment`. Fix the code, not the check.
5. When checks are green and every review comment is addressed, merge without asking (autonomous build phase), with the merge method the repo's history uses (`gh pr merge <n> --merge --delete-branch` today), then `git switch <default branch> && git pull --ff-only`, and report the merge commit. Never merge with a failing required check or an unaddressed review comment.

Never approve a PR review, force-push, push to the default branch, tag, or trigger a release. Merging only through `gh pr merge` per step 5.

After merge, release is a human call. If something breaks in the field, `/sdlc-maintain` brings it back into the loop. End with the handoff from `.claude/CLAUDE.md` (SDLC sessions) for whichever comes next: `/sdlc-build` for the next unchecked slice when the plan ships in several PRs, `/sdlc-maintain` for a failure, `/sdlc-intent` for the next change.
