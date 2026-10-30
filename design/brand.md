# Brand

The brandbook. Anyone making something that carries the CrocApp name (a screen, a page, a release image, a store listing, a post) starts here. The detailed rules live in the files this one points at.

## Positioning

CrocApp is a free, open-source, native app for iPhone, iPad and Mac that sends files, folders and text to another device with a short code phrase. It is built on [croc](https://github.com/schollz/croc) by Zack Scholl, and is unofficial and unaffiliated: never imply endorsement by croc's author.

Approved boilerplate, used verbatim:

| Length | Text |
|---|---|
| Name | CrocApp |
| Subtitle (≤ 30) | Send files with a code phrase |
| One line | Send files, folders and text to another device with a short code phrase. Free, open source and end-to-end encrypted. |
| Long | the App Store description in `docs/knowledge/app-store-listing.md` |

## Personality

**Trustworthy, private, fast, calm.** In that order when they conflict.

- Calm over exciting: no urgency, no confetti, no exclamation marks.
- Plain language over jargon: "end-to-end encrypted", not "PAKE-derived symmetric channel". The detail lives on How It Works, one tap deeper.
- Never overstate security. Claims come only from the approved list in `content.md` → Claims.
- Direction is always explicit: "Sending" and "Receiving" as words, never color or position alone.
- Nothing is accepted without an explicit yes, unless the user turned on auto-accept.
- Errors say what happened and what to do, a short title then one sentence, without blame: "The other device declined", "Ask them to send it again."

Copy mechanics (case, terminology, numbers) are `content.md`.

## Logo

**The app icon is the logo.** There is no separate logotype.

- Source: `assets/CrocAppIcon.icon` (Icon Composer). The mascot's body, belly and outline layers sit on a mint gradient, with dark and tinted variants. `app/CrocApp/AppIcon.icon` is the copy Xcode builds; keep the two identical (`assets/AGENTS.md`).
- The icon's gradient is the one gradient in the brand, because Icon Composer's Liquid Glass material is built from it. No other surface takes a gradient.
- Show the icon only as the platform renders it, in its system mask. Never redraw, recolor, rotate, crop, outline or add a shadow to it, never put type or a badge on it, and never set it on a busy photo.
- Clear space around the icon: at least a quarter of its width. Smallest size: 16px (the favicon).
- **Wordmark**: the word "CrocApp" set in the system font (`--font-sans`, `--weight-bold`) in `--color-text-primary`. It sits beside the icon or the mascot, never inside it. Social cards pair it with the accent `lock` glyph.

## Mascot

The croc character in `assets/mascot.png` (1024px source, never edited, never served).

- A personality accent, not a UI element. Allowed: the landing footer and 404 page, the docs navbar mark, web empty states, social cards. **Never inside the app**, and never in a transfer flow.
- Never recolor, flip, crop, stretch or add effects. It carries its own outline, so it works on both themes.
- Smallest size: 32px. On web it renders from the one derivative, `web/landing/assets/img/mascot-web.webp` (128px), at `--mascot-size-web` or the navbar height.
- Re-cut the derivative from the source rather than editing it: `sips -Z 128` then `cwebp -q 88 -alpha_q 100 -m 6`. The docs site copies the same file; there is no second derivative.

## Color at a glance

One accent: croc green, `#1E9E6A` light and `#2DC585` dark. No secondary brand hue. Status colors are Apple's system semantics, not brand colors: never repaint success green to match the accent, because the difference is the point. Everything else is Apple's neutral ladder.

Accent is for primary actions, selection, links, file-type glyphs and progress. Never for large washes, gradients or decoration. Full palette, aliases and contrast: `colors.md`.

## Type at a glance

SF Pro and SF Mono through the system font, never a shipped font file, never a serif. The code phrase is always mono. A serif headline or a teal-to-green gradient means a generated mockup has drifted off-system: redo it against the tokens. Scale: `typography.md`.

## Imagery

- **Screenshots** come only from `scripts/capture-screenshots.sh`, in light and dark pairs, never hand-edited, cropped or retouched (`docs/knowledge/screenshots.md`). Pages show them unframed; we never draw a device bezel of our own.
- **Social cards** are hand-made, in the layout below, and do not change without changing both.
- **Glyphs** are SF Symbols in the app and Lucide on the web (`iconography.md`). No illustration style beyond the mascot.

## Assets

| Asset | Path | Use |
|---|---|---|
| App icon | `assets/CrocAppIcon.icon` | the logo; the app builds `app/CrocApp/AppIcon.icon` |
| Mascot | `assets/mascot.png` | source for every mascot derivative |
| Mascot, web | `web/landing/assets/img/mascot-web.webp` | landing, docs navbar, web empty states |
| Favicons | `assets/favicons/` (source set), `web/landing/assets/img/favicon/` (served copy) | the app icon at web sizes: `favicon.ico` (16, 32, 48), `favicon-96x96.png`, `apple-touch-icon.png` (180), `web-app-manifest-{192x192,512x512}.png`, `site.webmanifest`. The docs site references the landing copy. Recipe below |
| Screenshots | `web/docs/screenshots/`, `web/landing/assets/img/screenshots/` (WebP, tracked), from `assets/screenshots/{mac,iphone,ipad}/<screen>-{light,dark}.png` (capture output, gitignored) | README, docs, landing hero |
| App Store screenshots | `assets/screenshots/app-store/<class>/NN-<screen>-{light,dark}.png` (generated at submission, gitignored) | App Store Connect |
| Social card | `web/landing/assets/img/og.jpg` | 1200×630, light: wordmark, accent `lock`, headline "Send files with a code phrase", the line "Encrypted end-to-end", the site URL, mascot on the trailing side |
| GitHub social preview | `assets/github-social-preview.png` | 1280×640, the same layout in dark values (`--bg-secondary`, `--label-1`, `--label-2-text`, `--green-400`) with the repo URL; uploaded by hand in the repo settings |
| Disk image background | `assets/dmg-background.tiff` | `components.md` → DiskImage |
| App Store badges | `web/landing/assets/img/app-store.svg`, `mac-app-store.svg` | Apple's artwork, below |

### Favicon recipe

Favicons are the app icon, not the bare mascot. Regenerate them whenever the icon changes:

1. Render the icon: `ictool assets/CrocAppIcon.icon --export-image --output-file icon.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1` (`ictool` path in `assets/AGENTS.md`). The render is the masked squircle with transparent corners; the macOS platform renders the same pixels.
2. Make an opaque touch master from it, because iOS and Android fill transparent corners with black: scale the render to 1198px (`sips -z 1198 1198`), center-crop to 1024 (`sips -c 1024 1024`), then fill the few remaining transparent corner pixels with the icon's own corner colors. The mascot stays inside the crop.
3. On [realfavicongenerator.net](https://realfavicongenerator.net), upload the step 1 render as the main icon and set: regular icon "Use the icon as is", no dark icon; Apple touch icon "Use a dedicated icon" with the step 2 master, "Use the icon as is", app name `CrocApp`; web app manifest "Use a dedicated icon" with the step 2 master, "Use the icon as is", name and short name `CrocApp`, background and theme color `#FFFFFF`; Windows tile left at its default; favicon path `/`, no version, metadata injection skipped. Download the zip.
4. Keep `favicon.ico`, `favicon-96x96.png`, `apple-touch-icon.png` and the two `web-app-manifest-*` PNGs. Drop `favicon.svg` (it only wraps a PNG) and the generated `site.webmanifest`: ours keeps `id`, `description`, `scope`, relative icon paths and `purpose: "any"`, with `theme_color` and `background_color` equal to `--bg-base` light (`#FFFFFF`). The mascot overflows the 80% maskable safe zone, so the icons are not `maskable`.
5. Put the set in `assets/favicons/`, copy the same files to `web/landing/assets/img/favicon/`.

## Naming

"CrocApp": one word, capital C and A. Never "Croc App", "Crocapp" or "CrocAPP". "croc", the CLI, is always lowercase. Bundle ID `com.bakirgdev.CrocApp`; share extension `com.bakirgdev.CrocApp.CrocShare`.

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
- The black badge is preferred, in both themes. Use Apple's white badge only where the black one is visually heavy, and never when another platform's badge sits beside it.
- Minimum height 40px onscreen (`--store-badge-height-web`). Clear space at least a quarter of the badge height, with nothing inside it.
- The App Store badge comes first in any row of badges and sits in a subordinate position to the page's own message.
- Never translate "App Store" or build a localized badge; Apple supplies the localizations.
