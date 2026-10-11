---
name: sdlc-spec
description: Stage 2 (Design) of the AI-native SDLC pipeline. Turns an accepted sdlc/<change>/intent.md into spec.md with numbered requirements, a design grounded in the existing codebase and project standards, and flagged areas of concern. Use when the user wants requirements, a design, or a spec for captured intent, or has just accepted an intent.md and asks what comes next.
argument-hint: "[sdlc/<change> directory]"
---

# Requirements and design (Stage 2: Design)

Requirements and design collapse into one pass. Project policy is applied while the spec is written, not discovered in a review weeks later. Claude writes the spec; the user, as product owner, reviews it.

## Find the change

Use the directory given in the arguments. Otherwise pick the change under `sdlc/` whose `intent.md` is accepted and has no `spec.md` yet; ask if none or several match. `intent.md` must say `Status: accepted`. If it says anything else, ask the user to accept it first: an unreviewed intent is the most expensive thing to build on.

## Steps

1. Load the standards the spec must conform to: `CLAUDE.md`, the docs it points to that touch this change (architecture, glossary, platform constraints, `docs/known-issues.md`), and every available skill whose domain the change touches, such as UI, accessibility, security, or App Store review. These are the policies. List the ones applied in the spec header.
2. Read the code the change integrates with, so the design fits the system as it is.
3. Run the playbook's pass:
   > Read the attached intent.md and produce a requirements and design spec for integrating it into our existing codebase. Apply the skills available to you so the plan conforms to our brand guidelines, security policies and UX standards. Document the spec fully as spec.md, ready to hand to the engineering team. Describe clearly any areas of concern, especially where you cannot satisfy contradicting policies.
4. Write `spec.md` next to `intent.md` from the template below. Number the requirements so the plan, the tests, and the review can cite them, and make each one checkable. For UI changes, name the visual target here (a mock, a reference screenshot, or the platform pattern to follow); the build checks against it later.
5. Review with the user, flagged concerns first, because they are what an analyst would have escalated. Resolve each one. Then check that the spec solves the stated problem and that every open question from the intent is answered or carried forward.
6. Gate: when the user accepts it, set `Status: accepted`. If review changed what is being asked for, update `intent.md` too, so the pair still records what was asked and what was decided.

Next stage: `/sdlc-plan`.

## Template

```markdown
# Spec: <title>
From: intent.md (<author>). Status: draft.
Standards applied: <CLAUDE.md, docs, skill names>

## Requirements
- R1. <One checkable requirement.>

## Design
<Components, interfaces, data flow, and where each piece lives in the codebase.>

## How each constraint in the intent is met
| Constraint | Met by |
| :--- | :--- |
| <Constraint from intent.md> | <R#, design element> |

## Open questions from the intent
- <Question>: <answer, or "Not answered. Carried forward as concern N.">

## Areas of concern
1. <What cannot be satisfied or is unproven, why, and a proposed resolution.> Owner: <area or person>.
```
