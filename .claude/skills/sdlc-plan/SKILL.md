---
name: sdlc-plan
description: Stage 3 (Build) entry of the AI-native SDLC pipeline. Works in plan mode from an accepted spec.md (or an accepted intent.md for a small fix) to an approved plan.md naming the files that change, the order of work split into one-session build slices, the risks, and the proof. Use before implementing any change tracked under sdlc/, or when the user asks to plan an accepted spec. Nothing is implemented without an accepted plan.
argument-hint: "[sdlc/<change> directory]"
---

# Plan mode as the starting point (Stage 3: Build)

Design review happens before code exists, while changing course is still a matter of editing a document. Plan mode enforces that: no file changes until the user accepts the plan.

## Find the change

Use the directory given in the arguments. Otherwise pick the change under `sdlc/` that has an accepted `spec.md` and no `plan.md` yet; ask if none or several match. `spec.md` must say `Status: accepted`. A small, bounded fix may plan straight from an accepted `intent.md`; the plan then numbers its own requirements in a Requirements section, so later stages still have `R#` to cite.

## Steps

1. Enter plan mode if the session is not already in it.
2. Read `intent.md`, `spec.md` if there is one, `CLAUDE.md`, and the code the change touches. For a wide change, delegate the reading to read-only subagents and keep their conclusions in this session.
3. Interview the user in `grilling` rounds on the decisions the spec leaves open. Do not ask what the code can answer.
4. Draft the plan from the template below. Cite spec requirements (`R1`...) in the order of work and the proof, and spec concerns in the risks, so the plan can be checked against the spec line by line. The proof names the project's real checks (from `CLAUDE.md` and the docs it points to) with a pass condition Claude can confirm alone, such as "all tests in X pass" or "the screenshot matches the mock". For a bug fix, the proof starts with a test that fails before the fix.
5. Split the order of work into build slices. Each slice is one session of `/sdlc-build`: one coherent area, small enough to finish without the conversation being compacted, and checkable on its own before the next starts. Mark a slice `Risk: high` when a mistake there would be silent or costly (core logic, security, data, concurrency); it runs on the stronger model.
6. Interrogate the draft before presenting it: what could this break, which step is riskiest, which options were rejected and why. Put the answers in Risks and state them when presenting, so the user can push on them.
7. Iterate until an engineer who never saw this conversation could implement the change from the plan alone.
8. Present the plan for approval by exiting plan mode. Once approved, write it to `plan.md` next to the spec with `Status: accepted`.

Next stage: `/sdlc-build` for slice B1, in a new session. End with the handoff from `.claude/CLAUDE.md` (SDLC sessions), using B1's model.

## Template

```markdown
# Plan: <title> (from intent.md and spec.md)
Status: draft.

## Requirements
<Only without a spec.md: R1. One checkable requirement.>

## Files that change
<path> (new), <path>, <path>

## Order of work
- [ ] 1. <Step.> (R1, R2)

## Build slices
- [ ] B1: steps 1-3. <Area.> Risk: normal | high.

## Risks
<What could break, the riskiest step, rejected options.> (spec concern N)

## Proof
<Each check: exact command or method, and its pass condition.> (R#)

## Build log
<Appended by /sdlc-build: one entry per session.>
```
