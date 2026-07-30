# Known issues

Triaged defects, accepted papercuts, and deferred work in the shipped app. Every item here was found during review and consciously not fixed. None block V1 unless marked.

This exists so a session does not re-discover and re-report the same thing. If you fix one, delete the line. If you decide one is permanent, move it to "Accepted" and say why.

Engine and bridge invariants live in `knowledge/crocmobile-bridge.md`; UI state-machine facts in `knowledge/app-ui-architecture.md`.

## Blocking release

- **Notarization is not real.** `scripts/build-devid.sh` stops at `syspolicy_check distribution`, a dry run. No `notarytool submit --wait`, no `stapler staple`. Until it lands, a downloaded build shows Gatekeeper's unidentified-developer refusal on first launch (`knowledge/tooling.md`).
- **The release pipeline ships an ad-hoc signature.** `.github/workflows/release.yml` builds with `CODE_SIGN_IDENTITY=-` because no Developer ID certificate exists. Enough for arm64 to execute, not enough for Gatekeeper on a downloaded copy: the first launch needs System Settings > Privacy & Security > Open Anyway. Accepted for v0.9.9, which is a symbolic release (ADR 0032); a blocker for anything after it.
- **No Developer ID Application certificate is installed.** Only `Apple Development` is present, so `scripts/build-devid.sh` stops at `DEVID-PENDING-CERT` before it ever reaches the notarization step above. Owner action: create one at developer.apple.com (Certificates > Developer ID Application).
- **`ExportOptions-MAS.plist` is committed but never exercised.** First real MAS export is its first test.
- **`actions/attest-build-provenance` runs before the DMG would be stapled** (`.github/workflows/release.yml`, "Attest build provenance" step). Harmless today, since nothing staples: the attested hash is the final hash. Once notarization lands, `stapler staple` rewrites the DMG after this step and the attestation would cover a pre-staple hash. Move the step after stapling when that happens.

## Engine (crocmobile)

- **`xfer()` has no watchdog.** If croc ever blocks past context cancel and prompt-pipe close, `activeMu` is held for the process's lifetime and every later transfer returns "another transfer is active". Deliberately not fixed: forcing the lock open while croc is still running would let two sessions mutate the same process-global state (`os.Chdir`, stdin/stdout swaps).
- **`poll()` reads `croc.Client` scalar and slice fields with no synchronization** (croc's own goroutines write them unguarded). Degrades to inconsistent progress numbers; bounds-checked (`session.go`'s `progressJSON`) so it cannot panic.

## Transfer controller

- Auto-accept against a remote sender running `--ask` auto-declines, and the resulting copy blames the wrong side ("the other side declined").
- `blockedAutoAccept` is mostly dormant — croc has sanitised incoming names since v10 — and a tiny transfer can reach `.done` before the block is evaluated.
- The async conflict scan's write-back guard is shape-based (`if case .incoming`), not generation-based: a stale scan from a previous transfer could in principle land on a new `.incoming`.
- The resend condition (`record.isSend && !record.isText && !record.bookmarks.isEmpty`) is duplicated across `HistoryView`'s context-menu and swipe-action sites, not shared.
- Cross-flow status bleed: an active Send renders on the Receive screen, because `isActive` is direction-agnostic. One-at-a-time is still enforced.
- No Cancel during `.incoming` — Decline is the only exit, and the terminal event can lag while croc auto-reconnects.

## Settings and trust

- Relay password is stored in plaintext `UserDefaults`. Keychain is the fix.
- When both relay addresses are customised, both are sent. The croc CLI blanks `relay6` in that case. Deliberate divergence, revisit if a peer ever disagrees.

## History

- `HistoryStore.clear()` uses `delete(model:)`. Whether a live `@Query` updates from it is unconfirmed in manual QA; fallback is a fetch-and-delete loop.
- Up to 200 synchronous `bookmarkData` calls run on the main actor at send tap.
- `blockedAutoAccept` transfers record as `.cancelled`.
- `AutoVerify` duplicates the history-write path.

## iOS

- A queued `BGContinuedProcessingTask` request is not cancelled when the transfer ends before the system adopts it.
- `backgroundExpired` is ignored in `run()`'s catch, so an expiry that surfaces as a thrown error gets generic copy.
- Manifest-name validation in `ShareInbox` does not match `ReceivedName`'s rules.
- "Open in Files" silently no-ops for provider-picked folders (`shareddocuments://` resolves local paths only). Consider hiding the button there.
- `UIFileSharingEnabled` is declared twice.
- The staged-files sheet is only offered on the next foregrounding, and starting a send from it does not route to a status view.
- Onboarding's `onDismiss` re-offer of the staged sheet has no `!controller.isActive` gate.

## macOS

- Dock-drop URLs queue invisibly: no badge, no route once the running transfer completes. The user has to visit Send to find them.
- `isBusy` mirrors `controller.isActive` one cycle late.
- `SendView`'s drop handler returns `true` even when every dropped file was already staged.
- `createDirectory` failure is swallowed in `OutputFolderStore.defaultFolder`.
- The receive-folder guard is duplicated across the iOS and macOS `doneView` branches.
- `pendingSendURLs` deduplicates against already-picked URLs but not within a single dropped batch.
- `AppRouter` is a singleton with no reset hook; multiple windows share one navigation path.
- **`LocalNetworkChecker` is a no-op stub on macOS.** `app/CrocApp/Platform/LocalNetworkChecker.swift`'s macOS branch does nothing, so `status` never leaves `.unknown` and `.denied` is unreachable there. `TransferStatusView` gates the whole local-network-denied banner on `status == .denied`, so on macOS the banner never renders — dead code, not a missing feature flag. macOS 15+ does have a Local Network privacy pane, so a real probe is possible but unwritten; no "Open Settings" button was added for it since that would read as live when it cannot be reached. Either gate the banner `#if os(iOS)` to say so explicitly, or give `LocalNetworkChecker` a real macOS implementation.

