# .claude/

Claude Code harness config for CrocApp. Claude Code is the only agent harness this project supports — do not add config for other agents.

## Layout

| Path | Committed | Purpose |
| --- | --- | --- |
| `settings.json` | yes | Shared baseline every contributor gets |
| `settings.local.json` | **no**, gitignored | Per-user overrides |
| `skills/` | yes | The `sdlc-*` pipeline skills, nothing else |
| `agents/` | yes | Project subagents (`verifier`, used by `/sdlc-build`) |

## Skills

`sdlc-*` follow Anthropic's AI-native SDLC playbook (https://claude.com/blog/the-ai-native-sdlc-playbook) and stay generic: project specifics live in `CLAUDE.md` and the docs it points to, which every stage reads. One skill per stage, run in order: `/sdlc-intent`, `/sdlc-spec`, `/sdlc-plan`, `/sdlc-build`, `/sdlc-review`, `/sdlc-ship`; `/sdlc-maintain` turns a failure back into a new intent. Each stage writes one artifact to `sdlc/<date>-<slug>/` (gitignored), and the next stage reads it; a stage only starts from an artifact the user accepted. Edit these skills in place; no tool manages them.

No other skill is committed here. Skills the pipeline relies on are installed per user with the `skills` CLI (https://skills.sh):

```bash
npx skills add mattpocock/skills -s grilling -g -a claude-code
```

`grilling` is required: every stage puts its questions to the user in grilling rounds; a plain yes/no confirmation, such as approving a commit, stays a plain question. A round goes out only after every subagent, lookup, and piece of research it could depend on has finished, so a printed question is never revised or withdrawn; this overrides `grilling`'s advice to ask non-dependent questions while research runs. If a later finding does reopen a settled answer, raise it as a new question in the next round. If `grilling` is not among the available skills, stop, give the user the command above, and ask them to relaunch the stage. When a change touches a domain (UI, accessibility, security, App Store review, ...) that no installed skill covers, name one for the user to install (`npx skills find <query>`) and carry on without it.

## SDLC sessions

Every stage runs in its own new session, launched with the model and effort below. A fresh session reads the accepted artifact, not the conversation that produced it.

| Stage | Model | Effort | Why |
| :--- | :--- | :--- | :--- |
| `/sdlc-intent` | `opus` | `high` | Conversation and judgment over a small context |
| `/sdlc-spec` | `opus` | `xhigh` | Design mistakes compound through every later stage |
| `/sdlc-plan` | `opus` | `xhigh` | Build follows the plan literally |
| `/sdlc-build`, one slice | `sonnet` | `high` | Carries out an accepted plan; fast and cheap over a large context |
| `/sdlc-build`, slice marked `Risk: high` | `opus` | `high` | Mistakes there are silent or costly |
| `/sdlc-build sdlc/<change> fix review` | `sonnet` | `high` | Findings are already pinned to file and line |
| `/sdlc-review` | `opus` | `high` | The gate needs the strongest fresh eyes |
| `/sdlc-ship` | `sonnet` | `medium` | Commit, PR, and CI are mechanical |
| `/sdlc-maintain` | `opus` | `high` | Root-cause diagnosis |

Inside a stage, subagents that write code run on the stage's model or `sonnet`; only pure lookups drop to `haiku`.

A build or spec session that outgrows one session (the conversation was compacted, or more work remains than fits) stops at a clean boundary, records its progress (the Build log, or a draft `spec.md`), and hands off to the same stage in a new session.

When a next stage exists, the final message ends with this handoff, after the session-end report `CLAUDE.md` asks for:

```text
Next: /sdlc-<stage> in a new session (<model>, <effort>: <why>). Quit this session, then run:
  claude --model <model> --effort <effort> --name "<name>" "/sdlc-<stage> sdlc/<change>"
If the stage does not start, run `claude --model <model> --effort <effort> --name "<name>"` and paste: /sdlc-<stage> sdlc/<change>
```

For a review fix the stage argument is `sdlc/<change> fix review`. For `/sdlc-plan`, add `--permission-mode plan` to both commands. Set effort with the flag, never `/effort`: the flag lasts one session, while `/effort` saves a new default that carries into later sessions.

`--name` labels the session in the `/resume` picker and the terminal title, so a later session can find the one that produced an artifact: `claude --resume <change>` opens the picker with that search term. The name is `<change>/<stage>`, where `<change>` is the directory name under `sdlc/`, and `<stage>` drops the `sdlc-` prefix and carries the build slice or the fix:

| Next session | Name |
| :--- | :--- |
| `/sdlc-spec`, `/sdlc-plan`, `/sdlc-review`, `/sdlc-ship` | `<change>/spec`, `<change>/plan`, `<change>/review`, `<change>/ship` |
| `/sdlc-build`, one slice | `<change>/build-<slice>`, e.g. `<change>/build-B1` |
| `/sdlc-build sdlc/<change> fix review` | `<change>/build-fix-review` |
| `/sdlc-intent`, `/sdlc-maintain` (no change directory yet) | `<YYYY-MM-DD>-intent`, `<YYYY-MM-DD>-maintain` |

When an earlier session of the change already used the name (a stage handing off to itself, a second review after a fix), append `-2`, `-3`, and so on.

## Settings

`settings.json` is the shared floor, `settings.local.json` overrides it per person. Precedence: local > project > user.

Adding an MCP server takes three edits:

1. Server definition in `.mcp.json` at repo root.
2. Server name in `enabledMcpjsonServers`.
3. `mcp__<server>` in `permissions.allow`, or it prompts on every call. Plugin-provided servers use `mcp__plugin_<plugin>_<server>`.

Plugins from non-Anthropic marketplaces need that marketplace declared in `extraKnownMarketplaces`, otherwise `enabledPlugins` resolves to nothing on a fresh clone.

Never commit `settings.local.json`. To change what every contributor gets, edit `settings.json`.

## Setup

Install `grilling` (see Skills). Personal overrides go in `.claude/settings.local.json`; `/status` lists which settings files actually loaded.
