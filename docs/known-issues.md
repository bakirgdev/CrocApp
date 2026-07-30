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
- **`poll()` reads `croc.Client` scalar and slice fields with no synchronization** (croc's own goroutines write them unguarded). Degrades to inconsistent progress numbers; bounds-checked (`session.go`'s `progressSnapshot`) so it cannot panic.

## History

- `HistoryStore.clear()` uses `delete(model:)` on `container.mainContext` and saves immediately, from a `@MainActor` type. Apple documents that deletion via that method takes effect on the next save, which is satisfied, and the known `@Query` refresh asymmetry is specifically about *inserts* from a background `ModelActor` context, not main-context deletes — so it should be fine by construction. Nobody has actually watched the list empty without a relaunch; the repo has no harness that drives History. Fallback if it ever misbehaves is a fetch-and-delete loop.
- `AutoVerify` duplicates the history-write path.

## iOS

- `UIFileSharingEnabled` is declared twice, in `app/Config/CrocApp-Info.plist` and as a pair of sdk-scoped `INFOPLIST_KEY_*` settings in the pbxproj. Deliberately left that way: the plist declaration is the one that works. Removing it drops the key from the built `Info.plist` entirely and takes the app out of the Files app, even though `xcodebuild -showBuildSettings` resolves the build setting to `YES` (measured on a simulator build). The pbxproj pair is inert for this key and harmless; drift risk only, since the values agree.

## macOS

- **The macOS local-network denial path is hard to exercise during development.** Enforcement reportedly only engages for builds resident in `/Applications` (single developer-forum thread FB16077972, not Apple documentation — strong inference, not verified here), so a DerivedData-launched Debug build can sit at `.ready` and read as falsely granted. Copy the app to `/Applications` before trying to reproduce a denial (ADR 0034).
- `AppRouter` is a singleton with no reset hook, so multiple windows share one navigation path. Deliberately not fixed: per-window navigation needs `@FocusedValue` plumbing to reach `AppDelegate` and `Commands`, which sit outside the environment graph, and multi-window reachability has never actually been observed. Revisit if someone reports it.

## Design system

- `CodeField` and `FileRow` from `design/components.md` are still not implemented as their own components.
- No shadow token exists in `DesignTokens.swift`. The QR frame (`design/components.md` → QRFrame) specs `--shadow-md`, but `QRCodeView` currently has no shadow at all; the macOS drop overlay uses `.glassEffect()` instead, which is correct per `design/materials-motion.md` ("prefer the material's own depth where one exists") and needs no manual shadow.

## Landing page

- **The primary CTA still resolves to nothing installable.** "Download" in the hero scrolls to three channels: two unlinked store badges and a GitHub releases link that 404s until there is a release. Honest, but the page's strongest call to action cannot yet be completed. The badges clear when the apps ship. The release link starts resolving on the first tag, and because v0.9.9 publishes as a normal release rather than a prerelease, it points at an ad-hoc signed build that Gatekeeper refuses on first launch until notarization is real.
- **The disk image background is 1x only.** `create-dmg` documents png, gif and jpg backgrounds, so `assets/dmg-background.png` has no HiDPI representation and reads soft on a Retina display. Fixing it means a multi-representation TIFF, which `create-dmg` does not document and which has not been tested here.
- **`--content-max-width` on the hero mockup.** `design/brand.md` now carves an explicit exception for elements that depict the app, so this is documented rather than fixed — but the exception is narrow and easy to over-apply.
- **Store badges are inverted in dark mode with a CSS filter.** Apple ships black and white variants; the repo has black only. Inverting a black-on-transparent badge produces the white variant, but it is a filter over supplied artwork, not the supplied artwork.
- **`assets/banner.webp` is used in one of its three assigned places.** `design/brand.md` assigns it to the README header, the landing hero and the social card. It is the README header. The hero now carries real screenshots, and the social card is a purpose-built `og.jpg` — both deliberate, so `brand.md`'s table is the thing that is stale.
- **Two landing dependencies are hand-maintained and nothing checks them:** `llms.txt`'s release status and the JSON-LD `dateModified` in `index.html`. Both have to be edited by hand on every release. There is no rendered "last updated" line in the footer — the JSON-LD field is the only date on the page. Templating `dateModified` from `git log` would fix the rot but puts a moving part inside a JSON-LD block, where a broken template silently corrupts structured data rather than failing loudly. `og.jpg` is a third hand-made asset but a deliberate one, fixed rather than rotting.

