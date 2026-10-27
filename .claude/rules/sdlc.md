# AI-native SDLC

This project runs changes through the AI-native SDLC skills. A task lives in `sdlc/<slug>/` on branch `sdlc/<slug>` and moves through one Claude Code session per phase. A phase is finished when its artifact has `status: accepted`.

| Phase | Start with | Writes |
|---|---|---|
| intent | `/sdlc-intent <idea or ticket>` | `task.yaml`, `intent.md` |
| spec | `/sdlc-spec <slug>` | `spec.md` |
| plan | `/sdlc-plan <slug>` | `plan.md` |
| build | `/sdlc-build <slug>` | code, tests, `build.md` |
| test | `/sdlc-test <slug>` | tests, fixes, `test.md` |
| deploy | `/sdlc-deploy <slug>` | pull request, `deploy.md` |

`/sdlc-maintain` turns alerts, incidents and scan findings into new intents. `/sdlc-setup` holds one-time project setup. `/sdlc-status` shows every task. On a `sdlc/<slug>` branch, hooks block code edits until plan.md is accepted and block code commits until the check command passes (`$SDLC_VERIFY`, or each repository's command in workspace mode).

## In every SDLC session

- **Files are the handoff.** Never rely on an earlier session. Read `sdlc/<slug>/task.yaml` and the artifacts before acting, and record decisions in the artifacts, not only in chat.
- **Questions go through the `grilling` skill.** Finish all research, tool calls and subagents first, then ask the whole round at once: short, simple questions, each with your recommended answer, worded so "yes" accepts it. Ask whenever something needs the user's decision, before or during implementation. If `grilling` is not among your available skills, stop and tell the user to install it: `npx skills add https://github.com/mattpocock/skills --skill grilling -a claude-code -g -y` (https://skills.sh/mattpocock/skills/grilling).
- **Check facts with context7.** Before relying on any library, framework, SDK, API, CLI or cloud-service detail you are not fully sure of, query the context7 MCP tools. If context7 is unavailable, say so and use the official documentation.
- **Browser checks use Playwright** (the Playwright MCP tools, or the project's Playwright test runner) unless the user asks for another tool, such as Claude in Chrome.
- **Never weaken a check to make it pass.** Fix the code, not the test.
- **Attribution follows the user.** Commits, pull requests, issues, releases and artifacts keep Claude Code's default attribution lines (such as `Co-Authored-By` and the PR footer). When the user's instructions (CLAUDE.md, memory, or chat) ask for no attribution to Claude, leave it out everywhere, including in agents' commits.
- **Help improve the SDLC itself.** These skills, agents, rules, hooks and scripts get better only when the sessions running them say where they fall short. When part of the flow gets in the way of good work, write it down rather than quietly working around it. Typical cases:
  - a step that is unclear, can be read two ways, or disagrees with another file;
  - a hook or gate that blocks correct work, or lets through work it should stop;
  - a default (model, effort, permission mode, risk tier, review depth) that clearly does not fit the task it was used for;
  - a step that costs time without catching anything, or a problem that slipped through to a later phase because no step looks for it;
  - a statement about Claude Code, a CLI flag or a settings key that context7 or the docs show to be wrong or outdated;
  - project setup that holds the flow back: a slow, flaky or missing check command, a REVIEW.md that lets noise through or misses what matters, a stale CLAUDE.md.

  Add each case under `## SDLC feedback` in the current phase's artifact, as one bullet: what happened, why it hurts, and the change you suggest, naming the file. Use the current artifact even when the case concerns an earlier phase, so accepted artifacts never change for it. In deploy, hold entries until step 6 writes deploy.md. In a session with no task (`/sdlc-setup`, `/sdlc-maintain`, `/sdlc-status`), tell the user the same content at the end instead. Copy in the `SDLC feedback:` lines that agents such as `sdlc-gatekeeper` and `sdlc-reviewer` report. Keep following the flow as written in the meantime: never edit `.claude/` or weaken a gate mid-task to get past it. Mention new entries when the phase ends; `/sdlc-deploy` decides where each one goes.

## Approving a phase (task.yaml `gate_mode`)

Before any approval, run the `sdlc-gatekeeper` agent on the phase and resolve what it reports.

- `solo`: ask the user to approve, as a grilling question that includes the gatekeeper's verdict. Only after an explicit yes, set `status: accepted`, `approved_by: <git config user.name>` and `approved_at: <YYYY-MM-DD>`.
- `auto`: when the gatekeeper returns PASS, set `status: accepted` and `approved_by: sdlc-gatekeeper` yourself. Ask the user only about decisions that are theirs. Exception: a `medium` or `high` risk task merges only after the user's explicit yes (`/sdlc-deploy` step 7).
- `strict`: never set `accepted` on your own. Commit the artifact as `draft`, tell the user who must accept it (intent and spec: the product owner; plan: the engineer, or a tech lead for higher-risk changes), and print `.claude/sdlc-scripts/next.sh <slug>` for them to run once it is accepted; skip the rest of "Ending a phase". For deploy, the code owner's approving review is the acceptance: when `gh pr view <n> --json reviewDecision` shows `APPROVED`, set deploy.md to `accepted` with `approved_by: <reviewer>`.

## Ending a phase

1. Commit the phase's files: `sdlc(<slug>): <phase> <accepted|draft>`. In workspace mode, commit them only when this folder is a git repository and `git check-ignore -q sdlc/<slug>/task.yaml` says they are not ignored; otherwise they stay local and the user keeps them.
2. Weigh the next phase's model, effort and permission mode. The defaults are in `.claude/sdlc-scripts/next.sh --defaults`. Values the user set in task.yaml (`<phase>_model`, `<phase>_effort`, `<phase>_permission`) always win. If a default clearly does not fit this task (its size, risk or ambiguity), pass `--model`, `--effort` or `--permission` and give the reason in one line. Do not choose the `fable` model or `bypassPermissions` yourself; use them only when the user asks.
3. Run `.claude/sdlc-scripts/next.sh <slug> [flags]`. With `run_mode: manual` it prints a command: show it to the user unchanged, to run in a new terminal. With `run_mode: autonomous` it starts the next phase as a background session: tell the user they can follow it with `claude agents` and `claude attach <slug>-<phase>`, then stop.

## Workspace mode

When `.claude/sdlc-workspace.yaml` exists, this folder holds several git repositories (every folder directly inside it that contains `.git`), and one task can change several of them.

- Always run from this folder. Every repository is already reachable from here, so no `--add-dir` is needed.
- Task files stay in `sdlc/<slug>/` in this folder. `repos:` in task.yaml lists the repositories the task changes, and each of them gets its own `sdlc/<slug>` branch, created from its own default branch.
- Run git per repository (`git -C <repo> ...`). Paths in the artifacts start with the repository folder, for example `api/src/app.ts`.
- Each repository's own CLAUDE.md owns its toolchain, commands and release process; read it before changing that repository.
- Each repository's check command is in `.claude/sdlc-workspace.yaml` as `<repo>: <command>`, run inside that repository. It replaces `$SDLC_VERIFY`.

## Context and compaction

Answers get less reliable as the context grows, long before the window is full. Claude cannot run `/compact` or `/clear`: it recommends them at the right moment and the user runs them. The context gate hook (`.claude/hooks/sdlc-context-gate.sh`) measures the session and says when, in every session in this project:

- **From `SDLC_COMPACT_SUGGEST` tokens (default 200K)**, end a reply with one line naming the best next move:
  - the work in this session continues: `/compact <focus>`, with the focus drafted;
  - the phase's artifact is accepted: the handoff command, because the next phase starts in a fresh session anyway;
  - the next request is unrelated: `/clear` or a new session.
- **From `SDLC_COMPACT_REQUIRE` tokens (default 350K)**, finish only small work, such as completing the artifact, the gatekeeper run and the handoff. About 40K tokens later, tools pause until the user compacts, except what saving the task's state and ending a phase need: `sdlc/` task files, the `sdlc-gatekeeper` agent, `git add sdlc/...`, `git commit`, `next.sh` and `status.sh`. Save the unfinished state and ask for `/compact`. If the user replies with anything else, work resumes for about 100K tokens.
- Compact at a natural break, never in the middle of a step. If the next work does not need this session's history, a new session beats compacting.
- On a task, write the unfinished state to the current artifact before asking: what is done, the next step, open questions with recommended answers, failing checks. Files outlive any summary.
- A good focus names the task slug and phase, the next step, and decisions not yet written down, for example `/compact keep task login-rate-limit, build step 4 of 6, the retry decision`.
- Background sessions have no one to type `/compact`: `next.sh` starts them with `--autocompact` at the require size, and the gate never pauses them.
- Both sizes are set in `.claude/settings.json` under `env`; `0` turns a stage off.

### Compact instructions

When summarizing, keep the task slug and phase, `gate_mode` and `run_mode`, open questions with their recommended answers, failing checks, and anything not yet written to the artifacts. After compaction, re-read task.yaml and the current artifact. A SessionStart hook re-injects the task state after compaction and on resume.
