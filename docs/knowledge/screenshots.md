# Screenshots

Every image in `assets/screenshots/` comes out of `scripts/capture-screenshots.sh`, driving real Debug builds of the shipping app. Nothing is a mockup, a crop, or a retouch. Eighteen shots, each captured light and dark at 2x: nine macOS, nine iOS. The script's header comment is the manifest; the `want <name>` blocks are the shot list.

Re-run the whole set with `scripts/capture-screenshots.sh`, or one shot with `scripts/capture-screenshots.sh mac-home` (still both appearances). It takes over the display for roughly fifteen minutes and flips the system appearance, restoring it on exit including on failure.

## How a screen is held still

The app is driven by the DEBUG-only flags in `AutoVerify.swift`, not by clicking:

| Flag | Does |
|---|---|
| `--screen ROUTE` | pushes `AppRouter.shared.path` on launch. Without it the harness runs the transfer while the UI sits on HomeView |
| `--stage PATH` | preloads the Send screen's file list, repeatable |
| `--seed-history` | writes sample `TransferRecord`s into the in-memory store |
| `--hold` | parks at the incoming prompt instead of auto-accepting |

These are orthogonal to the `--auto-*` transfer modes and to each other, which is what lets one launch produce "receiving, mid-transfer". `isHarnessRun` covers `--screen` too, so every capture launch gets reset settings and an in-memory history and can never touch real user state. In Release the whole thing compiles to a no-op.

## The constraints that shaped it

**Both ends of a capture transfer are this machine.** croc's local path wins its race against the relay and moves data at ~390 MB/s, so no payload is big enough to photograph mid-flight. `mac-transferring` passes `--relay croc.schollz.com:9009`, which also sets `harnessDisableLocal` and forces internet speed. Where the CLI is the sender (`ios-transferring`) `--throttleUpload` pins the rate directly, which is steadier — but budget for the handshake, which eats most of the first half minute before a single byte moves.

**Code prefixes collide across runs, not just within one.** The relay hashes a code's first four characters into a room name. Hardcoded prefixes made re-capturing a shot fail against its own previous run's room. The script derives every code from one random base plus an explicit offset; the offset is explicit because `$(code ...)` runs in a subshell and an incrementing counter would not survive between calls.

**Locale leaks into the pixels.** Byte counts and relative dates follow the host locale, so both launchers pass `-AppleLocale en_US -AppleLanguages '(en)'`. Without it the shots read "8,8 MB".

**An unfocused macOS window photographs wrong** — grey traffic lights, dimmed title. Every macOS capture raises the app first.

**`screencapture` needs a CGWindowID**, which no shell command hands out. The script compiles a throwaway Swift file calling `CGWindowListCopyWindowInfo`. AppleScript's window ids are AX ids and cannot be used here.

**Documents is the iOS receive folder**, so files a previous run received make the next incoming preview carry an "already exist and will be replaced" warning. Both capture functions delete the payload names first.

**A long-lived simulator stops reaching the relay.** After a few dozen transfers the app sits on "Starting…" forever while a plain CLI-to-CLI transfer on the same machine still works. `xcrun simctl shutdown` then `boot` clears it. Suspect this first when one iOS shot fails repeatedly and nothing about it changed.

## Where they are used

Seven pairs are referenced; the remaining eleven are captured and unused (`../known-issues.md`).

- Root `README.md`: `mac-send`, `ios-receive`, `mac-settings`, via `<picture>` elements that swap on the viewer's GitHub theme.
- Docs site: copies under `web/docs/static/img/screenshots/`, one pair per page, in English and all five locale trees — `mac-send` (first-transfer), `mac-send-files` (sending), `ios-receive` (receiving), `mac-settings` (settings-and-trust), `ios-settings` (power-options), `mac-history` (history), `ios-onboarding` (index). `.md` there is CommonMark (`docusaurus.config.ts` sets `markdown.format: 'detect'`), so `<ThemedImage>` is unavailable; the pages use GitHub's `#gh-light-mode-only` / `#gh-dark-mode-only` fragments and `src/css/custom.css` supplies the rule that makes them mean anything. That keys off Docusaurus's theme toggle rather than the OS setting.
- Landing hero: `web/landing/assets/img/screenshots/mac-send-*`, two `<img>` elements swapped by CSS. Not a `<picture>` with `prefers-color-scheme`, because the header's toggle pins `[data-theme]` and a media query would ignore it. This replaced a CSS-drawn mockup of the same screen.

A copy is a copy: changing a shot means re-running the script and re-copying to both web surfaces.
