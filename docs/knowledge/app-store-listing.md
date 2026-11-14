# App Store listing

The copy for CrocApp's App Store Connect record, written to be pasted field by field and reused for every App Store release. One app record holds iOS, iPadOS and macOS (universal purchase, bundle ID `com.bakirgdev.CrocApp`).

Every fenced block under a field heading is the exact text to paste. Character counts were measured with a script (Python `len()` for characters, `len(s.encode())` for the two byte-limited fields). When you change a block, recount it.

How to read the claims:

- **Documented**: an Apple page says it. The URL is in "Sources".
- **Verified locally**: read in this repo or in its Go module cache.
- **Inference** and **unknown**: labelled where they appear.

## Field limits

Limits come from Apple's App Store Connect Help (URLs in "Sources"). Two are bytes, not characters.

| Field | Limit | Used | Source |
| :--- | :--- | :--- | :--- |
| Name | 30 characters (min 2) | 7 | App information page |
| Subtitle | 30 characters | 29 | App information page |
| Promotional text | 170 characters | 152 | Platform version information page |
| Description | 4000 characters | see "Description" | Platform version information page |
| Keywords | 100 **bytes** (each keyword more than two characters) | 98 | Platform version information page |
| What's New | 4000 characters | see "What's New" | Platform version information page |
| App Review notes | 4000 **bytes** | see "Review notes" | Platform version information page |
| Support URL, Marketing URL, Privacy Policy URL | no limit stated; full URL with protocol | n/a | Platform version information page, App information page |
| Copyright | no limit stated; year first, then the holder; Apple adds the copyright symbol | n/a | Platform version information page |

Apple's pages state no limit for the URL and copyright fields. Unknown whether a hidden limit exists; these values are short.

## Name

```text
CrocApp
```

One word, capital C and A (`design/brand.md`, "Naming"). Not "Croc App", never "CrocAPP".

## Subtitle

```text
Send files with a code phrase
```

## Promotional text

Editable without a new build or review.

```text
Free, open source, no account. Send files, folders or text to another device with a short code phrase, end-to-end encrypted. An unofficial app for croc.
```

## Description

Length: 2918 characters. The security statements follow the approved list in `design/voice.md`, "Claims".

```text
CrocApp sends files, folders and text from one device to another with a short code phrase such as cape-junky-widow. No account, no sign-up, and the two devices do not need to be on the same network.

HOW IT WORKS
1. Choose what to send: files, a folder, or some text.
2. CrocApp shows a code phrase and a QR code. Read it out, message it, or let the other person scan it.
3. The other device enters the phrase, sees the list of files, and accepts. The transfer starts.

PRIVATE BY DESIGN
Transfers are end-to-end encrypted. The code phrase authenticates both devices, and a relay that passes the data along only ever sees ciphertext. CrocApp has no accounts, no analytics, no ads and no tracking, and your transfer history stays on your device. CrocApp has not had a formal third-party security audit.

FREE AND OPEN SOURCE
CrocApp is free: no purchases, no subscription, no tiers. The source code is public under the MIT license at github.com/bakirgdev/CrocApp.

WORKS WITH THE CROC COMMAND LINE
CrocApp is a native SwiftUI app built on croc, the file-transfer tool by Zack Scholl. A code phrase from the croc command line works in CrocApp, and the other way around. The other device needs croc 11 or newer: older croc 10 cannot transfer with CrocApp.

WHAT YOU CAN DO
- Send several files, whole folders, or text and clipboard contents.
- Receive with a code phrase, a scanned QR code, or a link. Opening a link only fills in the code; nothing connects until you tap Receive.
- See the file list before you accept, and choose Keep Both or Replace when a name is already taken.
- Watch progress and speed, cancel at any time, and resume an interrupted transfer.
- Send as Link: share encrypted files for someone who is not online, with a lifetime of 1 hour, 1 day or 7 days. A link holds up to 100 files and 1 GiB in total, and can be downloaded up to 100 times. You can revoke the link from History.
- Use your own relay, force local-network-only transfers, or route through a proxy, from Settings.
- iPhone and iPad: send from any app with the share sheet, find received files in the Files app, and use Shortcuts and Siri actions.
- Mac: drag and drop, a menu bar window for quick sends, and Shortcuts actions.
- Light and dark appearance and Dynamic Type.

WHAT TO KNOW
By default CrocApp uses the public relays run by the croc project to connect two devices, and the croc project's link server at getcroc.com for links. Your files are encrypted before they leave your device. You can point CrocApp at relays and a link server you run yourself. Nearby transfers over the local network depend on what your network and device allow.

CrocApp is an independent project. It is unofficial and not affiliated with or endorsed by croc or its author. croc is MIT licensed. Apple, iPhone, iPad, Mac and Siri are trademarks of Apple Inc.

Free to use, with no account. Questions and bug reports: https://crocapp.dev/support/
```

