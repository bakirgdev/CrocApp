---
paths:
  - "sdlc/**"
---

# SDLC artifact format

- `sdlc/<slug>/task.yaml` holds flat `key: value` lines only, because the scripts read it with awk. Keys: `slug`, `title`, `created`, `branch`, `gate_mode` (`solo`, `auto`, `strict`), `run_mode` (`manual`, `autonomous`), `pr` (`ask`, `auto`), `risk` (`low`, `medium`, `high`; set by the plan, raised by deploy, never lowered), in workspace mode `repos` (comma-separated repository folders, for example `repos: api, web`), and optional per-phase overrides such as `build_model: opus`, `build_effort: high`, `build_permission: auto`. Overrides apply to this task only; add them when the user asks.
- Each phase writes one artifact: intent `intent.md`, spec `spec.md`, plan `plan.md`, build `build.md`, test `test.md`, deploy `deploy.md`. Each starts with YAML frontmatter: `slug`, `phase`, `status`, `approved_by`, `approved_at`. intent.md also has `author` and `ticket`.
- `status` is `draft` (being written or reworked), `accepted` (its gate passed) or `rejected`. Intents written by `/sdlc-maintain` can also be `scheduled` or `dismissed` (add a `reason:` line). Only the approval rules in `.claude/rules/sdlc.md` set `accepted`.
- An accepted artifact is the contract for later phases. A small deviation that keeps the requirements (a different file, a renamed function) goes under `## Changes` with a date and reason, and the status stays. A change to scope, requirements or design sets the artifact back to `draft`, is recorded under `## Changes`, passes its gate again, and sets every later artifact back to `draft`.
- deploy.md records every review finding with an outcome: `fixed` (cite the commit), `wrong`, `intentional`, `unimportant` (each with a reason) or `deferred-intent` (Pre-existing; it becomes a new task).
- intent.md to test.md can end with `## SDLC feedback`: one bullet per suggested improvement to the SDLC or the project's setup (`.claude/rules/sdlc.md`). Adding a bullet during its own phase is not a deviation and leaves the status as it is. deploy.md's `## SDLC feedback` table lists every bullet from the earlier artifacts plus the deploy phase's own entries, each with an outcome: `issue` (cite the URL), `task` (cite the slug step 8 creates) or `dropped` (with a reason).
- Keep artifacts short and factual. Paste tool output literally in fenced `text` blocks; never paraphrase evidence.
