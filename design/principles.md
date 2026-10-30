# Principles

The rules behind every CrocApp surface: the SwiftUI apps (iOS, iPadOS, macOS), the landing page, the docs site and the release artwork. They follow current Apple practice (the iOS and macOS 26 SDKs, Liquid Glass, Dynamic Type, system semantic colors) and ask for judgment, not pixel matching. Values live in `tokens.css`; how they reach SwiftUI and CSS is `implementation.md`.

Most of the product is text and one progress bar. A wrong byte count is more visible than a wrong shadow.

## Color

The brand palette comes from the mascot (`assets/mascot.png`): **olive** is the brand color, **khaki** the second color (the mascot's belly), and dark olive the ink. Status colors are Apple's system semantics, not brand colors: never repaint success green to match the accent, because the difference is the point. Everything else is Apple's neutral ladder.

- **Consume aliases.** The base palette (`--olive-*`, `--khaki-*`, `--sys-*`, `--label-*`, `--fill-*`, `--bg-*`) holds literals; components take the `--color-<role>` aliases, which swap steps per theme.
- **Both themes, always.** Every surface has a light and a dark value (`light-dark()` on web, the asset catalog in the app). Light is the constrained theme: check contrast there first.
- **Prefer the system.** Where an Apple semantic color passes contrast on its surface, use it. A custom color set exists only where no semantic does the job (the accent family, secondary text, status tints).
- **Accent is for primary actions, selection, links, file-type glyphs and progress.** It does not wash large areas. Khaki is a supporting hue for the mascot, the icon and illustration, and stays out of controls.
- **Status colors fill, they do not label.** A tint and a glyph carry the kind; the words stay primary text.
- **Color is never the only signal.** Direction is an arrow and the word "Sending" or "Receiving", every status is stated in words, and a glyph that alone carries a status has an accessibility label.

Gradients and translucency are welcome where the platform uses them: the app icon and Liquid Glass are built from them. They decorate, and legibility never depends on them.

## Contrast

WCAG 2.2 AA is the floor: 4.5:1 for body text, 3:1 for large text and for UI boundaries and glyphs. Large text is 24px or more, or 18.66px or more at weight 700. `scripts/verify-design.sh` recomputes every ratio below from `tokens.css`, asserts the guidance as invariants and fails when the table here drifts from the tokens. Light, then dark:

| Pair (light) | Ratio | Reads as |
|---|---|---|
| `--color-accent` on base / grouped / its own tint | 4.06 / 3.63 / 3.54 | fills, glyphs, large text |
| `--color-accent-text` on base / card | 5.84 / 5.84 | AA body |
| `--color-accent-text` on grouped / accent tint / fill-tertiary wash | 5.23 / 5.09 / 5.06 | AA body |
| `--color-accent-text-on-tint` on base / grouped / accent tint / fill wash | 7.54 / 6.76 / 6.58 / 6.54 | stronger AA body |
| `--label-2` on base / grouped | 3.44 / 3.30 | glyphs and large text only (Apple's secondaryLabel) |
| `--label-2-text` on base / grouped | 5.63 / 5.26 | AA body |
| `--color-text-secondary` on accent tint / fill wash over grouped / error tint over grouped | 5.17 / 4.83 / 4.70 | AA body; the error tint is the weakest of the status tints |
| `--label-3` on base | 1.73 | decorative only |
| `--color-on-accent` on `--color-accent-solid` / `--color-accent-pressed` | 5.84 / 7.54 | AA body |
| `--color-on-status` on `--color-status-error` | 3.55 | filled destructive, see below |
| `--color-status-success` / `-warning` / `-error` on its own tint | 1.98 / 1.96 / 2.94 | fill only |
| `--color-status-success` / `-warning` / `-error` / `-info` on base | 2.22 / 2.20 / 3.55 / 4.02 | fill and glyph only |
| `--glass-tint-accent` composited on base | 1.14 | not a focus indicator |

| Pair (dark) | Ratio | Reads as |
|---|---|---|
| `--color-accent` on base / card / its own tint | 9.62 / 7.80 / 7.81 | AA body, so the accent aliases collapse to one step |
| `--color-on-accent` on `--color-accent-solid` / `--color-accent-pressed` | 5.99 / 7.13 | AA body |
| `--color-on-status` on `--color-status-error` | 3.41 | filled destructive, see below |
| `--label-2` on base | 6.36 | AA body |
| `--color-text-secondary` on a card / on a success tint over a card | 5.95 / 4.74 | AA body; the success tint is its weakest dark surface |
| status success / warning / error / info on its own tint | 8.05 / 7.93 / 5.25 / 4.92 | AA body |

### Contrast guidance

1. **Accent text is not accent fill.** Icons, fills, borders and progress bars take `--color-accent` and owe 3:1. Anything with a letter in it takes `--color-accent-text`, which clears 4.5:1 on every light surface. `--color-accent-text-on-tint` is optional and stronger: reach for it on a tinted wash when you want more margin. In the app that includes the label of a bordered or plain button, which would otherwise inherit the 4.06:1 tint.
2. **A status color is a fill, not a foreground.** In light it fails on its own tint and three of four fail on base. Status text (banner titles, trust-badge labels, destructive labels) is `--color-text-primary`; the tint and border carry the kind. Status glyphs may keep the kind color because an adjacent label always repeats them. Do not tint body copy.
3. **A filled prominent button uses `--color-accent-solid`**, the step white clears AA on (5.84 light), and presses to `--color-accent-pressed`. Dark keeps the accent. The filled destructive button ships at 3.55 light and 3.41 dark, the one accepted deviation: the system has one error red, and forking it for one control would split the status color from every glyph, tint and border that shares it. It holds only while the label stays at least 17px semibold, small sizes use a tinted destructive button, and filled destructive is limited to Decline and confirming Clear History.
4. **Secondary text is `--color-text-secondary`, never Apple's `.secondary`.** `--color-text-secondary` resolves to `--label-2-text` (0.78 alpha in light, the system's 0.60 in dark) and clears 4.5:1 on every surface that carries it. `.secondary` and `.tertiary` are for glyphs and large text. Text we write inside a system control (a Form footer, an empty-state description) takes the token explicitly; text the system draws itself (a placeholder, a picker value) keeps Apple's.
5. **`--color-text-tertiary` is neither text nor a UI boundary.** At 1.73:1 it is decorative. Anything a sighted user must see (disclosure chevrons, remove controls, empty-state glyphs) takes secondary or better.
6. **Links are `--color-accent-text`**, never the plain accent.
7. **The focus ring owes 3:1.** On web it is two 2px bands, `--color-surface-base` inside and `--color-accent` outside, so one band always has a 3:1 edge against whatever it surrounds. A tint cannot do this job: at 1.14:1 it leaves the ring invisible.

## Type

SF Pro for everything and SF Mono for code phrases and text payloads, through the system font APIs. **Never ship a font file**: Apple's fonts are not redistributable. On Apple hardware the web stacks in `tokens.css` resolve to real San Francisco and elsewhere fall through to the platform fonts.

- **The app scale is Apple's text styles** (`.largeTitle` through `.caption2`), so Dynamic Type works everywhere. Never a fixed point size for text. `tokens.css` mirrors the scale for the web, where it meets a separate fluid display scale (`--type-web-*`) for hero and section headings. Body copy and below stay on the shared scale, so a web page and an app screen read as one voice.
- **The code phrase is always mono**, lowercase, with positive tracking so the `word-word-word` groups stay separable when read aloud. It wraps only between words.
- **Numbers that change are tabular** (`font-variant-numeric: tabular-nums`, `.monospacedDigit()`), so a live speed never reflows.
- **Uppercase is rare.** Only the eyebrow above the code phrase uses it, with extra tracking.
- **Line length** follows the content column (`--content-max-width` in the app, `--content-max-width-prose-web` on web), not a character count.
- **Tracking** follows Apple's optical metrics at large sizes and is absent at caption sizes and below. In SwiftUI do not fight a text style's own tracking.

## Spacing and layout

A 4pt grid: every gap, pad and inset resolves to a `--space-*` step, and in SwiftUI a bare `.padding()` is the system default, so write the step. Components take their sizes from the system first (`.controlSize`, the grouped `Form`), and the scale second.

- **Content column.** The app's content is capped at `--content-max-width` on every device. Extra width becomes margin, never wider text. In compact width the cap sits on the screen's content; in regular width on each detail screen's content, never on the split view, sidebar or toolbar.
- **Web layout** uses its own caps and fluid rhythm (`--content-max-width-*-web`, `--gutter-web`, `--section-pad-web`), in `clamp()` with both ends on the grid. Breakpoints are literals in `rem`, because a custom property does not resolve inside a media condition. Keep them few, and add one only for a layout change you can name.
- **Hit targets** are at least `--hit-target-min` (44pt) for anything interactive. A system control that sets its own size (`PasteButton`) is checked with Accessibility Inspector.
- **Logical properties on web** (`padding-inline`, `inset-inline-start`), and leading and trailing, never left and right, in specs. An RTL locale is a `dir="rtl"` away.
- **Hierarchy comes from the system.** Page (`--color-surface-grouped`), then cards and grouped lists, then controls. On web the page is `--color-surface-base`, because links read at 5.84 there and a web page runs links through prose.

## Shape

Corners are continuous (`style: .continuous`, `.rect(cornerRadius:style:)`). A circular corner visibly mismatches system chrome.

- **Concentric corners.** Outer radius is inner radius plus the gap between them, as in iOS 26. A card padded 12 around children rounds them to the nearest smaller step (`--radius-xs` or `--radius-sm`) rather than inventing a value. Prefer the system's concentric shapes where SwiftUI offers them.
- **Capsules** for buttons, badges and progress bars; `--radius-md` and up for fields, banners and cards.
- **Borders** are hairlines. Focus is a ring, never a border.

## Materials and Liquid Glass

Glass is for the navigation and control layer that floats above content: toolbars, bars, floating buttons, the code card and the drop overlay. Content itself (lists, forms, cards on a page) is not glass.

- **In the app, use `.glassEffect(_:in:)` and nothing else.** Several glass surfaces that sit together share a `GlassEffectContainer`, so they render and morph as one. Never hand-roll a material plus a shadow to imitate it, and never put glass on glass.
- **The web approximates glass** with a translucent fill, backdrop blur and a saturation boost (`--glass-*`, `--blur-*`, `--shadow-glass`). Glass needs something to blur: on a flat page it reads as a tinted rectangle, so web uses solid fills except for the sticky nav, which has content scrolling under it.
- **Legibility never depends on glass.** If a surface stops reading when it turns solid, the surface was wrong. Reduced transparency (`prefers-reduced-transparency`, `.accessibilityReduceTransparency`) collapses glass to a solid card; `tokens.css` does it at the token level and `.glassEffect()` does it natively.
- **Elevation.** Depth runs page, then card, then sheet. System controls and sheets carry their own depth; the app adds a shadow only to a surface it draws itself. In dark, height comes from the surface step (black page, lighter cards), not from a shadow: if something looks flat in dark, raise its surface or add a separator.

## Motion

The app follows the system's animations, springs included. Motion should be calm, interruptible and never gratuitous: a transfer screen that performs is a transfer screen you do not trust.

- **Motion explains a change and is never the only signal.** The Copy button already says "Copied", the number is already the new number, the banner is already there. Reduce Motion removes the movement and keeps every change.
- **A transfer is a phase machine** (`idle`, `starting`, `waiting` or `connecting`, `confirmSend` or `incoming`, `transferring`, then `done`, `failed` or `stored`). The phase container cross-fades as one block; its contents do not animate in separately.
- **What persists must not move.** The direction header, trust badge and code phrase keep their position across phases, because the code phrase is what the user reads aloud.
- **Terminal phases arrive; they do not celebrate.** No confetti, pop or spin on done or failed.
- **Progress never moves backwards.** If a total revises downward, snap and keep moving forward. A readout that changes faster than once a second shows a new value at most once a second.
- **Loops are rare.** The one pulse on the direction glyph while the sender waits is allowed because it says the app is alive. Decoration does not loop.
- **Reduce Motion.** Under `prefers-reduced-motion` and `.accessibilityReduceMotion`, drop press scale, slides, symbol effects and pulses, and let state changes happen instantly. In SwiftUI pass `nil` instead of an animation, and `.contentTransition(.identity)` for content transitions.
- **Web press feedback** is a slight scale and the pressed background; the app takes press feedback from the system button styles.

## Haptics

iPhone only: iPad's are inconsistent across models and macOS has none. Haptics are additive: every event is also visible and announced, and nothing relies on them. Use the system semantics through `.sensoryFeedback`: `.success`, `.warning` and `.error` for what happens to a transfer (completed, a request needing an answer, failed or declined), `.selection` for a value captured (a copy, a scan). Do not fire on progress, ordinary taps or navigation, and not for an action the user took that ended silently (a Cancel or Decline). The **Haptics** setting (iPhone, on by default) turns them all off, and the system's own setting is respected.

## Accessibility

WCAG 2.2 AA is the floor on every surface; nothing in `components.md` is specced below it.

- **Contrast** per the section above.
- **Focus.** Every interactive element shows a visible indicator that owes 3:1. Web uses `--shadow-focus-ring` on `:focus-visible` with a transparent outline underneath so forced-colors mode still draws one; the app uses the system's. Never remove an indicator without replacing it.
- **Dynamic Type.** Text styles, never a fixed size; glyph sizes through text styles or `@ScaledMetric`. Check the largest accessibility size: nothing clips, and glyph frames take minimum widths. At those sizes a glyph moves above its text.
- **Hit targets** per Spacing and layout.
- **Labels.** Web glyphs are `aria-hidden` and the adjacent label carries the meaning. A glyph that alone carries a status has an accessibility label.
- **Nothing is hover-only.** Hover (macOS, iPad pointer, web) may restate and may apply the pressed background, never reveal. On web wrap it in `@media (hover: hover)` so a tap never leaves it stuck.
- **Input is never drag-only.** Every drop target ships beside a real file-picker button.
- **Announcements.** Errors and terminal failures are announced to VoiceOver, progress is not announced on every tick, a sidebar row's state is announced once per phase change, and a copy or scan announces "Copied", "Code scanned" or "Link scanned".

## Platform adaptation

Density, chrome and input change between devices; the screens, tokens and wording do not. A screen that needs a different component on macOS was designed wrong on iPhone.

- **Adapt by width class, never by device.** Compact width (iPhone, iPad Slide Over, a narrow Split View) is Home and one `NavigationStack`. Regular width (a wide iPad window, every Mac window) is a `NavigationSplitView` with the system's sidebar. The layout changes live as a window resizes. Behavior and wiring: `docs/knowledge/app-ui-architecture.md`, "Layout by width".
- **The system owns sidebars, toolbars and sheets.** We draw nothing on a sidebar, and the transfer state beside a row is words first.
- **Mac.** Menu bar commands give every toolbar action a shortcut, right-click menus are additive, drop is window-wide, and there is no camera or QR scan (absent, not disabled). iPad reaches the same commands through the hardware-keyboard menu.
- **Web** has a pointer and a keyboard, follows the OS theme, and uses page-width layout.
- **What must not diverge:** the accept gate (auto-accept is off by default everywhere), direction wording, the code phrase format and mono treatment, the contrast and accessibility floor, and token values: a platform may pick a different API, never a different number.

## Bans

The few hard rules. Everything else in this directory is guidance.

1. **System font only.** No font files shipped.
2. **SF Symbols only in the app.** Lucide exists because SF Symbols cannot ship to the web.
3. **No sounds**, notifications included. A transfer that beeps in a meeting is one people turn off.
4. **Honest security wording.** Never "secure", "anonymous", "unhackable" or "zero-knowledge"; claims come only from the approved list in `voice.md`, "Claims".
5. **Never show a code phrase, a link or file contents on a glanceable surface** (lock screen, widget, control, notification, Live Activity, Spotlight, Handoff, menu bar, Dock). The code phrase is the whole secret and a link's `#` fragment is the key.
6. **No exclamation marks in UI copy.**
