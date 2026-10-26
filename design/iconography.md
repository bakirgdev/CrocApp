# Iconography

**In the app: SF Symbols only.** No icon font, no custom vector where a symbol exists. SF Symbols cannot ship to the web, so the web substitutes [Lucide](https://lucide.dev) (ISC license), the closest rounded-outline match. The tables below are the contract between the two. A glyph not in a table gets its row before it gets its code.

## Shared meanings

| Meaning | Lucide (web) | SF Symbol (app) |
|---|---|---|
| Send | `circle-arrow-up` | `arrow.up.circle` (`.fill` on the Home buttons) |
| Receive | `circle-arrow-down` | `arrow.down.circle` (`.fill` on the Home buttons) |
| Sending (direction header) | `arrow-up` | `arrow.up` |
| Receiving (direction header) | `arrow-down` | `arrow.down` |
| Folder | `folder` | `folder` |
| Generic file | `file` | `doc` |
| Text payload | `file-text` | `doc.text` |
| Image | `image` | `photo` |
| Success | `circle-check` | `checkmark.circle` |
| Confirm, copied, feature-list bullet | `check` | `checkmark` |
| Copy | `copy` | `doc.on.doc` |
| Encrypted (pill) | `lock` | `lock.fill` |
| Verified (full trust badge) | `shield-check` | `checkmark.shield.fill` |
| Local network | `wifi` | `wifi` |
| Warning | `triangle-alert` | `exclamationmark.triangle.fill` |
| Error | `circle-alert` | `exclamationmark.circle.fill` |
| Info | `info` | `info.circle` |
| Disclosure | `chevron-right` | `chevron.right` (system-drawn in lists) |
| Share | `share` | `square.and.arrow.up` |
| Drop zone | `upload` | `square.and.arrow.up` |
| Settings | `settings` | `gearshape` |

## Web only

| Meaning | Lucide |
|---|---|
| Download, install | `download` |
| Speed, native performance | `zap` |
| Star, GitHub count | `star` |
| Theme: to dark | `moon` |
| Theme: to light | `sun` |
| Sponsor, support | `heart` |
| Drag-here hint (DMG background) | `arrow-right` |

## App only

| Meaning | SF Symbol |
|---|---|
| Remove item | `xmark.circle.fill` |
| Scan a QR code | `qrcode.viewfinder` |
| Send as link | `link.circle.fill` |
| Receive from a link | `link` |
| The other device connected | `person.crop.circle.badge.checkmark` |
| How It Works (toolbar) | `lock.shield` |
| PAKE: a strong key from a short code | `lock.shield.fill` |
| Code phrase (concept) | `key.fill` |
| Relay | `antenna.radiowaves.left.and.right` |
| Works anywhere | `globe` |
| History | `clock.arrow.circlepath` |
| Transfer completed (history status) | `checkmark.circle.fill` |
| Transfer failed (history status) | `xmark.circle.fill` |
| Transfer cancelled (history status) | `slash.circle` |
| Transfer declined (history status) | `hand.raised.fill` |
| Advanced settings | `slider.horizontal.3` |
| App mark (onboarding) | `arrow.left.arrow.right.circle.fill` |
| Menu bar icon, idle | `arrow.up.arrow.down.circle` |
| Menu bar icon, waiting or transferring | `arrow.up.arrow.down.circle.fill` |
| Menu bar icon, needs attention | `exclamationmark.circle.fill` (the Error glyph, reused) |
| Quick Look | `eye` |
| Camera denied, restricted or unavailable | `video.slash` |

`xmark.circle.fill` is both Remove item and the failed status on purpose: never on one screen together, and the history use carries an accessibility label naming the status.

`lock.shield` and `lock.shield.fill` differ on purpose: the outline is a toolbar button, the fill sits in a How It Works row.

## Lucide rules

- **No brand icons.** Lucide 1.x removed them (`github.svg` is gone). The GitHub link uses `star` plus the word "GitHub", never the Octocat mark.
- **Canonical `circle-*` names, never the legacy `*-circle` spellings.** Most legacy names are byte-identical aliases, but `check-circle` is a different glyph (an open arc with an oversized tick). `circle-check` is the match for `checkmark.circle`.
- The page inlines one `<symbol>` sprite and references it with `<use>`; the package is never bundled. The sprite comment names the Lucide version it was copied from.

Names verified against lucide-static 1.59.0. SF Symbol names are checked in the SF Symbols app before first use.

## Rendering

**Web (Lucide):** 24×24 viewBox, `fill: none`, `stroke: currentColor`, round caps and joins. Always `aria-hidden="true"`: the adjacent label carries the meaning. Glyphs under 20px take stroke 2 or more so they keep weight.

Stroke weights are unitless tokens: `stroke-width` scales with the viewBox, so a unit breaks every glyph.

| Token | Value |
|---|---|
| `--icon-stroke-light` | 1.5 |
| `--icon-stroke` | 1.8 (default) |
| `--icon-stroke-medium` | 2 |
| `--icon-stroke-heavy` | 2.2 |
| `--icon-stroke-heaviest` | 2.4 |

**App (SF Symbols):** size by text style so glyphs track Dynamic Type (`.font(.headline)`, `.imageScale`), or with `@ScaledMetric` where a component specifies a point size. Never a fixed `.font(.system(size:))`. `.symbolRenderingMode(.hierarchical)` in tinted tiles, monochrome inline. `.fill` variants inside colored circles, outlines standalone. Tint through the color aliases, never a raw color.

## Sizes in use

| Context | Size | Web stroke |
|---|---|---|
| Button large / medium / small | 20 / 18 / 15 | `--icon-stroke` / `-medium` / `-heavy` |
| FileRow type glyph, remove control | 20 | `--icon-stroke` |
| StatusBanner glyph | 19 | `--icon-stroke-medium` |
| TrustBadge pill / full | 14 / 19 | `--icon-stroke-heavy` / `-medium` |
| StatusBlock | 34 | `--icon-stroke-medium` |
| Direction header | 17 | `--icon-stroke-heaviest` |
| Disclosure chevron | 17 | `--icon-stroke-heaviest` |
| DropZone, EmptyState | 44 (34 compact) | `--icon-stroke-light` |
