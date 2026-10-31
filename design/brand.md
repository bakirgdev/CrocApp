# Brand

Anyone making something that carries the CrocApp name (a screen, a page, a release image, a store listing, a post) starts here. Tone and copy are `voice.md`; values are `tokens.css`.

## Positioning

CrocApp is a free, open-source, native app for iPhone, iPad and Mac that sends files, folders and text to another device with a short code phrase. It is built on [croc](https://github.com/schollz/croc) by Zack Scholl, and is unofficial and unaffiliated: never imply endorsement by croc's author.

Approved boilerplate, used verbatim:

| Length | Text |
|---|---|
| Name | CrocApp |
| Subtitle (at most 30 characters) | Send files with a code phrase |
| One line | Send files, folders and text to another device with a short code phrase. Free, open source and end-to-end encrypted. |
| Long | the App Store description in `docs/knowledge/app-store-listing.md` |

## Logo and icon

**The app icon is the logo.** There is no separate logotype.

- Source: `assets/CrocAppIcon.icon` (Icon Composer). The mascot's body, belly and outline layers sit on a pale khaki gradient in light and a deep olive gradient in dark, with a tinted variant. `app/CrocApp/AppIcon.icon` is the copy Xcode builds; keep the two identical (`assets/AGENTS.md`).
- Show the icon as the platform renders it, in its system mask. Do not redraw, recolor, rotate, crop or outline it, put type or a badge on it, or set it on a busy photo. Leave clear space of at least a quarter of its width, and do not go below 16px (the favicon).
- **Wordmark**: the word "CrocApp" in the system font (`--font-sans`, `--weight-bold`) in `--color-text-primary`, beside the icon or the mascot, never inside it.

## Mascot

The croc character in `assets/mascot.png` (1024px source, never edited, never served) is the palette source and may appear anywhere: onboarding, empty states, About, the landing page, the docs and social cards. Keep it out of a transfer's critical path, where it would compete with the code phrase and the progress.

- Do not recolor, flip, crop, stretch or add effects. It carries its own outline, so it works on both themes. Smallest size 32px.
- On web it renders from the one derivative `web/landing/assets/img/mascot-web.webp` (128px) at `--mascot-size-web` or the navbar height. Re-cut it from the source: `sips -Z 128` then `cwebp -q 88 -alpha_q 100 -m 6`. The docs site copies the same file.

## Palette

Taken from the mascot: **olive** is the brand color (500 `#83974F` is the mascot's body, 900 `#28350D` its ink), **khaki** (`--khaki-400`, the belly) is the second color, and dark olive is the ink. The accent aliases pick olive steps per theme (`principles.md`, "Color"). Khaki belongs to the icon, the mascot and illustration. The app and web UI stay olive plus Apple's neutrals and status colors.

Type is the system font, SF Mono for code. Glyphs are SF Symbols in the app and Lucide on the web, with no illustration style beyond the mascot.

## Imagery

- **Screenshots** come only from `scripts/capture-screenshots.sh`, in light and dark pairs, never hand-edited, cropped or retouched (`docs/knowledge/screenshots.md`). Pages show them unframed, with no device bezel of our own.
- **Social cards** are drawn by `scripts/social-cards.swift` in the layout in the table below and change only together.

## Assets

| Asset | Path | Use |
|---|---|---|
| App icon | `assets/CrocAppIcon.icon` | the logo; the app builds `app/CrocApp/AppIcon.icon` |
| Mascot | `assets/mascot.png` | source for every mascot derivative |
| Mascot, web | `web/landing/assets/img/mascot-web.webp` | landing, docs navbar, web empty states |
| Favicons | `assets/favicons/` (source set), `web/landing/assets/img/favicon/` (served copy) | the app icon at web sizes: `favicon.ico`, `favicon-96x96.png`, `apple-touch-icon.png`, `web-app-manifest-{192x192,512x512}.png`, `site.webmanifest`. The docs site references the landing copy |
| Screenshots | `web/docs/screenshots/`, `web/landing/assets/img/screenshots/` (WebP, tracked), from `assets/screenshots/{mac,iphone,ipad}/<screen>-{light,dark}.png` (capture output, gitignored) | README, docs, landing hero |
| App Store screenshots | `assets/screenshots/app-store/<class>/NN-<screen>-{light,dark}.png` (generated at submission, gitignored) | App Store Connect |
| Social card | `web/landing/assets/img/og.jpg` (landing and docs) | 1200×630, light: the icon's khaki gradient, wordmark, olive `lock`, headline "Send files with a code phrase", the line "Encrypted end-to-end", the site URL, mascot on the trailing side. Drawn by `scripts/social-cards.swift` |
| GitHub social preview | `assets/github-social-preview.png` | 1280×640, the same layout on the icon's deep olive with the repo URL, from the same script; uploaded by hand in the repo settings |
| Disk image background | `assets/dmg-background.tiff` | `docs/RELEASING.md`, "Disk image" |
| App Store badges | `web/landing/assets/img/app-store.svg`, `mac-app-store.svg` | Apple's artwork, below |

### Favicon recipe

Favicons are the app icon, not the bare mascot. Regenerate them whenever the icon changes:

1. Render the icon at 1024: `ictool assets/CrocAppIcon.icon --export-image --output-file icon.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1` (`ictool` path in `assets/AGENTS.md`). The render is the masked squircle with transparent corners.
2. Run `swift scripts/favicons.swift icon.png assets/favicons`. It writes `favicon.ico`, `favicon-96x96.png`, and the opaque `apple-touch-icon.png` and `web-app-manifest-*` PNGs (iOS and Android fill transparent corners with black, so the script scales the render over the icon's own background gradient).
3. Copy the set to `web/landing/assets/img/favicon/`.

`site.webmanifest` is hand-kept: it carries `id`, `description`, `scope`, relative icon paths and `purpose: "any"`, with `theme_color` and `background_color` equal to `--bg-base` in light (`scripts/verify-design.sh` checks). The mascot overflows the maskable safe zone, so the icons are not `maskable`.

## Naming

"CrocApp": one word, capital C and A. Never "Croc App", "Crocapp" or "CrocAPP". "croc", the CLI, is always lowercase. Bundle ID `com.bakirgdev.CrocApp`; the other five are listed in `docs/RELEASING.md`, "One-time setup".

Apple product names follow Apple's rules: singular, never possessive, never all caps, never abbreviated. "CrocApp for iPhone, iPad and Mac", not "the iPhone app". "App Store" with a capital A and S, and only "the" before it.

## Attribution and legal

| Where | Text |
|---|---|
| Landing footer, docs footer, About | "Built on croc by Zack Scholl (MIT). CrocApp is unofficial and not affiliated with croc." |
| Wherever an App Store badge appears | "Apple, the Apple logo, iPhone, iPad, Mac and App Store are trademarks of Apple Inc., registered in the U.S. and other countries and regions." |
| License | MIT, copyright holder exactly as in `LICENSE`: "Bakir Gracić" |
| Lucide sprite | its source comment names Lucide and its ISC license |

## App Store badges

From Apple's [marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/) (re-check before shipping new artwork):

- Use only Apple's badge artwork. Never modify, recolor, invert, angle or animate it; the gray border of the black badge is part of the artwork.
- The black badge is preferred, in both themes. Use the white badge only where the black one is visually heavy, and never when another platform's badge sits beside it.
- Minimum height 40px onscreen (`--store-badge-height-web`). Clear space at least a quarter of the badge height, with nothing inside it.
- The App Store badge comes first in any row of badges and sits subordinate to the page's own message.
- Never translate "App Store" or build a localized badge; Apple supplies the localizations.
