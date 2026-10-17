# design/

Canonical design system for every CrocApp surface: the SwiftUI apps (iOS, iPadOS, macOS), the landing page, the docs site, and the release artwork (app icon, DMG window, social cards). Every color, size, type style, motion value, component, glyph and word of UI copy is defined here. Nothing visual is invented at a call site.

## Layout

| Path | Owns |
| --- | --- |
| `brand.md` | The brandbook: positioning, voice, logo and mascot, color and type at a glance, imagery, naming, attribution, App Store badges |
| `content.md` | Copy mechanics: capitalization, sentences, errors, numbers, terminology, the approved security claims |
| `colors.md` | Palette, semantic aliases, verified contrast and the seven contrast rules |
| `typography.md` | Font stacks, the app type scale, the web display scale, tracking |
| `spacing-layout.md` | 4pt grid, radii, control sizes, layout caps, web layout, breakpoints, borders |
| `materials.md` | Liquid Glass, reduced transparency, elevation, focus |
| `motion.md` | Easing, durations, phase choreography, haptics, the no-audio rule |
| `components.md` | Every component: which system control it is, or the exact measurements when we draw it |
| `iconography.md` | SF Symbols (app) to Lucide (web) mapping, sizes, stroke weights |
| `accessibility.md` | The binding accessibility floor for all surfaces |
| `platforms.md` | What legitimately differs between iPhone, iPad, macOS and the web |
| `swiftui.md` | Token to SwiftUI translation |
| `web.md` | Token to landing page and docs site translation |
| `tokens.css` | Every token as a CSS custom property |

Topic files define values. `swiftui.md` and `web.md` translate them and never redefine one.

## Skills

Load `apple-design` before any design work (this directory, a view, a stylesheet, artwork), plus `swiftui-expert-skill` and `mobile-ios-design` for SwiftUI views. Install and conflict rules are in the root `AGENTS.md` → Skills. When a skill and this directory disagree, this directory wins: the skills teach springs and overshoot, and `motion.md` rules both out.

## Mirrors and checks

The markdown is canonical. Two hand-written mirrors carry it into code:

| Mirror | Consumed by |
| --- | --- |
| `tokens.css` | landing page, docs site |
| `app/CrocApp/Support/DesignTokens.swift` + `app/CrocApp/Assets.xcassets` color sets | the app |

Change a value in a markdown file and in both mirrors in the same commit. `design/tokens.css` is the only committed CSS copy: `scripts/assemble-site.sh` copies it for the landing page and `web/docs`'s `tokens` npm script for the docs site. Never edit a copy.

Two scripts enforce this directory, and CI runs both on any change to `design/`, `app/` Swift or color sets, or web CSS:

```bash
scripts/verify-contrast.sh   # every ratio colors.md claims, recomputed from tokens.css, plus the seven rules
scripts/verify-design.sh     # mirror parity (tokens.css = DesignTokens.swift = color sets) and the no-literals lint
```

Run them after touching any value. A failure means the change or this directory is wrong; fix one of them, never the check.

## Rules

1. **Tokens, not literals.** No raw hex, px, pt or duration in app or site code. If a value is missing, add the token here first. The few allowed literals are listed in `web.md` and `swiftui.md`.
2. **System first.** Where Apple ships the control (`Toggle`, `Picker`, `Form`, `ProgressView`, toolbars, alerts), the app uses it and this directory only says which one and what to set. We draw a component only when no system control does the job.
3. **SF Symbols only in the app.** Lucide exists only because SF Symbols cannot ship to the web. See `iconography.md`.
4. **System font only.** SF Pro and SF Mono through the system font APIs. Apple's font files are not redistributable; never ship one.
5. **Both themes, always.** Every surface has a light and a dark value: `light-dark()` on web, the asset catalog in the app. The one exception is `components.md` → DiskImage.
6. **Light is the constrained theme.** Check contrast there first. The seven rules in `colors.md` → Contrast bind every surface.
7. **One accent, no gradients in UI.** `brand.md` → Color at a glance.

## Naming

`--<category>-<role>-<modifier>`, lowercase, hyphenated.

| Layer | Pattern | Example | Rule |
| --- | --- | --- | --- |
| base palette | the thing itself | `--green-600`, `--label-2`, `--fill-3` | literal values. **Never consumed by a component**; aliases point at them |
| semantic alias | `--color-<role>` | `--color-accent-text-on-tint` | what it is for, never what it looks like. The layer you consume |
| scale step | category + step | `--space-5`, `--radius-lg` | the step is a position in the scale, not the value |
| web-only | a `web` name segment | `--gutter-web`, `--btn-pad-x-lg-web`, `--type-web-hero-size` | the app never mirrors it. Every token without `web` in its name is shared, and the app mirrors it unless `swiftui.md` → Not mirrored says why not |

Never encode a value in a name (`--green-600`, not `--green-dark`).

## Adding or removing a token

1. **Check it is really missing.** Most missing values are an existing token at the wrong layer.
2. Add it to the topic file that owns it, with the role it plays.
3. Add it to `tokens.css` in the matching group.
4. If it is shared, add it to `DesignTokens.swift` or a color set and to the parity table in `scripts/verify-design.sh`. If the app deliberately does not mirror it, add it to `swiftui.md` → Not mirrored instead.
5. If it is a color, run `scripts/verify-contrast.sh` and add a row to `colors.md` → Contrast for anything that reads on top of it.
6. A component measurement used by one component is a component constant in `components.md`, not a token.

A token is live when the app or a site consumes it, or when it is a step in a scale. **Scales stay whole** (spacing, radius, type, weight, tracking, control height, icon size, icon stroke, glass, Apple's label/fill/background ladders) so nobody reaches for the wrong rung. Any other token with no consumer is dead: delete it from every file in the same commit.

## Editing

- Values are cross-referenced. Changing one means grepping `design/` and both mirrors for it.
- `scripts/build-dmg.sh` takes its geometry from `components.md` → DiskImage; change both together.
- Verified facts carry the date they were checked (contrast ratios, the Lucide version, Apple API names). Re-verifying means moving the date.
- Cite design sections by name (`components.md` → AcceptGate), never by line number. Line numbers rot.
