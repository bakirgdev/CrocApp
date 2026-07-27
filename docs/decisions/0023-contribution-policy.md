# 0023. Contribution policy

Status: accepted
Date: 2026-07-27

## Context

The repo was public and buildable with no contributor-facing policy: no `CONTRIBUTING.md`, no code of conduct, no security policy file. Issue forms, a PR template and CI existed, so the mechanics were there, but nothing said who may contribute, how commits should look, or what "verified" means to a reviewer who is not the maintainer. GitHub's community profile flagged the gaps, and the working rules that matter here (harness verification, design tokens, docs self-heal) lived only in `CLAUDE.md`, which reads as AI-session config rather than contributor guidance.

## Decision

Three files at the repo root, plus the pointers into them.

- **`CONTRIBUTING.md`** is self-contained: setup, repo map, branch and commit conventions, style, design rules, verification matrix, docs rules, PR flow, an out-of-scope list, and licensing. It links to ADRs and `docs/knowledge/` for depth rather than restating them.
- **Fully open to pull requests.** No issue-first requirement, no maintainer-only areas. Large features get a "talk first" nudge, not a gate.
- **Conventional Commits** (`type(scope): subject`) with scopes matching the repo layout, and **Conventional Branch** names. Subjects stay imperative, lowercase, no trailing period.
- **Verification is required and honestly reported.** Changes to `crocmobile/session.go`, `CrocKit/Sources/`, or `TransferController` need the matching `scripts/verify-*.sh` output pasted into the PR. A contributor who cannot run it writes "not verified" and the maintainer runs it before merge. Nobody merges an unverified transfer-path change.
- **AI-assisted contributions are allowed with disclosure.** One line in the PR when a model wrote a substantial part. The contributor still owns the code: understands it and verified it. Unread, unverified bulk-generated PRs are closed without review.
- **`CODE_OF_CONDUCT.md`**: Contributor Covenant 3.0, verbatim apart from the two placeholder blocks the upstream text requires filling in (reporting channel, enforcement ownership) and the substitution of "Community Moderators" for the single maintainer. Reports go to `bakirgdev@gmail.com`, with GitHub abuse reporting named as the escape hatch when the report concerns the maintainer.
- **`SECURITY.md`**: private advisories only, explicit in-scope paths versus what belongs upstream in croc, no bounty, no response-time promise, and a repeat of the no-audit warning.
- **Inbound equals outbound.** Contributions are MIT under the repo `LICENSE`. No DCO, no CLA, no sign-off.

## Consequences

- Conventional Commits does not match the existing history (`start preparing repo`, `improve mcp's`). History is not rewritten; the convention applies going forward. Nothing enforces it, so drift is possible until a commit-lint job exists.
- Squash merges mean the **PR title** is the commit subject that lands. It carries the convention, not the contributor's intermediate commits.
- Contributor Covenant 3.0 is CC BY-SA 4.0, so the adapted `CODE_OF_CONDUCT.md` inherits CC BY-SA 4.0 for its own text. The attribution block is required and must survive edits. This is the one file in the repo not under MIT.
- The enforcement ladder assumes moderators. With one maintainer, every rung is the same person, and the file says so rather than pretending otherwise.
- `CONTRIBUTING.md` duplicates rules that also live in `CLAUDE.md`, `README.md`, and the PR template: build commands, verification bar, design rules, docs self-heal. That is deliberate (a contributor should not have to read `CLAUDE.md`), and it is a drift surface. When a working rule changes, `CONTRIBUTING.md` changes in the same commit.
- The PR template gained the Conventional Commits and AI-disclosure notes as HTML comments, so the checklist did not grow.
