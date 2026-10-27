---
name: sdlc-intent
description: Starts an SDLC task. Turns an idea or ticket into an approved intent.md under sdlc/<slug>/ and sets the task's slug, branch, approval mode, run mode and model choices. Use to begin any new feature, fix or change in a project that runs the AI-native SDLC.
argument-hint: "[idea in your own words | ticket reference]"
disable-model-invocation: true
---

# Intent

Capture the problem once, in the originator's own words, as `sdlc/<slug>/intent.md`. Turning it into requirements is the spec phase's job.

Input: $ARGUMENTS

## Steps

1. Classify the input.
   - A ticket reference (`#123`, `ABC-123`, a tracker URL): read it with `gh issue view` or the tracker's MCP tools and record it as `ticket:`.
   - An alert, metric breach or incident: tell the user to run `/sdlc-maintain` with it instead, and stop.
   - Empty: ask for the idea.
   - Anything else is the idea, in the originator's words.
2. Check the ground.
   - Single-repo mode: the project must be a git repository; if it is not, stop and say so, because the git history is the audit trail. Note the current branch and any uncommitted changes. If `SDLC_VERIFY` is empty, tell the user that code commits will be blocked until `/sdlc-setup verify` has run.
   - Workspace mode (`.claude/sdlc-workspace.yaml` exists): list the repositories with their current branches and uncommitted changes, and name any without a check command in that file.
   - In both modes, read CLAUDE.md and skim the code the idea touches, so the questions are informed.
3. Grill the originator until every section of the template has real content or an explicit open question: what they cannot do today, who is affected, what better looks like, the constraints, what is out of scope. Settle the task setup in the same round:
   - **Slug**: propose a kebab-case slug of at most 40 characters from the title, plus two or three alternatives (shorter, more specific, or prefixed with the ticket ID such as `abc-123-<slug>`). The user may pick their own. It names `sdlc/<slug>/`, the branch `sdlc/<slug>` and the sessions `<slug>-<phase>`, for this task only. If the folder or branch already exists, propose another.
   - **Approval mode** (`gate_mode`), recommend `solo`:
     - `solo`: you approve each phase with a yes in chat, and Claude records it.
     - `auto`: an independent reviewer agent checks each phase and Claude approves when it passes; you are asked only about decisions that are yours.
     - `strict`: the playbook's roles. The named owner sets the status or merges the PR; Claude never approves.
   - **Run mode** (`run_mode`), recommend `manual`:
     - `manual`: each phase ends with a command you run in a new terminal.
     - `autonomous`: each phase starts the next one as a background session; you are pulled in only for questions and approvals (follow it with `claude agents`).
   - **Pull request** (`pr`), recommend `ask`: with `ask` Claude asks before pushing, opening and merging; with `auto` it does all three itself.
   - **Repositories** (workspace mode): which repositories the task changes.
   - **Models**: show the output of `.claude/sdlc-scripts/next.sh --defaults` and ask whether any phase of this task should use a different model, effort or permission mode.
4. Create and switch to branch `sdlc/<slug>` from the default branch (usually `main`). If you are on another `sdlc/*` branch, or the tree has uncommitted changes, ask the user to commit or stash them first: they would travel into the task, and the commit gate counts them. In workspace mode, do this in each repository the task changes, each from its own default branch.
5. Write `sdlc/<slug>/task.yaml` and `sdlc/<slug>/intent.md` from the templates below. Keep the originator's wording. For a ticket, the originator corrects the draft before it is committed.
6. Show the draft and apply every correction.
7. Approve it as `.claude/rules/sdlc.md` says for the chosen `gate_mode`, and commit both files.
8. Ask the user to name this session with `/rename <slug>-intent`, so `claude -r <slug>-intent` finds it later. Claude cannot rename sessions.
9. End the phase as `.claude/rules/sdlc.md` says.

## task.yaml

```yaml
slug: <slug>
title: <short title>
created: <YYYY-MM-DD>
branch: sdlc/<slug>
gate_mode: solo
run_mode: manual
pr: ask
```

In workspace mode, add `repos: <repo>, <repo>`. Add `<phase>_model`, `<phase>_effort` or `<phase>_permission` lines only for overrides the user asked for, for example `build_model: opus`.

## intent.md

```markdown
---
slug: <slug>
phase: intent
status: draft
author: <name> (<role>)
ticket:
approved_by:
approved_at:
---

# Intent: <short title>

## Problem
<What cannot be done today, who it affects, evidence if any.>

## Proposed outcome
<What better looks like, in the originator's words.>

## Affected users and systems
<People, teams, services, APIs.>

## Constraints
<What must hold: data, security, budget, deadlines, policy.>

## Out of scope

## Open questions
<Anything not yet known. The spec phase answers each one or carries it forward.>
```
