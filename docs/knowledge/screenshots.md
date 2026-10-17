# Screenshots

Every image in `assets/screenshots/` comes out of `scripts/capture-screenshots.sh`, driving real Debug builds of the shipping app. Nothing is a mockup, a crop, or a retouch. The script header is the manifest; `scripts/capture-screenshots.sh --list` prints every output file and size without touching the display.

```
assets/screenshots/
  mac/SCREEN-{light,dark}.png      per-window capture, 2x, real window shape
  iphone/SCREEN-{light,dark}.png   iPhone 17 Pro Max simulator, 1320x2868, 9:41 status bar
  ipad/SCREEN-{light,dark}.png     iPad Pro 13-inch (M5) simulator, 2064x2752, 9:41 status bar
  app-store/{iphone,ipad,mac}/NN-SCREEN.png   light only, PNG, no alpha, Apple's exact sizes
```

## Running it

```
scripts/capture-screenshots.sh                 # everything; empties assets/screenshots/ first
scripts/capture-screenshots.sh ipad            # one device
scripts/capture-screenshots.sh mac history     # devices and screens combine; both appearances
scripts/capture-screenshots.sh --copy-web      # refresh the web copies, no display needed
```

A run takes over the display and flips the system appearance twice, restoring it on exit including on failure. The terminal that runs it needs Screen Recording, Accessibility and Automation of System Events; the preflight names whichever is missing before anything is built. It creates two simulators ("CrocApp Shots iPhone", "CrocApp Shots iPad"), starts a croc relay and, for `stored-link`, a store server, and removes all of them on exit. Needs Go (the store server comes from `crocmobile/cmd/croctest`) and a v11 `croc` (default `/opt/homebrew/bin/croc`, override with `CROC`; crocmobile pins v11.5.4).

After a run, refresh the web copies with `--copy-web`. It overwrites only the files already present under `web/docs/static/img/screenshots/` and `web/landing/assets/img/screenshots/` (same `mac/`, `iphone/`, `ipad/` subfolders); to publish a new shot, copy its file there once.

## The screens

One vocabulary across devices, kebab-case, named for the state shown.

| Screen | State |
|---|---|
| `onboarding` | first-run welcome (iPhone and iPad only; on macOS it is a sheet whose window photographs with grey traffic lights) |
| `home` | Send and Receive |
| `send-files` | three staged files |
| `send-code` | "Ready to send": code phrase and QR |
| `sending` | mid-transfer, 40%, 6 MB/s |
| `receive-code` | empty Receive screen |
| `receive-incoming` | incoming preview, Decline / Accept |
| `receive-conflict` | incoming preview with Keep Both / Replace |
| `receiving` | mid-transfer, 40%, 6 MB/s |
| `receive-done` | "Transfer complete" |
| `stored-link` | "Link ready" after Send as link |
| `history` | ten seeded records |
| `how-it-works` | the trust screen |
| `settings` | Settings (macOS: General tab) |
| `settings-advanced` | Advanced settings (macOS: Advanced tab) |

The App Store subset is `send-files`, `send-code`, `sending`, `receive-incoming`, `receiving`, `receive-done`, `stored-link`, `history`, `settings`, `how-it-works`, in that upload order, identical on all three devices. Change `STORE_SCREENS` in the script to reorder (at most ten).

## App Store sizes

From Apple's screenshot specifications, https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications (fetched 2026-10-16). `.png`, `.jpg` or `.jpeg`, no alpha channel, up to ten per size. The page names iPhone classes by display type, not inches.

| Device dir | Pixels | Apple's class | Notes |
|---|---|---|---|
| `iphone` | 1320x2868 | Dynamic Island (large) | iPhone 17 Pro Max simulator, native pixels |
| `ipad` | 2064x2752 | 13" display | required because the app runs on iPad; iPad Pro 13-inch (M5) simulator |
| `mac` | 2880x1800 | 16:10, one of four accepted sizes | the window composed on a canvas |

Open points against the current page:

- It lists Dynamic Island (medium), 1206x2622 or 1179x2556, as the one required iPhone class, and Dynamic Island (large) as optional. This set provides only the large size, on the page's statement that the highest resolution is scaled down. Whether App Store Connect accepts a large-only iPhone set for submission was not verified; if it asks for the medium size, scale these or capture on an iPhone 17 Pro (1206x2622).
- It lists iPhone Duo (outer 1398x2034, inner 2007x2853) screenshots as mandatory from April 2027 for apps built with the iOS 27.1 SDK or later. Not captured here.
- The previous set had a separate 6.3-inch class from an iPhone 17 Pro simulator. It is dropped: one iPhone simulator and one iPad simulator produce both the main and the store set.

