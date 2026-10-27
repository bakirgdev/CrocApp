---
name: sdlc-deploy
description: Sixth SDLC phase. Ships a tested task. Reviews the branch with reviewers scaled to its risk tier, pushes it, opens a pull request linked to the task's artifacts, works through CI failures and review comments until only approval remains, and merges when the task and its risk tier allow it. Use after /sdlc-test.
argument-hint: "<slug>"
disable-model-invocation: true
allowed-tools:
  - Bash(.claude/sdlc-scripts/status.sh)
  - Bash(.claude/sdlc-scripts/status.sh *)
---

# Deploy

The agent takes the change up to the merge gate. Who passes that gate depends on the task's settings.

## Task state

!`.claude/sdlc-scripts/status.sh $ARGUMENTS`

## Steps

1. Pick the task: the slug from the input, else the current `sdlc/<slug>` branch, else ask which one from the table above. Switch to its branch. test.md must be `accepted`.
2. Set the risk tier. Start from `risk:` in task.yaml (set by the plan; `medium` if missing). Raise it to `high` when the branch diff touches a path that always needs a human: CI and release workflows (`.github/workflows/` and the like), `.claude/`, `CLAUDE.md`, `REVIEW.md`, and every path under `## Always human` in REVIEW.md. The tier only goes up. Record it in task.yaml with a one-line reason in deploy.md.
3. Review the branch before pushing, in rounds of at most three. Depth follows the tier:
   - `low`: the `sdlc-reviewer` agent in `find` mode.
   - `medium`: `sdlc-reviewer`, plus `/code-review high` and `/security-review`.
   - `high`: `sdlc-reviewer` with model opus, plus `/code-review max` and `/security-review`.

   Give `sdlc-reviewer` the slug, the diff range (`<default branch>...HEAD`) and nothing about how the code was written. Run `/code-review` and `/security-review` on the committed branch, with no target, which reviews the current branch's changes; in workspace mode, run `sdlc-reviewer` per repository in `repos:` and give `/code-review` each repository's path as its target. `/code-review` reads CLAUDE.md but not REVIEW.md, which is why `sdlc-reviewer` always runs. Rate every security finding Important. Then send the Important and Pre-existing findings from all reviewers to one fresh `sdlc-reviewer` in `verify` mode, and keep only what it confirms.

   Handle each confirmed finding, and record its outcome in deploy.md:
   - Important or security: fix it test-first, as in `/sdlc-test`, covering every instance of its class. Outcome `fixed`, citing the commit.
   - Nit: fix it if it is small, else outcome `unimportant`.
   - Pre-existing: never fix it in this branch. Outcome `deferred-intent`; step 8 turns it into a new task.
   - A finding you judge wrong or intentional: outcome `wrong` or `intentional` with the reason. For an Important or security finding, the user must agree.

   Rounds 2 and 3 run only `sdlc-reviewer` (find, then verify), on the new commits (`<last reviewed sha>..HEAD`), with every earlier finding passed in so none repeats. If Important findings remain after round 3, stop and grill the user on the approach instead of looping. If the review led to code commits, run `sdlc-verifier` again and paste its result under `## Checks`.
