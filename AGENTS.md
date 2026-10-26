# CrocApp

Native SwiftUI GUI for the croc file-transfer CLI.

## Workflow

Do every change on a new branch and land it through a pull request (merge rules: `.github/AGENTS.md`). GitHub deletes the remote branch when the PR merges. Then delete the local branch: `git switch main && git pull --ff-only && git branch -D BRANCH`. Use `-D`, because a squash merge leaves the branch's commits out of `main`, so `-d` refuses.

## Verification

A green build is not evidence a transfer works. A change to `crocmobile/session.go`, `CrocKit/Sources/` or `TransferController` needs its matching transfer harness run, with the output quoted (`docs/BUILDING.md`, "Verification harnesses"). Anything not run is reported as "not verified".

## Docs

`docs/README.md` indexes the contributor docs and `docs/AGENTS.md` holds their writing rules. A change is finished when the docs that describe it match it:

| You changed | Bring in step |
| --- | --- |
| `crocmobile/` or `CrocKit/` | `docs/knowledge/crocmobile-bridge.md`, `docs/ARCHITECTURE.md` |
| App models, views or settings | `docs/knowledge/app-ui-architecture.md`, `docs/knowledge/features.md` |
| Anything a user sees | `CHANGELOG.md` (`## [Unreleased]`), the docs site page in `web/docs/content/` |
| `web/landing/` | `docs/knowledge/landing-page.md` |
| Scripts, CI, toolchain pins | `docs/BUILDING.md`, `docs/knowledge/tooling.md` |
| Signing, Sparkle, store builds or listing | `docs/RELEASING.md`, `docs/knowledge/app-store-listing.md` |
| The croc version | `docs/knowledge/croc-upgrade-playbook.md` (it lists the rest) |
| Security-relevant behavior | `docs/THREAT-MODEL.md` |
| A defect found and left, or fixed | `docs/known-issues.md` |

Run `scripts/verify-docs.sh` after editing markdown; CI runs it.

## Design

Anything a user sees (app views, the landing page, the docs site, release artwork, store copy, UI strings) follows `design/`. Start at `design/AGENTS.md`. Run `scripts/verify-design.sh` after touching any of it; CI runs it.

New app text must be localizable (String Catalogs, English only today). How each kind of string is written, what is never localized, and how to sync the catalogs: `docs/knowledge/app-ui-architecture.md`, "Localization".

## Skills

Load these before the matching work, every time:

| Work | Skills |
| --- | --- |
| Anything design-related, on any surface: `design/`, views, stylesheets, artwork, UI copy | `apple-design` |
| SwiftUI views, app UI, Liquid Glass, animation | `swiftui-expert-skill`, `mobile-ios-design` |
| App Store submission, listing copy, review notes, entitlements, privacy | `apple-appstore-reviewer` |

If one is missing, install it (user-level, all from [skills.sh](https://skills.sh) sources) before starting, then reload skills:

```bash
npx skills add emilkowalski/skills --skill apple-design -g -y
npx skills add avdlee/swiftui-agent-skill --skill swiftui-expert-skill -g -y
npx skills add wshobson/agents --skill mobile-ios-design -g -y
npx skills add github/awesome-copilot --skill apple-appstore-reviewer -g -y
```

Check what is installed with `npx skills ls -g`. When a skill's advice conflicts with this repo (`design/`, a directory's `AGENTS.md`), the repo wins.

## Editing AGENTS.md files

Every `AGENTS.md` in this repo (root or in sub-dirs) is written and updated through the `claude-md-management:claude-md-improver` skill, or the closest equivalent your agent has. Run it on the file you change: audit it against the real state of its directory, then apply targeted edits. Keep each file short, current and specific to its directory. Don't restate what the code or another doc already says.