## Design system

- `CodeField` and `FileRow` from `design/components.md` are still not implemented as their own components.
- No shadow token exists in `DesignTokens.swift`. The QR frame (`design/components.md` → QRFrame) specs `--shadow-md`, but `QRCodeView` currently has no shadow at all; the macOS drop overlay uses `.glassEffect()` instead, which is correct per `design/materials-motion.md` ("prefer the material's own depth where one exists") and needs no manual shadow.

## Landing page

- **The primary CTA still resolves to nothing installable.** "Download" in the hero scrolls to three channels: two unlinked store badges and a GitHub releases link that 404s until there is a release. Honest, but the page's strongest call to action cannot yet be completed. The badges clear when the apps ship. The release link starts resolving on the first tag — and because v0.9.9 publishes as a normal release rather than a prerelease, it will point at an ad-hoc signed build that Gatekeeper refuses on first launch. The card's "Notarized DMG, signed with a Developer ID" line is wrong from that moment until notarization is real.
- **The disk image background is 1x only.** `create-dmg` documents png, gif and jpg backgrounds, so `assets/dmg-background.png` has no HiDPI representation and reads soft on a Retina display. Fixing it means a multi-representation TIFF, which `create-dmg` does not document and which has not been tested here.
- **`--content-max-width` on the hero mockup.** `design/brand.md` now carves an explicit exception for elements that depict the app, so this is documented rather than fixed — but the exception is narrow and easy to over-apply.
- **Store badges are inverted in dark mode with a CSS filter.** Apple ships black and white variants; the repo has black only. Inverting a black-on-transparent badge produces the white variant, but it is a filter over supplied artwork, not the supplied artwork.
- **`assets/banner.webp` is orphaned.** `design/brand.md` assigns it to the README header, the landing hero and the social card. It appears in none of them.
- **Three landing dependencies are hand-maintained and nothing checks them:** `llms.txt`'s release status, the footer's "last updated" date, and `og.jpg`. The first two have to be edited by hand on every release; `og.jpg` is deliberately a fixed hand-made asset and is not derived from the tokens.

## Docs site

- **No site search, on purpose.** A local search plugin is a new dependency and Algolia DocSearch is an external account plus a third-party request from a page that makes a privacy claim. Sixteen pages with a full sidebar and browser find-in-page is enough for now. Revisit if the page count grows.
- **The version dropdown is invisible.** Docusaurus hides `docsVersionDropdown` while only one version exists (ADR 0027); it stays hidden until the first `docusaurus docs:version` cut.
- **The five non-English locales are unreviewed machine-assisted drafts.** `bs`, `de`, `es`, `fr`, `ru` carry a warning admonition saying so, but nothing has native-speaker review yet (ADR 0028).
- **A landing-only change rebuilds the docs site too, and vice versa.** Both Pages workflows call `scripts/assemble-site.sh`, which builds both surfaces regardless of which one changed (ADR 0025).
- **A commit touching both `web/landing/` and `web/docs/` deploys twice.** Both workflows match, and the shared `github-pages` concurrency group with `cancel-in-progress: false` queues them rather than collapsing them, so the same artifact from the same SHA is built and published twice, back to back (observed at roughly 45s each). Harmless, since the second deploy is byte-identical to the first, and preferable to `cancel-in-progress: true`, which would abort a deploy mid-flight. The cost disappears if the two workflows are ever collapsed into one.
- **Most screenshots are captured but unused.** `scripts/capture-screenshots.sh` writes eighteen light/dark pairs; the README, the four guide pages and the landing hero between them reference four. The rest are carried in the repo without a reader.
- **No pull-request preview build.** `onBrokenLinks: throw` means a broken docs build is only discovered on push to `main`, when `landing.yml` or `docs.yml` runs and fails.
- **`web/landing/sitemap.xml` still lists only the landing URL.** `robots.txt` now advertises the Docusaurus-generated `/docs/sitemap.xml` as a second sitemap, so crawlers reach it, but the two sitemaps stay separate and the landing one is hand-maintained.

## Accepted

- **`mac-settings-*.png` shows a text caret in the Address field.** The macOS Settings scene gives its first `TextField` focus the moment it opens. Defocusing it needs a click somewhere else, and any click that lands outside the window drops it behind the clicked one before `screencapture` can run.
- **The macOS Settings window cannot be photographed whole.** It is a fixed 480x450 and refuses `AXSize` writes, so the shot ends mid-row wherever the form is longer than that. Scrolled to the top is the framing that at least starts on a section header.
- **`OutputFolderStore.select` silently no-ops if bookmarking fails.** Rare, and the alternative is an error path for a condition the user cannot act on.
- **Receive list identity is by file name.** Duplicate names within one transfer are a croc-level concern, not a UI one.
- **No explicit `stopScanning` when the QR scanner sheet dismisses.** VisionKit tears down with the view controller.
- **`.combine` on the transfer progress view may hide the percentage from VoiceOver.** Worth a real accessibility pass, not a spot fix.
- **Gesture-level flows are not machine-verified.** Drag-and-drop, camera QR, and taps have no XCUITest coverage by project rule. Verify them by hand.
