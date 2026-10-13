---
name: sdlc-build
description: Stages 3-4 (Build, Test) of the AI-native SDLC pipeline. Implements one build slice of an accepted sdlc/<change>/plan.md per session, or the Important findings of its review.md, with a feedback loop: failing test first for bugs, the project's checks after every step, plan.md kept in sync, and a fresh-context verifier before the last slice reports done. Use when a change under sdlc/ has an accepted plan.md and the user says implement, build, or go, asks to continue that change, or asks to fix its review findings.
argument-hint: "[sdlc/<change> directory] [fix review]"
---

# Build with a feedback loop (Stages 3-4: Build, Test)

Every session checks its own work before a human sees it. A late signal makes the user the bottleneck, so what reaches them has already passed the checks, with the output attached.

## Find the change

Use the directory given in the arguments. Otherwise pick the change under `sdlc/` whose `plan.md` is accepted and has no `PR:` line yet; ask if none or several match. `plan.md` must say `Status: accepted`. Without an accepted plan, stop and point to `/sdlc-plan`: nothing is implemented without one.

## Pick this session's work

- **Fix review**: when the arguments say `fix review`, or `review.md` lists Important findings and no Build log entry records fixing that review (its `Reviewed:` line), this session fixes every Important finding in it, one step per finding ID (`I1`...).
- **Next slice**: otherwise, the first unchecked slice under Build slices.
- **Nothing left**: every slice is checked and no review is waiting on fixes. Say so and hand off: to `/sdlc-ship` if the latest `review.md` has no Important finding and nothing changed after it, otherwise to `/sdlc-review`.

Work on the branch `plan.md` names for this slice's PR, or else a branch named after the change slug. Create it from the up-to-date default branch when it does not exist yet.

## Steps

1. Read `plan.md` (including its Build log), `spec.md` if there is one, and `CLAUDE.md`. The plan's Proof section is the definition of done. If a target in this session's work cannot be checked without asking the user, sharpen it with them in a `grilling` round before writing code.
2. For a bug fix, write the failing test first. Reproduce the bug as a test, run it, and confirm it fails for the expected reason. Then make it pass without editing that test. A test that existed before the fix and was not rewritten is the proof the bug is gone.
3. Implement this session's steps in the plan's order. After each step, run the narrowest check that covers it and fix the code until it passes, then tick the step in `plan.md`. Fix the code, not the check: never skip, delete, or loosen a failing test to get green.
4. For UI work, close the loop visually: render or screenshot, compare against the mock or reference named in the spec, adjust. Two or three rounds is normal.
5. Keep `plan.md` true. When the implementation departs from the plan, update `plan.md` at once and say what changed and why. Review checks the diff against the plan, so a stale plan turns correct code into findings.
6. Before ending the session, run the checks covering everything it touched, plus any `CLAUDE.md` requires for those areas. After the last slice or a review fix, run every check in the Proof instead, then dispatch the `verifier` subagent with the change directory. It runs in a fresh context and cannot edit, so its verdict is not colored by the assumptions that produced the code.
7. Tick the slice and append a Build log entry to `plan.md`: date, the slice, or "review fix" with the review's `Reviewed:` line and the finding IDs fixed, steps done, checks run with their result, deviations, and anything not verified. If the session must stop early, stop at a step boundary and log where the next session resumes.
8. Commit this session's work on the change branch, following the repo's commit convention, without asking (autonomous build phase, `.claude/CLAUDE.md`). Push is `/sdlc-ship`'s job.
9. Report in the session-end format `CLAUDE.md` asks for, covering each step, the commands run with their output, and anything not verified.

Next stage: the next slice, or `/sdlc-review` after the last slice or a review fix. End with the handoff from `.claude/CLAUDE.md` (SDLC sessions), using the next slice's risk to pick its model.
