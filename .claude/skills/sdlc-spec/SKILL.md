---
name: sdlc-spec
description: Second SDLC phase. Turns an accepted intent.md into spec.md with numbered, testable requirements, a design, a mapping for every constraint, and flagged policy conflicts, applying the project's policy skills. Use after /sdlc-intent.
argument-hint: "<slug>"
disable-model-invocation: true
allowed-tools:
  - Bash(.claude/sdlc-scripts/status.sh)
  - Bash(.claude/sdlc-scripts/status.sh *)
---

# Spec

Requirements and design are written in one pass, with the project's policies applied while the spec is written rather than discovered in review.

## Task state

!`.claude/sdlc-scripts/status.sh $ARGUMENTS`

## Steps

1. Pick the task: the slug from the input, else the current `sdlc/<slug>` branch, else ask which one from the table above. Switch to its branch. intent.md must be `accepted`; otherwise stop and report its status.
2. Read intent.md, CLAUDE.md and the code the change touches. Use `Explore` subagents (or `feature-dev:code-explorer` when installed) for wide reads. List the policy skills available to you (security, brand, UX, API conventions); if there are none, record that as a concern. In workspace mode, read the CLAUDE.md of every repository in `repos:`, and describe the contracts between them (APIs, shared types, events) in the design.
3. Research before asking: check every library, API and platform assumption with context7.
4. Grill the user on the design choices that are theirs, in one round.
5. Write `sdlc/<slug>/spec.md` from the template:
   - number the requirements R1, R2, ... and make each one testable;
   - give every constraint in intent.md a row in the constraint table;
   - answer every open question from intent.md, or carry it forward as a numbered concern;
   - name an owner on every concern; two policies that contradict each other are a concern, never settled silently;
   - for front-end work, record the approved mock in `mock:` (a path or URL).
6. Approve the spec for the task's `gate_mode` (`.claude/rules/sdlc.md`) and commit it. In the commit body, list the policy skills applied and the skills version, which is the output of `git log -1 --format=%h -- .claude/skills`.
7. End the phase as `.claude/rules/sdlc.md` says.

## spec.md

```markdown
---
slug: <slug>
phase: spec
status: draft
approved_by:
approved_at:
mock:
---

# Spec: <title>

Policy skills applied: <names, or none>

## Requirements
- R1. <testable requirement>

## Design
<Components, interfaces, data flow, where the change lives.>

## How each constraint is met
| Constraint (from intent.md) | Met by |
| --- | --- |

## Open questions from the intent
- <question>: <answer>, or carried forward as concern <n>.

## Concerns
1. <conflicting policies, unverified risks, scope exclusions>. Owner: <who resolves it>.

## Changes
```
