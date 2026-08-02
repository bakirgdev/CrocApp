# Brand

## Positioning

CrocApp is a free, open-source, native SwiftUI GUI for [croc](https://github.com/schollz/croc). Unofficial and unaffiliated — never imply endorsement by croc's author. Always attribute croc (MIT, Zack Scholl) on the landing page, the docs site and the About screen.

## Personality

**Trustworthy, private, fast, calm.** In that order when they conflict.

- Calm over exciting: no countdown urgency, no confetti, no exclamation marks.
- Plain language over jargon: "end-to-end encrypted", not "PAKE-derived symmetric channel" — the detail belongs on the "How it works" screen, one tap deeper.
- Never overstate the security claim. What is true: transfers are end-to-end encrypted, the code phrase authenticates both sides, and the relay only ever sees ciphertext. Do not extend past that.
- Direction is always explicit. "Sending" / "Receiving" as words, never colour or position alone.
- Errors state what happened and what to do, in one line, without blame: "The other side declined the transfer."

## Accent

Deep croc green, `#1E9E6A` (light) / `#2DC585` (dark). One accent, no secondary brand hue. Status colors are Apple's system semantics and are not brand colors — do not repaint success green to match the accent, the difference is the point.

Accent is for: primary action fills, active/selected state, links, file-type glyphs, progress fills. Accent is not for: large background washes, gradients, decorative shapes.

**No gradients.** A teal-to-green gradient or a serif headline means a generated mockup has drifted off-system; re-do it against the tokens rather than editing the drift.

## Assets

| Asset | Path | Use |
|---|---|---|
| App icon source | `assets/CrocAppIcon.icon` | Xcode icon composer source; export for App Store, docs favicon, README |
| Banner | `assets/croc-banner.webp` | README header |
| Screenshots | `assets/screenshots/<platform>-<screen>-{light,dark}.png` | landing hero, README, docs pages. Regenerated only by `scripts/capture-screenshots.sh` — never hand-edited or hand-cropped |
| Social card | `web/landing/assets/img/og.jpg` | Open Graph / link previews. Hand-made on purpose, not derived from the tokens |
| Mascot | `assets/mascot.png` | source, 512px. Never served |
| Mascot, web | `web/landing/assets/img/mascot-web.webp` | 128px derivative — landing page, empty states on web, docs 404 |
| Disk image background | `assets/dmg-background.png` | 660×400, the macOS DMG's Finder window. Spec in `components.md` → DiskImage |

The mascot is a personality accent, not a UI element — it never appears inside the app's transfer flows.

The web derivative exists because the 512px source is 51 KB to draw a 64px mark. Re-cut it from the source rather than editing it: `sips -Z 128` then `cwebp -q 88 -alpha_q 100 -m 6`.

## Naming

"CrocApp", one word, capital C and A. Bundle ID `com.bakirgdev.CrocApp`; share extension `com.bakirgdev.CrocApp.CrocShare`. "croc" (the CLI) stays lowercase, always. Never write "Croc App" or "CrocAPP".

## Web surfaces

The landing page and the docs site carry the brand through the same tokens, so the marketing surface and the product look like one thing. How that is applied — page fill, width caps, theming, glass — is `web.md`.
