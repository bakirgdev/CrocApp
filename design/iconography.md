# Iconography

**In the app: SF Symbols only.** No bundled icon font, no custom vector where a symbol exists. SF Symbols are Apple system glyphs and cannot ship to the web, so the design system and the web properties substitute [Lucide](https://lucide.dev) (MIT) — the closest rounded-outline match. The table below is the contract between the two.

## Mapping

| Meaning | Lucide key (web / design system) | SF Symbol (app) |
|---|---|---|
| Send / outbound | `arrow-up-circle` | `arrow.up.circle` |
| Receive / inbound | `arrow-down-circle` | `arrow.down.circle` |
| Sending (progress header) | `arrow-up` | `arrow.up` |
| Receiving (progress header) | `arrow-down` | `arrow.down` |
| Folder | `folder` | `folder` |
| Generic file | `file` | `doc` |
| Text payload | `file-text` | `doc.text` |
| Image | `image` | `photo` |
| Remove item | `x-circle` | `xmark.circle.fill` |
| Success | `check-circle` | `checkmark.circle` |
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
| Error | `alert-circle` | `exclamationmark.circle.fill` |
| Info | `info` | `info.circle` |
| Disclosure | `chevron-right` | `chevron.right` |
| Share sheet | `share` | `square.and.arrow.up` |
| Drop zone / upload | `upload` | `square.and.arrow.up` |
| Speed / relay | `zap` | `bolt.fill` |
| Settings | `settings` | `gearshape` |
| Star / GitHub count (web only) | `star` | — |
| Theme: to dark (web only) | `moon` | — |
| Theme: to light (web only) | `sun` | — |

**Lucide 1.x has no brand icons** — `github.svg` was removed and 404s on the CDN. The landing page's GitHub link therefore uses `star` plus the word "GitHub" rather than the Octocat mark, which also sidesteps the trademark question. Do not reintroduce a brand glyph from an older Lucide version.

Two names in this table are Lucide 1.x *aliases*: `arrow-up-circle` and `x-circle` now resolve to `circle-arrow-up` and `circle-x`. Geometry is identical and both names still fetch, so the rows stand — but use the canonical names if these ever stop redirecting.

Check each name in the SF Symbols app before first use, and prefer `.fill` variants inside colored tiles / circles, outline variants standalone. If a screen needs a glyph that is not here, add the row before adding the code.

## Rendering

**Web (Lucide):** 24×24 viewBox, `fill: none`, `stroke: currentColor`, `stroke-linecap`/`linejoin: round`. Default size 22, default stroke width 1.8; use 2 – 2.4 for glyphs under 20px so they keep weight. Always `aria-hidden="true"` — the adjacent label carries the meaning.

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
