# design/

Canonical design system for every CrocApp surface: the SwiftUI apps (iOS / macOS / iPadOS), the landing page, and the docs site. Every color, size, type style, motion value and component measurement in the project is defined here. Nothing visual is invented at a call site.

## Layout

| Path | Purpose |
| --- | --- |
| `colors.md` | Brand green scale, Apple system semantics, semantic aliases, verified contrast, the seven contrast rules |
| `typography.md` | Font stacks, app type scale, web display scale, mono sizes, tracking |
| `spacing-layout.md` | 4pt grid, concentric radii, control sizing, layout caps, breakpoints, borders |
| `materials.md` | Liquid Glass materials, reduced transparency, elevation, focus ring |
| `motion.md` | Easing, durations, phase choreography, haptics, the no-audio rule |
| `components.md` | Every component's exact measurements, variants and states |
| `iconography.md` | SF Symbols (app) ↔ Lucide (web) mapping, sizes, stroke weights |
| `accessibility.md` | The binding accessibility floor for all three surfaces |
| `content.md` | Capitalization, sentences, errors, number and date formatting, terminology |
| `brand.md` | Voice, accent usage, naming, asset inventory |
| `platforms.md` | What legitimately differs between iPhone, iPad and macOS |
| `swiftui.md` | Token → SwiftUI / Apple API translation |
| `web.md` | Token → landing page / docs site translation |
| `tokens.css` | Every token as a CSS custom property, for web |

Topic files define values. `swiftui.md` and `web.md` are the two platform files — they translate, never redefine.

`scripts/verify-contrast.py` recomputes every ratio `colors.md` claims, straight from `tokens.css`, and asserts the seven rules as invariants. Run it after touching any color.

## Three mirrors, hand-synced

The markdown files are canonical. Both mirrors are written by hand and nothing generates either:

| Mirror | Consumed by |
| --- | --- |
| `tokens.css` | landing page, docs site |
| `app/CrocApp/Support/DesignTokens.swift` + `app/CrocApp/Assets.xcassets` | the app |

Change a value in a markdown file and change it in both mirrors in the same commit, or they drift silently.

`design/tokens.css` is the only committed copy. The web copies are gitignored and written by tooling — `scripts/assemble-site.sh` for the landing page, `web/docs`'s `tokens` npm script for the docs site. Never edit a copy.

## Rules

1. **Tokens, not literals.** No raw hex, px, pt or duration in app or site code. If a value is missing, add the token here first.
2. **SF Symbols only in SwiftUI apps.** Lucide exists purely because SF Symbols cannot ship to the web. Never bundle Lucide, never draw a custom glyph where a symbol exists. See `iconography.md`.
3. **System font only.** SF Pro / SF Mono through the system font APIs. Apple's font files are not redistributable — never ship one.
4. **Both themes, always.** Every surface has a light and a dark value: `light-dark()` on web, the asset catalog in SwiftUI. One exception, `components.md` → DiskImage, because Finder cannot swap a DMG background.
5. **Liquid Glass is native.** `.glassEffect()` is the target; the CSS `backdrop-filter` recipe approximates it, never the reverse.
6. **Light is the constrained theme.** Check contrast there first — dark clears everything. The seven rules in `colors.md` → Contrast bind all three surfaces, and `components.md` is written to them.

## Naming

`--<category>-<role>-<modifier>`, all lowercase, hyphenated, no abbreviations that are not already in the table below.

| Layer | Prefix | Example | Rule |
| --- | --- | --- | --- |
| base palette | the thing itself | `--green-600`, `--label-2`, `--fill-3` | literal values, numeric steps, **never consumed directly by a component** |
| semantic alias | `--color-` | `--color-accent-text-on-tint` | what it is *for*, never what it looks like. This is the layer you consume |
| scale step | category + integer | `--space-5`, `--radius-lg` | the number means position in the scale, not the value |
| platform-scoped | `-web` suffix | `--content-max-width-web` | web-only; an unsuffixed token is shared |

Never encode a value in a name (`--green-600`, not `--green-dark`), never encode a component in a shared token (`--btn-*` and `--pill-*` are the documented exception, and they are web-only).

## Adding a token

1. **Check it is really missing.** Most "missing" values are an existing token used at the wrong layer.
2. Add it to the topic file that owns it, with the role it plays, not just the number.
3. Add it to `tokens.css` in the matching group.
4. Add it to `swiftui.md`, and to `DesignTokens.swift` or a color set if the app needs it. If the app deliberately does not need it, say so in `swiftui.md` rather than leaving a hole.
5. If it is a color, run `scripts/verify-contrast.py`, and add a row to `colors.md` → Contrast if anything reads on top of it.
6. If it is a component measurement, it probably is not a token: `components.md` keeps those as component constants.

## Reserved tokens

Some tokens have no consumer and are still correct to keep. They exist so the app stays visually native, or so a scale is complete:

| Token | Why it stays |
| --- | --- |
| `--bg-secondary`, `--bg-tertiary`, `--fill-4`, `--separator-opaque`, `--color-text-quaternary`, `--color-fill-secondary` | Apple semantics. The ladder has to be complete or a view reaches for the wrong rung |
| `--type-title1`, `--type-caption2` | the app scale is `Font.TextStyle` and must stay whole |
| `--ink` | the source of truth for the `<meta name="theme-color">` literals, which cannot take a `var()` |

Anything not on that list and not in use is dead. `--green-50`, `--green-100`, `--ease-spring` and `--tracking-caption` were cut for exactly that reason.

## Editing

- Values are cross-referenced heavily. Changing one means grepping `design/` for it, plus both mirrors.
- Measurements in `components.md` are exact, not approximate. `scripts/build-dmg.sh` takes its geometry from that file's DiskImage section; changing one without the other leaves the file lying.
- If a screen needs a glyph, a size or a state that is not here, add the row before writing the code.
- Verified numbers carry the date they were checked (contrast ratios, the Lucide version, the iOS 26 APIs). Re-verifying means moving the date.