4. Push and open the pull request. With `pr: ask` in task.yaml, ask once before pushing and opening; with `pr: auto`, go ahead. Follow the repository's PR conventions. In the body, link every file in `sdlc/<slug>/`, list the R# coverage from test.md, paste the final verify output, and add `## Risk` (the tier, its reason, and the risks from plan.md) and `## How to revert` (the plan's rollback, or reverting the merge commit). In workspace mode, open one PR per repository in `repos:`, each linking the others; when the task files are not committed, paste the spec's requirements into each body instead of linking them.
5. Work the PR until only approval remains. Watch `gh pr checks <n>` and the unresolved comments (`gh pr view <n> --comments`). Treat comments from a review service (such as Code Review for Claude Code) as findings: same outcomes, and the same three-round cap, counted together with step 3. Fix each, push, and reply in each thread with the outcome and its reason. If the same check fails the same way after two attempts, stop and report it. Escalate any comment that needs a human decision.
6. Settle the SDLC feedback (`.claude/rules/sdlc.md`): every bullet under `## SDLC feedback` in the earlier artifacts, plus the entries held from this phase, including the reviewers' `SDLC feedback:` lines. If review was noisy, add one more: when two or more findings of the same `Class`, across all rounds and sources, ended `wrong` or `unimportant`, suggest the REVIEW.md change that would have kept them out. With no entries, skip to writing deploy.md. Otherwise ask in one grilling round where each goes, with a recommendation for each:
   - `issue`: a flaw in the SDLC files as published (the skills, agents, rules, hooks and scripts in `.claude/`). The target is the repository those files came from: `bakirgdev/ai-native-sdlc`, unless the project's README or CLAUDE.md names a fork. Draft the title and body: what happened, why it hurts, the suggested change. Keep only what someone outside the project needs, and leave out project code, paths, ticket text, tool output with secrets, and anything else private. Show the draft in the question. An issue is visible to others, so open it with `gh issue create` only after a yes. Use `task` instead when this project is that repository, or when the flaw is in this project's own edits to `.claude/`.
   - `task`: anything this project owns, such as its check command, REVIEW.md, CLAUDE.md or its edits to `.claude/`. Choose its slug now; step 8 creates the task, naming in its Problem section the file to change and the `/sdlc-setup` play that owns it, if any.
   - `dropped`: not worth acting on, with the reason.

   Entries that come up later in this phase, such as the gatekeeper's, go into the approval question in the same way.

   Then write `sdlc/<slug>/deploy.md` from the template, approve it for the task's `gate_mode` (`.claude/rules/sdlc.md`), then commit and push it.
7. Merge:
   - `low` risk, `pr: auto`, green checks: merge with the repository's merge method (`gh pr merge`).
   - `medium` or `high` risk, or `pr: ask`: ask first, whatever `pr` says. For `high`, list the always-human paths it touches in the question. An agent's approval never stands in for this yes.
   - `strict` mode: the code owner approves and merges.
   In `solo` mode, one question can cover both deploy.md's approval and the merge.
   - Workspace mode: merge in the order of `## Merge order` in plan.md.
   Never bypass branch protection or required reviews.
8. For each `deferred-intent` finding, create a new task as `/sdlc-maintain` describes, with `author: review agent (<slug>)` and the finding as evidence, so `/sdlc-maintain triage` picks it up. Do the same for each SDLC feedback entry with outcome `task`, with `author: sdlc feedback agent (<slug>)`. Switch back to this task's branch after.
9. After each merge, follow the repository's documented release process (its CLAUDE.md, CONTRIBUTING or release workflow): propose the version, then tag or release, and watch the pipeline it starts. Creating tags and releases is visible to others: ask first unless `pr: auto` and the risk is `low`. If the changed service has no control bands yet, suggest `/sdlc-setup bands`. Ask before deleting the branch. Report the task complete and show `.claude/sdlc-scripts/status.sh <slug>`.

## deploy.md

```markdown
---
slug: <slug>
phase: deploy
status: draft
approved_by:
approved_at:
---

# Deploy: <title>

PR: <url> (one line per repository in workspace mode)

Risk: <low | medium | high>, <reason>

## Review findings
<t> findings: <i> Important, <n> Nit, <p> Pre-existing. Rounds: <1-3>.

| Round | Source | Severity | File:line | Class | Finding | Outcome | Reason or commit |
| --- | --- | --- | --- | --- | --- | --- | --- |

## SDLC feedback
<none, or one row per entry>

| Artifact | Feedback | Outcome | URL, slug or reason |
| --- | --- | --- | --- |

## Checks
<final state of the PR checks>

## Release
<pipeline run and result, or: none configured>
```
