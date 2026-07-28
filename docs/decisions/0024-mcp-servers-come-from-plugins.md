# 0024. context7 and playwright come from plugins, not `.mcp.json`

Status: accepted
Date: 2026-07-28

## Context

Claude Code can load the same MCP server twice: once from the project's `.mcp.json` and once from an enabled plugin that ships the same server. Both catalogs load, both sets of tools appear, and the session pays for every tool description twice. The names differ only by prefix (`mcp__context7__query-docs` next to `mcp__plugin_context7_context7__query-docs`), so nothing errors and the duplication is easy to miss.

That is exactly what happened. `.mcp.json` declared `context7` while `.claude/settings.json` enabled `context7@context7-marketplace`, both live at once. The same collision had already been noticed for playwright and was resolved the other way, by uninstalling the plugin and keeping the `.mcp.json` entry.

`.mcp.json` entries have one advantage here: they can be wrapped in the `caveman-shrink` stdio proxy, which compresses tool descriptions (ADR 0004). Plugins cannot be wrapped, since the plugin owns its own server command.

## Decision

- **A server is declared in exactly one place.** Never a `.mcp.json` entry and an enabled plugin for the same server.
- **Where a maintained plugin exists, the plugin wins.** `context7@context7-marketplace` and `playwright@claude-plugins-official` are enabled in `.claude/settings.json`; both entries are gone from `.mcp.json`.
- **`.mcp.json` keeps what has no plugin.** `xcode` (`xcrun mcpbridge`) and `gopls` (`$(go env GOPATH)/bin/gopls mcp`) stay there, still behind `caveman-shrink`.
- **Permission entries follow the tool prefix.** A plugin server's tools are namespaced `mcp__plugin_<plugin>_<server>`, so `permissions.allow` carries `mcp__plugin_context7_context7`, not `mcp__context7`.

## Consequences

- context7 and playwright tool descriptions are no longer compressed by `caveman-shrink`. That is the price of the plugin path, and it is smaller than the duplicate catalog it replaces.
- Plugin updates arrive on the marketplace's schedule rather than the pinned `npx` invocation the `.mcp.json` entry used. Version drift is possible and is not pinned anywhere in this repo.
- `enabledMcpjsonServers` and `enabledPlugins` in `.claude/settings.json` are now the single list to check when a tool goes missing. A server that appears in neither is off.
- Adding any future MCP server means checking for a plugin of the same name first, and picking one side.
