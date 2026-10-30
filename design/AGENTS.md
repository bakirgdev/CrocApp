# design/

The design system for every CrocApp surface: the SwiftUI apps (iOS, iPadOS, macOS), the landing page, the docs site and the release artwork. It follows current Apple practice (iOS and macOS 26, Liquid Glass, Dynamic Type) and gives principles first, with few hard rules. Values live in `tokens.css`; nothing visual is invented at a call site.

## Layout

| File | Owns |
| --- | --- |
| `principles.md` | Color, contrast, type, spacing and layout, shape, materials and Liquid Glass, motion, haptics, the accessibility floor, platform adaptation, and the few hard bans |
| `tokens.css` | Every token as a CSS custom property: the canonical values |
| `components.md` | Which system control or drawn component each piece of UI is, and short usage guidance |
| `voice.md` | Personality, copy patterns, terminology, numbers, the approved security claims |
| `brand.md` | Logo and icon, mascot, palette summary, assets, favicon recipe, naming, legal, store badges |
| `implementation.md` | Token to SwiftUI API and to web CSS, glyph mapping, what the app does not mirror, the web color rule |

## How to use it

Load `apple-design` before any design work, plus `swiftui-expert-skill` and `mobile-ios-design` for SwiftUI views (install and conflict rules: root `AGENTS.md`, "Skills"). When a skill and this directory disagree, this directory wins.

Reach for the system control first, system semantic colors where they pass contrast, text styles for type, and `--space-*` and `--radius-*` for the rest. The app follows the system's animations. Draw something custom only when no system control does the job.

## Mirrors and checks

`tokens.css` is canonical. Two hand-written mirrors carry it into code:

| Mirror | Consumed by |
| --- | --- |
| `design/tokens.css` itself | landing page and docs site (`scripts/assemble-site.sh` and the `tokens` npm script of `web/docs` copy it; never edit a copy) |
| `app/CrocApp/Support/DesignTokens.swift` and the color sets in `app/CrocApp/Assets.xcassets` | the app |

Change a value in `tokens.css` and in both app mirrors in the same commit. CI runs `scripts/verify-design.sh` on any change to `design/`, app Swift or color sets, or the web CSS, scripts and manifest it lints. It enforces:

- **Parity.** Every shared token equals its Swift constant or color set (colors within 1/255 per channel, in both themes), and each shared token is either mirrored or listed under `implementation.md`, "Not mirrored".
- **Contrast.** Every ratio in `principles.md`, "Contrast" is recomputed from `tokens.css` and must match the table, the stated guidance holds as invariants (WCAG thresholds never relax), and the focus ring and the web manifest colors stay as specified.
- **No raw colors in web code.** Hex, color functions and named colors in web CSS, HTML and scripts are findings.

A failure means the change or this directory is wrong; fix one of them, never the check. The check does not lint Swift: reviewers keep views on tokens and text styles.

## Naming

`--<category>-<role>-<modifier>`, lowercase, hyphenated.

| Layer | Pattern | Example | Rule |
| --- | --- | --- | --- |
| base palette | the thing itself | `--olive-600`, `--label-2`, `--fill-3` | literal values, never consumed by a component; aliases point at them |
| semantic alias | `--color-<role>` | `--color-accent-text` | what it is for, never what it looks like. The layer you consume |
| scale step | category and step | `--space-5`, `--radius-lg` | the step is a position in the scale, not the value |
| web-only | a `web` name segment | `--gutter-web`, `--type-web-hero-size` | the app never mirrors it. Every token without `web` is shared and mirrored unless `implementation.md`, "Not mirrored" says why not |

Never encode a value in a name: `--olive-600`, not `--olive-dark`.

## Adding or removing a token

1. Check it is really missing. Most missing values are an existing token at the wrong layer.
2. Add it to `tokens.css` in the matching group, with a comment for the role it plays when that is not obvious.
3. If it is shared, add it to `DesignTokens.swift` or a color set and to the parity table in `scripts/verify-design.sh`. If the app deliberately does not mirror it, add it to `implementation.md`, "Not mirrored".
4. If it is a color, run `scripts/verify-design.sh` and add a row to `principles.md`, "Contrast" (and the script's table) for anything that reads on top of it.
5. A measurement used by one component is a constant in that component, not a token.

A token is live when the app or a site consumes it, or when it is a step in a scale. Scales stay whole (spacing, radius, type, weight, tracking, control height, icon size, icon stroke, glass, Apple's label, fill and background ladders). Any other token with no consumer is dead: delete it everywhere in the same commit.

## Editing

- Cite sections by name (`components.md`, "AcceptGate"), never by line number, and grep the old heading text when renaming one.
- Verified facts name what they were checked against (the Lucide version, the SDK, the tool that computed a ratio), never a date.
- Run `scripts/verify-docs.sh` after editing markdown here, and `scripts/verify-design.sh` after touching a value.
