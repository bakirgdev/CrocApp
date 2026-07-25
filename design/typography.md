# Typography

SF Pro for everything; SF Mono for code phrases and text payloads. Names mirror `UIFont.TextStyle` so the app can use `Font.system(.headline)` etc. directly and inherit Dynamic Type.

## Families

```css
--font-sans: -apple-system, BlinkMacSystemFont, "SF Pro Text", "SF Pro Display",
             "Helvetica Neue", "Segoe UI", system-ui, sans-serif;
--font-mono: ui-monospace, "SF Mono", "SFMono-Regular", Menlo, Monaco,
             "Cascadia Mono", "Roboto Mono", monospace;
```

**Do not ship font files.** SF Pro and SF Mono are Apple system fonts and are not redistributable. On Apple hardware the stacks above resolve to real San Francisco; elsewhere they fall through to the platform UI / mono font. The Claude Design project self-hosts SF Pro Text OTFs so its canvas renders correctly — that is a preview artifact, not something to copy into `web/`.

Cascadia Mono sits in the mono fallback as a nice non-Apple monospace (SIL OFL 1.1, redistributable) but is not bundled here either; it only matches if the visitor already has it.

## Weights

| Token | Value |
|---|---|
| `--weight-regular` | 400 |
| `--weight-medium` | 500 |
| `--weight-semibold` | 600 |
| `--weight-bold` | 700 |

## Scale

Size / line-height / default weight, in px (= pt on Apple platforms at 1×).

| Token prefix | Size | Line-height | Weight | Used for |
|---|---|---|---|---|
| `--type-large-title` | 34 | 41 | 700 | screen hero titles |
| `--type-title1` | 28 | 34 | 700 | |
| `--type-title2` | 22 | 28 | 700 | sheet / section heroes |
| `--type-title3` | 20 | 25 | 600 | StatusBlock result title |
| `--type-headline` | 17 | 22 | 600 | button labels, sheet title, row emphasis |
| `--type-body` | 17 | 22 | 400 | settings row title, default body |
| `--type-callout` | 16 | 21 | 400 | file names, medium buttons, detail lines |
| `--type-subhead` | 15 | 20 | 400 | descriptions, segment labels, badge label |
| `--type-footnote` | 13 | 18 | 400 | secondary captions, small buttons, banner body |
| `--type-caption1` | 12 | 16 | 400 | progress captions |
| `--type-caption2` | 11 | 13 | 400 | densest metadata |

Each has three custom properties: `--type-<name>-size`, `-lh`, `-weight`.

## Mono display sizes

| Token | Size | Line-height | Used for |
|---|---|---|---|
| `--type-code-hero` | 30 | 38 | the sender's code phrase (bold, `user-select: all`) |
| `--type-code-body` | 15 | 22 | code input field, text payloads |

## Web display scale (landing + docs only)

Never used by the app. The app scale stops at 34px because that is a phone screen title; a landing hero on a 27" display needs more. Fluid, so the page reads the same at 375px and 1440px. Line-heights are unitless ratios, not px.

| Token prefix | Size | Line-height | Weight | Tracking | Used for |
|---|---|---|---|---|---|
| `--type-web-hero` | `clamp(40px, 6.2vw, 68px)` | 1.06 | 700 | `--tracking-web-hero` `-1.5px` | the one H1 |
| `--type-web-section` | `clamp(28px, 3.6vw, 40px)` | 1.15 | 700 | `--tracking-web-section` `-0.6px` | section H2 |
| `--type-web-sub` | `clamp(20px, 2.4vw, 26px)` | 1.3 | 600 | `--tracking-web-section` | H3 / card title |
| `--type-web-lead` | `clamp(17px, 1.6vw, 21px)` | 1.5 | 400 | `--tracking-web-lead` `-0.2px` | hero deck, section intro |

Body copy below lead size stays on the app scale (`--type-body` and down) — the two scales meet there deliberately, so a web page and an app screen read as the same voice.

Helper classes: `.t-web-hero` `.t-web-section` `.t-web-sub` `.t-web-lead`. These are written longhand in `tokens.css` rather than with the `font:` shorthand, because the shorthand's `size/line-height` slot does not reliably survive a `clamp()` substituted through `var()`.

Numeric readouts (sizes, speeds, progress counters, clock) use tabular figures: `font-variant-numeric: tabular-nums` on web, `.monospacedDigit()` in SwiftUI. Never let a live speed counter reflow.

## Tracking

SF tightens optically at large sizes; these mirror Apple's metrics.

| Token | Value |
|---|---|
| `--tracking-large-title` | `0.37px` |
| `--tracking-title2` | `0.35px` |
| `--tracking-headline` | `-0.43px` |
| `--tracking-body` | `-0.41px` |
| `--tracking-caption` | `0px` |
| `--tracking-code` | `0.5px` |
| `--tracking-eyebrow` | `0.6px` |

`--tracking-eyebrow` is the uppercase footnote label above a code phrase ("READY TO SEND", `components.md` → CodePhraseDisplay). Uppercase needs the extra letter-spacing that lowercase does not.

Positive tracking on the code phrase is deliberate: it separates the `NNNN-word-word-word` groups so a phrase can be read aloud or transcribed without ambiguity.

## Convenience classes (web)

Tokens are the source of truth; these are shorthands defined in `tokens.css`:

`.t-large-title` `.t-title2` `.t-title3` `.t-headline` `.t-body` `.t-callout` `.t-footnote` `.t-caption` `.t-code`

## Rules

- Uppercase only for the small eyebrow label above the code phrase (`--type-footnote`, weight 600, `letter-spacing: 0.6px`). Nowhere else.
- No serif, anywhere. If a Claude Design render drifts into a serif or a teal gradient, it has left the system.
- Line length capped by `--content-max-width` (480px) in the app, `--content-max-width-prose` (680px) on web — not by a character count.
- In the app, respect Dynamic Type — use text styles, never a hardcoded point size, and verify at the largest accessibility size.
