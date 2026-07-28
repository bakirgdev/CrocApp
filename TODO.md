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
- [ ] Recurring-review note: bump the GH workflow macOS runner image (`macos-26` → `27`, and onward) only when Apple ships the matching OS release across platforms. Track this somewhere durable, not just here

## Landing page (`web/landing/`)

Blocked on the first release / store listings:

- [ ] iPhone & iPad card: App Store badge (`assets/img/app-store.svg`) is an unlinked `<img>` in `index.html`. Wrap in `<a>` when the listing exists
- [ ] Mac card: same for the Mac App Store badge (`assets/img/mac-app-store.svg`)
- [ ] Brew card prints `brew install --cask crocapp` with a copy button, but no cask is published. Verify the command actually works before the card claims it. Blocked on notarization (`docs/known-issues.md`)
- [ ] `llms.txt` says "Not yet released" and lists channels as pending. Update it in the *same* change that updates the page copy — the two must agree

Not blocked:

- [ ] Link the docs site from the page — nav, own section, wherever fits best
- [ ] "How to build" links to `blob/main/README.md` with no anchor. Add a build section to the README, point the link at its exact `#anchor`
- [ ] Footer has a hand-typed "Page last updated" date. Bump on every copy change (the sitemap `lastmod` is stamped automatically by `landing.yml`; this one is not)
- [ ] `assets/banner.webp` is unused. `design/brand.md` assigns it to the README header, the landing hero and the social card — it's in none of them. Use it or drop the claim
- [ ] Apple ships store badges in black and white; repo has black only and dark mode inverts it in CSS. Swap in Apple's white asset if the inversion ever looks wrong

## App

- [ ] Prompt for camera and local network permission after the onboarding screen closes on first launch, and check permission state before using each feature *(known fix, feeds the pre-publish review below)*
- [ ] Brew cask
- [ ] Copy the Claude design into the app — target v1.1.0

## Ops / external

- [ ] Add the project domain to the private main Gmail account's Google Search Console
- [ ] Build specialized skills/commands/agents for QOL/DevEx while developing (release, format, actions, ...) — ask Claude Code for suggestions

## Prompts to run in a clean session

Pre-App-Store full review:

> Make a nice prompt for CC to review the whole app, fully test it, check if it is ready code-wise and otherwise: performant, optimized, code optimized for human contributors and AI, well commented but in healthy doses (short is better), user-ready, all features work. Review, then make planned phases, then plan each phase and do it via multiple prompts using subagents for the phase's plan. Commit where it fits and push on each phase done. Deep but simple recap of what's done / verified / fixed. These are the last checks of the app itself before App Store publish. One known fix needed: prompt user for camera and local network permission after onboarding screen is closed on first launch, and check state before using each feature.

Known-issues sweep:

> List known issues from the markdown file, understand each, research how to fix, and suggest a plan for what and how to fix. I approve the plan, then you write an optimized prompt to fix it in one go in the next clean session.
