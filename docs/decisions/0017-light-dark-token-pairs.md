# 0017. `tokens.css` expresses themes with `light-dark()`

Status: accepted
Date: 2026-07-26

## Context

`design/tokens.css` carried every themed value three times: once in `:root` for light, once under `[data-theme="dark"]`, and once more under `@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) }` so an untouched page follows the OS. The two dark blocks were 57 identical lines that had to be kept in sync by hand, in a file that is already a hand-maintained mirror of the markdown.

That is two drift surfaces stacked on one another, and the file header had to warn about it.

## Decision

Every themed token is one declaration using `light-dark()`, resolved by `color-scheme`:

```css
:root { color-scheme: light dark; --bg-grouped: light-dark(#F2F2F7, #000000); }
[data-theme="light"] { color-scheme: light; }
[data-theme="dark"]  { color-scheme: dark; }
```

`:root` declaring `light dark` is what makes an untouched page follow the OS, so the `prefers-color-scheme` mirror is no longer needed for colour. Both duplicated blocks are gone: 449 lines to 329.

Shadows follow the same shape by giving the dark `--shadow-sm` a second layer it did not previously have, so all six shadow tokens have theme-independent geometry and only their alphas flip. `--shadow-knob` does not flip at all — the switch knob is `--paper` in both themes.

`light-dark()` has been Baseline since May 2024 (Chrome 123, Safari 17.4, Firefox 120).

## Consequences

- One place to change a themed value, and no way for the two dark blocks to disagree, because there are none.
- The theme toggle still wins over the OS in both directions, now through `color-scheme` rather than selector specificity.
- **`light-dark()` only takes colours.** Anything that flips and is not a colour still needs a `prefers-color-scheme` mirror — the landing page's theme-toggle glyph swap is a `display` change and keeps its own media query. Do not assume the pattern generalises.
- Browsers older than the 2024 baseline degrade rather than break, but not gracefully: a custom property holding an unsupported `light-dark()` parses, then makes each *use* of it invalid at computed-value time, so those properties fall back to inherited or initial values. The page stays readable and loses the palette. Accepted for a site whose product ships on iOS 26 / macOS 26; revisit if analytics ever show meaningful pre-2024 traffic.
- Verified after migration by driving the page in a real browser: every semantic alias, both filled-button variants, the trust pill and `--shadow-sm` resolve to the correct value in both themes.
