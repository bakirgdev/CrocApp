# Screenshots

Every image in `assets/screenshots/` comes out of `scripts/capture-screenshots.sh`, driving real Debug builds of the shipping app. Nothing is a mockup, a crop, or a retouch. Two sets:

- **Main set**, `assets/screenshots/*.png`: twenty-five shots, each captured light and dark at 2x, twelve macOS and thirteen iOS. Used by the README, the docs site and the landing page.
- **Store set**, `assets/screenshots/store/<class>/NN-name.png`: the App Store Connect uploads, light only, PNG with no alpha channel, numbered in upload order. Not copied to the web.

The script's header comment is the manifest; the `want <name>` blocks are the shot list. `scripts/capture-screenshots.sh --list` prints both sets with every output file and expected size, without touching the display.

Re-run everything with `scripts/capture-screenshots.sh`, or one shot with `scripts/capture-screenshots.sh mac-home` (still both appearances, plus its store files if it has any). A full run takes over the display for roughly forty minutes (the old eighteen shots took fifteen) and flips the system appearance, restoring it on exit including on failure. A single-shot run is minutes, except that the build steps always run first.

After a run, refresh the web copies with `scripts/capture-screenshots.sh --copy-web`. It overwrites only the files already present in `web/docs/static/img/screenshots/` and `web/landing/assets/img/screenshots/` (to publish a new shot, copy its file there once), so it is safe to repeat. Store-size files stay only under `assets/screenshots/store/`.

## The main set

| Platform | Shots |
|---|---|
| macOS | `mac-home`, `mac-send-files`, `mac-send`, `mac-receive`, `mac-transferring`, `mac-done`, `mac-history`, `mac-howitworks`, `mac-settings`, `mac-advanced`, `mac-stored`, `mac-conflict` |
| iOS | `ios-home`, `ios-onboarding`, `ios-send`, `ios-send-code`, `ios-receive-code`, `ios-receive`, `ios-history`, `ios-settings`, `ios-advanced`, `ios-transferring`, `ios-stored`, `ios-conflict`, `ios-done` |

The seven additions to the original eighteen are the 1.0 screens: on both platforms the Advanced settings page (`*-advanced`), the "Link ready" result of Send as link (`*-stored`) and the incoming preview with Keep Both / Replace (`*-conflict`); on iOS `ios-send-code` (the parked "Ready to send" code and QR, the twin of `mac-send`). The original eighteen keep their names. All new shots need no new harness route: they combine the existing `--screen`, `--hold`, `--auto-*` flags.

## The store set

Sizes are from Apple's App Store Connect screenshot specifications, https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications (fetched 2026-10-15). Up to ten screenshots per size, `.png`, `.jpg` or `.jpeg`, no alpha channel or transparency. The page names iPhone classes by display type, not inches, so the inch labels below are the nearest common names, not Apple's wording.

| Class dir | Pixels | How it is produced | Why |
|---|---|---|---|
| `iphone-6.3` | 1206x2622 | the main set's light iOS shots on the `iPhone 17 Pro` simulator, passed through `imgtool flatten` | the "Dynamic Island, medium" class, the one iPhone size Apple requires |
| `iphone-6.9` | 1320x2868 | a throwaway `iPhone 17 Pro Max` simulator, one extra light pass | the "Dynamic Island, large" class. Optional itself, but without it Apple requires the 1284x2778 / 1242x2688 size instead, so providing it also settles that |
| `ipad-13` | 2064x2752 | a throwaway `iPad Pro 13-inch (M5)` simulator, one extra light pass | the 13-inch class, required because the app runs on iPad |
| `mac` | 2880x1800 | the window capture composed on a canvas | 16:10 Mac size, required for Mac apps |

The first three are native pixels at 3x/2x, no scaling. 1206x2622 is confirmed against the existing `ios-*` shots on `iPhone 17 Pro`. The other two simulator sizes (iPhone 17 Pro Max 1320x2868, iPad Pro 13-inch 2064x2752) come from the device specs, not from a capture on this machine: the script screenshots each throwaway simulator right after boot and fails before any shot if the size is off.

