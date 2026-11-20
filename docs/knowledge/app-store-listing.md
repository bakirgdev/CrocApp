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
| Promotional text | 170 characters | 146 | Platform version information page |
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
Send files, folders or text to another device with a short code phrase. End-to-end encrypted, no account, open source. An unofficial app for croc.
```

## Description

Length: 2859 characters. It carries no price wording (the price shows on the product page) and no Dynamic Type claim, and it names the navigation, the widget and the Control Center controls. The security statements follow the approved list in `design/voice.md`, "Claims".

```text
CrocApp sends files, folders and text from one device to another with a short code phrase such as cape-junky-widow. No account, no sign-up, and the two devices do not need to be on the same network.

HOW IT WORKS
1. Choose files, a folder or some text.
2. CrocApp shows a code phrase and a QR code. Read it out, message it, or let the other person scan it.
3. The other device enters the phrase, sees the file list, and accepts. The transfer starts.

PRIVATE BY DESIGN
Transfers are end-to-end encrypted. The code phrase authenticates both devices, and a relay that passes the data along only ever sees ciphertext. CrocApp has no accounts, no analytics, no ads and no tracking, and your transfer history stays on your device. CrocApp has not had a formal third-party security audit.

WORKS WITH CROC
CrocApp is a native SwiftUI app built on croc, the open-source file-transfer tool by Zack Scholl. A code phrase from the croc command line works in CrocApp, and the other way around. The other device needs croc 11 or newer: older croc 10 cannot transfer with CrocApp.

WHAT YOU CAN DO
- Send several files, whole folders, text or clipboard contents.
- Receive with a code phrase, a link, or a scanned QR code on iPhone and iPad. Opening a link only fills in the code; nothing connects until you tap Receive.
- See the file list before you accept. Watch progress and speed, cancel at any time, and resume an interrupted transfer.
- Send as Link: share encrypted files with someone who is not online. A link lasts 1 hour, 1 day or 7 days, holds up to 100 files and 1 GiB in total, can be downloaded up to 100 times, and can be revoked from History.
- Use your own relay, send over the local network only, or route through a proxy, from Settings.
- Move between Send, Receive and History with tabs on iPhone and a sidebar on iPad and Mac. Files, text and codes you entered stay when you switch.
- iPhone and iPad: send from any app with the share sheet, find received files in the Files app, and use Shortcuts and Siri actions, a widget and Control Center controls.
- Mac: drag and drop, a menu bar window for quick sends, and Shortcuts actions.
- Light and dark appearance.

WHAT TO KNOW
By default CrocApp uses the public relays run by the croc project to connect two devices, and the croc project's link server at getcroc.com for links. Your files are encrypted before they leave your device. You can point CrocApp at relays and a link server you run yourself. Nearby transfers over the local network depend on what your network and device allow.

The source code is public under the MIT license at github.com/bakirgdev/CrocApp. CrocApp is an independent project. It is unofficial and not affiliated with or endorsed by croc or its author. Apple, iPhone, iPad, Mac and Siri are trademarks of Apple Inc.

