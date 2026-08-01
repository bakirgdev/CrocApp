# .claude/

Claude Code harness config for CrocApp. Claude Code is the only agent harness this project supports — do not add config for other agents.

## Layout

| Path | Committed | Purpose |
| --- | --- | --- |
| `settings.json` | yes | Shared baseline every contributor gets |
| `settings.local.example.json` | yes | Template for personal settings |
| `settings.local.json` | **no**, gitignored | Per-user overrides |
| `skills/` | yes | Vendored skills useful for the project |

## Skills

Managed with the `skills` CLI (https://skills.sh). Sources and content hashes live in `skills-lock.json` at repo root; restore with `npx skills experimental_install`.

Add with `--copy` so the files land in `skills/` as real files instead of symlinks into `node_modules`:

```bash
npx skills add <owner/repo> -s <skill> -a claude-code --copy
```

One `-s` per skill; comma-separated names do not match. Before adding, check the skill is not already provided by an enabled plugin — both copies load under separate names, and the vendored one goes stale.

## Settings

`settings.json` is the shared floor, `settings.local.json` overrides it per person. Precedence: local > project > user.

Adding an MCP server takes three edits:

1. Server definition in `.mcp.json` at repo root.
2. Server name in `enabledMcpjsonServers`.
3. `mcp__<server>` in `permissions.allow`, or it prompts on every call. Plugin-provided servers use `mcp__plugin_<plugin>_<server>`.

Plugins from non-Anthropic marketplaces need that marketplace declared in `extraKnownMarketplaces`, otherwise `enabledPlugins` resolves to nothing on a fresh clone.

Never commit `settings.local.json`. To change what new contributors start with, edit `settings.local.example.json`.

## Setup

```bash
cp .claude/settings.local.example.json .claude/settings.local.json
```

Then edit to taste. `/status` lists which settings files actually loaded.
