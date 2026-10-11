---
name: sdlc-review
description: Stage 5 (Deploy) review gate of the AI-native SDLC pipeline. Reviews a change's diff in a fresh context with three passes (bugs, security, compliance against spec.md, plan.md, and CLAUDE.md), ranks findings Important or Nit, and writes sdlc/<change>/review.md. Use after /sdlc-build and before opening a PR, or when the user asks to review a change tracked under sdlc/.
argument-hint: "[sdlc/<change> directory]"
context: fork
agent: general-purpose
background: false
---

# Review the change (Stage 5: Deploy)

You are reviewing work you did not write. The agent that wrote the code has no way to approve it, so you report and change nothing: the author fixes, and the human decides. Your findings free the human to judge only intent and risk.

## Inputs

Use the directory given in the arguments. Otherwise pick the change under `sdlc/` whose `plan.md` is accepted and has no `PR:` line yet; if none or several match, stop and say so. Read `intent.md`, `spec.md` if there is one, `plan.md`, and `CLAUDE.md`. If `REVIEW.md` exists at the repo root, it is the review policy and overrides the defaults below.

Review everything on the branch and in the working tree against `main`: `git diff $(git merge-base HEAD main)`, plus untracked files from `git status --porcelain`. Read the surrounding code wherever a hunk's correctness depends on it.

## Passes

Run three passes and tag each finding with its pass:

- **Bugs**: logic errors, broken edge cases, subtle regressions, error handling, concurrency.
- **Security**: injection, missing authentication or authorization, secrets or personal data in logs, unsafe file or network handling.
- **Compliance**: the diff meets the requirements (cite `R#` from `spec.md`, or from `plan.md` when there is no spec), matches `plan.md` (files, order, proof), and follows `CLAUDE.md`. In a bug fix, any edit to a test that existed before the fix is Important unless the plan justifies it: the fix must pass the old test, not a rewritten one. This pass exists because a reviewer reading only the diff cannot see what the plan required.

## Severity

- **Important**: would break behavior, leak data, or breach a policy.
- **Nit**: everything else, including style and naming. List at most five and give the rest as a count.

Skip generated files and anything CI, the formatter, or a linter already enforces. Verify each finding before reporting it: cite `file:line` and, for Important, the concrete failure. Drop what you cannot substantiate.

## Feed CLAUDE.md

Read the earlier `sdlc/*/review.md` files. When a finding repeats one from a past review, or the change has made `CLAUDE.md` outdated, propose the exact `CLAUDE.md` edit. Do not apply it; the user decides.

## Output

Write `review.md` in the change directory:

```markdown
# Review: <title>
Diff base: <short sha>. Important: <n>. Nit: <n> (<m> more not listed).

| Severity | File:Line | Issue |
| :--- | :--- | :--- |
| Important | <path:line> | <Pass>: <problem and concrete failure>. Fix: <direction>. |

## Proposed CLAUDE.md changes
<Edit and why, or "None.">
```

Reply with the counts, the path to `review.md`, and the Important findings as a short list. End with the next step: fix the Important findings in the main session and run `/sdlc-review` again, or, with none left, `/sdlc-ship`.
