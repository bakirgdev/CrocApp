# CrocApp 1.0.0: what is left, and how to publish to the App Store

Written 2026-10-15 at the end of the build phase (slice B27 of `sdlc/2026-10-12-publish-polished-1-0/plan.md`). This file is a personal hand-off, not part of the shipped docs. It is not committed; delete it when the release is done.

## 1. Where things stand

Done and verified:

| Item | State |
| :--- | :--- |
| All 27 build slices (B1 to B27) | Built, reviewed, merged to `main` (PRs #12 to #27) |
| GitHub release `v1.0.0` | Published 2026-10-15 by the `release` workflow (run 38751704094): `CrocApp-1.0.0-arm64.dmg`, `SHA256SUMS.txt`, `Croc.xcframework-1.0.0.zip`, `appcast.xml` |
| DMG | Notarized and stapled. `xcrun stapler validate` passes. `spctl` says "accepted, source=Notarized Developer ID". SHA-256 matches `SHA256SUMS.txt` |
| Release workflow rehearsal | `workflow_dispatch` from `main` (run 38750570268) ended `success` |
| App Store builds | Version 1.0.0 build 1 (2026-10-14) and **build 2 (2026-10-15)** uploaded to App Store Connect for iOS and macOS. Both printed `APPSTORE-UPLOAD-OK` |
| Website | `crocapp.dev` live: `/privacy/`, `/support/`, `/r/` and the AASA file return HTTP 200 |
| Machine cleanup (step 60) | Done. The app's local data, caches, builds and the simulator install were removed |

Not done. This is the real to-do list; sections 2 to 6 explain each item.

| # | Item | Who | Blocks Submit? |
| :--- | :--- | :--- | :--- |
| A | Check the build 2 upload: ITMS warning email, TestFlight processing | you | yes |
| B | Device checklist items still open (O8) | you, with Claude confirming SHA-256 values | yes |
| C | Accessibility Inspector and VoiceOver audit (O12, R29) | you | yes |
| D | Decide the SIEC curve question (export compliance) | you | yes |
| E | Check Apple's reply to multicast request WA7J9P8GM7 | you | yes (changes what ships) |
| F | Ask the croc maintainer for the written reply (R41) | you | yes (reminder) |
| G | Fill in App Store Connect (O9) and attach build 2 | you | yes |
| H | Press Submit for Review on iOS and macOS | you | this is the step |
| I | R37: open the downloaded DMG on a clean macOS account | you | no, but do it |
| J | Sparkle update test from an older install | you | no |
| K | After approval: store badges, copy check, `future` issues | you or Claude | after approval |
| L | Housekeeping: remove the "Autonomous build phase" section, run `cchk` | you | after everything |

## 2. Before you submit (A to F)

### A. Check build 2

1. Open the developer-account email (gracicbakir@icloud.com). Apple sends ITMS warnings or errors there after processing. The one to watch for is ITMS-91053 (a missing required-reason API declaration in `app/CrocApp/PrivacyInfo.xcprivacy`). If one arrives, fix what it names, bump `CURRENT_PROJECT_VERSION` in `app/Config/Version.xcconfig` to 3 in its own commit, and upload again (section 7).
2. In App Store Connect, open CrocApp, then TestFlight. Confirm the iOS and the macOS build 2 finished processing and are not marked invalid.
3. Expect the harmless "Upload Symbols Failed" lines for `Croc.framework` at upload time; they are not ITMS warnings (`docs/known-issues.md`, "Accepted").

Build 2 is the one to attach to the submission. Build 1 can stay in TestFlight.

### B. Device checklist (O8)

The checklist is `docs/knowledge/device-test-checklist.md`. Passed already (2026-10-14, "all pass"): "Links and web receive" items 1 to 6 and "Transport and Tailcat gate" (a) to (d). Still open, run on your iPhone (iOS 26+) and Mac:

| Section | Needs | Notes |
| :--- | :--- | :--- |
| Stored transfers (R18 to R21), items 1 to 5 | iPhone, a second phone for item 3, a Mac to hash files | Uses the public getcroc.com server and the internet. Hash with `shasum -a 256`; the received file's SHA-256 must equal the source's |
| Menu bar on a Mac (R26) | Mac | Includes the menu-bar window that the accessibility audit also covers |
| Shortcuts actions (R27) | iPhone or Mac | |
| iPad File menu (R28) | iPad or the iPad simulator | The simulator screenshot is the Proof row; a real iPad is optional |

Tell Claude which items pass or fail and give the SHA-256 values, and it will confirm and tick them in `plan.md`. Anything that fails goes back to `/sdlc-build` as a fix (see section 8).

### C. Accessibility audit (O12, R29)

No session could drive Accessibility Inspector, so this was never done. Audit every view that is new or changed since 0.9.9, on iOS and on macOS, with Accessibility Inspector and VoiceOver:

- The Keep Both / Replace sheet; the "When a file already exists" and Connection pickers.
- The waiting screen: QR code, Share Link, relay note.
- Send as link and its result screen; the stored-link row on Receive; History (Revoke confirmation, row layout); the stored-server field.
- The Advanced settings page (iOS page, macOS tab, inline errors, Reset to Defaults).
- The menu-bar window; the Settings About section.

Check by ear (open questions from `docs/known-issues.md`, Release): whether VoiceOver reads an Advanced field's hint and its visible footnote or error twice; whether a decorative QR image with a label is exposed as an image; Full Keyboard Access focus in the menu-bar window when its content changes. Not looked at by anyone: the macOS layout of the changed views.

Fix anything unresolved before submitting. A fix needs a new build number.

### D. SIEC decision (export compliance)

croc's `siec` PAKE curve is selectable in Advanced settings. It may count as non-standard cryptography. Pick one:

1. Hide the curve from the picker (small engineering change, then a new build 3).
2. Send the BIS/NSA notification email to `crypt@bis.doc.gov` and `enc@nsa.gov` with `https://github.com/bakirgdev/CrocApp` as the source.
3. Take advice.

The research is in `docs/knowledge/app-store-listing.md`, "Export compliance". It is not legal advice, and you are responsible for the classification. The current position: `ITSAppUsesNonExemptEncryption` is `false` (open-source exemption, EAR 742.15(b)) and France is excluded from availability.

### E. Multicast request WA7J9P8GM7

Check gracicbakir@icloud.com for Apple's reply to the request filed 2026-10-12 (developer.apple.com/contact/request/networking-multicast).

- **Granted:** Apple adds "Multicast Networking" as a capability on `com.bakirgdev.CrocApp`. Then add the `com.apple.developer.networking.multicast` entitlement (see `docs/BUILDING.md` section 7 step 10 and the iOS multicast setting), bump the build number, and upload again.
- **Not granted by submission time:** ship as is, with the iOS multicast setting hidden, and file a `future` issue that quotes WA7J9P8GM7.

### F. croc maintainer (R41)

You treat the maintainer's reply as a yes to everything asked (the name, the public relay pool default, the Tailcat/DERP `auto` default, getcroc.com stored transfers and the browser link). The reply text is not in the repo. Before Submit, ask once more. If you get written permission, add a line to the review notes (spec concern 10).

## 3. Fill in App Store Connect (G)

Everything to paste is in `docs/knowledge/app-store-listing.md`. Every fenced block there is the exact text for one field, with Apple's limits and the measured length. The App Store Connect click paths below follow that file and Apple's help pages; Apple changes the labels often, so read each screen. This was written without access to your App Store Connect account, so none of it was checked on the live screens.

One record holds both platforms: "CrocApp", bundle ID `com.bakirgdev.CrocApp`, universal purchase. Team `HBSU359M33`.

### G1. Pricing and availability

1. Price: Free (USD 0). No in-app purchases.
2. Availability: **all countries and regions except France.** App Store Connect, your app, Pricing and Availability, App Availability, Set Up Availability (or Manage), Specific Countries or Regions. Select all but France, and keep the box that includes new regions.
3. After saving, check both platform pages show France as unavailable (the listing file notes Apple does not say whether the setting covers iOS and macOS together).
4. Reason: Apple's own table makes `ITSAppUsesNonExemptEncryption = false` coherent only without France. File a `future` issue to add France back after an ANSSI declaration (see section 6).

### G2. App Information

| Field | Value |
| :--- | :--- |
| Name | `CrocApp` |
| Subtitle | from the "Subtitle" block (29 of 30 characters) |
| Primary category | Utilities |
| Secondary category | Productivity (optional; drop it if unsure) |
| Privacy Policy URL | `https://crocapp.dev/privacy/` |
| Content rights, Age rating | see G4 |

### G3. Version page (iOS, then macOS)

Fill in both platform tabs; the text is the same unless noted.

| Field | Source in the listing file |
| :--- | :--- |
| Promotional text (170 max) | "Promotional text" |
| Description (4000 max) | "Description" |
| Keywords (100 bytes max) | "Keywords" |
| What's New (4000 max) | "What's New in 1.0.0" |
| Support URL | `https://crocapp.dev/support/` |
| Marketing URL | `https://crocapp.dev` |
| Copyright | `2026 Bakir Gračić` |
| Version | 1.0.0 |
| Build | build **2** (pick it in the Build section; it appears only after processing) |
| Screenshots | section 3.1 below |
| App Review Information | section 3.2 below |

Before you press Submit, both `https://crocapp.dev/support/` and `https://crocapp.dev/privacy/` must return 200. They did on 2026-10-15; re-check with `curl -s -o /dev/null -w '%{http_code}\n' https://crocapp.dev/privacy/`.

#### 3.1 Screenshots

Files are in `assets/screenshots/store/`, light mode, no alpha, eight per size:

| Folder | Pixels | Use for |
| :--- | :--- | :--- |
| `iphone-6.9` | 1320x2868 | iPhone 6.9" (largest iPhone set) |
| `iphone-6.3` | 1206x2622 | iPhone 6.3" |
| `ipad-13` | 2064x2752 | iPad 13" |
| `mac` | 2880x1800 | Mac |

Upload them in file-name order (`01-send` first). Known cosmetic issues from the capture run (`docs/knowledge/screenshots.md`): the new iOS shots lack the Dynamic Island, and the iOS "Link ready" shot cuts off the Done button at the bottom. Replace those before submitting if they bother you; re-run `scripts/capture-screenshots.sh` as that file describes. The menu-bar popover could not be captured, so it has no shot. Check the sizes after any re-capture: `sips -g pixelWidth -g pixelHeight -g hasAlpha <file>` must show the exact size and `hasAlpha: no`.

#### 3.2 App Review Information

- Sign-in required: off (the app has no account).
- Contact first name, last name, phone (international format with a plus sign) and email: yours to fill in. They are not in the repo, and the developer-account address is not necessarily the public support contact.
- Notes: paste the fenced block under "Review notes" in the listing file (3289 of 4000 bytes). It explains the no-second-device test path, using getcroc.com in a browser as the peer.
- Before pasting, check by hand (the listing file's "Open checks before Submit"):
  1. Send a file from getcroc.com in a browser and receive it in the app on a real device. The browser-sends, app-receives direction is not verified anywhere in the repo.
  2. getcroc.com's current labels: Send, Receive, Choose files, "Croc code or stored link", Copy code. They were read on 2026-10-15 and belong to the croc project.
  3. Whether to add the maintainer's written reply (item F).

### G4. App Privacy and Age Rating

App Privacy: answer **"No, we do not collect data from this app."** Save. No further questions. Privacy Policy URL `https://crocapp.dev/privacy/`. `PrivacyInfo.xcprivacy` agrees (tracking false, no tracking domains, no collected data types). Residual risk: Send as link keeps ciphertext on getcroc.com for up to 7 days, and Apple could read that as collection. If App Review disagrees, the fallback is "Other User Content", not linked to the user, not used for tracking, purpose "App Functionality".

Age rating: App Information, Age Ratings, Set Up. Answer the questionnaire exactly as the table under "Age rating" in the listing file: nothing selected under in-app controls and capabilities (no Unrestricted Web Access, User-Generated Content, Messaging and Chat, Advertising), None for every content descriptor, No for Gambling and Loot Boxes, Not Applicable for the age category. Expected result: **4+**.

### G5. Export compliance

Both `Info.plist` files carry `ITSAppUsesNonExemptEncryption = false` and France is excluded, so Apple's documented behavior is that the encryption questions are skipped and no "Missing Compliance" status appears. Open each processed build (iOS, macOS) and confirm that. If a build does show the questions anyway, follow step 3 in "Export compliance, Recommended answers" in the listing file, and stop if the flow contradicts Apple's own table (ask Apple Developer Support instead of guessing).

### G6. Attach builds and submit

1. On the iOS version page, Build section: select build 2. Repeat on the macOS version page.
2. Check that no field shows a red warning. Check the "Version Release" choice (manual release is the safer first choice: you decide when it goes live after approval).
3. Add for Review, then **Submit for Review** for each platform. With universal purchase, submit both so they go through together.
4. Status should move to "Waiting for Review". Review usually takes a day or two; Apple's reply comes to the developer-account email.

## 4. After you press Submit (H, I, J)

### I. R37, a clean macOS account

Create or use a macOS user that has never run CrocApp, download `CrocApp-1.0.0-arm64.dmg` from the GitHub release, open it, drag the app out, and launch it. Pass condition: only the standard first-launch "downloaded from the Internet" prompt, no Gatekeeper block. The DMG already passes `spctl` and `stapler`, so this should hold.

### J. Sparkle update test

Sparkle ships only in the Direct (DMG) build. To test an update from an older install, follow `docs/BUILDING.md` section 7, "Testing a Sparkle update locally". The very first local update test once hung after "Install and Relaunch" (`docs/known-issues.md`); it is unknown whether that was a first-launch artifact. Do not run both channels on one Mac: the App Store and DMG builds are both named `CrocApp.app`, so dragging the DMG copy into /Applications replaces the App Store copy.

## 5. After approval (K)

1. Release the build (if you chose manual release). The listings become live.
2. **Link the store badges** on the landing page and docs (they are unlinked on purpose until the listing URLs exist; slice B27 was to do it). Then check the copy still reads right. The merged copy says store listings "arrive at launch" and the DMG is "from version 1.0.0"; update those lines in `web/docs/content/index.md`, `faq.md`, `getting-started/install.md`, `web/landing/index.html`, `web/landing/llms.txt` and `README.md`. `web/**` deploys on merge.
3. Re-run the stale-text check: `grep -rniE "not released|nothing has shipped|planned" README.md web/landing web/docs/content` should print nothing.
4. Also check `curl -s https://crocapp.dev/ | grep -c downloadUrl` is still at least 1.
5. If the multicast request was not granted, file the `future` issue quoting WA7J9P8GM7 (see E).

## 6. Follow-up issues to file

Not filed yet. Each is a `future` GitHub issue:

- Add France back: file the ANSSI declaration (demarches.numeriques platform), switch `ITSAppUsesNonExemptEncryption` to `true` with the issued code, upload new builds, add France to availability. Allow at least a month from a complete file.
- Multicast on iOS, only if Apple has not granted WA7J9P8GM7 by submission.
- The SIEC curve, if you chose to hide it rather than notify BIS and NSA.
- Optional cosmetic: the Dynamic Island and the clipped Done button in the new iOS screenshots.

Open `future` issues already exist for: Crowdin localization (#11), Homebrew cask (#10), croc maintainer infrastructure and a web version (#9, #8), Finder Share extension (#22), Control Center control (#23), Spotlight indexing (#24), widgets (#25).

## 7. Reference: how to ship a build to App Store Connect

Use this for build 3 (any fix) and for every later release. Full detail is in `docs/BUILDING.md` section 7, "App Store builds" and "Owner steps".

1. Be on an up-to-date `main`. Xcode must be signed in to the Apple ID that belongs to team `HBSU359M33` (Settings, Accounts). `CrocKit/Croc.xcframework` must exist (`scripts/build-xcframework.sh`).
2. Bump the build number: edit `CURRENT_PROJECT_VERSION` in `app/Config/Version.xcconfig` (currently 2) in its own commit. App Store Connect refuses a build number it has already seen for the same `MARKETING_VERSION`. For a new version, change `MARKETING_VERSION` and `web/docs/package.json` as well, and add a `CHANGELOG.md` entry.
3. Dry run, nothing leaves the Mac: `scripts/build-appstore.sh`. It must print `APPSTORE-EXPORT-OK ios` and `APPSTORE-EXPORT-OK macos`.
4. Upload: `scripts/build-appstore.sh --upload`. It must print `APPSTORE-UPLOAD-OK ios` and `APPSTORE-UPLOAD-OK macos`.
5. Check the developer-account email for ITMS warnings and the TestFlight tab for both builds (item A).
6. For a DMG release: push an annotated tag `vX.Y.Z` from `main`, then approve the `release` environment deployment in GitHub Actions (or `gh api -X POST repos/bakirgdev/CrocApp/actions/runs/<run id>/pending_deployments -F 'environment_ids[]=<env id>' -f state=approved -f comment=...`). `release.yml` notarizes and publishes the DMG, `SHA256SUMS.txt` and `appcast.xml`. A `workflow_dispatch` run rehearses everything without publishing.
7. Required GitHub secrets on the `release` environment (all set on 2026-10-14): `DEVID_P12_BASE64`, `DEVID_P12_PASSWORD`, `DEVID_PROFILE_BASE64`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `SPARKLE_ED_PRIVATE_KEY`. The Developer ID profile "CrocApp Direct Developer ID" expires in 2044.
8. `scripts/build-dmg.sh` needs Homebrew's `create-dmg`, which was uninstalled in the cleanup. The release workflow installs what it needs on its own runner; reinstall locally with `brew install create-dmg` only if you build a DMG by hand.

## 8. If something fails or Apple rejects the build

- Review comments or a rejection: read Apple's message, fix the cause, and use `/sdlc-maintain` to turn it into a new intent, which restarts the pipeline (`/sdlc-intent`, then `/sdlc-spec`, `/sdlc-plan`, `/sdlc-build`, `/sdlc-review`, `/sdlc-ship`). For a tiny fix, a single slice through `/sdlc-build` plus `/sdlc-review` is enough.
- Handoff commands start with `cclaude-dsp`, not `claude` (your saved preference).
- A failing device-checklist item: fix it in code, bump the build number, upload a new build, and re-attach it to the version before you submit.
- Common upload failures: "Invalid Export Compliance Code" means `ITSAppUsesNonExemptEncryption` and `ITSEncryptionExportComplianceCode` do not match your documentation; keep the key `false` while France is excluded. A build number App Store Connect has seen is refused; bump it.

## 9. Housekeeping when everything is done (L)

1. `.claude/CLAUDE.md` still has the "Autonomous build phase" section. It says to remove it when the build phase ends. That is now: it lets Claude commit, push, open and merge PRs without asking. Delete the section (small PR) so normal ask-first rules apply again.
2. Optional: tick step 59 in `sdlc/2026-10-12-publish-polished-1-0/plan.md` after Submit, and ask Claude for a final review pass over the whole project.
3. Run `cchk` last. It deletes `projects/` (transcripts and auto-memory) and Claude Code state, so this file and `plan.md`'s Build log are your only record of the session. Copy anything you still want before running it. Do not run it inside a Claude session.
4. Delete this file.