The simulators are created with `xcrun simctl create "CrocApp Shots <class>" <device type id>` and deleted when the pass ends and on exit, including on failure. The device types default to `PHONE_TYPE=com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max` and `PAD_TYPE=com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-16GB`, both present in Xcode 27 here (`iPad-Pro-13-inch-M4-16GB` also exists); override the variables if a toolchain ships neither. The script checks they are installed before it builds.

**Mac.** A window capture is 1120x1400 (a 560x700 pt window at 2x), not 16:10, and a stretched window would be dishonest. `imgtool compose` (a small Swift file the script compiles; there is no ImageMagick on the machine) draws the untouched window at 1x, centred, with a soft shadow, on a flat blue-grey gradient canvas of exactly 2880x1800. `mac-menubar` is the one composed pair: the home window and the menu-bar popover side by side. Needs a Retina main display so the capture comes out at 2x; the composer rejects an image that does not fit the canvas.

**No alpha.** Window captures and simulator screenshots carry an alpha channel. `imgtool` draws into a `noneSkipLast` bitmap context, which writes a PNG with no alpha channel at all (flattening over a colour alone would keep the channel). The last step of every run, `verify_store`, runs `sips -g pixelWidth -g pixelHeight -g hasAlpha` on every store file and fails on any size mismatch or `hasAlpha: yes`; after a full run it also fails on a missing file.

### Upload order

| # | iPhone 6.3, iPhone 6.9, iPad 13 | Mac |
|---|---|---|
| 01 | `send` (staged files) | `send-files` |
| 02 | `send-code` (code and QR) | `send` (code and QR) |
| 03 | `transferring` | `transferring` |
| 04 | `receive` (incoming preview) | `done` |
| 05 | `stored` (Link ready) | `stored` |
| 06 | `history` | `history` |
| 07 | `conflict` (Keep Both / Replace) | `conflict` |
| 08 | `advanced` | `advanced` |

A full run clears `assets/screenshots/store/` first, so a renumbered shot cannot leave a stale file.

## Known soft spots in the 1.0 shots

None of these has run yet; the first real run proves or breaks them.

- **`*-stored` shows a loopback link.** "Send as link" goes to a local `croctest store-server` (as `verify-app-mac.sh` does), never a real server, so the link and QR name `127.0.0.1`. The script builds `crocmobile/cmd/croctest`, so it needs Go.
- **`mac-settings` and `mac-advanced` window titles.** Settings is now a General/Advanced `TabView`, and the window title probably follows the selected tab. The script accepts `CrocApp Settings`, `General` and `Settings` for the first and clicks the `Advanced` toolbar button through System Events for the second. If macOS 26 names these differently, `shoot_window` fails with the title it wanted.
- **No menu-bar shot.** The menu-bar popover cannot be captured reliably: macOS hides the status item when the menu bar is full, so no script can click it. The script has no `mac-menubar` shot; take one by hand if the listing needs it.
- **`*-conflict`** pre-places `Presentation.pdf` and `Cover-Art.png` in the receive folder, then parks the incoming preview with `--hold`. The conflict scan has to finish inside the wait (20 s macOS, 30 s iOS).

## How a screen is held still

The app is driven by the DEBUG-only flags in `AutoVerify.swift`, not by clicking:

| Flag | Does |
|---|---|
| `--screen ROUTE` | pushes `AppRouter.shared.path` on launch. ROUTE is one of `home`, `send`, `receive`, `settings`, `advanced` (Settings with the Advanced page pushed, iOS), `howItWorks`, `history`, `onboarding`; `home` and `onboarding` push no path (`onboarding` forces the first-run sheet instead). Without the flag the harness runs the transfer while the UI sits on HomeView |
| `--stage PATH` | preloads the Send screen's file list, repeatable. Only takes effect with `--screen send` |
| `--seed-history` | writes sample `TransferRecord`s into the in-memory store |
| `--hold` | parks at the incoming prompt instead of auto-accepting |
| `--auto-store-send PATH` with `--store-server URL --store-downloads N` | the `*-stored` shots: uploads to the local store server and parks on the Link ready screen |

