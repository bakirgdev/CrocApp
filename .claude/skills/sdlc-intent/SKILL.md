---
name: sdlc-intent
description: Stage 1 (Plan) of the AI-native SDLC pipeline. Turns an idea, feature request, or GitHub issue into a reviewed intent.md proto-spec under sdlc/. Use when the user wants to start a change through the SDLC pipeline, asks to capture or write up an idea or issue as intent, or mentions intent.md or sdlc/.
argument-hint: "[idea in your own words | issue number or URL]"
---

# Capture intent (Stage 1: Plan)

Intent is captured once, in the originator's own words, as a file the next stage can act on. It records what is wanted, why, and under which constraints. It does not record how: design is the job of `/sdlc-spec`, and a solution written in now narrows the spec before anyone has read the code.

The user is the originator and the product owner. Claude writes the file; the user corrects and accepts it. Trivial changes (a typo, a one-line fix) skip the pipeline.

## Steps

1. Take the input. For an issue, read it with `gh issue view <n> --comments`. For an idea, let the user describe it in their own terms: what they cannot do today, who is affected, what better looks like, what is out of scope. No formal language needed.
2. Brainstorm until the idea is concrete. Ask the questions an analyst would ask: scope, users, constraints, what success looks like. One question per message, multiple choice when the options are known. Read `CLAUDE.md` and the docs it points to only enough to ask sharp questions, not to design.
3. Write `sdlc/<YYYY-MM-DD>-<slug>/intent.md` from the template below: today's date, a 2-5 word kebab-case slug. Keep it short; the playbook's own example is twelve lines.
4. Show the file and apply the user's corrections. Anything Claude misunderstood is fixed here, before it costs a spec.
5. Gate: when the user accepts it, set `Status: accepted`. If they drop it, set `Status: rejected` and add one line saying why. A draft never moves to the next stage.

Next stage: `/sdlc-spec`. A small, bounded fix can go straight to `/sdlc-plan`.

## Template

```markdown
# Intent: <short title>
Author: <git user.name> (<idea | issue #N>). Status: draft.

## Problem
<What is wrong or missing today, and who it hurts.>

## Proposed outcome
<What better looks like, observable by a user.>

## Affected users and systems
<Who is affected, and which parts of the system.>

## Constraints
<Hard limits, including what is out of scope.>

## Open questions
<What is still unknown. The spec must answer or carry forward each one.>
```
