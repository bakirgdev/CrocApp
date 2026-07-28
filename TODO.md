# TODO

Personal scratch list. Not a doc — never cite from `docs/`.

## Repo hardening (gate: v0.9.9)

Enforce on GitHub, all of these together:

- [ ] Main branch: no direct pushes, contributions via PR only
- [ ] Main branch: block force pushes of any kind
- [ ] Required status check: CI from the PR must pass
- [ ] Required status check: Pages preview must pass for landing and/or docs page changes
- [ ] Review for more rules worth adding at the same time
- [ ] **Before** making CI a required check: replace the `paths` allowlist in `ci.yml` with a change-detection job that reports success. Today a filtered-out PR runs zero jobs, so a required check stays pending forever (see `docs/knowledge/tooling.md`)
- [ ] Pin third-party actions to commit SHAs (`maxim-lobanov/setup-xcode`, `golangci/golangci-lint-action`) — mutable major tags are a supply-chain hole

## Workflows

- [ ] Release workflow
- [ ] Docs workflow (`docs.yml`) — build it to the same standard as `landing.yml`, once the docs site exists

## Landing page (`web/landing/`)

- [ ] iPhone & iPad card: App Store badge (`assets/img/app-store.svg`) is an unlinked `<img>` in `index.html`. Wrap in `<a>` when the listing exists
- [ ] Mac card: same for the Mac App Store badge (`assets/img/mac-app-store.svg`)
- [ ] Brew card prints `brew install --cask crocapp` with a copy button, but no cask is published. Verify the command actually works before the card claims it. Blocked on notarization (`docs/known-issues.md`)
- [ ] Link the docs site from the page — nav, own section, wherever fits best

## App

- [ ] Prompt for camera and local network permission after the onboarding screen closes on first launch, and check permission state before using each feature *(known fix, feeds the pre-publish review below)*
- [ ] Brew cask
- [ ] Copy the Claude design into the app — target v1.1.0

## Ops / external

- [ ] Add the project domain to the private main Gmail account's Google Search Console
- [ ] Build specialized skills/commands/agents for QOL/DevEx while developing (release, format, actions, etc.) — ask Claude Code for suggestions

## Prompts to run in a clean session

Pre-App-Store full review:

"
Audit CrocApp end to end for App Store readiness. This is the last check of the app itself before publish, so treat gaps as blockers, not nits. Start from `docs/ARCHITECTURE.md` and `docs/known-issues.md`.

**Review first, no edits.** Judge: every feature actually works, runtime performance, code quality for both human contributors and AI agents, comment density (short, why-not-what, healthy doses), and first-run UX polish. Run the builds, swift-format lint, golangci-lint, govulncheck, and the `scripts/verify-*.sh` harnesses; quote real output. Report every finding with severity, including low-severity ones.

One defect is already known and must land: on first launch, request camera and local network permission after the onboarding screen closes, and check permission state before each feature that uses them.

**Then execute.** Group findings into phases ordered by risk. For each phase in turn: write the plan, hand the work to subagents, review what comes back, verify with the matching harness, commit, push. One phase per pass, not all at once.

Close with a plain-words recap: what was done, what was verified with which command, what was fixed.

Think before answering (maximum reasoning)
"
  
Known-issues sweep:

"
Read `docs/known-issues.md`. For every entry: find the real cause in the code and cite `file:line`, research the correct fix (context7, web, gopls/xcode MCP, or subagents, not guesses), and state its blast radius.

Output one plan: issues ranked by severity, each with root cause, chosen fix, files touched, and the command that verifies it. Change no code this session.

After I approve the plan, write a single self-contained prompt that carries out the whole thing in one clean session.

Think before answering (maximum reasoning)
"