**Mac.** A window capture is typically 1120x1400 (a 560x700 pt window at 2x), not 16:10, and a stretched window would be dishonest. `imgtool compose` (`scripts/screenshots/imgtool.swift`) draws the untouched window at 1x, centred, with a soft shadow, on a flat blue-grey gradient canvas of exactly 2880x1800. Needs a Retina main display so the capture comes out at 2x.

**No alpha.** Window captures and simulator screenshots carry an alpha channel. `imgtool` draws into a `noneSkipLast` bitmap context, which writes a PNG with no alpha channel at all (flattening over a colour alone would keep the channel). The last step of every run runs `sips -g pixelWidth -g pixelHeight -g hasAlpha` on every store file and fails on a wrong size, an alpha channel, a missing file, or more than ten files per device.

## How a screen is held still

The app is driven by DEBUG-only launch flags in `app/CrocApp/Support/AutoVerify.swift`, not by clicking. In Release the harness compiles to a no-op. Every harness launch gets reset settings and an in-memory history, so it never touches real user state.

| Flag | Does |
|---|---|
| `--screen ROUTE` | navigates on launch: `home`, `send`, `receive`, `settings`, `advanced`, `howItWorks`, `history`, `onboarding` |
| `--stage PATH` | preloads the Send list, repeatable, with `--screen send` |
| `--seed-history` | fills the in-memory history with showcase records |
| `--hold` | parks at the incoming prompt instead of auto-accepting |
| `--auto-send PATH --code CODE`, `--auto-receive CODE` | run a real transfer |
| `--auto-store-send PATH --store-server URL --store-downloads N` | upload to the local store server and park on "Link ready" |
| `--relay ADDR`, `--relay-password PW` | use a custom relay (also switches the LAN race off) |
| `--shown-relay default` | make the trust UI name the public relay, whatever `--relay` says |
| `--throttle RATE` | cap the app's upload rate, e.g. `6m` |

The harness answers in the app's Documents folder, and the script polls instead of sleeping:

| File | Meaning |
|---|---|
| `verify-ready.txt` | the requested screen has been on display for a second (push animation done) |
| `verify-phase.txt` | the transfer's current phase: `waiting`, `incoming conflicts=N`, `transferring percent=N`, `done`, ... |
| `verify-code-ready.txt` | a send has its code, so a receiver may start |
| `verify-result.txt` | `ok success=<bool>` or `error <msg>` |
| `verify-store-link.txt` | the stored link |

The one fixed wait left is `settle` (one second): a view needs a frame or two to draw a state it was just given, and nothing signals that. The same goes for the pause after raising a macOS window, which is a title bar repaint.

## The constraints that shaped it

