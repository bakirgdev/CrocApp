# assets/

Source-of-truth design and marketing files. Mostly binary and committed as-is; nothing here is build output, and nothing here is served directly except through the copies named below. `design/brand.md` → Assets is the inventory across the whole repo.

## Layout

| Path | What it is | Used by |
| --- | --- | --- |
| `mascot.png` | 1024×1024 mascot, the root image every other mascot asset derives from | Icon layer, `web/landing/assets/img/mascot-web.webp`, social cards |
| `CrocAppIcon.icon/` | Icon Composer package: `icon.json` (mint gradient background, dark variant, two glass groups) plus three layers cut from `mascot.png` at full size: `0_body.png` (whole silhouette), `1_belly.png`, `2_outline.png` (ink, white when tinted) | Mirrored to `app/CrocApp/AppIcon.icon`, which is the copy Xcode builds |
| `favicons/` | Favicon set generated from the app icon on realfavicongenerator.net: `favicon.ico`, `favicon-96x96.png`, `apple-touch-icon.png`, `web-app-manifest-{192x192,512x512}.png`, `site.webmanifest` | Source of truth. The served copy is `web/landing/assets/img/favicon/`; the docs site references that copy. Recipe: `design/brand.md` → Favicon recipe |
| `dmg-background.tiff` | DMG Finder window background, dark, 660×400 at 1x and 2x | `scripts/build-dmg.sh`. Spec: `design/components.md` → DiskImage |
| `github-social-preview.png` | 1280×640, dark; same layout as `web/landing/assets/img/og.jpg` | Only the repository's GitHub Settings → Social preview, uploaded by hand. No file references it |
| `screenshots/{mac,iphone}/<screen>-{light,dark}.png` | Full-resolution captures of only the screens something shows (list: `docs/knowledge/screenshots.md` → Where they are used), published from `build/screenshots/` by `scripts/capture-screenshots.sh --copy-web` | README; sources of the web copies |

The App Store upload sets are not here: the capture script writes them to `build/screenshots/app-store/<class>/` (gitignored) for each submission.

## Rules

- `mascot.png` is never edited. Re-cut derivatives from it instead (recipes in `design/brand.md`).
- Change the icon in `CrocAppIcon.icon`, with Icon Composer, then copy it over the app's copy so the two stay identical: `rsync -a --delete assets/CrocAppIcon.icon/ app/CrocApp/AppIcon.icon/`. Check a render without opening Xcode: `"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" assets/CrocAppIcon.icon --export-image --output-file icon.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1` (renditions include `Dark` and `TintedDark`).
- After changing the icon, regenerate `favicons/` (recipe in `design/brand.md`), then copy the set to `web/landing/assets/img/favicon/`.
- `dmg-background.tiff` is a multi-representation TIFF, built with `tiffutil -cathidpicheck bg.png bg@2x.png -out dmg-background.tiff`. Change `design/components.md` → DiskImage and `scripts/build-dmg.sh` together with it.
- After replacing `github-social-preview.png`, upload it again in the repository settings. GitHub keeps its own copy.
- Screenshots come only from `scripts/capture-screenshots.sh`, driving real Debug builds with the mock data described in `docs/knowledge/screenshots.md`. It writes every capture to `build/screenshots/`. Never hand-edit, crop or retouch one; re-run the script, for a single screen if that is all that changed.
- Pages use WebP copies, not these files: `web/docs/screenshots/` and `web/landing/assets/img/screenshots/`. After a capture, run `scripts/capture-screenshots.sh --copy-web` (needs `cwebp`): it refreshes the published PNGs here from `build/screenshots/`, then the WebPs.
- To publish a new screen, copy its pair from `build/screenshots/` into `screenshots/`, run `cwebp` once into the web folder at the page's size, and reference it. `scripts/verify-docs.sh` fails on a PNG here that nothing shows.
- When app UI changes, recapture the affected screens, and all of them after a broad visual change.
