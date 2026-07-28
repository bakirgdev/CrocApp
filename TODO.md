# TODO

Personal scratch list. Not a doc — never cite from `docs/`.

## Repo hardening (gate: v0.9.9)

Enforce on GitHub, all of these together:

- Main branch: no direct pushes, contributions via PR only
- Main branch: block force pushes of any kind
- Required status check: CI from the PR must pass
- Required status check: Pages preview must pass for landing and/or docs page changes
- Review for more rules worth adding at the same time
- **Before** making CI a required check: replace the `paths` allowlist in `ci.yml` with a change-detection job that reports success. Today a filtered-out PR runs zero jobs, so a required check stays pending forever (see `docs/knowledge/tooling.md`)
- Pin third-party actions to commit SHAs (`maxim-lobanov/setup-xcode`, `golangci/golangci-lint-action`) — mutable major tags are a supply-chain hole

## Screenshots

Nothing exists in `assets/screenshots/` yet. Manifest of the six light/dark pairs to capture is in `assets/screenshots/README.md`. Blocked on a build worth photographing, and on the app restyle (v1.1.0) if that lands first, otherwise they get reshot.

- Capture the six pairs: mac-send, ios-receive, mac-settings, each light and dark, 2x, no device frames, no real codes
- Put them back in `README.md`. The `## Screenshots` section and its three `<picture>` blocks were removed because they rendered as broken images on the public repo page
- Add them to the docs guide pages (`web/docs/content/getting-started/first-transfer.md`, `guide/sending.md`, `guide/receiving.md`, `guide/settings-and-trust.md`). Images live in `web/docs/static/img/` and are referenced per locale, so add them once in English and the five locale trees inherit nothing: each locale copy needs the same markdown
- Landing page: decide whether the hero or the Features section gets one
- Store listings need their own separately sized set, not these

## Landing page (`web/landing/`)

- iPhone & iPad card: App Store badge (`assets/img/app-store.svg`) is an unlinked `<img>` in `index.html`. Wrap in `<a>` when the listing exists
- Mac card: same for the Mac App Store badge (`assets/img/mac-app-store.svg`)
- Brew card prints `brew install --cask crocapp` with a copy button, but no cask is published. Verify the command actually works before the card claims it. Blocked on notarization (`docs/known-issues.md`)

## App

- Brew cask (research)

## Ops / external

- Add the project domain to the private main Gmail account's Google Search Console
- Build specialized skills/commands/agents for QOL/DevEx while developing (release, format, actions, etc.) — ask Claude Code for suggestions

## Prompts to run in a clean session
  
Known-issues sweep:

"
Read `docs/known-issues.md`. For every entry: find the real cause in the code and cite `file:line`, research the correct fix (context7, web, gopls/xcode MCP, or subagents, not guesses), and state its blast radius.

Output one plan: issues ranked by severity, each with root cause, chosen fix, files touched, and the command that verifies it. Change no code this session.

After I approve the plan, write a single self-contained prompt that carries out the whole thing in one clean session.

Think before answering (maximum reasoning)
"
