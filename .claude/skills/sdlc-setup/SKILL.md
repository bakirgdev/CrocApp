---
name: sdlc-setup
description: One-time project setup for the AI-native SDLC. Plays are verify (the feedback loop and SDLC_VERIFY), workspace (several git repositories in one folder), claude-md, review (REVIEW.md for code review), policy-skill, guardrail (build-time hooks), gates (approval hooks), evals (a regression suite for the agent's configuration), pipeline (CI/CD) and bands (control-band detection). Run each play once per project, from the default branch.
argument-hint: "verify | workspace | claude-md | review | policy-skill <policy> | guardrail <rule> | gates | evals | pipeline | bands <metric>"
disable-model-invocation: true
---

# Setup

Input: $ARGUMENTS

Choose the play from the first word.
- Empty input: show which plays are already in place (SDLC_VERIFY set, a verify section in CLAUDE.md, REVIEW.md, policy skills, project hooks, `evals/`, `bands.yaml`) and ask which to run.
- Anything else: list the plays and ask.

Rules for every play:
- Run setup from the default branch (in workspace mode, from the workspace folder), not from a `sdlc/<slug>` branch, where the plan gate would block it.
- Hooks and settings go in the project's `.claude/` only, never in `~/.claude`.
- Ask before creating CI workflows, schedules, or anything that holds credentials.
- When a play is done and the project is a git repository, commit its changes on the default branch (ask first), so SDLC tasks start from a clean tree.
- Never handle secret values.

## verify: the feedback loop

1. Find how the project is checked today: CLAUDE.md, a Makefile, package.json scripts, the CI config.
2. Make each check one command that exits non-zero on failure (build, test, lint). If it takes several steps or setup knowledge, propose one target such as `make check` or `npm run check`.
3. Add a "Verifying your work" section to CLAUDE.md:
   - each command, with an example of healthy output;
   - the rule to run all of them and paste the output before calling work done;
   - "if a test fails, fix the code, not the test".
4. Set `SDLC_VERIFY` to the combined command under `env` in `.claude/settings.json`. The commit gate runs it on every code commit of an SDLC task. Use `true` only for a project with nothing to check, and say what that gives up.
5. Run the command once and paste the output. Tell the user to restart their Claude Code sessions so they pick up the new value.

## workspace: several repositories in one folder

Use it when this folder, whether a git repository or not, holds several git repositories and tasks span them. In workspace mode it replaces `verify`.

1. List the repositories: every folder directly inside this one that contains `.git`.
2. For each, find its check command as in `verify`, from its CLAUDE.md, Makefile, package.json or CI config. Grill the user on the whole list in one round.
3. Write `.claude/sdlc-workspace.yaml` with one `<repo>: <command>` line per repository (`true` opts a repository out). This file switches workspace mode on; deleting it switches back to single-repo mode.
4. Tell the user whether task files will be committed: only when this folder is a git repository and `sdlc/` is not git-ignored. Never create a git repository here and never change its `.gitignore` for this.
5. Run the play again whenever repositories are added or removed: new ones get a check command, removed ones lose their line.

## claude-md

1. Without a CLAUDE.md, ask the user to run `/init`, then continue from its draft.
2. Cut it to what a new joiner needs on day one: commands (with healthy output), the conventions that matter, the architecture, and a "Things Claude gets wrong" section. Keep it under a page, because Claude reads all of it every session.
3. The working rule: when Claude makes the same mistake twice, the correction goes under "Things Claude gets wrong". `claude-md-management`'s `/revise-claude-md` applies it when installed.
4. Do not copy the SDLC rules into CLAUDE.md. `.claude/rules/sdlc.md` already loads them.

## review: REVIEW.md

REVIEW.md tells reviewers what matters in this repository. `sdlc-reviewer` reads it in `/sdlc-deploy`, and so does the managed Code Review service; the local `/code-review` does not, so rules for every review belong in CLAUDE.md.

1. Read CLAUDE.md, the CI config and recent review comments or reverts (`gh pr list --state merged`, `git log --grep revert -i`). Draft the file with the code owners, and grill the user on it in one round.
2. Write `REVIEW.md` at the root, short, with these sections:
   - `## What failure means here`: one line per area (for docs, "it lies"; for config, "it misroutes"), and which findings count as Important. Style is Nit at most.
   - `## Nits`: report at most 5.
   - `## Do not report`: generated files, lockfiles, vendored code, anything CI already enforces.
   - `## Evidence`: every behavior claim cites `file:line`, not an inference from a name. The summary starts with a count and says "nothing to fix" when there is nothing.
   - `## Always check`: the team rules to check on every change.
   - `## Always human`: paths that always need a person to approve (auth, billing, installers, release config). `/sdlc-deploy` treats them as `high` risk, as it does CI workflows and `.claude/`.
3. A subdirectory can have its own REVIEW.md, which adds rules for changes under it.
4. The working rule: when review flags the same thing twice, move it to its source, a guardrail hook or lint rule if it must always hold, else CLAUDE.md or REVIEW.md.
5. Once a month, read the outcomes in `sdlc/*/deploy.md`. Many `wrong` or `unimportant` outcomes in one class mean REVIEW.md should skip it or set a higher bar.

## policy-skill

1. Pick one rule that is applied inconsistently today, such as a security standard, an API convention or a brand rule. It needs a named owner and a written source of truth; if either is missing, stop and ask.
2. Write `.claude/skills/<name>/SKILL.md` from that source, not from memory:
   - a description that says when it applies (task types, file kinds);
   - numbered rules, plus any check script.

   Keep model invocation on, so it loads by itself. `skill-creator` helps when installed.
3. Test that it triggers: ask for the relevant task several ways, each in a fresh subagent, and confirm the skill loads every time.
4. A skill is advisory. If the rule must always hold, back it with `guardrail` and the same check in CI.
5. When the policy changes, the skill changes with the owner's sign-off. `/sdlc-spec` records the skill versions in force.

## guardrail: build-time hooks

1. Write the check as a fast script in `.claude/hooks/`, scoped to the file that changed. Typical checks: protected paths, formatter and linter after an edit, secrets kept out of the diff, a policy that must always hold. Heavier checks belong in the commit gate or CI. `hookify` can draft a hook from a description when installed.
2. Register it in `.claude/settings.json`: PreToolUse to block, or PostToolUse on `Edit|Write` to check after an edit. A PostToolUse hook cannot undo the edit; exit code 2 shows its message to Claude, which then fixes the problem.
3. Every block states the rule, the file and line, and what to do instead.
4. Edit and Write hooks do not see files changed by shell commands, so run the same script as a required PR check.
5. Test it: pipe a sample hook payload into the script for a passing and a failing case, and show both exit codes.
6. A hook that waits for human approval does not belong here; use `gates`.

## gates: approval hooks

1. Get the written list of human approvals that must survive, such as change sign-off, release authorization and protected paths. If none exists, draft it with the user.
2. Express each as a PreToolUse hook that returns `permissionDecision` `allow`, `ask` or `deny` with a reason. Match the tool that acts: `Bash`, a deploy MCP tool, or `Edit|Write` on protected paths.
3. The hook reads approval records the agent cannot write, such as a change ticket's state.
4. Make every reason useful. The reason on `ask` is shown to the person. The reason on `deny` is shown to Claude and must name the route to approval.
5. In a non-interactive run nobody can answer `ask`, so it acts as a deny. Allow the pipeline path where the approved merge already is the approval.
6. Hooks that must never be switched off belong in managed settings owned by an admin. Say so, but do not write them.
7. For pull requests, suggest branch protection on the default branch (the user turns it on): require a pull request and green checks, dismiss stale approvals when new commits are pushed, and require code owner review, with a `CODEOWNERS` file that covers the `## Always human` paths in REVIEW.md, CI workflows and `.claude/`.
8. Test each outcome (allow, ask, deny) with a sample payload and show the JSON.

## evals: configuration regression suite

1. Collect 20 to 50 real tasks from merged PRs, each with its accepted outcome.
2. Write each as `evals/<name>.json` with these fields:
   - `name`;
   - `source`: the PR or incident;
   - `from`: the commit before the change;
   - `prompt`: the task as originally asked;
   - `may_change`: the paths a run may touch;
   - `checks`: tests pass, lint is clean, behavior is unchanged, no test lines are removed.
3. Write `evals/run.sh`. For each case it checks out `from` in a temporary worktree, runs `claude -p "<prompt>"`, runs the checks, and prints PASS or FAIL. Do not use `--bare`: it skips CLAUDE.md, skills and hooks, which are what the suite tests.
4. Run it in CI on a schedule and on pull requests that touch `CLAUDE.md`, `.claude/**` or `evals/**`. The user adds the API key as a CI secret. Gate merges on the pass rate.
5. Every production incident adds a case. Replace cases that no longer tell good configurations from bad ones.
6. Review cases test the reviewer. Each `evals/review/<name>.json` has `from` (the commit before the PR that caused an incident or revert), `to` (its last commit) and `expect`: the bug's `file:line` and class, confirmed by someone who knows that code, or an empty list for a PR known to be clean. `evals/run.sh` checks out `to` (not `from`) in a temporary worktree and runs `claude -p "Use the sdlc-reviewer agent in find mode on <from>..<to>"` and scores a hit when a finding names the expected file and line. Report recall, and false Important findings on clean cases. Rerun on every change to `sdlc-reviewer.md`, REVIEW.md or the model.

## pipeline: CI/CD

1. Start with read-only judgment steps in CI: `claude -p` to triage a failed build, summarize a flaky test, or draft a changelog.
2. Add write steps behind the existing gates. Everything the agent writes arrives as a PR through branch protection; it has no route to push to the default branch.
3. Agent jobs run sandboxed, with short-lived, narrowly scoped tokens and no production credentials.
4. Expose deployment as tools (release, status, rollback) through one MCP server per environment, so allowlists can tell staging from production.
5. Tier autonomy by environment:
   - dev: the agent deploys freely;
   - staging: the hook asks, or allows the pipeline on the default branch;
   - production: needs the release manager's recorded approval, enforced by a `gates` hook.

   Rollback stays allowed everywhere.
6. Make rollback one rehearsed command, exercised in staging, because `/sdlc-maintain` relies on it.

## bands: control-band detection

1. With the service owner, pick one metric with a stable baseline: CI test failure rate, post-deploy 5xx rate, or PR cycle time.
2. Write a deterministic detection script, with no model involved. It computes the mean and σ over a rolling window (for example 30 days of hourly readings), plus drift rules: 4 of the last 5 readings above 1σ, or 8 in a row above the mean. Unit-test it.
3. Write `bands.yaml` with the response tiers:
   - 1σ: `log`;
   - 2σ: `diagnose`, read-only, through the `sdlc-diagnoser` agent;
   - 3σ: `propose`, with the exact allowed routes (open a PR, or named pre-approved runbooks).
4. Wire the trigger to run `claude -p "/sdlc-maintain breach <detector output>"` with tool permissions that match the tier. The trigger can be a scheduled CI job, a monitoring webhook, or cron.