These are orthogonal to the `--auto-*` transfer modes and to each other, which is what lets one launch produce "receiving, mid-transfer". `isHarnessRun` covers `--screen` too, so every capture launch gets reset settings and an in-memory history and can never touch real user state. In Release the whole thing compiles to a no-op.

## The constraints that shaped it

**Both ends of a capture transfer are this machine.** croc's local path wins its race against the relay and moves data at ~390 MB/s, so no payload is big enough to photograph mid-flight. `mac-transferring` passes `--relay croc.schollz.com:9009`. That equals croc's old default (`models.DEFAULT_RELAY`), which crocmobile treats as "not custom", so the transfer goes through the public relay pool, not that host. The flag still sets `harnessDisableLocal`, so the LAN path is off and the transfer runs at internet speed. Where the CLI is the sender (`ios-transferring`) `--throttleUpload` pins the rate directly, which is steadier — but budget for the handshake, which eats most of the first half minute before a single byte moves.

**Code prefixes collide across runs, not just within one.** The relay hashes a code's first four characters into a room name (these are legacy-format codes like `NNNN-word`; a three-word code uses its first word). Hardcoded prefixes made re-capturing a shot fail against its own previous run's room. The script derives every code from one random base plus an explicit offset; the offset is explicit because `$(code ...)` runs in a subshell and an incrementing counter would not survive between calls.

**Locale leaks into the pixels.** Byte counts and relative dates follow the host locale, so both launchers pass `-AppleLocale en_US -AppleLanguages '(en)'`. Without it the shots read "8,8 MB".

**An unfocused macOS window photographs wrong** — grey traffic lights, dimmed title. Every macOS capture raises the app first.

**`screencapture` needs a CGWindowID**, which no shell command hands out. The script compiles a throwaway Swift file calling `CGWindowListCopyWindowInfo`. AppleScript's window ids are AX ids and cannot be used here.

**Documents is the iOS receive folder**, so files a previous run received make the next incoming preview carry an "already exist and will be replaced" warning. Both capture functions delete the payload names first.

**A long-lived simulator stops reaching the relay.** After a few dozen transfers the app sits on "Starting…" forever while a plain CLI-to-CLI transfer on the same machine still works. `xcrun simctl shutdown` then `boot` clears it. Suspect this first when one iOS shot fails repeatedly and nothing about it changed.

## Where they are used

Seven pairs are referenced; the remaining eighteen main-set pairs and the whole store set are captured and unused by the web (`../known-issues.md`). The store set is for App Store Connect only.

- Root `README.md`: `mac-send`, `ios-receive`, `mac-settings`, via `<picture>` elements that swap on the viewer's GitHub theme.
- Docs site: copies under `web/docs/static/img/screenshots/`, one pair per page — `mac-send` (first-transfer), `mac-send-files` (sending), `ios-receive` (receiving), `mac-settings` (settings-and-trust), `ios-settings` (power-options), `mac-history` (history), `ios-onboarding` (index). `.md` there is CommonMark (`docusaurus.config.ts` sets `markdown.format: 'detect'`), so `<ThemedImage>` is unavailable; the pages use GitHub's `#gh-light-mode-only` / `#gh-dark-mode-only` fragments and `src/css/custom.css` supplies the rule that makes them mean anything. That keys off Docusaurus's theme toggle rather than the OS setting.
- Landing hero: `web/landing/assets/img/screenshots/mac-send-*`, two `<img>` elements swapped by CSS. Not a `<picture>` with `prefers-color-scheme`, because the header's toggle pins `[data-theme]` and a media query would ignore it. This replaced a CSS-drawn mockup of the same screen.

A copy is a copy: changing a shot means re-running the script and `scripts/capture-screenshots.sh --copy-web`.
