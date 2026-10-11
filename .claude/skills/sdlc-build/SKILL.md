---
name: sdlc-build
description: Stages 3-4 (Build, Test) of the AI-native SDLC pipeline. Implements an accepted sdlc/<change>/plan.md with a feedback loop: failing test first for bugs, the project's checks after every step, plan.md kept in sync, and a fresh-context verifier before reporting done. Use when a change under sdlc/ has an accepted plan.md and the user says implement, build, or go, or asks to continue that change.
argument-hint: "[sdlc/<change> directory]"
---

# Build with a feedback loop (Stages 3-4: Build, Test)

Every session checks its own work before a human sees it. A late signal makes the user the bottleneck, so what reaches them has already passed the checks, with the output attached.

## Find the change

Use the directory given in the arguments. Otherwise pick the change under `sdlc/` whose `plan.md` is accepted and has no `PR:` line yet; ask if none or several match. `plan.md` must say `Status: accepted`. Without an accepted plan, stop and point to `/sdlc-plan`: nothing is implemented without one.

## Steps

1. Read `plan.md`, `spec.md` if there is one, and `CLAUDE.md`. The plan's Proof section is the definition of done. If a target cannot be checked without asking the user, sharpen it with them before writing code.
2. For a bug fix, write the failing test first. Reproduce the bug as a test, run it, and confirm it fails for the expected reason. Then make it pass without editing that test. A test that existed before the fix and was not rewritten is the proof the bug is gone.
3. Implement in the plan's order. After each step, run the narrowest check that covers it and fix the code until it passes. Fix the code, not the check: never skip, delete, or loosen a failing test to get green.
4. For UI work, close the loop visually: render or screenshot, compare against the mock or reference named in the spec, adjust. Two or three rounds is normal.
5. Keep `plan.md` true. When the implementation departs from the plan, update `plan.md` at once and say what changed and why. Review checks the diff against the plan, so a stale plan turns correct code into findings.
6. Before reporting done, run every check in the Proof plus any `CLAUDE.md` requires for the touched area. Then dispatch the `verifier` subagent with the change directory. It runs in a fresh context and cannot edit, so its verdict is not colored by the assumptions that produced the code.
7. Report in the session-end format `CLAUDE.md` asks for, covering each plan step, the commands run with their output, and anything not verified.

Do not commit here; `/sdlc-ship` does. Next stage: `/sdlc-review`.
