# 0004. Token-optimization commitment

Status: accepted
Date: 2026-07-21

## Context

Development is AI-first on a fixed-quota Claude Max plan. Token spend is the scarce resource; wasted context shortens sessions and degrades output quality.

## Decision

Optimize the whole workflow for token economy:

- `rtk` proxies dev CLI output (60-90% savings), enforced via hook.
- caveman plugin compresses assistant output; caveman-shrink wraps the context7 MCP server.
- Docs written dense and minimal; noisy command output redirected to files, not context.
- Prefer subagents for exploration/research to keep main context clean.

## Consequences

- Longer productive sessions, more work per quota.
- Terse docs/communication style may read unusual to human contributors; code, commits, and PRs stay normal prose.