## Docs site

- **No site search, on purpose.** A local search plugin is a new dependency and Algolia DocSearch is an external account plus a third-party request from a page that makes a privacy claim. Sixteen pages with a full sidebar and browser find-in-page is enough for now. Revisit if the page count grows.
- **The version dropdown is invisible.** Docusaurus hides `docsVersionDropdown` while only one version exists (ADR 0027); it stays hidden until the first `docusaurus docs:version` cut.
- **The five non-English locales are unreviewed machine-assisted drafts.** `bs`, `de`, `es`, `fr`, `ru` carry a warning admonition saying so, but nothing has native-speaker review yet (ADR 0028).
- **A landing-only change rebuilds the docs site too, and vice versa.** Both Pages workflows call `scripts/assemble-site.sh`, which builds both surfaces regardless of which one changed (ADR 0025).
- **A commit touching both `web/landing/` and `web/docs/` deploys twice.** Both workflows match, and the shared `github-pages` concurrency group with `cancel-in-progress: false` queues them rather than collapsing them, so the same artifact from the same SHA is built and published twice, back to back (observed at roughly 45s each). Harmless, since the second deploy is byte-identical to the first, and preferable to `cancel-in-progress: true`, which would abort a deploy mid-flight. The cost disappears if the two workflows are ever collapsed into one.
- **Eleven of the eighteen screenshot pairs are unused.** `scripts/capture-screenshots.sh` writes eighteen light/dark pairs; the README, six docs pages and the landing hero between them reference seven. The rest are deliberate headroom, not waste — adding a usage is cheap, re-capturing a deleted one is not.
- **The two sitemaps stay separate.** `web/landing/sitemap.xml` is hand-maintained and lists the one landing URL; `robots.txt` advertises the Docusaurus-generated `/docs/sitemap.xml` alongside it, so crawlers reach both. Not a defect with a single landing route — the `lastmod` that used to rot there has been dropped.

## Accepted

- **When both relay addresses are customised, both are sent.** croc's own CLI blanks `RelayAddress6` whenever v4 is customised, without checking whether v6 was customised too (`src/cli/cli.go`, send and receive alike), so it silently discards a user's custom v6 relay. Keeping both is more correct, not less. The divergence is deliberate (ADR 0012) and is not going to be "fixed" toward the CLI's behaviour.
- **`mac-settings-*.png` shows a text caret in the Address field.** The macOS Settings scene gives its first `TextField` focus the moment it opens. Defocusing it needs a click somewhere else, and any click that lands outside the window drops it behind the clicked one before `screencapture` can run.
- **The macOS Settings window cannot be photographed whole.** It is a fixed 480x450 and refuses `AXSize` writes, so the shot ends mid-row wherever the form is longer than that. Scrolled to the top is the framing that at least starts on a section header.
- **`OutputFolderStore.select` silently no-ops if bookmarking fails.** Rare, and the alternative is an error path for a condition the user cannot act on.
- **Receive list identity is by file name.** Duplicate names within one transfer are a croc-level concern, not a UI one.
- **`.combine` on the transfer progress view may hide the percentage from VoiceOver.** Worth a real accessibility pass, not a spot fix.
- **Gesture-level flows are not machine-verified.** Drag-and-drop, camera QR, and taps have no XCUITest coverage. No ADR decides this; the rule is the repo owner's standing instruction not to write tests unasked. Verify them by hand.