Questions and bug reports: https://crocapp.dev/support/
```

The description does not claim VoiceOver or Dynamic Type support. Add them only after the accessibility audit in "Open checks before submitting" has passed.

## Keywords

- Comma separated, no spaces.
- Words already in the name or subtitle (`crocapp`, `send`, `files`, `code`, `phrase`) and the category (`utilities`) are left out because Apple already indexes them.
- `croc` is a deliberate keep: the name is one token, and the protocol name is what people search.
- `airdrop` is left out on purpose (another company's trademark). `wormhole` is left out too: it names other transfer products (Magic Wormhole, Wormhole), which guideline 2.3.7 treats as trademark-adjacent.
- `secure` and `p2p` are search terms people type; keywords are never shown, so `design/voice.md`, "Terminology", which binds displayed copy, does not apply to them.
- 1.3.0 dropped `private` (near-synonym of `encrypted` and `secure`), `mac`, `lan`, `drop`, `peer` and `text`, and added `clipboard`, `cli`, `large`, `photos` and `video` for features the app has (Paste, the croc command line, large files, Add Photos). This is a hypothesis: no search-popularity data was available and Product Page Optimization is off, so only App Analytics impressions before and after show whether it helped. The previous string is in git history.

```text
croc,transfer,share,encrypted,secure,qr,p2p,link,folder,nearby,e2ee,clipboard,cli,large,photos,video
```

## What's New

App Store Connect shows no What's New field on an app's first version. From the second App Store release on, write it from that release's `[x.y.z]` section of `CHANGELOG.md`, in the voice of the description: short, what a user sees first, and honest about what was removed. The text is per platform, because the Mac lost **Run a Relay** and iOS never had it. The first lines show before "more", so the navigation change leads.

Version 1.3.0, iOS (1277 characters):

```text
• iPhone now has tabs for Send, Receive, History and Settings, and iPad has a sidebar. Files you picked, text you typed and a code stay when you switch.
• The buttons that answer a screen (Send, Receive, Accept, Decline, Cancel) sit at the bottom, in the same place every time. Add Files, Add Folder and Add Photos are one Add menu.
• Buttons and colors use the system's own styles, with one olive accent.
• Fixed: the patterns under Exclude from sends now apply to every folder send. Before, they only worked when the folder was sent as a zip.
• Fixed: a finished transfer no longer leaves its files, text or custom code staged for the next one.
• The transfer engine is croc 11.6.5. It fixes a crash that a malformed connection could cause in the local relay CrocApp runs while it sends.
• Removed: the Home screen. Send, Receive and History each have their own tab or sidebar entry.
• Removed: History in Spotlight. Entries CrocApp added to Spotlight are deleted the first time you open this version. Find Transfers and Open Transfer in Shortcuts still work.
• Removed: Multicast Address, Built-in DNS Resolver, Single Connection and Exact Paths in Advanced settings. Your Exact Paths move to the patterns under Exclude from sends, and the others go back to croc's defaults.
```

Version 1.3.0, macOS (1418 characters):

```text
• The Mac has a sidebar for Send, Receive and History. Files you picked, text you typed and a code stay when you switch. Settings stays its own window.
• The buttons that answer a screen (Send, Receive, Accept, Decline, Cancel) sit at the bottom, in the same place every time. Add Files and Add Folder are one Add menu.
• Buttons and colors use the system's own styles, with one olive accent.
• Fixed: the patterns under Exclude from sends now apply to every folder send. Before, they only worked when the folder was sent as a zip.
• Fixed: a finished transfer no longer leaves its files, text or custom code staged for the next one.
• The transfer engine is croc 11.6.5. It fixes a crash that a malformed connection could cause in the local relay CrocApp runs while it sends.
• Removed: Run a Relay and Check Relay. To host a relay, run croc relay on a machine you control. The relay address and password you set in Settings still work.
• Removed: the Home screen. Send, Receive and History each have their own sidebar entry.
• Removed: History in Spotlight. Entries CrocApp added to Spotlight are deleted the first time you open this version. Find Transfers and Open Transfer in Shortcuts still work.
• Removed: Multicast Address, Built-in DNS Resolver, Single Connection and Exact Paths in Advanced settings. Your Exact Paths move to the patterns under Exclude from sends, and the others go back to croc's defaults.
```

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

China mainland stays available. Its declarations are in "App Compliance (China mainland)".

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
| Capabilities | Shared Location | Not selected (the app reads no location) |
| Capabilities | Advertising | Not selected (no ads) |
| Mature themes | Dating and Relationships | No |
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

Shared Location and Dating and Relationships are newer questions, required from 15 January 2027 or with any earlier change to the questionnaire. The declaration is editable only while a version is being prepared: on the live app info the API refuses with "This age rating declaration is not editable" (verified). So they are answered with the next version, through the questionnaire or a PATCH of `sharedLocation` and `datingAndRelationships`, both booleans (the API rejected a string for the second). `asc age-rating edit` has no flags for them yet.

Sending arbitrary files to another person is not content the app hosts or shows. The recipient sees a file list and accepts or declines each transfer.

## Review notes

Paste into App Review Information, Notes, per platform. Limit 4000 bytes: the iOS block is 2988 bytes, the macOS block 3842. Contact name, phone (international format with a plus sign) and email are yours to fill in; they are not in this repo. Step 1 names an Add menu conditionally: make it plain or drop it once the 1.3.0 build is final.

iOS:

```text
CrocApp is a free, open-source file-transfer app: it sends files, folders and text to another device with a short code phrase, end-to-end encrypted. It is a native front end for the open-source croc tool (https://github.com/schollz/croc, MIT, by Zack Scholl). CrocApp is unofficial and unaffiliated with croc or its author; the croc maintainer was informed by email. Source: https://github.com/bakirgdev/CrocApp

WHAT CHANGED IN 1.3.0: navigation is tabs on iPhone (Send, Receive, History, Settings) and a sidebar on iPad. Buttons and colors use the system styles. Removed: the Home screen, History in Spotlight (the first launch deletes the entries older versions added), and four Advanced options (Multicast Address, Built-in DNS Resolver, Single Connection, Exact Paths). The engine is croc 11.6.5. Permissions and App Privacy answers are unchanged from 1.2.1.

ACCOUNT: none. No login, sign-up, purchase or subscription, so there is no demo account. Sign-in required is off.

NETWORK: code transfers connect two devices through croc's public relay pool (1.getcroc.com to 4.getcroc.com, TCP port 9009), which only forwards ciphertext. Send as Link (optional) uses https://getcroc.com. The croc maintainer runs both, not CrocApp. Settings lets a user pick their own. No analytics, ads or developer-side servers. If your network blocks port 9009, a code transfer reports "No public relay answered": use step 3, which needs only HTTPS.

PERMISSIONS (first use, both optional): Local network, "CrocApp uses the local network to discover nearby devices for direct, faster transfers." Denying it leaves relay transfers working. Camera, "CrocApp uses the camera to scan the QR code for a code phrase." Only on Receive, Scan QR Code; typing the code works without it.

TEST WITHOUT A SECOND DEVICE: use croc's browser client at https://getcroc.com as the other device, in a browser on your computer, with the default settings.

1. App sends, browser receives. On the Send tab tap Add, then Files, or type text, then tap Send. A code phrase like cape-junky-widow and a QR code appear. In the browser open https://getcroc.com, choose Receive, enter the code, and accept.
2. Browser sends, app receives. At https://getcroc.com choose Send, choose a file, and note the code. On the Receive tab type the code (or paste the getcroc.com link; the app keeps only the code) and tap Receive. The file list appears. Tap Accept. The file is saved to the receive folder (On My iPhone, CrocApp, in the Files app).
3. Send as Link (HTTPS only): on the Send tab choose files, turn on "Send as Link", tap Send as Link. A link and QR code appear. Open the link in a browser, or on the Receive tab paste it into the Code phrase field ("Receive from Link") and tap Receive. On the History tab, Revoke Link makes it stop working.

The getcroc.com page is the croc project's and may change wording. Please keep CrocApp in the foreground during a transfer on iPhone and iPad.

Questions: https://crocapp.dev/support/
```

macOS (the iOS text with the Mac differences and the entitlement paragraph):

```text
CrocApp is a free, open-source file-transfer app: it sends files, folders and text to another device with a short code phrase, end-to-end encrypted. It is a native front end for the open-source croc tool (https://github.com/schollz/croc, MIT, by Zack Scholl). CrocApp is unofficial and unaffiliated with croc or its author; the croc maintainer was informed by email. Source: https://github.com/bakirgdev/CrocApp

WHAT CHANGED IN 1.3.0: navigation is tabs on iPhone (Send, Receive, History, Settings) and a sidebar on iPad and Mac. Buttons and colors use the system styles. Removed: on the Mac, Run a Relay and Check Relay; the Home screen, History in Spotlight (the first launch deletes the entries older versions added), and four Advanced options (Multicast Address, Built-in DNS Resolver, Single Connection, Exact Paths). The engine is croc 11.6.5. Permissions, entitlements and App Privacy answers are unchanged from 1.2.1.

ACCOUNT: none. No login, sign-up, purchase or subscription, so there is no demo account. Sign-in required is off.

NETWORK: code transfers connect two devices through croc's public relay pool (1.getcroc.com to 4.getcroc.com, TCP port 9009), which only forwards ciphertext. Send as Link (optional) uses https://getcroc.com. The croc maintainer runs both, not CrocApp. Settings lets a user pick their own. No analytics, ads or developer-side servers. If your network blocks port 9009, a code transfer reports "No public relay answered": use step 3, which needs only HTTPS.

PERMISSIONS (first use, both optional): Local network, "CrocApp uses the local network to discover nearby devices for direct, faster transfers." Denying it leaves relay transfers working. Camera (iPhone and iPad only), "CrocApp uses the camera to scan the QR code for a code phrase." Only on Receive, Scan QR Code; typing the code works without it.

TEST WITHOUT A SECOND DEVICE: use croc's browser client at https://getcroc.com as the other device, in a browser on your computer (on the same Mac for the macOS build), with the default settings.

1. App sends, browser receives. On the Send tab (Send in the sidebar on iPad and Mac) tap Add, then Files, or type text, then tap Send. A code phrase like cape-junky-widow and a QR code appear. In the browser open https://getcroc.com, choose Receive, enter the code, and accept.
2. Browser sends, app receives. At https://getcroc.com choose Send, choose a file, and note the code. On the Receive tab type the code (or paste the getcroc.com link; the app keeps only the code) and tap Receive. The file list appears. Tap Accept. The file is saved to the receive folder (on iPhone and iPad, On My iPhone, CrocApp, in the Files app).
3. Send as Link (HTTPS only): on the Send tab choose files, turn on "Send as Link", tap Send as Link. A link and QR code appear. Open the link in a browser, or on the Receive tab paste it into the Code phrase field ("Receive from Link") and tap Receive. On the History tab, Revoke Link makes it stop working.

The getcroc.com page is the croc project's and may change wording. Please keep CrocApp in the foreground during a transfer on iPhone and iPad.

Questions: https://crocapp.dev/support/

MAC ENTITLEMENTS. network.server: the Mac accepts incoming TCP in two places only. (1) Each send runs croc's local relay, normally on ports 9009 to 9013, so a receiver on the same network connects directly (during a send, lsof -nP -iTCP:9009 -sTCP:LISTEN lists CrocApp); Skip Local Network in Settings, Advanced turns it off. (2) At the first transfer after each launch, a local-network permission check listens on an ephemeral port, advertised as Bonjour _crocapp._tcp, for at most 8 seconds and drops every connection. No relay can be started from the app. downloads.read-write: received files go to Downloads/CrocApp by default. On Mac, click where the steps say tap.
```

Check the notes by hand before pasting, as listed in "Open checks before submitting".

Keep the "MAC ENTITLEMENTS" paragraph while the macOS app carries `network.server`. Apple's automated Mac check rejects the build under guideline 2.4.5 when the entitlement "does not appear to have matching functionality", because the listeners live in the statically linked Go engine, where the check does not find them. The rejection asks for a reply to App Review that explains the use, plus the same explanation in these notes. The entitlement cannot go: croc starts its local relay on every send unless **Skip Local Network** is on, and fails the send when the port cannot be bound (`setupLocalRelay` in croc 11 `src/croc/local_relay.go`). The relay is not the only listener: `LocalNetworkChecker` opens an `NWListener` on an ephemeral port, advertised as `_crocapp._tcp`, for at most 8 seconds at the first transfer after launch, so the notes name both and never say "nothing else listens".

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in both App Store Info.plists (`../RELEASING.md`, "Export compliance"), and France is excluded from availability: Apple's own table makes `false` coherent only while France is out. The research (Apple, US and French sources, what is unknown) is in [issue #115](https://github.com/bakirgdev/CrocApp/issues/115).

| If App Store Connect asks | Answer |
| :--- | :--- |
| Availability | All countries or regions except France |
| "Missing Compliance" on an uploaded build | Not expected with the key set. If it appears: uses encryption, yes; Category 5, Part 2 exemption, no; available in France, no; standard algorithms, not proprietary |
| It then demands a French declaration with France excluded | Stop and ask Apple Developer Support: that contradicts Apple's table |

## App Compliance (China mainland)

App Information has an **App Compliance** page with two declarations for China mainland. Apple keeps an app without them out of China mainland, and checks changed answers with the next version sent to App Review. Both can be edited later.

| Declaration | Answer | Basis |
| :--- | :--- | :--- |
| AI Generated or Synthetic Content: "Does your app offer AIGC services in China mainland?" | **No** | CrocApp has no AI features. |
| Security Assessment: "Does your app include features that require a security assessment in China mainland?" | **No** | See below. |

Why No holds for the Security Assessment (owner's decision; research, not legal advice):

- Apple's help page names the features as distributing AI-generated content or "enabling end-to-end encrypted instant messaging (EIM)", and says to select No if the app does not offer them (verified, "View China mainland compliance information" in "Sources").
- The Chinese rule behind it (CAC provisions on internet information services with public opinion attributes or social mobilization capability) lists forums, blogs, microblogs, chat rooms, communication groups, public accounts, short video, live streaming, information sharing and mini programs. Each reaches many people. A code-phrase transfer between two devices, with no accounts, contacts, threads or discovery, is none of these (inferred).
- Weakest points: sending text, which is closest to messaging, and **Send as Link**, a URL anyone holding it can open, which is closest to "information sharing". Apple also accepts No when a feature is disabled in China mainland, which is the fallback for Send as Link.
- Answering Yes needs a completed assessment report that an individual outside China cannot obtain in practice (inferred from third-party guidance), so Yes would mean leaving China mainland.

Unknown: how Apple verifies a No, and whether the CAC reads a one-off encrypted transfer as messaging. The CAC had Apple remove Bitchat, an account-less encrypted chat app, under the same rules.

## Open checks before submitting

Before every submission:

- App Accessibility claims VoiceOver and Voice Control on iPhone, iPad and Mac from 1.2.1. The rest of the accessibility audit, Larger Text and Sufficient Contrast included, passed on the owner's runs with the 1.3.0 App Store builds (#124, #173). Rerun the Accessibility Inspector and VoiceOver passes on the shipped screens after any change to layout, text styles or colors, before keeping those claims for a new version.
- Run the review-note steps on the uploaded iOS and macOS builds, with the tab and sidebar names as the build shows them, and fix the notes where a label differs. Recount the blocks in this file after any wording change.
- Read getcroc.com's current labels (Send, Receive, Choose files, "Croc code or stored link", Copy code) and compare them with the review notes. The page belongs to the croc project and can change.
- Check the contact name, phone and email in App Review Information. They are not in the repo, and the developer-account address is not necessarily the public support contact.
- Confirm `https://crocapp.dev/support/` and `https://crocapp.dev/privacy/` return HTTP 200.
- Re-check that getcroc.com still runs its own analytics (Umami) and ads (Google AdSense), as the privacy page says, and update the page's date for that check. The reviewer opens getcroc.com, and the `/r/` page links to it. The app does not load it (no web view).
- Keep France out of availability until the ANSSI declaration exists (see "Export compliance").
- Answer any age rating question still unanswered, such as Shared Location and Dating and Relationships (see "Age rating"), once the new version exists.
- After the upload, rename the new Asset Library images and archive or delete the replaced ones (see "Screenshots").

## Screenshots

`scripts/capture-screenshots.sh` writes every set (`screenshots.md`). Each class directory under `assets/screenshots/app-store/` fills one slot on the iOS or macOS version page, in file order. Documented on Apple's screenshot specifications page (URL in "Sources").

| Slot in App Store Connect | Class directory | Pixels | Status |
| :--- | :--- | :--- | :--- |
| iPhone with Dynamic Island (medium display) | `iphone-6.3` | 1206x2622 | Required |
| iPhone with Dynamic Island (large display) | `iphone-6.9` | 1320x2868 | Optional |
| iPhone Duo, outer display | `iphone-duo-outer` | 1398x2034 | Optional now; required from April 2027 for an app built with the iOS 27.1 SDK or later |
| iPhone Duo, inner display | `iphone-duo-inner` | 2853x2007 (landscape) | Same as the outer display |
| iPad 13-inch | `ipad-13` | 2064x2752 | Required |
| Mac | `mac` | 2880x1800 | One of four accepted 16:10 sizes |

- Apple's page accepts either orientation for both iPhone Duo displays (1398x2034 or 2034x1398, 2007x2853 or 2853x2007). The inner set is landscape, the device's open pose, which shows the sidebar layout. The outer set is portrait.
- Uploading iPhone Duo screenshots adds a badge to the product page saying the app is made for iPhone Duo (documented on the same page). The app builds with Xcode 27.2 (`.xcode-version`), whose iOS SDK is 27.2, so the April 2027 requirement applies to it.
- Inference: the iPhone Duo slots appear on the iOS version page only, beside the other iPhone slots. Not checked in App Store Connect.
- Uploads also land in the Asset Library (`asc asset-library images list`). Name each image there `<slot>: <NN> <Screen>, <Light|Dark>`, for example `iPhone 6.9: 01 Send Files, Light`, with slots `iPhone 6.3`, `iPhone 6.9`, `iPhone Duo`, `iPad 13` and `Mac`. The header asset is `Product Page Header`. Rename with `asc asset-library images rename`.
- An image no version uses can be deleted. Once an image went to App Review with a version, Apple refuses to delete it ("can no longer be deleted"), so archive it instead with `asc asset-library images archive`.

## Submitting

- Press **Add for Review** on each platform's version page. It only builds a draft; nothing reaches Apple until **Submit for Review**.
- App Store Connect keeps one draft submission per platform, so iOS and macOS go in as two submissions, one right after the other.
- A screenshot that is still processing blocks **Add for Review** with "1 or more screenshots must finish processing". Reload after a minute and press it again.
- Version release is Automatically release this version after approval on both platforms, so approval publishes the app and there is no separate **Release This Version** step.
- **A later version.** The **+** next to "iOS App" or "macOS App" in the sidebar adds it; enter `MARKETING_VERSION`, paste "What's New" from the version's `CHANGELOG.md` section, and pick the build once it has processed. Description, keywords, screenshots and "What's New" change only with a new version; promotional text changes any time without review.
- While either platform has a version in review, App Information and App Privacy are locked for both.
- **Creative assets** (the header and search results asset) are uploaded in the Asset Library and go through **Add for Review** there, as an iOS submission of their own with no build. Once approved, select the asset on the iOS version page > Header and Search Results.

## Sources

Apple's pages change. Re-read them before you rely on a limit or a rule.

- App information (name 30, subtitle 30, privacy URL): https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Platform version information (promo 170, description 4000, keywords 100 bytes, What's New 4000, notes 4000 bytes, copyright, URLs): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Screenshot specifications (sizes per slot, the iPhone Duo requirement and badge): https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- Age ratings values and definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- Set an app age rating: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- App privacy details (definition of collect, third-party partners): https://developer.apple.com/app-store/app-privacy-details/
- Manage availability: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store
- View China mainland compliance information (Security Assessment, AIGC, when to select No): https://developer.apple.com/help/app-store-connect/manage-compliance-information/view-china-mainland-compliance-information/
- CAC provisions on the security assessment of internet information services with public opinion attributes or social mobilization capability: https://www.cac.gov.cn/2018-11/15/c_1123716072.htm
- getcroc.com page and its bundled script (labels, Umami, AdSense): https://getcroc.com
- Local: `app/Config/*.plist`, `app/CrocApp/PrivacyInfo.xcprivacy`, `app/CrocApp.xcodeproj/project.pbxproj` (purpose strings, category), `LICENSE`, `../RELEASING.md`.
