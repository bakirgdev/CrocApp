# Iconography

**In the app: SF Symbols only.** No bundled icon font, no custom vector where a symbol exists. SF Symbols are Apple system glyphs and cannot ship to the web, so the design system and the web properties substitute [Lucide](https://lucide.dev) (MIT) — the closest rounded-outline match. The table below is the contract between the two.

## Mapping

| Meaning | Lucide key (web / design system) | SF Symbol (app) |
|---|---|---|
| Send / outbound | `circle-arrow-up` | `arrow.up.circle` |
| Receive / inbound | `circle-arrow-down` | `arrow.down.circle` |
| Sending (progress header) | `arrow-up` | `arrow.up` |
| Receiving (progress header) | `arrow-down` | `arrow.down` |
| Folder | `folder` | `folder` |
| Generic file | `file` | `doc` |
| Text payload | `file-text` | `doc.text` |
| Image | `image` | `photo` |
| Remove item | `circle-x` | `xmark.circle.fill` |
| Success | `circle-check` | `checkmark.circle` |
| Download / install (web only) | `download` | — |
| Confirm / copied | `check` | `checkmark` |
| Close / decline | `x` | `xmark` |
| Add files | `plus` | `plus` |
| QR code | `qr-code` | `qrcode` (scanner sheet: `qrcode.viewfinder`) |
| Copy | `copy` | `doc.on.doc` |
| Paste | `clipboard` | `doc.on.clipboard` |
| Encrypted (pill) | `lock` | `lock.fill` |
| Verified / trust (full badge) | `shield-check` | `checkmark.shield.fill` |
| Local network | `wifi` | `wifi` |
| Warning | `triangle-alert` | `exclamationmark.triangle.fill` |
| Error | `circle-alert` | `exclamationmark.circle.fill` |
| Info | `info` | `info.circle` |
| Disclosure | `chevron-right` | `chevron.right` |
| Share sheet | `share` | `square.and.arrow.up` |
| Drop zone / upload | `upload` | `square.and.arrow.up` |
| Drag-here hint (DMG background only) | `arrow-right` | — |
| Speed / relay | `zap` | `bolt.fill` |
| Settings | `settings` | `gearshape` |
| Star / GitHub count (web only) | `star` | — |
| Theme: to dark (web only) | `moon` | — |
| Theme: to light (web only) | `sun` | — |
| Sponsor / support (web only) | `heart` | — |

App-only screens have no web call site yet, so the Lucide column stays empty until one appears. Pick the match then, in this table, before writing the markup.

| Meaning | Lucide key (web / design system) | SF Symbol (app) |
|---|---|---|
| History | — | `clock.arrow.circlepath` |
| Transfer completed (history status) | — | `checkmark.circle.fill` |
| Transfer failed (history status) | — | `xmark.circle.fill` |
| Transfer cancelled (history status) | — | `slash.circle` |
| Transfer declined (history status) | — | `hand.raised.fill` |
| Code phrase (concept) | — | `key.fill` |
| PAKE / strong key from short code | — | `lock.shield.fill` |
| Relay | — | `antenna.radiowaves.left.and.right` |
| Works anywhere | — | `globe` |
| App mark in the onboarding sheet | — | `arrow.left.arrow.right.circle.fill` |
| Camera unavailable / denied / restricted | — | `video.slash` |

`xmark.circle.fill` does double duty: Remove item, and the failed history status. That is deliberate. It is never both on one screen, and the history use carries an accessibility label naming the status (`components.md` → HistoryRow).

**Lucide 1.x has no brand icons** — `github.svg` was removed. The landing page's GitHub link uses `star` plus the word "GitHub" rather than the Octocat mark, which also sidesteps the trademark question. Do not reintroduce a brand glyph from an older Lucide version.

**Use the canonical `circle-*` names above, not the legacy `*-circle` spellings.** `alert-circle`, `x-circle`, `arrow-up-circle` and `arrow-down-circle` still ship as byte-identical aliases, so either name renders correctly today — but `check-circle` is **not** an alias. It is a distinct glyph: an open arc (`M21.801 10A10 10 0 1 1 17 3.335`) with an oversized check breaking out of it. Reaching for it when you want the closed circle-with-tick silently draws the wrong mark. `circle-check` is the true match for `checkmark.circle`.

Verified against lucide-static 1.27.0 (2007 icons), 2026-07-26.

On the web the page inlines one `<symbol>` sprite and references it with `<use>`, rather than repeating path data at every call site. Same glyphs, same rules; it just stops ~30 copies of the same `<path>` from shipping.

Check each name in the SF Symbols app before first use, and prefer `.fill` variants inside colored tiles / circles, outline variants standalone. If a screen needs a glyph that is not here, add the row before adding the code.

## Rendering

**Web (Lucide):** 24×24 viewBox, `fill: none`, `stroke: currentColor`, `stroke-linecap`/`linejoin: round`. Default size 22, default stroke width 1.8; use 2 – 2.4 for glyphs under 20px so they keep weight. Always `aria-hidden="true"` — the adjacent label carries the meaning.

Stroke weights are tokens, and unitless: `stroke-width` scales with the viewBox, so a unit on any of these breaks every glyph that uses it.

| Token | Value |
|---|---|
| `--icon-stroke-light` | 1.5 |
| `--icon-stroke` | 1.8 (default) |
| `--icon-stroke-medium` | 2 |
| `--icon-stroke-heavy` | 2.2 |
| `--icon-stroke-heaviest` | 2.4 |

**App (SF Symbols):** size by text style so glyphs track Dynamic Type (`.imageScale`, or `Image(systemName:).font(.headline)`), `.symbolRenderingMode(.hierarchical)` for tinted tiles, `.monochrome` inline. Tint with `--color-accent`'s Swift equivalent, never a hardcoded green.

## Sizes in use

| Context | Size | Stroke (web) |
|---|---|---|
| Button large / medium / small | 20 / 18 / 15 | default |
| Row leading icon (settings tile) | 17 | 2 |
| File row type icon | 20 | default |
| Remove control | 20 | default |
| Banner leading glyph | 19 | 2 |
| TrustBadge pill | 14 | 2.2 |
| TrustBadge full circle | 19 | 2 |
| StatusBlock circle | 34 | 2 |
| Direction header | 18 | 2.4 |
| Disclosure chevron | 18 | 2.4 |
| EmptyState | 44 (34 compact) | 1.5 |
