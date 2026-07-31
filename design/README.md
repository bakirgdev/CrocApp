# CrocApp design system

Single source of truth for CrocApp's visual language: the SwiftUI app (iOS 26 / macOS 26), the landing page, and the docs site.

These files are the **canonical, human-readable token set**. `tokens.css` is a convenience mirror for web consumers — if you change a value in a markdown file, change it in `tokens.css` too (and vice versa). Nothing generates one from the other.

`design/tokens.css` is the only copy. `web/landing/tokens.css` is gitignored and copied in: by `.github/workflows/github-pages.yml` at deploy, and by hand for local preview (`cp design/tokens.css web/landing/ && python3 -m http.server --directory web/landing`).

## Files

| File | Contents |
|---|---|
| `colors.md` | Brand green scale, Apple system semantics, light/dark themes, contrast data |
| `typography.md` | Font stacks, iOS type scale, mono code sizes, tracking |
| `spacing-layout.md` | 4pt grid, concentric radii, control sizing, layout caps, borders |
| `materials-motion.md` | Liquid Glass materials, elevation/shadows, easing, durations, focus ring |
| `components.md` | Every component's measurements, variants and states |
| `iconography.md` | SF Symbols (app) ↔ Lucide (web) mapping, sizes, stroke weights |
| `brand.md` | Voice, accent usage, mascot/banner/icon assets, web surfaces, do-not list |
| `swiftui-mapping.md` | Token → SwiftUI/Apple API translation for the app restyle |
| `tokens.css` | All CSS custom properties in one file, for web |

## Provenance

Generated in Claude Design and extracted here on 2026-07-25 (ADR 0015). That project is gone — this directory is the whole design system now, and nothing outside the repo needs consulting.

## Binding rules

1. **SF Symbols only in the app.** Lucide glyphs exist purely because SF Symbols cannot ship to the web. Never bundle Lucide, never draw a custom glyph where an SF Symbol exists. See `iconography.md`.
2. **System font only.** SF Pro / SF Mono via the system font APIs (`Font.system`, `-apple-system`). Do not self-host or bundle Apple font files — they are not redistributable. Off-Apple browsers fall through the stack in `typography.md`.
3. **Tokens, not literals.** No raw hex, px, or duration in app or site code. If a value is missing, add a token here first.
4. **Both themes, always.** Every surface has a light and a dark value. On web, dark is opt-in via `[data-theme="dark"]` plus a `prefers-color-scheme` mirror; in SwiftUI it is automatic through the asset catalog / `Color` semantics.
5. **Liquid Glass is native.** In SwiftUI use `.glassEffect()`; the CSS `backdrop-filter` recipe is a web approximation only, and the design project's renders are likewise approximations.

## Accessibility floor

- Body text ≥ 4.5:1, large text and UI component boundaries ≥ 3:1 (WCAG 2.2 AA).
- The brand accent `#1E9E6A` is **3.41:1** on white: safe for fills, icons, borders and large text, never for a word. Accent text is `--color-accent-text`, or `--color-accent-text-on-tint` on grouped and tinted surfaces.
- A status color is a fill, never a foreground. Status text is `--color-text-primary`.
- Minimum hit target 44×44pt (`--hit-target-min`).
- Never encode transfer direction (sending vs receiving) in color alone — the arrow glyph and the word carry it. See `components.md` → TransferProgress.
- Respect `prefers-reduced-motion` / `.accessibilityReduceMotion`: drop the press-scale and the indeterminate shimmer, keep the state change.
- Respect `prefers-reduced-transparency` / `.accessibilityReduceTransparency`: glass collapses to the solid card fill.

The six numbered rules in `colors.md` → Contrast are binding on all three surfaces. `components.md` is written to them.
