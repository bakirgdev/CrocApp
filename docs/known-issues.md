# Known issues

Defects, limitations and risks the project knowingly lives with. Each item says what is wrong, why it was left, and what would change that.

An item is added when a defect is found and left, and deleted when the defect is fixed. If a limitation is permanent, it goes under "Accepted" with the reason.

Engine and bridge invariants are in `knowledge/crocmobile-bridge.md`. UI state-machine facts are in `knowledge/app-ui-architecture.md`.

## Release

These items gate Submit for Review of the first App Store release (`knowledge/project-overview.md`, "Status").

- **Export compliance needs two owner actions in App Store Connect.**
  - The position (`ITSAppUsesNonExemptEncryption` is `false`, France excluded from availability) is in `RELEASING.md`, "Export compliance". Owner actions: remove France from availability, and file a `future` issue to add it back after an ANSSI declaration.
  - The research behind this is in `knowledge/app-store-listing.md`, "Export compliance". It is not legal advice, and the exact App Store Connect questions could not be fetched.
- **The Accessibility Inspector and VoiceOver audit has not run on any 1.0 view.**
  - It needs Accessibility Inspector and VoiceOver on iOS and macOS, so no automated session can do it.
  - Views to cover: the Keep Both / Replace sheet, the **When a File Already Exists** picker, the waiting screen's QR code, Share Link and relay note, Send as Link and its result screen, the stored-link row on Receive, History (Revoke and the row layout), the stored-server field, the Advanced settings page, and the menu-bar window.
  - Checked so far without the tools: a code pass over every 1.0 view against `design/accessibility.md`, and the iPhone 17 Pro simulator at the largest accessibility text size. The sheet's buttons stack, status screens scroll, the code wraps, and the picker reads in full. Long names in the incoming list are middle-truncated by design.
  - Still to check by ear: whether VoiceOver reads an Advanced field's hint and its visible footnote or error twice, whether a decorative QR image with a label is exposed as an image, and Full Keyboard Access focus in the menu-bar window when its content changes.
  - Not looked at: the macOS layout of the changed views.
  - Not measured: the rendered size of the code field's system `PasteButton` against the 44 pt hit target. SwiftUI lets the app set only its border shape, label style and tint, so the system decides its size.
- **`release.yml` puts the signing passwords on `security` argv.**
  - The `.p12` password and the throwaway keychain password appear in `security import ... -P`, `security create-keychain -p`, `security unlock-keychain -p` and `security set-key-partition-list -k`.
  - `security` has no stdin option for them, so other processes on the runner can read them while the command runs.
  - Acceptable only on a single-tenant runner. Never run this workflow on a shared runner.
- **`release.yml` installs `create-dmg` unpinned** (`brew install create-dmg`).
  - `scripts/build-dmg.sh` runs it while the signing keychain is unlocked and the notary key is on disk. A compromised or broken formula update would run with access to both.
  - Homebrew has no simple version pin for a formula, and a version check would fail every release after an upstream bump.
  - If this changes, pin it in a version file like `scripts/croc-v10.version`.
- **A local Sparkle update test once hung after "Install and Relaunch".**
  - The test is in `RELEASING.md`, "Testing a Sparkle update locally". On the first launch of the `com.bakirgdev.CrocApp.direct` bundle ID on that Mac, the update downloaded and prepared. Then the app never terminated, its Quit menu item was ignored, and the installer kept waiting.
  - Later runs passed, some with Sparkle's first-launch defaults deleted, so first-launch state alone does not explain it. The cause is unknown.
  - If it recurs, watch `log stream` for `org.sparkle-project.Sparkle` and for the app's termination, and repeat the release rehearsal from a clean macOS account.
- **App Store uploads report "Upload Symbols Failed" for `Croc.framework` (iOS) and `A` (macOS).**
  - Xcode embeds a 50 KB stub `Croc.framework` dylib with no dSYM, because the gomobile xcframework is a static archive linked into the app binary. There is nothing to symbolicate there.
  - It is a warning of Xcode's upload step, not an ITMS warning, and the build still processes.
