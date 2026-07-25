# docs/decisions

Architecture Decision Records (ADRs). One decision per file: `NNNN-short-slug.md`, numbered sequentially.

Format per file, kept short and direct:

```
# NNNN. Title
Status: accepted | proposed | superseded by NNNN
Date: YYYY-MM-DD

## Context
## Decision
## Consequences
```

Sections may differ where one genuinely does not apply (a decision with no cost worth naming drops `## Consequences`; a decision whose alternatives matter adds `## Rejected`). The header block does not vary.

An accepted ADR is **corrected in place, by overwrite**. When a fact in it stops being true — a value drifts, a workflow moves, a channel gets blocked — rewrite the sentence so the file reads as current truth. No `Amended YYYY-MM-DD` markers, no changelog inside the file; git history is the changelog. Overwriting means re-checking: verify the rewritten claim against the repo, and fix whatever it names if that has drifted too.

Overwrite is for facts, not for course changes. **Reversing or replacing a decision means a new ADR** that supersedes the old one; mark the old `Status: superseded by NNNN` and leave its reasoning intact.

A `## Consequences` entry that is really an open defect belongs in `../known-issues.md` as well, and gets deleted from there when it is fixed. The ADR keeps the reasoning; the issues file tracks the state.
