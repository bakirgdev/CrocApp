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

**No gradients.** If a generated design shows a teal-to-green gradient or a serif headline, it has drifted off-system — regenerate with "use only design system tokens, SF Pro, croc green accent".

## Assets

| Asset | Path | Use |
|---|---|---|
| App icon source | `assets/CrocAppIcon.icon` | Xcode icon composer source; export for App Store, docs favicon, README |
| Banner | `assets/banner.webp` | README header, landing hero, social card |
| Mascot | `assets/mascot.png` | landing page, empty states on web, docs 404 |

The mascot is a personality accent, not a UI element — it never appears inside the app's transfer flows.

## Naming

"CrocApp", one word, capital C and A. Bundle ID `com.bakirgdev.CrocApp`; share extension `com.bakirgdev.CrocApp.CrocShare`. "croc" (the CLI) stays lowercase, always. Never write "Croc App" or "CrocAPP".

## Web surfaces

The landing page and docs site use these same tokens (`tokens.css`) so the marketing surface and the product look like one thing. They are web pages, not an app shell: keep the Apple type scale and colors, drop the device chrome, use the `solid` material where there is nothing behind glass to blur, and cap content at `--content-max-width` (wider only for full-bleed hero and screenshots).

Both themes are required on both sites, and both must honour the OS preference by default.