The description does not claim VoiceOver support. Add it only after the accessibility audit in "Open checks before submitting" has passed.

## Keywords

- Comma separated, no spaces.
- Words already in the name or subtitle (`crocapp`, `send`, `files`, `code`, `phrase`) and the category (`utilities`) are left out because Apple already indexes them.
- `croc` is a deliberate keep: the name is one token, and the protocol name is what people search.
- `airdrop` is left out on purpose (another company's trademark). `wormhole` is left out too: it names other transfer products (Magic Wormhole, Wormhole), which guideline 2.3.7 treats as trademark-adjacent.
- `secure`, `p2p` and `peer` are search terms people type; keywords are never shown, so `design/voice.md`, "Terminology", which binds displayed copy, does not apply to them.

```text
croc,transfer,share,encrypted,secure,private,qr,p2p,link,mac,folder,lan,nearby,e2ee,drop,peer,text
```

## What's New

App Store Connect shows no What's New field on an app's first version. From the second App Store release on, write it from that release's `[x.y.z]` section of `CHANGELOG.md`, in the voice of the description.

## URLs, category, price

| Field | Value |
| :--- | :--- |
| Support URL | `https://crocapp.dev/support/` |
| Marketing URL | `https://crocapp.dev` |
| Privacy Policy URL | `https://crocapp.dev/privacy/` |
| Primary category | Utilities (matches `LSApplicationCategoryType` `public.app-category.utilities` in the build settings, verified locally) |
| Secondary category | Productivity (optional; a judgement call, drop it if unsure). Both platforms of the record share the categories. |
| Copyright | `2026 Bakir Gracić` (the holder in `LICENSE` is "Bakir Gracić", with the accent; Apple adds the symbol) |
| Price | Free (USD 0), no In-App Purchases |
| Version | `MARKETING_VERSION` in `app/Config/Version.xcconfig`; attach the iOS and macOS builds that finished processing in TestFlight |
| Privacy choices URL | leave empty (optional per Apple) |
| Sign-in required (App Review) | off; the app has no account |
| Content Rights (App Information) | No, the app does not contain, show, or access third-party content (owner's answer) |
| Advertising Identifier | the app uses no IDFA |
| iPhone and iPad Apps on Apple Silicon Macs (Pricing and Availability) | off, so the native macOS app is the only one Macs see |
| Product page Header and Search Results asset (universal 16:9, 5244x2950) | `assets/app-store-header.png`, from `scripts/social-cards.swift`; uploaded through the Asset Library. Shown on iOS and iPadOS 27 and later only |

The Direct build's **Support CrocApp** link points at a payment destination outside In-App Purchase, so the App Store builds omit it (guideline 3.1.1); `AboutSection` picks the link with `#if DIRECT`. **Rate CrocApp** opens `https://apps.apple.com/app/id6805675003?action=write-review` and appears in App Store builds only.

The support and privacy pages exist in `web/landing/` (`support/`, `privacy/`). The privacy page must name every server the app talks to and what each one sees, because the App Privacy label says nothing about them. Both URLs must answer HTTP 200 on the live site before you submit. App Store Connect stores the privacy URL without the trailing slash; `https://crocapp.dev/privacy` redirects (301) to `/privacy/`, so that is fine.

## Availability

Recommended: **All countries or regions except France.** In App Store Connect: your app, Pricing and Availability, App Availability, Set Up Availability, "Specific Countries or Regions", select all but France, tick the box that keeps new regions available (documented steps in "Sources"). If you used "All Countries or Regions", use Manage, Manage Availability and deselect France.

Basis (details and uncertainty in issue #115):

- Apple documents that a French encryption declaration is required for an app that uses an industry-standard algorithm not provided by the Apple operating system, "only if you're distributing your app on the App Store in France."
- croc, linked into the app, implements the cryptography (AES-256-GCM, P-256 and related primitives, verified locally); CrocApp adds none. The app still falls in that row of Apple's table, because the algorithms are not provided by the operating system.
- The owner decided to leave France out if App Store Connect requires the French declaration. Apple's table says it does, so France is out of the first release.
- Adding France later needs an ANSSI declaration. Track it as a `future` item; it is not filed from this file.

Unknown: whether availability set here applies to the iOS and macOS platforms together. Apple's availability page does not say. After saving, check that both platform pages show France as unavailable.

## App Privacy

| Question | Answer |
| :--- | :--- |
| "Do you or your third-party partners collect data from this app?" | **No, we do not collect data from this app.** Save. No further questions. (Apple's page does not use the words "Data Not Collected"; the product page then shows that label.) |
| Privacy Policy URL | `https://crocapp.dev/privacy/` (required for iOS and macOS apps) |

Does `PrivacyInfo.xcprivacy` agree? Verified locally (`app/CrocApp/PrivacyInfo.xcprivacy`): `NSPrivacyTracking` is false, `NSPrivacyTrackingDomains` is empty, `NSPrivacyCollectedDataTypes` is empty. The three required-reason entries (UserDefaults `CA92.1`, FileTimestamp `C617.1` and `3B52.1`, SystemBootTime `35F9.1`) are API declarations, not collection, and do not conflict with the answer.

Why "not collected" holds:

- Documented definition: "Collect" means "transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time." "Third-party partners" are "analytics tools, advertising networks, third-party SDKs, or other external vendors whose code you've added to your app."
- Inference: the developer receives nothing. The relays and getcroc.com are servers the user's transfer talks to, not code in the app, and they hold ciphertext only. This is a reading of the definition, not an Apple statement. Apple's page says nothing about end-to-end encryption or ciphertext.
- Residual risk: with Send as Link, getcroc.com keeps ciphertext for the lifetime the user chooses (up to 7 days). Apple could read that as collection. The fallback if App Review disagrees is to declare "Other User Content", not linked to the user, not used for tracking, purpose "App Functionality". Signal's label omits queued encrypted messages, which is a precedent, not a rule.

## Age rating

- Apple's questionnaire is answered in App Information, Age Ratings, Set Up Age Ratings (documented steps).
- It has in-app controls and capabilities (select those that apply), a frequency (None, Infrequent, Frequent) for each content descriptor, Yes/No for Gambling and Loot Boxes, and a final step for age category and override.
- Category names below are from Apple's "Age ratings values and definitions" page, which lists 4+, 9+, 13+, 16+, 18+.
- The exact on-screen question wording was not available, so the mapping below is by category name.
- Read each screen as you go.

| Section | Item | Answer for CrocApp |
| :--- | :--- | :--- |
| In-app controls | Parental Controls | Not selected (none in the app) |
| In-app controls | Age Assurance | Not selected |
| Capabilities | Unrestricted Web Access | Not selected. The app has no embedded browser (no `WKWebView`, `SFSafariViewController`; verified by search). Links open in the system browser. |
| Capabilities | User-Generated Content | Selected (owner's choice). Apple's definition is "broad distribution of content created by users", and CrocApp moves a file from one person to one other person, so not selecting it is also defensible. Inference: a reviewer may ask about reporting and blocking (guideline 1.2); the answer is that only devices sharing a code phrase exchange anything, and nothing is published. |
| Capabilities | Messaging and Chat | Not selected. See the note below. |
| Capabilities | Social Media, Social Media Disabled for Users Under 13 | Not selected |
| Capabilities | Advertising | Not selected (no ads) |
| Mature themes | Profanity or Crude Humor, Horror/Fear Themes, Alcohol/Tobacco/Drug Use or References | None |
| Medical or wellness | Medical or Treatment Information, Health or Wellness Topics | None |
| Sexuality or nudity | all three | None |
| Violence | all four | None |
| Chance-based | Simulated Gambling, Contests | None |
| Chance-based | Gambling, Loot Boxes | No |
| Age category | | Not Applicable (not "Made for Kids") |
| Override | | None |
| Age Suitability URL | | leave empty |

Result: **4+**, as App Store Connect showed with these answers. In Apple's table, 4+ is the tier whose allowed content includes messaging and chat, user-generated content, advertising and parental controls, so the Messaging and Chat decision below does not change the rating.

Note on Messaging and Chat (judgement): Apple defines it as users who "directly communicate with one another through features within the app" (text, voice, video, messaging, posting). CrocApp can send a text snippet, but it is a one-shot transfer with no conversation, contacts or accounts. "Not selected" is the honest reading, and ticking it would also leave the rating at 4+. The residual risk is a reviewer who disagrees; the review notes say what the text feature is.

Sending arbitrary files to another person is not content the app hosts or shows. The recipient sees a file list and accepts or declines each transfer.

## Review notes

Paste into App Review Information, Notes. Length: 3954 bytes of the 4000 allowed. Contact name, phone (international format with a plus sign) and email are yours to fill in; they are not in this repo.

```text
CrocApp is a free, open-source file-transfer app: it sends files, folders and text to another device with a short code phrase, end-to-end encrypted. It is a native front end for the open-source croc tool (https://github.com/schollz/croc, MIT, by Zack Scholl). CrocApp is unofficial and unaffiliated with croc or its author; the croc maintainer was informed by email. Source: https://github.com/bakirgdev/CrocApp

ACCOUNT: none. There is no login, sign-up, purchase or subscription, so there is no demo account. Sign-in required is off.

NETWORK: transfers connect two devices through croc's public relay pool (1.getcroc.com to 4.getcroc.com, TCP port 9009), which only forwards ciphertext. Links ("Send as Link", optional) use https://getcroc.com. The croc maintainer runs both, not CrocApp. Settings lets a user pick their own relay and link server. No analytics, ads or developer-side servers.

IF YOUR NETWORK BLOCKS PORT 9009: a code transfer then reports "No public relay answered". Use step 4 instead. Send as Link needs only HTTPS (port 443) and works on any network that allows the web.

PERMISSIONS (first use, both optional):
- Local network: "CrocApp uses the local network to discover nearby devices for direct, faster transfers." Used only to find another device on the same network. Denying it leaves relay transfers working.
- Camera (iPhone and iPad only): "CrocApp uses the camera to scan the QR code for a code phrase." Used only on Receive, Scan QR Code. Typing the code works without it.

TEST WITHOUT A SECOND DEVICE: use croc's own browser client at https://getcroc.com as the other device. Use a browser on your computer. For the macOS build, use a browser on the same Mac. Use the default settings.

1. App sends, browser receives.
   a. In CrocApp tap Send, Add Files (or type text), then tap Send. A code phrase like cape-junky-widow and a QR code appear.
   b. In the browser open https://getcroc.com, choose Receive, enter the code, and accept. The browser saves the file.
   c. Or tap Share Link in CrocApp, open that https://crocapp.dev/r/ link in a browser, and tap "Receive in Your Browser".
2. Browser sends, app receives.
   a. At https://getcroc.com choose Send, choose a file, and note the code the page shows.
   b. In CrocApp tap Receive, type the code (or paste the getcroc.com link; the app keeps only the code), and tap Receive.
   c. The file list appears. Tap Accept. The file is saved to the receive folder (on iPhone and iPad, On My iPhone, CrocApp, in the Files app).
3. Link flow: tap the link https://crocapp.dev/r/#cape-junky-widow in Notes or Messages with CrocApp installed (iOS does not open the app for a URL typed into Safari), or open that page in a browser and press Open in CrocApp. CrocApp opens on Receive with the code filled in and does not connect until you tap Receive.
4. Send as Link (HTTPS only): in Send choose files, turn on "Send as Link", then tap Send as Link. A link and QR code appear. Open the link in a browser to get the file, or receive it in the app: tap Receive, paste the link into the Code phrase field (the screen shows "Receive from Link"), and tap Receive. In History, Revoke Link makes it stop working.

The browser UI at getcroc.com is the croc project's and may change wording; the flow stays: one device shows a code, the other enters it.

Please keep CrocApp in the foreground during a transfer on iPhone and iPad.

Questions: https://crocapp.dev/support/

MAC ENTITLEMENTS. network.server: the Mac accepts incoming TCP in two features. 1) Each send runs croc's local relay on ports 9009-9013 so a receiver on the same network connects directly (during a send, lsof -nP -iTCP:9009 -sTCP:LISTEN lists CrocApp). 2) Settings, Relay tab (or the menu bar window), Run a Relay: off by default; when on, the Mac serves croc's relay protocol on ports 9009-9012. downloads.read-write: received files go to Downloads/CrocApp by default. On Mac, click where the steps say tap.
```

Check the notes by hand before pasting, as listed in "Open checks before submitting".

Keep the "MAC ENTITLEMENTS" paragraph while the macOS app carries `network.server`. Apple's automated Mac check rejects the build under guideline 2.4.5 when the entitlement "does not appear to have matching functionality", because the listeners live in the statically linked Go engine, where the check does not find them. The rejection asks for a reply to App Review that explains the use, plus the same explanation in these notes. The entitlement cannot go: croc starts its local relay on every send unless **Skip Local Network** is on, and fails the send when the port cannot be bound (`setupLocalRelay` in croc 11 `src/croc/local_relay.go`).

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in both App Store Info.plists (`../RELEASING.md`, "Export compliance"), and France is excluded from availability: Apple's own table makes `false` coherent only while France is out. The research (Apple, US and French sources, what is unknown) is in [issue #115](https://github.com/bakirgdev/CrocApp/issues/115).

| If App Store Connect asks | Answer |
| :--- | :--- |
| Availability | All countries or regions except France |
| "Missing Compliance" on an uploaded build | Not expected with the key set. If it appears: uses encryption, yes; Category 5, Part 2 exemption, no; available in France, no; standard algorithms, not proprietary |
| It then demands a French declaration with France excluded | Stop and ask Apple Developer Support: that contradicts Apple's table |

## Open checks before submitting

Before every submission:

- From 1.2.1, App Accessibility claims VoiceOver and Voice Control on iPhone, iPad and Mac, on the owner's runs with the App Store builds. The rest of the accessibility audit is still open (`../known-issues.md`, "Release"). Until it passes, keep VoiceOver and "largest text sizes" claims out of the description and What's New.
- Read getcroc.com's current labels (Send, Receive, Choose files, "Croc code or stored link", Copy code) and compare them with the review notes. The page belongs to the croc project and can change.
- Check the contact name, phone and email in App Review Information. They are not in the repo, and the developer-account address is not necessarily the public support contact.
- Confirm `https://crocapp.dev/support/` and `https://crocapp.dev/privacy/` return HTTP 200.
- Re-check that getcroc.com still runs its own analytics (Umami) and ads (Google AdSense), as the privacy page says, and update the page's date for that check. The reviewer opens getcroc.com, and the `/r/` page links to it. The app does not load it (no web view).
- Keep France out of availability until the ANSSI declaration exists (see "Export compliance").

## Submitting

- Press **Add for Review** on each platform's version page. It only builds a draft; nothing reaches Apple until **Submit for Review**.
- App Store Connect keeps one draft submission per platform, so iOS and macOS go in as two submissions, one right after the other.
- A screenshot that is still processing blocks **Add for Review** with "1 or more screenshots must finish processing". Reload after a minute and press it again.
- Version release is Manual, so the website's store links can go live before the listing does. Approval does not publish the app; **Release This Version** on each platform does.
- **A later version.** The **+** next to "iOS App" or "macOS App" in the sidebar adds it; enter `MARKETING_VERSION`, paste "What's New" from the version's `CHANGELOG.md` section, and pick the build once it has processed. Description, keywords, screenshots and "What's New" change only with a new version; promotional text changes any time without review.
- While either platform has a version in review, App Information and App Privacy are locked for both.
- **Creative assets** (the header and search results asset) are uploaded in the Asset Library and go through **Add for Review** there, as an iOS submission of their own with no build. Once approved, select the asset on the iOS version page > Header and Search Results.

## Sources

Apple's pages change. Re-read them before you rely on a limit or a rule.

- App information (name 30, subtitle 30, privacy URL): https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Platform version information (promo 170, description 4000, keywords 100 bytes, What's New 4000, notes 4000 bytes, copyright, URLs): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Age ratings values and definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- Set an app age rating: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- App privacy details (definition of collect, third-party partners): https://developer.apple.com/app-store/app-privacy-details/
- Manage availability: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store
- getcroc.com page and its bundled script (labels, Umami, AdSense): https://getcroc.com
- Local: `app/Config/*.plist`, `app/CrocApp/PrivacyInfo.xcprivacy`, `app/CrocApp.xcodeproj/project.pbxproj` (purpose strings, category), `LICENSE`, `../known-issues.md`, `../RELEASING.md`.
