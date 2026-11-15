# Principles

The rules behind every CrocApp surface: the SwiftUI apps (iOS, iPadOS, macOS), the landing page, the docs site and the release artwork. The app is built from system controls, system styles and system colors, so Apple's current practice (iOS and macOS 26, Liquid Glass, Dynamic Type) is not restated here. This file holds what is ours: the few custom pieces, the product's behavior and the web.

Most of the product is text and one progress bar. A wrong byte count is more visible than a wrong shadow.

## System first

- Use the system control, its style and the system's default spacing and sizes. Do not rebuild one in a view.
- Draw something custom only when no system control does the job, and keep it small. What is custom, and why: the accent (brand), the code phrase display and QR frame (the product's one secret), the drop zone and status block (no system equivalent), and the mascot.
- The app has no spacing, radius, size or color tokens. A measurement one view needs is a named constant in that view.

## Platform adaptation

Navigation, chrome and input change between devices; the screens, wording and rules do not.

- **iPhone** is a `TabView` with Send, Receive, History and Settings. **iPad and Mac** show the same tabs as a sidebar (`.sidebarAdaptable`), a sidebar by default on iPad. On the Mac, Settings stays the Settings scene (⌘,) and is not a tab.
- **Primary actions are pinned to the bottom of the screen**, in the same place on every device.
- Adapt by size class, never by device. The layout changes live as a window resizes. Behavior and wiring: `docs/knowledge/app-ui-architecture.md`, "Layout by width".
- The system owns tab bars, sidebars, toolbars and sheets. We draw nothing on them, and the transfer state beside a sidebar row is words first.
- **Mac.** Menu bar commands give every toolbar action a shortcut, right-click menus are additive, drop is window-wide, and there is no camera or QR scan (absent, not disabled). iPad reaches the same commands through the hardware-keyboard menu.
- **What must not diverge:** the accept gate (auto-accept is off by default everywhere), direction wording, the code phrase format and mono treatment, and the accessibility floor.

## Controls

- The one primary action of a screen is `.buttonStyle(.glassProminent)`. Every other button is `.glass`, and a plain tertiary action is `.borderless`. A destructive action takes `role: .destructive` on a `.glass` button with `.foregroundStyle(.red)` on its label: the system draws that label in the primary color, and `.tint(.red)` fixes it on iOS but fills the whole button red on macOS, where a destructive action would then outweigh the primary one. No custom button style, fill or hit area.
- Toggles, pickers, segmented controls, forms, lists, sheets, alerts, menus and share are the system's, unmodified. Segment labels are Title Case.
- An alert or confirmation dialog is only for an irreversible destructive action or a failure the user must acknowledge; everything else is an inline banner. A confirmation title is a question, a failure title a statement, with at most two actions.
- Context menus and swipe actions are additive: every action is reachable another way. A swipe's leading edge is constructive, its trailing edge destructive.

## Color

- **The accent is brand olive, and only the accent is.** `AccentColor` is the one color set, `#5C6B2E` in light (olive-700) and `#6C7C3C` in dark, olive darkened from the mascot's body until a white label clears 4.5:1. It is the global accent of every app target, so nothing sets `.tint` at a scene root. It tints controls, links, selection and progress. On the Mac, system controls may follow the user's accent instead.
- Every other color is the system's, drawn as the system draws it: `.primary`, `.secondary`, `.tertiary`, and system red, green and orange for status. The app declares no other color sets. Never repaint a status color to match the accent.
- Olive appears in the app only as the accent tint and in artwork (the icon, the mascot). Khaki belongs to the icon, the mascot and illustration.
- **Color is never the only signal.** Direction is an arrow and the word "Sending" or "Receiving", every status is stated in words, and a glyph that alone carries a status has an accessibility label.

## Contrast

WCAG 2.2 AA is the floor: 4.5:1 for body text, 3:1 for large text and for UI boundaries and glyphs. Large text is 24px or more, or 18.66px or more at weight 700.

- **The accent clears it by choice.** The system draws a white label on a `.glassProminent` or `.borderedProminent` fill, so the fill must hold 4.5:1 against white. `#5C6B2E` is 5.84:1 (5.84:1 measured on an iPhone 17 simulator screenshot of a `.glassProminent` button) and `#6C7C3C` is 4.58:1 (4.63:1 measured, the fill drew as `#6C7B3C`). The dark accent on black is 4.59:1. Olive-400 `#A3B86A` fails: a white label on it measured 2.18:1. A new accent value must keep both ratios.
- **Known limit: the accent as small text on a dark card.** `#6C7C3C` on the dark grouped card `#1C1C1E` is 3.72:1, below 4.5:1. The app therefore draws no accent-colored body or footnote text: text is `.primary` or `.secondary`, and the accent appears on controls, glyphs and `.borderless` button labels as the system draws them. The accessibility audit (`docs/knowledge/app-store-listing.md`, "Open checks before submitting") carries this.
- **Text on a custom fill passes AA** on its own. Text the system draws on its own fills is the system's.
- **Secondary text is the system's `.secondary`.** In light it is about 3.44:1 on white, below 4.5:1 for small text, so the claim that all small text clears 4.5:1 in light mode no longer holds. This is a known trade for system styling: the accessibility audit (`docs/knowledge/app-store-listing.md`, "Open checks before submitting") carries it, and the App Store "Sufficient Contrast" label is not claimed until Accessibility Inspector has run on the shipped screens.
- **Status colors are fills and glyphs, not text.** A tint and a glyph carry the kind; the words stay primary text.

## Type

SF Pro for everything and SF Mono for code phrases and text payloads, through the system font APIs. **Never ship a font file**: Apple's fonts are not redistributable.

- **Text styles only** (`.largeTitle` through `.caption2`), so Dynamic Type works everywhere. Never a fixed point size for text, and in SwiftUI do not fight a style's own tracking.
- **The code phrase is always mono**, lowercase, with positive tracking so the `word-word-word` groups stay separable when read aloud. It wraps only between words.
- **Numbers that change are tabular** (`.monospacedDigit()`), so a live speed never reflows.
- **Uppercase is rare.** Only the eyebrow above the code phrase uses it.
- **Icons** are SF Symbols in the app. Size them by text style or `@ScaledMetric`.

## Materials

The system's materials and Liquid Glass come with its controls: the `.glass` styles, toolbars, tab bars and sheets.

- Glass is the navigation and control layer that floats above content. Content (lists, forms, a page) is not glass, and glass never sits on glass.
- A surface we float ourselves (the code card, the drop overlay) uses `.glassEffect(_:in:)`, with surfaces that sit together in a `GlassEffectContainer`, or a system material. Never hand-roll a blur plus a shadow.
- Legibility never depends on glass. If a surface stops reading when it turns solid, the surface was wrong. Reduce Transparency is the system's to handle.

## Motion

The app follows the system's animations, springs included. Motion is calm, interruptible and never gratuitous: a transfer screen that performs is a transfer screen you do not trust.

- **Motion explains a change and is never the only signal.** The Copy button already says "Copied", the number is already the new number. Under `.accessibilityReduceMotion` (`prefers-reduced-motion` on web) slides, symbol effects and pulses go and every change stays: pass `nil` instead of an animation, and `.contentTransition(.identity)`.
- **A transfer is a phase machine** (`idle`, `starting`, `waiting` or `connecting`, `confirmSend` or `incoming`, `transferring`, then `done`, `failed` or `stored`). The phase container cross-fades as one block; its contents do not animate in separately.
- **What persists must not move.** The direction header and the code phrase keep their position across phases, because the code phrase is what the user reads aloud.
- **Terminal phases arrive; they do not celebrate.** No confetti, pop or spin on done or failed, and the one pulse on the direction glyph while the sender waits is the only loop.
- **Progress never moves backwards.** If a total revises downward, snap and keep moving forward. A readout that changes faster than once a second shows a new value at most once a second.

## Haptics

iPhone only: iPad's are inconsistent across models and macOS has none. Haptics are additive: every event is also visible and announced, and nothing relies on them. Use the system semantics through `.sensoryFeedback`: `.success`, `.warning` and `.error` for what happens to a transfer (completed, a request needing an answer, failed or declined), `.selection` for a value captured (a copy, a scan). Do not fire on progress, ordinary taps or navigation, and not for an action the user took that ended silently (a Cancel or Decline). The **Haptics** setting (iPhone, on by default) turns them all off, and the system's own setting is respected.

## Accessibility

WCAG 2.2 AA is the floor on every surface.

- **Contrast** per the section above.
- **Focus.** Every interactive element shows a visible indicator that owes 3:1. The app uses the system's; never remove one without replacing it.
- **Dynamic Type.** Check the largest accessibility size: nothing clips, and at those sizes a glyph moves above its text.
- **Target size.** The app takes the system controls' sizes and checks any control that sets its own (`PasteButton`) with Accessibility Inspector. The web follows WCAG 2.2 target size (2.5.8): at least 24 by 24 CSS px.
- **Labels.** A glyph that alone carries a status has an accessibility label. Web glyphs are `aria-hidden` and the adjacent label carries the meaning.
- **Nothing is hover-only.** Hover (Mac, iPad pointer, web) may restate and may apply the pressed background, never reveal.
- **Input is never drag-only.** Every drop target ships beside a real file-picker button.
- **Announcements.** Errors and terminal failures are announced to VoiceOver, progress is not announced on every tick, a sidebar row's state is announced once per phase change, and a copy or scan announces "Copied", "Code scanned" or "Link scanned".

## Web

The landing page and the docs site consume `tokens.css`, a web-only token file: the app has no mirror of it, and the build copies it (never edit a copy). Both sites ship both themes and follow the OS. Head, images and policy: `docs/knowledge/landing-page.md`.

- **Tokens, not literals.** Components take the `--color-*` aliases. `scripts/verify-design.sh` flags a hex color, `rgb()` or `hsl()` function or named color in web code. The one exception is the `theme-color` literals browser chrome needs, in three places: the landing page's meta tags, `web/docs/docusaurus.config.ts` and `theme_color` and `background_color` in `site.webmanifest`. All equal `--bg-base` in light and dark, and the script checks that.
- **System font fallback is fine.** The stacks in `tokens.css` resolve to San Francisco on Apple hardware and fall through to the platform fonts elsewhere. Headings take the `.t-web-*` classes, everything at body size and below the shared scale.
- **Layout** uses the `--content-max-width-*-web`, `--gutter-web` and `--section-pad-web` tokens, in `clamp()` with both ends on the 4pt grid. Breakpoints are literals in `rem`, because a custom property does not resolve inside a media condition. Use logical properties (`padding-inline`), never left and right.
- **Page fill** is `--color-surface-base`. Cards are `--color-surface-card` with a hairline border, because in light the two fills are the same white.
- **Glass.** Only the sticky nav is glass, with content scrolling under it; everything else is solid. `prefers-reduced-transparency` collapses it at the token level.
- **Hover and focus.** Hover is the pressed background inside `@media (hover: hover)`. Focus is `--shadow-focus-ring`, never restyled per component: two solid bands, so one always has a 3:1 edge against whatever it surrounds.
- **Contrast.** Computed from `tokens.css` (nothing recomputes them, so redo it when a token changes): `--color-accent-text` on page or card 5.84:1 light and 9.62:1 dark, `--color-text-secondary` 5.63:1 light and 5.95:1 on a dark card, `--color-on-accent` on `--color-accent-solid` 5.84:1 light and 5.99:1 dark, `--color-accent` 4.06:1 light so fills and glyphs only. Links are `--color-accent-text`, never the plain accent, and secondary text is `--color-text-secondary`, never Apple's `.secondary`.
- **Icons** are [Lucide](https://lucide.dev) (ISC), the closest rounded outline match to SF Symbols: one inline `<symbol>` sprite referenced with `<use>`, 24×24 viewBox, `fill: none`, `stroke: currentColor`, round caps, `aria-hidden="true"`. Use canonical `circle-*` names (`check-circle` is a different glyph), no brand icons, and the unitless `--icon-stroke-*` tokens, because `stroke-width` scales with the viewBox.
- **Docs site.** `web/docs/src/css/custom.css` maps Infima's variables onto tokens, and `web/docs/src/prismTheme.ts` writes `var(--token)` strings. The mascot is the navbar mark.

## Bans

The few hard rules. Everything else in this directory is guidance.

1. **System font only.** No font files shipped.
2. **SF Symbols only in the app.** Lucide exists because SF Symbols cannot ship to the web.
3. **No sounds**, notifications included. A transfer that beeps in a meeting is one people turn off.
4. **Honest security wording.** Never "secure", "anonymous", "unhackable" or "zero-knowledge"; claims come only from the approved list in `voice.md`, "Claims".
5. **Never show a code phrase, a link or file contents on a glanceable surface** (lock screen, widget, control, notification, Live Activity, Handoff, menu bar, Dock). The code phrase is the whole secret and a link's `#` fragment is the key.
6. **No exclamation marks in UI copy.**
