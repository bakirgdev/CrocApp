# CrocApp

Native SwiftUI GUI for the croc file-transfer CLI.

## Design

Anything a user sees (app views, the landing page, the docs site, release artwork, store copy, UI strings) follows `design/`. Start at `design/AGENTS.md`. Run `scripts/verify-design.sh` after touching any of it; CI runs it.

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
