# CrocApp design system

Single source of truth for CrocApp's visual language: the SwiftUI app (iOS 26 / macOS 26), the landing page, and the docs site.

These files are the **canonical, human-readable token set**. `tokens.css` is a convenience mirror for web consumers — if you change a value in a markdown file, change it in `tokens.css` too (and vice versa). Nothing generates one from the other.

## Files

| File | Contents |
|---|---|
| `colors.md` | Brand green scale, Apple system semantics, light/dark themes, contrast data |
| `typography.md` | Font stacks, iOS type scale, mono code sizes, tracking |
| `spacing-layout.md` | 4pt grid, concentric radii, control sizing, layout caps, borders |
| `materials-motion.md` | Liquid Glass materials, elevation/shadows, easing, durations, focus ring |
| `components.md` | Every component's measurements, variants and states |
| `iconography.md` | SF Symbols (app) ↔ Lucide (web) mapping, sizes, stroke weights |
| `brand.md` | Voice, accent usage, mascot/banner/icon assets, do-not list |
| `swiftui-mapping.md` | Token → SwiftUI/Apple API translation for the app restyle |
| `tokens.css` | All CSS custom properties in one file, for web |

## Provenance

Generated in [Claude Design](https://claude.ai/design) project **CrocApp** (`1134b33b-a4d8-41df-b68c-9fe634f5eccb`), design system `crocapp-design-system-da946140-1515-4920-b169-b09b2be383d4`. Extracted to this repo 2026-07-25. Workflow and prompts: `docs/knowledge/claude-design-workflow.md`. Decision to adopt: ADR 0015.

The design project also holds 26 screen files (iPhone + macOS, all transfer phases). Those are visual spec, not code to port — read them for layout intent, implement natively.

## Binding rules

1. **SF Symbols only in the app.** Lucide glyphs exist purely because SF Symbols cannot ship to the web. Never bundle Lucide, never draw a custom glyph where an SF Symbol exists. See `iconography.md`.
2. **System font only.** SF Pro / SF Mono via the system font APIs (`Font.system`, `-apple-system`). Do not self-host or bundle Apple font files — they are not redistributable. Off-Apple browsers fall through the stack in `typography.md`.
3. **Tokens, not literals.** No raw hex, px, or duration in app or site code. If a value is missing, add a token here first.
4. **Both themes, always.** Every surface has a light and a dark value. On web, dark is opt-in via `[data-theme="dark"]` plus a `prefers-color-scheme` mirror; in SwiftUI it is automatic through the asset catalog / `Color` semantics.
5. **Liquid Glass is native.** In SwiftUI use `.glassEffect()`; the CSS `backdrop-filter` recipe is a web approximation only, and the design project's renders are likewise approximations.

## Accessibility floor

- Body text ≥ 4.5:1, large text and UI component boundaries ≥ 3:1 (WCAG 2.2 AA).
- The brand accent `#1E9E6A` hits only **3.41:1** on white. It is safe for fills, icons, borders and large text — **not** for small body copy on light backgrounds. Use `--green-700` (`#178055`, 4.94:1) for links and small accent text in the light theme. Full table in `colors.md`.
- Minimum hit target 44×44pt (`--hit-target-min`).
- Never encode transfer direction (sending vs receiving) in color alone — the arrow glyph and the word carry it. See `components.md` → TransferProgress.
- Respect `prefers-reduced-motion` / `.accessibilityReduceMotion`: drop the press-scale and the indeterminate shimmer, keep the state change.
