---
name: sdlc-build
description: Fourth SDLC phase. Implements an accepted plan.md step by step with a tight feedback loop, runs parallel-safe steps in separate worktrees, records deviations, and writes build.md with literal verification output. Use after /sdlc-plan.
argument-hint: "<slug>"
disable-model-invocation: true
allowed-tools:
  - Bash(.claude/sdlc-scripts/status.sh)
  - Bash(.claude/sdlc-scripts/status.sh *)
---

# Build

Implement the accepted plan, checking every step against the project's own tests as you go.

## Task state

!`.claude/sdlc-scripts/status.sh $ARGUMENTS`

## Steps

1. Pick the task: the slug from the input, else the current `sdlc/<slug>` branch, else ask which one from the table above. Switch to its branch. plan.md must be `accepted`; the plan gate hook blocks code edits otherwise. If a check command is missing (`SDLC_VERIFY`, or in workspace mode a task repository's line in `.claude/sdlc-workspace.yaml`), stop and ask the user to run `/sdlc-setup verify` (or `/sdlc-setup workspace`) first, because the commit gate needs it.
2. Read plan.md, spec.md and CLAUDE.md. Check library and API details with context7 as you go.
3. Work the steps in order. For each one:
   1. Where practical, start with a test that proves its R#; the `sdlc-test-writer` agent writes it and confirms it fails.
   2. Implement the step.
   3. Run the narrowest relevant test while iterating, then the full `$SDLC_VERIFY`, and fix until it passes. Never weaken a check.
4. Hand `parallel-safe` steps to `sdlc-implementer` agents, two or three at a time, each in its own worktree. Commit your work first, because each worktree starts from the default branch and fast-forwards to `sdlc/<slug>`. Merge their branches into `sdlc/<slug>`, then run the full verify command. In workspace mode use `sdlc-repo-implementer` instead: one agent per repository at a time, working in the repository itself with no worktree and no commits. When they are all done and each repository's check passes, commit each repository.
5. Commit in logical steps, following the repository's commit convention (in workspace mode, per repository with `git -C <repo>`). The commit gate runs the check command on every code commit.
6. Handle deviations:
   - Same requirements, different detail: record it under `## Changes` in plan.md and commit that with the code.
   - A change of scope, requirements or design: stop and grill the user. Set plan.md (and spec.md if needed) back to `draft`, record why under `## Changes`, commit, and end the session with `.claude/sdlc-scripts/next.sh <slug> --phase plan` (or `--phase spec`). Build resumes after the plan is accepted again.
7. When every step is done and `code-simplifier` is installed, run it on the changed code, then verify again.
8. Run `sdlc-verifier` once on the finished work, from a fresh context, and fix what it reports.
9. Write `sdlc/<slug>/build.md` from the template, pasting the final verify output literally.
10. Approve it for the task's `gate_mode` (`.claude/rules/sdlc.md`); the gatekeeper compares the diff with plan.md. Commit it.
11. End the phase as `.claude/rules/sdlc.md` says.

## build.md

````markdown
---
slug: <slug>
phase: build
status: draft
approved_by:
approved_at:
---

# Build: <title>

## Done
- Step 1: <what>, commits <hash>, <hash>

## Deviations from the plan
- <none, or what changed and why; also recorded in plan.md under Changes>

## Verification
```text
<literal output of $SDLC_VERIFY>
```

## Notes for the test phase
- <anything the tester should look at closely>
````
