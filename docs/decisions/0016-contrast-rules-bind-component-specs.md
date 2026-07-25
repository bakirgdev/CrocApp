# 0016. Contrast rules bind the component specs

Status: accepted
Date: 2026-07-26

## Context

ADR 0015 recorded the contrast facts alongside the tokens. `design/colors.md` grew a measured table and a set of rules from it; `design/components.md` was written earlier, from the Claude Design component source, and was never reconciled with them.

An audit on 2026-07-26 recomputed every pair and found ten places where `components.md` specified a foreground its own colour file forbids. The pattern was consistent: a colour that is legal as a **fill** was being used as a **foreground**.

- Accent labelling a button, a paste control or a sheet action: 2.98 – 3.41:1.
- Status colours titling a `StatusBanner`, a `TrustBadge` pill or a tinted destructive button: 1.96 – 2.95:1.
- `--color-text-tertiary` (1.74:1) on disclosure chevrons, remove controls and empty-state glyphs — all things a sighted user must see.

The landing page had already hit each of these while being built and worked around them locally, leaving `styles.css` carrying comments that contradicted `components.md`. The spec was the stale artefact, not the implementation.

## Decision

`colors.md` → Contrast holds six numbered rules. They are binding on the app, the landing page and the docs site, and `components.md` is written to them rather than beside them.

The two that decide most specs:

- **Accent never labels anything.** Icons, fills, borders and progress bars keep `--color-accent` (they owe 3:1 and clear it). Text takes `--color-accent-text` on base/card surfaces and `--color-accent-text-on-tint` everywhere else in light, including `--color-surface-grouped`.
- **A status colour is a fill, never a foreground.** Status text is `--color-text-primary`; the tint and border carry the semantic. Status *glyphs* may stay in the kind colour: they are `aria-hidden` and always redundant with an adjacent label, which makes them decorative.

Two deviations are accepted rather than fixed: filled `prominent` (3.41:1) and `destructive` (3.55:1) buttons clear 3:1 but not 4.5:1, which is what Apple's own filled controls measure. They stay, conditioned on a label that is never smaller than 17px semibold, and on small sizes using a tinted variant instead.

## Consequences

- `components.md` no longer contradicts `colors.md`. A component spec can be implemented literally without re-deriving contrast.
- The restyle inherits the rules: `swiftui-mapping.md` now carries colour sets for `--color-accent-text` and `--color-accent-text-on-tint`, so `Color.accentColor` is a fill in the app exactly as `--color-accent` is on the web.
- Dark theme is unaffected — every accent-text alias collapses to `--green-400` there. This only ever costs anything in light, which is why light is checked first.
- Apple's increased-contrast greens were evaluated as a way to keep status-coloured titles and rejected: `#248A3D` is 3.92:1 on its own tint, still short. There is no status green that can label its own tint, so the rule is uniform across all four kinds rather than per-kind.
