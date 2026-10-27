---
name: sdlc-plan
description: Third SDLC phase. Turns an accepted spec.md into an implementation plan (files, ordered steps citing requirements, a proof for every requirement, risks and rollback) and commits it as plan.md; code edits stay blocked until plan.md is accepted. Use after /sdlc-spec.
argument-hint: "<slug>"
disable-model-invocation: true
allowed-tools:
  - Bash(.claude/sdlc-scripts/status.sh)
  - Bash(.claude/sdlc-scripts/status.sh *)
---

# Plan

No code is written until someone could build the change from plan.md alone.

## Task state

!`.claude/sdlc-scripts/status.sh $ARGUMENTS`

## Steps

1. Pick the task: the slug from the input, else the current `sdlc/<slug>` branch, else ask which one from the table above. Switch to its branch. spec.md must be `accepted`. If the task has an accepted intent.md but no spec.md, say the spec phase was skipped and ask whether to continue.
2. Read intent.md, spec.md, CLAUDE.md and the code. Use `Explore` subagents (or `feature-dev:code-architect` when installed) for wide reads. Check every library or API detail with context7.
3. Draft the plan:
   - the files that change, with new ones marked;
   - the steps in order, each citing the R# it serves, and marked `parallel-safe` when no other step touches its files;
   - a proof for every R#: a test file, a command, or a Playwright check;
   - the risks, with a rollback for each;
   - the risk tier: `low` (docs, copy, additive changes behind a flag), `medium` (ordinary changes, sensitive areas such as caching, auth flows or prompts) or `high` (billing, security, data migrations, CI and release workflows, installers, anything under `## Always human` in REVIEW.md), with a one-line reason. Set by the change, not by who asks for it;
   - the alternatives you rejected, and why;
   - in workspace mode, paths that start with their repository folder, and a `## Merge order` section: the order in which the repositories merge and release, and why every state in between stays compatible.
4. Interrogate the draft before showing it: what could it break, which step is riskiest, what is missing. Iterate until someone who never saw this conversation could implement it from the plan alone.
5. Grill the user on the choices that are theirs.
6. Run `sdlc-gatekeeper` on the draft (pass the plan text if plan.md is not written yet) and resolve its findings.
7. If this session is in plan mode, present the plan with ExitPlanMode; in `solo` mode the user's approval there is the gate's yes. Otherwise write plan.md directly: the plan gate hook keeps code blocked either way.
8. Write `sdlc/<slug>/plan.md` and set `risk:` in task.yaml, finish the approval for the task's `gate_mode` (`.claude/rules/sdlc.md`), and commit it before any code changes.
9. End the phase as `.claude/rules/sdlc.md` says.

## plan.md

```markdown
---
slug: <slug>
phase: plan
status: draft
approved_by:
approved_at:
---

# Plan: <title>

## Files that change
- <path> (new)
- <path>

## Steps
1. <step> (R1, R2). parallel-safe
2. <step> (R3).

## Proof
- R1: <test file and test name, command, or Playwright check>

## Risks and rollback
Risk tier: <low | medium | high>, because <reason>.

- <risk> (spec concern <n>). Rollback: <how>.

## Merge order (workspace mode)
1. <repo>: <why it goes first>

## Alternatives not taken
- <option>: <why not>.

## Changes
```
