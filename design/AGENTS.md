# design/

The design rules for every CrocApp surface: the SwiftUI apps (iOS, iPadOS, macOS), the landing page, the docs site and the release artwork. The app is built from system controls, styles and colors, so this directory holds principles first, then what is custom and why. Only the web has tokens.

## Layout

| File | Owns |
| --- | --- |
| `principles.md` | System first, platform adaptation, controls, color, contrast, type, materials, motion, haptics, accessibility, the web rules, and the few hard bans |
| `components.md` | The behavior of the app's own pieces (drop zone, code phrase, status block, accept gate) |
| `tokens.css` | Web-only custom properties for the landing page and docs site; the app has no mirror |
| `voice.md` | Personality, copy patterns, terminology, numbers, the approved security claims |
| `brand.md` | Logo and icon, mascot, palette, assets, favicon recipe, naming, legal, store badges |

## How to use it

Load `apple-design` before any design work, plus `swiftui-expert-skill` and `mobile-ios-design` for SwiftUI views (install and conflict rules: root `AGENTS.md`, "Skills"). When a skill and this directory disagree, this directory wins.

Reach for the system control, its style, system semantic colors, text styles and default spacing first. Draw something custom only when no system control does the job.

## Checks

`scripts/verify-design.sh` runs in CI and checks the web only: no raw colors in the landing page and docs site sources, and the `theme-color` literals equal `--bg-base`. Nothing machine-checks the app's views or contrast, so reviewers do, with Accessibility Inspector. A failure means the change or this directory is wrong; fix one of them, never the check.

## Editing

- Cite sections by name (`components.md`, "AcceptGate"), never by line number, and grep the old heading text when renaming one.
- Verified facts name what they were checked against (the Lucide version, the SDK, the tool that computed a ratio), never a date.
- Token names are `--<category>-<role>-<modifier>`, lowercase, never encoding a value (`--olive-600`, not `--olive-dark`), with a `web` segment for web-only layout and metrics. A token is live only while a site consumes it: delete an unused one in the same commit, and consume the `--color-*` aliases, not the base palette.
- Run `scripts/verify-docs.sh` after editing markdown here, and `scripts/verify-design.sh` after touching `tokens.css` or web code.
