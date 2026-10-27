---
name: sdlc-test
description: Fifth SDLC phase. Verifies a built task independently in a fresh context. Runs every check, proves each requirement with tool output, checks the UI against the mock with Playwright, fixes failures test-first, and writes test.md. Use after /sdlc-build.
argument-hint: "<slug>"
disable-model-invocation: true
allowed-tools:
  - Bash(.claude/sdlc-scripts/status.sh)
  - Bash(.claude/sdlc-scripts/status.sh *)
---

# Test

The work is checked by a context that did not write it, and every claim ends up backed by tool output.

## Task state

!`.claude/sdlc-scripts/status.sh $ARGUMENTS`

## Steps

1. Pick the task: the slug from the input, else the current `sdlc/<slug>` branch, else ask which one from the table above. Switch to its branch. build.md must be `accepted`.
2. Run the `sdlc-verifier` agent with the slug. It runs `$SDLC_VERIFY` (in workspace mode, each task repository's check command), each proof in plan.md including any check across repositories, and, when spec.md has a `mock:`, a Playwright comparison against the mock. It reports evidence and never fixes anything.
3. When `pr-review-toolkit` is installed, also run its `pr-test-analyzer` agent (coverage gaps against the R# list) and its `silent-failure-hunter` agent (swallowed errors) on the branch diff.
4. Fix every failure or gap test-first:
   1. The `sdlc-test-writer` agent writes a test that reproduces it. Confirm the test fails for the expected reason, and quote the failure line.
   2. Commit that test on its own: `test(<slug>): reproduce <issue>`.
   3. Fix the code without touching that test. Prove it: `git diff <test-commit> -- <test file>` must print nothing.
   4. Run the full verify command.
5. Repeat steps 2 to 4 until the verifier reports every R# passing.
6. If the task came from an incident (intent.md's `author` is an agent) and the project has an `evals/` suite, add an eval case for it in that suite's format (`/sdlc-setup evals`).
7. Write `sdlc/<slug>/test.md` from the template.
8. Approve it for the task's `gate_mode` (`.claude/rules/sdlc.md`) and commit it.
9. End the phase as `.claude/rules/sdlc.md` says.

## test.md

````markdown
---
slug: <slug>
phase: test
status: draft
approved_by:
approved_at:
---

# Test: <title>

## Requirements
| R# | Check | Result | Evidence |
| --- | --- | --- | --- |
| R1 | <test or command> | PASS | <literal summary line> |

## UI against the mock
<differences found, or: no mock>

## Fixes
- <issue>: test <hash>, fix <hash>

## Verification
```text
<literal output of $SDLC_VERIFY>
```

## Remaining risks
````
