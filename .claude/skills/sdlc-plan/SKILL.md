---
name: sdlc-plan
description: Stage 3 (Build) entry of the AI-native SDLC pipeline. Works in plan mode from an accepted spec.md (or an accepted intent.md for a small fix) to an approved plan.md naming the files that change, the order of work, the risks, and the proof. Use before implementing any change tracked under sdlc/, or when the user asks to plan an accepted spec. Nothing is implemented without an accepted plan.
argument-hint: "[sdlc/<change> directory]"
---

# Plan mode as the starting point (Stage 3: Build)

Design review happens before code exists, while changing course is still a matter of editing a document. Plan mode enforces that: no file changes until the user accepts the plan.

## Find the change

Use the directory given in the arguments. Otherwise pick the change under `sdlc/` that has an accepted `spec.md` and no `plan.md` yet; ask if none or several match. `spec.md` must say `Status: accepted`. A small, bounded fix may plan straight from an accepted `intent.md`; the plan then numbers its own requirements in a Requirements section, so later stages still have `R#` to cite.

## Steps

1. Enter plan mode if the session is not already in it.
2. Read `intent.md`, `spec.md` if there is one, `CLAUDE.md`, and the code the change touches.
3. Interview the user on the decisions the spec leaves open. Do not ask what the code can answer.
4. Draft the plan from the template below. Cite spec requirements (`R1`...) in the order of work and the proof, and spec concerns in the risks, so the plan can be checked against the spec line by line. The proof names the project's real checks (`CLAUDE.md` lists them; changes to the engine or transfer path need their `scripts/verify-*.sh` harness) with a pass condition Claude can confirm alone, such as "all tests in X pass" or "the screenshot matches the mock". For a bug fix, the proof starts with a test that fails before the fix.
5. Interrogate the draft before presenting it: what could this break, which step is riskiest, which options were rejected and why. Put the answers in Risks and state them when presenting, so the user can push on them.
6. Iterate until an engineer who never saw this conversation could implement the change from the plan alone.
7. Present the plan for approval by exiting plan mode. Once approved, write it to `plan.md` next to the spec with `Status: accepted`.

Next stage: `/sdlc-build`. With a solid plan, implementation is often a single pass, so continue into it in the same session unless the user wants to stop.

## Template

```markdown
# Plan: <title> (from intent.md and spec.md)
Status: draft.

## Requirements
<Only without a spec.md: R1. One checkable requirement.>

## Files that change
<path> (new), <path>, <path>

## Order of work
1. <Step.> (R1, R2)

## Risks
<What could break, the riskiest step, rejected options.> (spec concern N)

## Proof
<Each check: exact command or method, and its pass condition.> (R#)
```