- **The App Store and direct-download builds cannot both be installed in /Applications.**
  - Both are named `CrocApp.app` (`PRODUCT_NAME = CrocApp` on `CrocApp Direct`, so the menu bar, About and Quit say "CrocApp").
  - The separate bundle ID keeps their data apart, but dragging the DMG copy into /Applications replaces the App Store copy.
  - What the App Store does when a direct-download `CrocApp.app` is already there is untested. Use one channel per Mac.

## Harnesses

- **No harness proves a LAN-discovery transfer on a custom multicast address.**
  - croc drops discovery packets from its own host's addresses, so two peers on one machine never find each other (CLI to CLI included).
  - The multicast case in `scripts/verify-interop.sh` instead listens on the group and asserts what each side announces.
  - A real two-device check on a shared non-default group has not been done.
- **A harness run on the public relays (`PUBLIC_POOL=1`) fails at random when they rate-limit.**
  - A croc v11 relay admits 30 connections a minute from one address (`DEFAULT_SOURCE_JOIN_LIMIT`, `DEFAULT_JOIN_LIMIT_WINDOW`). A multiplexed transfer opens 9 per peer (1 control, 8 data). With both peers on one machine, two transfers on the same pool relay inside a minute can be refused with `relay admission rate limited`.
  - `verify-interop.sh`, `verify-app-mac.sh` and `verify-app-sim.sh` then fail at whichever step hits the limit. The pool-relay case in `verify-interop.sh` waits 60 s and turns multiplexing off for this reason.
  - A slow admission also defeats a fixed 3 s wait after a sender. The receiver then joins first and fails with `joinedEarly` ("The other device wasn't ready, or the connection was too slow."). Seen in `verify-app-mac.sh` scenario 8, where the CLI sender's room confirmation took 4.8 s.
  - By default the harnesses avoid both: each starts its own `croc relay` with raised admission limits and starts a receiver only when that relay's debug log shows the sender's room (`BUILDING.md`, "Verification harnesses"; CI's `interop (local relay)` job runs the same way).
  - A pool relay's log is not ours to read, so on the public pool, and with an explicit `RELAY`, the harnesses still wait a fixed 3 s after a sender. Leave a minute between public-pool runs, and treat a failure as a regression only after finding the cause in its log.
  - Every checkout and session on one machine shares one address, so one limit: another run on the public pool can use up yours.
- **Two checkouts cannot run the same harness at once on one Mac.**
  - `verify-app-mac.sh` and `verify-app-sim.sh` share the app container, `~/Downloads/CrocApp` and the pasteboard. A wrapper sender and `--local` scenarios in `verify-interop.sh` bind croc's default ports 9009 to 9013 and announce on the default multicast group, so a second run sees the first one's sender.
  - Take turns. The local relay needs no care: each run picks its own free ports, and each checkout builds into its own DerivedData (`derived_data` in `scripts/lib.sh`).

## Design system

- **iPad shows the iPhone layout stretched: the layout is specified, not built.**
  - `design/platforms.md`, "Layout by width", specifies a `NavigationSplitView` for regular width (sidebar rows Send, Receive, History, plus Settings on iPad; the Mac keeps its Settings scene) and keeps Home plus `NavigationStack` for compact width. The implementation is pending.
  - Today the app is one `NavigationStack` and `TARGETED_DEVICE_FAMILY` is `1,2`. On an iPad Pro 13-inch the screens are the phone screens at tablet size, with content capped by `LayoutCap.contentMaxWidth` and wide empty margins.
  - The `ipad/` screenshots and the 13-inch App Store set show exactly that.
  - Until the split view ships, App Store listing copy must not promise an iPad-optimised experience.
- **The views predate the amended design book.** What the book now specifies and the app does not do yet:
  - About 30 call sites style text with `.secondary` instead of `Color.textSecondary` (`design/colors.md` rule 4). The `Color.textSecondary` call sites already follow it, because the alias now routes to the `ColorTextSecondary` set. The Swift lint does not catch `.secondary`.
  - The user's own cancel or decline ends on the failure `StatusBlock`, with the error glyph and tint, although `design/content.md`, "Errors", says it is not a failure. Its title stands alone with **Done**, as the book wants; `StatusBlock` has no neutral kind for it yet.
  - `CodePhraseDisplay` labels the code "Transfer code" for VoiceOver, a banned term (`design/content.md`, "Terminology").
  - Not built: the Home recent transfers, the Notifications settings, local notifications, widgets, the Control Center control, the menu bar icon states, the Dock badge and progress, Quick Look and drag-out of received files, and the extra motions in `design/motion.md`, "Vocabulary".
- **`FileRow` looks up each staged file's size in `init(url:)`** (`app/CrocApp/Views/FileRow.swift`).
  - It is synchronous file I/O on the main actor, run by `SendView` when it builds the row. A network or iCloud volume could make it hitch.
  - Not measured. A fix would read the size once when files are staged.
- **A little on-screen text cannot be translated yet.**
  - The `/s` after a transfer speed (`TransferStatusView.speedText`) and the receive-folder labels "Downloads/CrocApp" and "Documents" (`OutputFolderStore.defaultDisplayName`) are English text built by hand. `byteCount` already localizes the size itself.
  - `CodeField.tooShortMessage` counts "characters" with `EngineConstraints.minCodeLength`, which is 6. It is not inflected (`design/content.md`, "Numbers"), so a minimum of 1 would read "1 characters". Every other count noun is inflected.
  - Fixing the speed needs a format string, and the folder labels need the system's folder names. Left because the app has one language so far (`knowledge/app-ui-architecture.md`, "Localization").

## Landing page

- **The two store badges are not links.**
  - The hero **Download** button scrolls to three channels. The direct-download card links to the latest GitHub release.
  - The App Store and Mac App Store cards say "Coming soon" and show unlinked badges, because those apps are not released.
  - They become links when the apps ship, with real alt text (the markup carries a comment saying so).
- **The hero mockup uses `--content-max-width`.**
  - `design/web.md` allows this for an element that depicts the app.
  - The exception is narrow and easy to over-apply.
- **The release status in `llms.txt` and `index.html` is hand-maintained and nothing checks it.**
  - `llms.txt`, the JSON-LD `softwareVersion` and the "available now" copy have to be edited on every release (`RELEASING.md`, "Each release").
  - The JSON-LD carries only `datePublished`, which stays true. A `dateModified` would go stale on every commit, and templating it from `git log` would put a moving part inside a structured-data block, where a broken template corrupts silently.
  - `og.jpg` is a second hand-made asset, but it does not change.
- **The landing CSP is a meta tag, so it cannot stop framing, and the docs site has none.**
  - GitHub Pages cannot send headers. `frame-ancestors` is ignored in a meta tag, so clickjacking of the `/r/` buttons stays open.
  - The docs pages carry no policy, because Docusaurus injects inline scripts that would need a hash for each.
  - `scripts/assemble-site.sh` does not check the landing policy; a violation shows only in the browser console (`knowledge/landing-page.md`, "Content-Security-Policy").
- **A manual theme pin that disagrees with the OS downloads both hero image variants.** The `<picture>` source follows the OS until `app.js` runs, so the OS variant loads first and the pinned one after it. Accepted: only a visitor who overrode the OS theme pays it.
- **GitHub Pages serves `.well-known/apple-app-site-association` as `application/octet-stream`.** It has no extension and Pages cannot set a header. Apple fetches it that way today. Not verified on a device after each deploy; re-test universal links if Apple tightens the check.
- **`/r/` accepts any fragment of six or more characters without whitespace as a code.**
  - So `/r/#download` offers to open "download" in CrocApp.
  - It is display only: the text is escaped and the app validates the code.
  - Tightening the check would reject valid custom codes, so it stays loose.
- **The AASA file claims `/r/*`**, wider than the one page that exists.
  - `/r/x` is a GitHub Pages 404, so no real link is taken.
  - Narrowing the component to `/r/` would match the page. Apple caches the file, so the change needs a universal-link re-test on a device and in the Direct build.
- **`security.txt` has an `Expires` field** (`web/landing/.well-known/security.txt`). Renew it before that date passes.

## Docs site

- **No site search, on purpose.**
  - A local search plugin is a new dependency. Algolia DocSearch is an external account plus a third-party request from a page that makes a privacy claim.
  - Eighteen pages with a full sidebar and browser find-in-page are enough at this size. Revisit if the page count grows.
- **The docs 404 page keeps Docusaurus's default meta description.** The theme's NotFound page sets only a title. Changing it needs a swizzle, which is not worth the upkeep.
- **A landing-only change rebuilds the docs site too, and the reverse.** `github-pages.yml` calls `scripts/assemble-site.sh`, which builds both surfaces regardless of which one changed.
- **Most screenshot pairs are unused.**
  - `scripts/capture-screenshots.sh` writes light/dark pairs under `assets/screenshots/{mac,iphone,ipad}/`. The README, the docs pages and the landing hero reference ten of them: `mac/send-code`, `mac/send-files`, `mac/settings`, `mac/settings-advanced`, `mac/history`, `mac/receive-conflict`, `mac/stored-link`, `iphone/send-code`, `iphone/receive-incoming`, `iphone/onboarding`. The web copies are WebP, under `web/docs/screenshots/` and `web/landing/assets/img/screenshots/`.
  - The `app-store/` set is for App Store Connect only.
  - The rest are headroom on purpose: adding a usage is cheap, and re-capturing a deleted one is not.
- **The two sitemaps stay separate.**
  - `web/landing/sitemap.xml` is hand-maintained and lists the landing, support and privacy pages.
  - `robots.txt` advertises it next to the Docusaurus-generated `/docs/sitemap.xml`, so crawlers reach both.
- **The docs build is not fully pinned.**
  - `packageManager` in `web/docs/package.json` has no `+sha512` hash. `github-pages.yml` installs pnpm with `pnpm/action-setup`, so pnpm is pinned by version only.
  - The four `overrides` in `web/docs/pnpm-workspace.yaml` are open-ended `>=` floors.
  - `pnpm audit --prod` reports one High advisory with no fix: `braces@3.0.3` (GHSA-vfj7-8cjw-p6xm, stack exhaustion), reached through `chokidar` and `micromatch` inside Docusaurus core. It is build-time only, and no attacker input reaches the glob handling.
  - Re-run the audit on each Docusaurus upgrade.

## Accepted

Permanent or deferred, each with its reason.

### Build and CI

- **`braces` <= 3.0.3 (GHSA-vfj7-8cjw-p6xm) has no patched release.**
  - It is reached only at docs build time, through `chokidar` and `micromatch` over our own paths, never from user input. No override can lift it.
  - `pnpm audit` lists it, and any Dependabot alert for it is dismissed with this reason.
  - `web/docs/osv-scanner.toml` ignores it so OpenSSF Scorecard's Vulnerabilities check does not count it. Remove this item and that entry when `braces` publishes a fix.
- **`golang.org/x/crypto` carries GO-2026-5932 (the unmaintained `openpgp` package) with no fixed version.**
  - The advisory covers the whole module, but nothing imports `openpgp`. In non-test code croc v11.5.5 imports only the `argon2`, `chacha20poly1305`, `hkdf`, `pbkdf2` and `ssh` packages of `x/crypto`, and `go tool govulncheck ./...` in `crocmobile/` reports it as required but not called.
  - `crocmobile/osv-scanner.toml` ignores it for Scorecard. Remove both if `x/crypto` drops `openpgp` or a dependency starts importing it.
- **Three OpenSSF Scorecard alerts are dismissed as "won't fix".** Scorecard opens a code-scanning alert for every check below 10, and these cannot reach 10 with one maintainer.
  - **Branch-Protection:** 10 needs two approving reviewers with admins included, so nothing could merge. `main` keeps pull requests, the `ci pass` check, linear history, and no force push or deletion.
  - **Code-Review:** needs approvals from someone other than the author.
  - **CII-Best-Practices:** the project holds the passing badge, which scores below the maximum (exact score not verified). 10 needs gold, and gold needs several developers.
  - Revisit Branch-Protection and Code-Review if a second maintainer joins.

### App and UI

- **Unsigned Mac builds cannot use the Keychain.**
  - The data-protection keychain needs the `com.apple.application-identifier` entitlement, which a signed build gets from its provisioning profile. A build with `CODE_SIGNING_ALLOWED=NO` (CI, or a contributor outside team `HBSU359M33`) reads nothing, and every write or delete fails with `errSecMissingEntitlement`. The relay password, the proxies and Send as Link receipts do not persist; a relay password or proxy field shows "Couldn't save to the Keychain".
  - No test or harness needs it: they inject in-memory secret stores. An unsigned iOS Simulator build was not checked.
- **`dropDestination(for:action:isTargeted:)` stays at `ContentView.swift`, `SendView.swift` and `MenuBarQuickSendView.swift`.**
  - The Xcode 27 SDK marks it deprecated only for a future OS (`deprecated: 100000.0`), so builds emit no warning.
  - The replacement `dropDestination(for:isEnabled:action:)` takes a `Void` action (a drop cannot be rejected) and has no `isTargeted`. Its highlight API `onDropSessionUpdated` is iOS 27 / macOS 26 only, and the deployment target is iOS 26.0.
  - Revisit when the minimum OS reaches 27.
- **Keychain items written by earlier builds stay behind.**
  - Mac: `KeychainStore` reads, writes and deletes only in the data-protection keychain (`kSecUseDataProtectionKeychain`). Earlier Mac builds (the withdrawn 0.9.9 and 1.0.0 disk images, and development builds) wrote to the login keychain. CrocApp no longer reads those items, and clearing a field in Settings does not delete them.
  - Not a new exposure: they stay as they were stored, in the login keychain under the access control they were created with.
  - No migration code, by owner decision: the app has no users. Remove them by hand in Keychain Access (search for `com.bakirgdev.CrocApp`), or with `security delete-generic-password -s com.bakirgdev.CrocApp -a <account>` for each account: `relayPassword`, `advanced.socks5Proxy`, `advanced.httpProxy`, `storedReceipts`.
  - iPhone and iPad: an item that an earlier TestFlight or development build wrote keeps `kSecAttrAccessibleAfterFirstUnlock`, so a backup can still restore it to another device, until that setting (or the receipt list) is next saved.
- **`OutputFolderStore.select` silently does nothing if bookmarking fails.** It is rare, and the alternative is an error path for a condition the user cannot act on.
- **Receive list identity is by file name.** Duplicate names within one transfer are a croc-level concern, not a UI one.
- **Gesture-level flows are not machine-verified.**
  - Drag-and-drop, camera QR and taps have no XCUITest coverage, by decision.
  - Unit tests cover non-UI logic (Go `go test -race`, Swift Testing in `CrocKitTests` and `CrocAppTests`, all in CI). The harnesses cover transfers. UI flows are verified by hand.
  - See `CONTRIBUTING.md`.
- **The trust badge names the configured route, not the path that carried the data.**
  - `TrustBadge` reads the relay setting. A transfer that croc moved over the LAN still shows "Via the public croc relay" (or the custom relay).
  - croc does not report the winning path to the engine.
  - The badge's claim that the server sees only encrypted data holds on every path.
- **`HistoryStore.clear()` has not been watched emptying the list without a relaunch.**
  - It uses `delete(model:)` on `container.mainContext` and saves immediately, from a `@MainActor` type.
  - Apple documents that deletion through that method takes effect on the next save, which is satisfied. The known `@Query` refresh asymmetry concerns inserts from a background `ModelActor` context, not main-context deletes.
  - No harness drives History. If it ever misbehaves, fall back to a fetch-and-delete loop. Save and fetch failures are logged (`os.Logger`, category `history`).
- **`UIFileSharingEnabled` is declared twice**, in `app/Config/CrocApp-Info.plist` and as a pair of sdk-scoped `INFOPLIST_KEY_*` settings in the pbxproj.
  - The plist declaration is the one that works. Removing it drops the key from the built `Info.plist` and takes the app out of the Files app, even though `xcodebuild -showBuildSettings` resolves the build setting to `YES` (measured on a simulator build).
  - The pbxproj pair is inert for this key and harmless. The only risk is drift, and the values agree.
- **A plain Mac launch can open with no window.**
  - Seen on a development Mac for a bundle ID that carried saved restoration state: a normal launch opened no window and logged `hasPersistentStateToRestore=1` with a restored window of `0x0`. The same happened on a `WindowGroup` build, so the single `Window` scene did not cause it. A fresh bundle ID opened its window every time, also after the window was closed and the app relaunched.
  - A reopen (`open -a`, a Dock click) or a link brings the window back. The cause is not pinned down. `.defaultLaunchBehavior(.presented)` and `.restorationBehavior(.disabled)` on the `Window` did not fix the case above, so neither is in the code.
- **Deleting a stored upload's History row removes the only Revoke button.** The receipt stays in the Keychain until the link expires, but nothing lists receipts without a record. Revoke before deleting the row. Revisit if users lose links this way.
  - The same holds for a link sent while **Save Transfer History** is off: the upload leaves no record, so the link can only expire. The setting's footer does not say so.
- **The Camera app cannot open CrocApp for a stored link.**
  - The stored link points at the transfer server, and Associated Domains covers only `crocapp.dev/r/*`, so a camera scan opens the server's page in the browser.
  - In-app **Scan QR Code** and Paste work.
- **The menu-bar window cannot take a drop on the icon itself.**
  - `MenuBarQuickSendView`'s drop zone exists only while the window is open, so the user clicks the icon first and then drops.
  - A `MenuBarExtra` has no drop target on its status item. The **Choose Files...** button needs no drag.
- **A Shortcuts send action returns at the code, not at the end of the transfer.**
  - `SendFilesIntent` and `SendTextIntent` finish when `awaitCode()` sees `.waiting`. A shortcut that goes on to quit CrocApp, or a user who closes it, ends the transfer before the receiver has the files. The dialog says "Keep CrocApp open until the transfer ends."
  - The code has to reach the receiver while the sender is still waiting, so the action cannot wait for the end. Receive does wait for the end.
  - Neither the actions nor the Finder Quick Action have been run on a device (`knowledge/device-test-checklist.md`, "Shortcuts actions").
- **The macOS local-network denial path is hard to exercise during development.**
  - This is a development-procedure note, not an app defect.
  - Enforcement reportedly engages only for builds resident in `/Applications` (one developer-forum thread, not Apple documentation; strong inference, not verified here). A Debug build launched from DerivedData can sit at `.ready` and read as falsely granted.
  - Copy the app to `/Applications` before trying to reproduce a denial.

### Engine and croc behaviour

- **When both relay addresses are customised, both are sent.**
  - croc's own CLI blanks `RelayAddress6` whenever the IPv4 address is customised, without checking whether the IPv6 one was customised too (`src/cli/cli.go`, send and receive alike), so it silently discards a custom IPv6 relay.
  - Keeping both is more correct. The divergence is deliberate and will not be "fixed" toward the CLI's behaviour.
- **A zipped-folder receive that collides with more than 4096 existing members still fails.**
  - crocmobile answers croc's per-member `Overwrite '<path>'? (y/N)` prompts from a batch of 4096 lines written up front (`promptPolicyAnswers`). The batch is sized to fit a fresh pipe buffer on Darwin and Linux, so the write never blocks.
  - Past that, croc's unzip reads EOF and fails with `received archive failed validation or extraction`, leaving the received `.zip`.
  - A larger batch could block the write (`knowledge/crocmobile-bridge.md`).
- **The incoming sheet cannot preview which members of a zipped folder already exist.**
  - The file list shows one `.zip` name, so the conflict scan sees no members and offers only Accept (Keep Both).
  - Existing members are kept and matching ones in the archive are skipped under every policy, Replace and auto-accept included. The stdin answers croc's unzip prompt reads are always "n", because a queued "y" would also answer the accept prompt croc re-runs after a reconnect or forces when the sender used `--ask` (`knowledge/crocmobile-bridge.md`).
  - The archive's contents are known to croc only after it unpacks, and keeping what is there loses nothing.
- **A file whose name ends in a space cannot be sent to a croc v11 peer.**
  - CrocApp sends the exact name (crocmobile `splitPaths`). croc 11.5.5 receivers, CLI and crocmobile alike, refuse it: `unsafe receive path in "report.pdf ": Windows-trimmed trailing character`. The sender sees `cancelled`.
  - The refusal is croc's receive-path policy. Rename the file to send it.
- **A croc v11 reconnect after a manually accepted receive ends as `refused`.**
  - croc re-runs the accept prompt on the sender's file list after each reconnect (`resetForReconnectAttempt`, then `processMessageFileInfo`). The next queued stdin answer is "n", so the receive fails instead of resuming.
  - Answering "y" there would accept a list the user never saw, and crocmobile cannot tell that prompt from the unzip prompt on the same pipe.
  - Read from croc v11.5.5 source; no harness forces a reconnect.
- **A cancelled transfer that croc never returns from keeps the engine until CrocApp is relaunched.**
  - The cancel watchdog reports it after 15 s as `engineStuck`, so the app leaves the transfer and every later start fails at once with "The cancelled transfer didn't stop. Quit and reopen CrocApp to transfer again." (`knowledge/crocmobile-bridge.md`, "Cancel and teardown").
  - The lock itself stays held: forcing it open while croc still runs would let two sessions change the same process-global state (`os.Chdir`, the stdin and stdout swaps).
  - No such hang has been seen. The watchdog is covered only by a Go test with a blocking stand-in for croc.
- **Restoring croc's proxy and DNS globals can race a croc dial goroutine that outlived its transfer.**
  - croc's relay dial race (`raceRelayTCPWithDialer`, `src/croc/relay_dial.go`) returns on a cancel without waiting for its dial goroutine. That goroutine can still read the globals `setNetworkGlobals` set (`network.go`) while this transfer's restore, or the next transfer's setup, writes them.
  - `go test -race` reported it for a receive cancelled during its relay dial. The read happens in a dial that is already cancelled, but a torn read of a Go string can in principle crash the process. Not seen outside the race detector.
  - A fix needs croc to take these settings per client instead of as package globals.
- **`poll()` reads `croc.Client` scalar and slice fields with no synchronization** (croc's own goroutines write them unguarded).
  - The worst case is a briefly wrong progress number. It is bounds-checked (`progressSnapshot` in `session.go`), so it cannot panic.
  - A real fix needs upstream locking.
- **A generated-code send with no internet or no reachable pool relay fails before a code is shown.**
  - With default settings, no pool relay answers the 1 s probe (`generatePublicCode` in `crocmobile/relay.go`), so the send fails with code `noPublicRelay` (croc's `no public relay available`, the same as the v11 CLI).
  - A "draw a code anyway and let a LAN peer join" fallback does not work: after the relay dial fails, croc waits for a LAN peer for only 10 s (`defaultAlternateSenderRouteTimeout`, unexported), and a `croctest send -relay 127.0.0.1:1` with no receiver printed its code and failed about 11 s later.
  - Workaround: turn on **Local Network Only** (`web/docs/content/troubleshooting.md`, "Relay unreachable"). The app shows "No public relay answered" and "Check your internet connection, or turn on Local Network Only in Settings if both devices are on the same network."
- **A receiver that joins before the sender fails, and so does the sender.**
  - The receiver's `pake1` local probe times out after 500 ms and it carries on with the main PAKE. The sender's late reply to the old probe is then decoded as a transfer message and fails with `flate: corrupt input before offset 6` (`knowledge/crocmobile-bridge.md`, "Start order: sender first").
  - Generated codes are sender-first, but custom codes are not. A receiver who types an agreed code before the sender taps Send, or an app receiver waiting on a CLI sender using `CROC_SECRET`, hits it.
  - The receiver reports `joinedEarly`: "The other device wasn't ready" and "Start the send there first, or use a faster connection, then enter the code again." A sender with LAN on fails with croc's `could not secure channel` and shows "The code phrases don't match", because that code is also a real mismatch.
  - There is no automatic retry of the receive. With a croc v11.5.5 CLI sender, the sender had already failed when the receiver did, and a second receive with the same code only waited for a sender that was gone. Both sides have to start again, sender first.
  - Workaround: start the sender first, then the receiver. `verify-app-sim.sh`, `verify-app-mac.sh` and `verify-interop.sh` all delay their CLI receiver for this reason.
  - The same error follows a slow link even when the sender was first: croc waits only 500 ms for the probe reply, so a SOCKS5 proxy, a slow mobile link or a distant relay can make the reply late. The detail therefore offers a fix for both causes.
  - Not verified whether `schollz/croc` has an upstream issue for it. The probe timeout and the frame decoding are croc's.
- **Cancelling a start is best effort.**
  - `CancelStart()` reaches a start only once Go has registered its context (`lockTransfer`, `Getwd`, the network globals). A cancel that lands before that finds nothing, and the start goes on to show a code.
  - `TransferController` recovers by cancelling by transfer ID as soon as the start returns. Other callers of `CrocEngine` (such as `crockit-verify`) do not.
- **A file name with a line break fails as an Advanced setting.**
  - `CrocEngine.joinedPaths` refuses such a path with code `invalidSetting`, the code for a bad proxy, speed limit, multicast address or sender IP. The failure screen then says "An Advanced setting can't be used" and offers **Open Settings**, which cannot fix a file name.
  - A fix gives the refusal its own code, or checks the names in the app before the start. Workaround: rename the file.
- **A panic inside `Cancel` or `Respond` reports `OnError` while the transfer still runs.**
  - `reportPanic` there skips the single-final-event guard, so CrocKit drops the live session's handle and the session can later send a second final event.
  - It needs a Go panic in those calls, which none has been seen to raise. A fix claims the session's terminal flag first, or only logs the panic.
- **A malformed callback payload ends the Swift stream before Go has finished.**
  - `DelegateBridge` finishes the stream without marking the transfer ended, so a new start within the Go cancel's unwind time fails with "Another transfer is still running" (the removed 300 ms retry used to hide this).
  - It needs a payload the bridge cannot decode, which only a bridge bug produces.
- **A transfer with a croc 10 peer usually shows no error and waits until the user cancels.**
  - The app reports `peerVersion` ("peer uses unsupported PAKE protocol version 0; upgrade both croc clients") only when both peers reach the same relay room.
  - croc v10 derives the room from the code's first 4 characters (`src/croc/croc.go`, `SharedSecret[:4]`). croc v11 derives it from the first word of a three-word code (`src/codephrase/codephrase.go`, `Parse`). So an app-generated code lands in a different room than a v10 peer computes, unless the first word has exactly 4 letters.
  - The v10 CLI's default relay `croc.schollz.com:9009` is the same server as pool relay `1.getcroc.com` but not pools 2 to 4, so only codes that map to pool relay 1 meet.
  - Checked by runs: over a shared relay with a legacy-format code (for example `7020-alpha-beta-gamma`) the app gets `peerVersion` in both directions. The v10 CLI prints `could not secure channel` (sender) or `broken pipe` (receiver).
  - A v10 peer cannot be changed, and the room and relay derivation are croc's. Workaround: the v10 side upgrades to croc 11.
- **croc prints the code phrase, and a non-default relay password, to stderr on every send.**
  - croc builds the "On the other computer run" line (`croc <code>`, plus `--pass <password>` when the password is not the default) with `Quiet=false`. crocmobile needs that (`knowledge/crocmobile-bridge.md`). Its debug logger also prints file names and paths.
  - Nothing in the app captures stderr. A build launched from Finder, the Dock or the Home Screen has it connected to `/dev/null` (strong inference, not measured on a device), so it reaches no log store or crash report.
  - A harness run or an Xcode debug session does capture it (`verify-app-mac.sh` writes it to its temp logs).
  - Revisit if croc gains a way to silence that line without `Quiet`.
