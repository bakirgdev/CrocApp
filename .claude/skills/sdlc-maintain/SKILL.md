---
name: sdlc-maintain
description: Closes the SDLC loop after release. Diagnoses a control-band breach, an incident, a ticket or a scan finding within its tier's limits and writes the finding back as an agent-authored intent.md, or triages the queue of agent-written intents. Use with breach, oncall, scan or triage.
argument-hint: "breach <detector output> | oncall <incident or ticket> | scan | triage"
disable-model-invocation: true
---

# Maintain

Detection stays deterministic. Claude is called in when a band is breached or an incident arrives, and what it finds re-enters the loop as a new intent.

Input: $ARGUMENTS

Choose the play from the first word: `breach`, `oncall`, `scan` or `triage`. Empty input means `triage`. For anything else, list the four plays and ask.

Every play turns a finding into a new task the same way:
1. Create branch `sdlc/<slug>` from the default branch (in workspace mode, in each repository the finding concerns, listed as `repos:`).
2. Write `sdlc/<slug>/task.yaml` with `gate_mode: solo`, `run_mode: manual` and `pr: ask` unless the user says otherwise.
3. Write `sdlc/<slug>/intent.md` in the `/sdlc-intent` format, with `status: draft`, an agent `author`, and the evidence in the Problem section.
4. Commit both files (in workspace mode, only as `.claude/rules/sdlc.md` allows). The new task then waits for `triage`.

Above the `log` tier, writing and committing that intent is the one write always allowed.

## breach

1. Parse the trigger: metric, tier (1σ, 2σ or 3σ; a drift rule counts as 2σ), reading, mean and σ. Find the metric's `bands.yaml`. If there is none, stop, because the tiers must come from version-controlled config, and suggest `/sdlc-setup bands`.
2. Obey the tier set in bands.yaml:
   - `log`: nothing more to do. Stop.
   - `diagnose`: read-only. Delegate to the `sdlc-diagnoser` agent. No edits, deploys or PRs.
   - `propose`: act only through the routes bands.yaml lists, such as opening a PR into review or triggering a pre-approved runbook like `rollback-deploy`.
3. Write the finding as a new task with `author: monitoring agent (<metric>, <tier>)`. When a runbook ran, add `## Action already taken` with what it reported.
4. When the fix ships, its test phase adds an eval for this class of incident, and a review case (`/sdlc-setup evals`) when the diagnosis names the PR that caused it.

Process metrics work the same way. A drift in PR cycle time produces a report for engineering leadership instead of an intent.

## oncall

1. Act as first responder for the incident, ticket or message. Test hypotheses with whoever leads the response, and keep the reasoning in the conversation. Use `sdlc-diagnoser` to gather the evidence.
2. Every fix becomes its own task, so it still passes plan, verify and review. A small, bounded fix can move through the phases quickly. Use `author: on-call agent (<incident>)`.
3. Confirm the metric is back at its baseline with the tools available, and state the reading.
4. Write the post-mortem to the repository's lessons file. Ask where it lives; if there is none, propose `LESSONS.md` at the root.

## scan

1. When the `claude-security` plugin is installed, run its scan on the repository, or on the directory the user names. Otherwise run `/security-review` and say the deep scan is not available.
2. Triage the findings by confidence. Give every dismissed finding a reason, so it does not come back as new.
3. Each finding worth fixing becomes a task with `author: scan agent (<scanner>)`. A bounded one is a small task. A wider one (an architectural weakness, a pattern repeated across services) is described as such.
4. Static analysis and dependency scanning stay in CI. Scans add to them; they do not replace them.

## triage

1. List the agent-written intents still in draft: run `.claude/sdlc-scripts/status.sh` and read each task's intent.md `author`.
2. Present them in one grilling round, each with its evidence and your recommendation. Route product-facing findings to the product owner.
3. The user decides. For each decision, switch to that task's branch (`git switch sdlc/<slug>`), record it in intent.md, and commit:
   - fix now: `accepted`
   - schedule: `scheduled`
   - dismiss: `dismissed`, with a `reason:` line

   Never decide yourself, whatever the gate mode. In `strict` mode the user's decision here stands in for the product owner's acceptance.
4. For each accepted intent, end its intent phase as `.claude/rules/sdlc.md` says, so its next command is `/sdlc-spec <slug>`. Dismissal reasons are input for tuning the bands.