**A local relay.** `start_relay` runs `croc relay` on `127.0.0.1` with a random block of five ports and a random password (in the environment as `CROC_PASS`, in the app's launch arguments as `--relay-password`; both die with the run). Every transfer shot goes through it, so a run needs no internet for the transfers and cannot collide with anyone's relay room. The croc CLI peers still make their own update check to GitHub. The relay runs with `--debug` because its "room has first peer" line is the signal that a sender is registered; the receiver must join after that, or the PAKE handshake is corrupted. This leans on croc v11's log wording, so the script refuses another major version.

**Codes are random.** `new_code` builds `NNNN-word-word-word` from `/dev/urandom` with three distinct words. The relay hashes a code's first four characters into a room name, so the four digits are unique within a run.

**Mid-transfer shots.** Localhost moves 150 MB in under a second, so nothing is photographable unthrottled. The sender is throttled (`--throttle 6m` on the app, `--throttleUpload 6m` on the CLI), and at 40% the script sends `SIGSTOP` to the peer. Both ends then stand still, so the bar and the rate stay as they are. `sending` has the app as sender and a CLI receiver; `receiving` is the mirror.

**macOS launch arguments come in pairs.** AppKit reads `--flag value` as a defaults pair and any bare leftover token as a file to open, which suppresses the window. A flag without a value (`--hold`, `--seed-history`) must come last, and a new flag should take a value.

**Locale leaks into the pixels.** Both launchers pass `-AppleLocale en_US -AppleLanguages '(en)'`; without it byte counts read "8,8 MB".

**An unfocused macOS window photographs wrong** (grey traffic lights). Each launch raises the app by pid.

**`screencapture` needs a CGWindowID**, which `scripts/screenshots/window.swift` reads from `CGWindowListCopyWindowInfo` (AppleScript's window ids are AX ids and cannot be used).

**Documents is the receive folder.** Files a previous shot received make the next incoming preview carry an "already exist" warning, so `clean_docs` removes the payload names before every shot. `receive-conflict` then pre-places two of them on purpose.

**The status bar shows 09:41:00.** `simctl status_bar --time` takes an ISO instant with fractional seconds (the plain `9:41` form is not accepted by every runtime), and the iOS 27 simulator renders it with seconds. Not fixable from the script.

**Simulator runtime.** A newer runtime can lack older device types (iOS 27.1 here has neither the iPhone 17 Pro Max nor the iPad Pro 13-inch M5), and `simctl create` without a runtime picks the oldest. The script tries installed runtimes newest first.

**A long-lived simulator stops reaching the relay.** Not an issue now that the run creates and deletes its own simulators; if a manual simulator sits on "Starting..." forever, `simctl shutdown` then `boot` clears it.

## Mock data and showcase conventions

For any future screenshot work:

- **Real files, generated at run time, never committed.** `scripts/screenshots/payload.swift` renders a three-page PDF (`Quarterly-Report.pdf`) and a JPEG (`Ridge-Sunrise.jpg`); `Meeting-Notes.md` is a heredoc; `Design-Assets.zip` comes from `ditto`. File rows show a symbol by file type, so real extensions matter more than real content. Large transfer payloads (`Project-Archive.zip`, `Field-Recordings.zip`, 150 MB) are random bytes under a believable name, because only the name is ever shown.
- **Neutral, pleasant names.** No personal names, no real people or companies, no real hosts (`store.example.org` for the stored-link record). Names read like work files.
- **History is a showcase list** (`seedHistory` in `AutoVerify.swift`): sends and receives, completed, declined, failed and cancelled, a text snippet, a stored link with its expiry, file counts of one to four, ages from twelve minutes to five weeks. Names match the payload names where a payload exists, and sizes match the real payloads, so the incoming preview and the history agree.
- **The code on screen is random per run** and never a real one.
- **What is on screen must be true of a default setup.** The relay is local, but the trust UI is pinned to the default relay (`--shown-relay default`) so the browser-receive note and the pill read as a normal install. The `stored-link` shot names `127.0.0.1` because it goes to a local store server.
- **Same states on every device**, so a screen name means one thing everywhere. Add a screen by adding its name to `SCREENS`, a case to `capture_screen`, and, for macOS, its window title to `mac_titles`.
- **Keep shots free of transient UI**: no "Starting...", no spinners that mean "slow", no permission alerts, no focus carets. Wait on a harness signal, not a delay.

## Known soft spots

- **`stored-link` is cut off at the bottom** on iPhone: the result screen is taller than the screen and the Done button peeks out. That is the app's layout, not the capture.
- **`ipad/` is the phone layout stretched.** See `../known-issues.md`.
- **No menu-bar shot.** The menu-bar popover cannot be captured reliably: macOS hides the status item when the menu bar is full, so no script can click it.
- **`mac/onboarding` is not captured** (see the table above).

## Where they are used

Seven pairs are referenced; the rest and the whole `app-store/` set are captured and unused by the web (`../known-issues.md`).

- Root `README.md`: `mac/send-code`, `iphone/receive-incoming`, `mac/settings`, via `<picture>` elements that swap on the viewer's GitHub theme.
- Docs site: copies under `web/docs/static/img/screenshots/`, one pair per page: `mac/send-code` (first-transfer), `mac/send-files` (sending), `iphone/receive-incoming` (receiving), `mac/settings` (settings-and-trust), `iphone/settings` (power-options), `mac/history` (history), `iphone/onboarding` (index). `.md` there is CommonMark (`docusaurus.config.ts` sets `markdown.format: 'detect'`), so `<ThemedImage>` is unavailable; the pages use GitHub's `#gh-light-mode-only` / `#gh-dark-mode-only` fragments and `src/css/custom.css` supplies the rule that makes them mean anything. That keys off Docusaurus's theme toggle rather than the OS setting.
- Landing hero: `web/landing/assets/img/screenshots/mac/send-code-*`, two `<img>` elements swapped by CSS. Not a `<picture>` with `prefers-color-scheme`, because the header's toggle pins `[data-theme]` and a media query would ignore it.

A copy is a copy: changing a shot means re-running the script and `scripts/capture-screenshots.sh --copy-web`.
