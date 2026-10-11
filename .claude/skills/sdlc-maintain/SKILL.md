---
name: sdlc-maintain
description: Stage 6 (Maintain) of the AI-native SDLC pipeline, which closes the loop. Diagnoses a failure read-only (failed CI run, crash or bug report, security finding, regression) and writes it as a new intent.md under sdlc/ so it re-enters the pipeline. Use when the user wants an incident, failing CI run, crash, bug report, or scan finding triaged or captured into the SDLC pipeline, rather than fixed on the spot.
argument-hint: "[CI run URL | issue | log path | symptom]"
---

# Close the loop (Stage 6: Maintain)

What breaks re-enters the pipeline as `intent.md`, so the user triages and reviews the work instead of starting it. Diagnosis is read-only. Any action goes through the gated routes (plan, review, PR), never a direct fix on the default branch or a release.

## Steps

1. Gather evidence: failed run logs (`gh run view <id> --log-failed`), the issue (`gh issue view <n> --comments`), crash logs, repro steps. Reproduce it if that is cheap and safe.
2. Check `docs/known-issues.md`. If the failure is already listed, say so and stop unless the user wants it fixed now.
3. Diagnose without editing code. State the root-cause hypothesis and label it verified, inferred, or speculative, with the evidence for each.
4. Write `sdlc/<YYYY-MM-DD>-<slug>/intent.md` from the template below, the Stage 1 format plus an Evidence section. The proposed outcome includes the regression guard: the test or check that would have caught this, so the same class of failure cannot return silently.
5. Triage with the user:
   - **Fix now**: set `Status: accepted`. Small and bounded goes to `/sdlc-plan`, whose bug-fix proof starts with a failing test. Anything wider goes to `/sdlc-spec`.
   - **Schedule**: add it to `docs/known-issues.md` following that file's rules, and set `Status: deferred`. Nothing picks up a deferred intent until the user accepts it.
   - **Dismiss**: set `Status: rejected` with the reason, so the same finding is recognized next time.

## Template

```markdown
# Intent: <symptom, short>
Author: <git user.name> (incident: <run URL | issue #N | report>). Status: draft.

## Problem
<What fails, since when, and who is affected.>

## Evidence
<Log lines, run links, repro steps, the root-cause hypothesis and its confidence.>

## Proposed outcome
<The fixed behavior, plus the regression test or check that guards it.>

## Affected users and systems
<Who is affected, and which parts of the system.>

## Constraints
<Hard limits, including what is out of scope.>

## Open questions
<What is still unknown.>
```
