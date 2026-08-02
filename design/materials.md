# Materials and elevation

How a surface looks and how it sits. What changes over time is `motion.md`.

## Liquid Glass

Three material weights. Each pairs a fill (`colors.md`) with a blur strength and a fixed saturation boost.

| Material | Fill | Blur | Where |
|---|---|---|---|
| thin | `--color-surface-glass-thin` | `--blur-thin` 12px | light overlays, floating chrome |
| regular | `--color-surface-glass` | `--blur-regular` 24px | default panel, glass buttons |
| thick | `--color-surface-glass-thick` | `--blur-thick` 40px | sheet headers, toolbars over content |
| solid | `--color-surface-card` | — | fallback with no translucency |

`--glass-saturate: 180%`.

Web recipe:

```css
background: var(--color-surface-glass);
backdrop-filter: blur(var(--blur-regular)) saturate(var(--glass-saturate));
-webkit-backdrop-filter: blur(var(--blur-regular)) saturate(var(--glass-saturate));
border: 1px solid var(--color-glass-border);
border-radius: var(--radius-lg);
box-shadow: var(--shadow-glass);
```

In SwiftUI this is `.glassEffect()` — do **not** hand-roll `.ultraThinMaterial` + shadow to imitate the CSS. The CSS is the approximation, the native effect is the target. Anything that renders behind glass must have enough contrast on its own; glass is decoration, never the thing carrying legibility.

Glass needs something to blur. On a flat single-color background it reads as a slightly tinted rectangle — that is the expected look on the landing page, so prefer the `solid` material there unless there is real imagery behind.

## Reduced transparency

`prefers-reduced-transparency: reduce` / `.accessibilityReduceTransparency` collapses all three glass materials to `solid`: blur to 0, saturation to 100%, fill to `--color-surface-card`, border to `--color-separator`. `tokens.css` does this at the token level, so a component that consumes `--color-surface-glass` needs no branch of its own.

This is safe precisely because glass is decoration — nothing in the system relies on it for legibility or for state. If a surface stops being readable when it turns solid, the surface was wrong, not the media query.

## Elevation

Geometry is theme-independent; only the shadow colors flip, which is why each token is one declaration with `light-dark()` alphas rather than a pair.

| Token | Geometry | Light α | Dark α |
|---|---|---|---|
| `--shadow-sm` | `0 1px 2px`, `0 1px 1px` | .06, .04 | .40, .30 |
| `--shadow-md` | `0 4px 16px`, `0 1px 3px` | .08, .05 | .50, .40 |
| `--shadow-lg` | `0 12px 40px`, `0 4px 12px` | .14, .08 | .60, .50 |
| `--shadow-glass` | `0 8px 32px` + `inset 0 1px 0 var(--glass-highlight)` | .12 | .55 |
| `--shadow-knob` | `0 3px 8px`, `0 1px 1px` | .15, .16 | .50, .40 |
| `--shadow-focus-ring` | `0 0 0 2px var(--color-surface-base)`, `0 0 0 4px var(--color-accent)` | — | same |

The inset highlight in `--shadow-glass` is the top edge-light that sells the material. Keep it. `--shadow-knob` is the switch knob's, and flips like every other shadow here: the knob is `--paper`, which is black in dark, and a 15%-black shadow under a black knob on a dark track is nothing at all.

Depth ladder: page → card (`sm`/`glass`) → sheet (`lg`). Three levels, no more.

**In dark, height comes from the surface, not the shadow.** The page is black and cards step up to `#1C1C1E`; that tonal step is what reads as elevation. The shadow alphas rise in dark only so an edge stays visible against a black page, never to carry the height on their own. If something looks flat in dark, raise its surface a step or give it a separator. Do not add a shadow, and never add a shadow that exists only in dark.

## Focus

`:focus-visible` clears the native outline and applies `--shadow-focus-ring` — a 4px ring in two 2px bands: `--color-surface-base` inside, `--color-accent` outside. Interactive glass and prominent buttons swap their own shadow for the ring while focused.

**Two bands, not one halo, and never a tint.** Why, and the 1.14:1 measurement that forced it: `colors.md` rule 7.
