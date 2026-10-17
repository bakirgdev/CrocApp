# Materials and elevation

How a surface looks and how it sits. What changes over time is `motion.md`.

## Liquid Glass

In the app, glass is `.glassEffect()` and nothing else (`swiftui.md` → Materials). Never hand-roll `.ultraThinMaterial` plus a shadow to imitate the CSS: the native effect is the target and the CSS is the approximation.

The web approximation has three weights. Each pairs a fill (`colors.md` → Glass fills) with a blur and a fixed saturation boost:

| Material | Fill | Blur | Where |
|---|---|---|---|
| thin | `--color-surface-glass-thin` | `--blur-thin` 12px | floating chrome |
| regular | `--color-surface-glass` | `--blur-regular` 24px | the sticky nav, glass buttons |
| thick | `--color-surface-glass-thick` | `--blur-thick` 40px | bars over content |
| solid | `--color-surface-card` | none | the default on a flat page |

`--glass-saturate: 180%`.

```css
background: var(--color-surface-glass);
backdrop-filter: blur(var(--blur-regular)) saturate(var(--glass-saturate));
-webkit-backdrop-filter: blur(var(--blur-regular)) saturate(var(--glass-saturate));
border: var(--border-hairline) solid var(--color-glass-border);
box-shadow: var(--shadow-glass);
```

Glass needs something to blur. On a flat single-color page it reads as a tinted rectangle, so the web uses `solid` unless real content scrolls behind. Anything on glass must be legible on its own: glass is decoration, never the thing carrying legibility.

## Reduced transparency

`prefers-reduced-transparency: reduce` and `.accessibilityReduceTransparency` collapse every glass material to `solid`: blur 0, saturation 100%, fill `--color-surface-card`, border `--color-separator`. `tokens.css` does this at the token level, so a component consuming `--color-surface-glass` needs no branch of its own; `.glassEffect()` does it natively.

This is safe because nothing relies on glass for legibility or state. If a surface stops being readable when it turns solid, the surface was wrong.

## Elevation

Geometry is theme-independent; only the shadow alphas flip, which is why each token is one declaration with `light-dark()` alphas.

| Token | Geometry | Light α | Dark α |
|---|---|---|---|
| `--shadow-sm` | `0 1px 2px`, `0 1px 1px` | .06, .04 | .40, .30 |
| `--shadow-md` | `0 4px 16px`, `0 1px 3px` | .08, .05 | .50, .40 |
| `--shadow-lg` | `0 12px 40px`, `0 4px 12px` | .14, .08 | .60, .50 |
| `--shadow-glass` | `0 8px 32px` + `inset 0 1px 0 var(--glass-highlight)` | .12 | .55 |
| `--shadow-focus-ring` | `0 0 0 2px var(--color-surface-base)`, `0 0 0 4px var(--color-accent)` | n/a | n/a |

The inset highlight in `--shadow-glass` is the top edge-light that sells the material; keep it.

Depth ladder: page, then card (`sm` or `glass`), then sheet (`lg`). Three levels, no more. System controls and sheets in the app carry their own depth; the app adds a shadow only where it draws the surface itself (the QR frame takes `--shadow-md`).

**In dark, height comes from the surface, not the shadow.** The page is black and cards step up to `#1C1C1E`; that tonal step reads as elevation. The dark alphas rise only so an edge stays visible against black. If something looks flat in dark, raise its surface a step or give it a separator; never add a shadow that exists only in dark.

## Focus

On web, `:focus-visible` replaces the native outline with `--shadow-focus-ring`: two 2px bands, `--color-surface-base` inside and `--color-accent` outside, so one band always has a 3.41:1 edge against whatever it surrounds (`colors.md` rule 7). A focused element swaps its own shadow for the ring. A transparent `outline` stays underneath so forced-colors mode, which drops box shadows, still draws an indicator.

In the app the system draws focus (`swiftui.md` → Focus). Never remove a focus indicator without replacing it.
