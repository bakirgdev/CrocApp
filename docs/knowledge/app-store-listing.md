# App Store listing

The copy for CrocApp's App Store Connect record, written to be pasted field by field and reused for every App Store release. One app record holds iOS, iPadOS and macOS (universal purchase, bundle ID `com.bakirgdev.CrocApp`). The record has not been submitted yet: the first App Store release is the first submission, and it goes out as 1.1.0 (`../RELEASING.md`, "App Store builds").

Every fenced block under a field heading is the exact text to paste. Character counts were measured with a script (Python `len()` for characters, `len(s.encode())` for the two byte-limited fields). When you change a block, recount it.

How to read the claims:

- **Documented**: an Apple, ANSSI or eCFR page says it. The URL is in "Sources".
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

Length: 2921 characters. The security statements follow the approved list in `design/content.md`, "Claims".

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
- Send as Link: share encrypted files for someone who is not online, with a lifetime of 1 hour, 1 day or 7 days and a limit on downloads (up to 100 files and 1 GiB). You can revoke the link from History.
- Use your own relay, force local-network-only transfers, or route through a proxy, from Settings.
- iPhone and iPad: send from any app with the share sheet, follow a transfer in a Live Activity, find received files in the Files app, and use Shortcuts and Siri actions.
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
- `airdrop` is left out on purpose (another company's trademark).
- `secure`, `p2p` and `peer` are search terms people type; keywords are never shown, so `design/content.md`, "Terminology", which binds displayed copy, does not apply to them.

```text
croc,transfer,share,encrypted,secure,private,qr,p2p,wormhole,folder,lan,nearby,e2ee,drop,peer,text
```

## What's New

Not verified: whether App Store Connect shows or requires this field for an app's first version. Apple's version-information page, the only Apple source recorded here, does not say. Paste the text below if the field appears, and leave it empty if it does not. Later releases replace it with that release's changes, taken from the `[x.y.z]` section of `CHANGELOG.md`.

Length: 1217 characters.

```text
CrocApp is on the App Store for iPhone, iPad and Mac.

Highlights
- Send as Link: share encrypted files by link or QR code with someone who is not online. You choose the lifetime and the number of downloads, and can revoke the link from History.
- Links: opening a CrocApp link, a crocapp.dev/r/ link or a getcroc.com link fills in the code on the Receive screen. Nothing connects until you tap Receive.
- A Keep Both or Replace choice when a received file has the same name as one you already have.
- Advanced settings: proxies, sender IP, send speed limit and more. The defaults suit most people.
- Mac menu bar quick send, and Shortcuts and Siri actions for sending and receiving.
- iPad File menu: Show Receive Folder in Files (Shift Command R).

Good to know
- The transfer engine is croc 11.5.5. A device running croc 10 cannot transfer with CrocApp; it needs croc 11 or newer.
- Errors say what went wrong: a wrong code, a refused transfer, a lost connection, a device on an older croc, or no public relay available.
- History keeps less of a code than before, and never the whole code.

CrocApp is free and open source. It is unofficial and not affiliated with croc or its author.
```

Update the highlights to match the release you submit. If the first App Store release has other changes, list those.

## URLs, category, price

| Field | Value |
| :--- | :--- |
| Support URL | `https://crocapp.dev/support/` |
| Marketing URL | `https://crocapp.dev` |
| Privacy Policy URL | `https://crocapp.dev/privacy/` |
| Primary category | Utilities (matches `LSApplicationCategoryType` `public.app-category.utilities` in the build settings, verified locally) |
| Secondary category | Productivity (optional; a judgement call, drop it if unsure). Unknown whether the iOS and macOS platforms of one record share categories; check that the App Information page shows both. |
| Copyright | `2026 Bakir Gracić` (the holder in `LICENSE` is "Bakir Gracić", with the accent; Apple adds the symbol) |
| Price | Free (USD 0), no In-App Purchases |
| Version | `MARKETING_VERSION` in `app/Config/Version.xcconfig`; attach the iOS and macOS builds that finished processing in TestFlight |
| Privacy choices URL | leave empty (optional per Apple) |
| Sign-in required (App Review) | off; the app has no account |

The support and privacy pages exist in `web/landing/` (`support/`, `privacy/`). The privacy page must name every server the app talks to and what each one sees, because the App Privacy label says nothing about them. Both URLs must answer HTTP 200 on the live site before you submit.

## Availability

Recommended: **All countries or regions except France.** In App Store Connect: your app, Pricing and Availability, App Availability, Set Up Availability, "Specific Countries or Regions", select all but France, tick the box that keeps new regions available (documented steps in "Sources"). If you used "All Countries or Regions", use Manage, Manage Availability and deselect France.

Basis (details and uncertainty in "Export compliance" below):

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
| Capabilities | User-Generated Content | Not selected. Apple's definition is "broad distribution of content created by users"; CrocApp moves a file from one person to one other person. |
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

Expected result: **4+**. In Apple's table, 4+ is the tier whose allowed content includes messaging and chat, user-generated content, advertising and parental controls, so the Messaging and Chat decision below does not change the rating.

Note on Messaging and Chat (judgement): Apple defines it as users who "directly communicate with one another through features within the app" (text, voice, video, messaging, posting). CrocApp can send a text snippet, but it is a one-shot transfer with no conversation, contacts or accounts. "Not selected" is the honest reading, and ticking it would also leave the rating at 4+. The residual risk is a reviewer who disagrees; the review notes say what the text feature is.

Sending arbitrary files to another person is not content the app hosts or shows. The recipient sees a file list and accepts or declines each transfer.

## Review notes

Paste into App Review Information, Notes. Length: 3304 bytes of the 4000 allowed. Contact name, phone (international format with a plus sign) and email are yours to fill in; they are not in this repo.

```text
CrocApp is a free, open-source file-transfer app: it sends files, folders and text to another device with a short code phrase, end-to-end encrypted. It is a native front end for the open-source croc tool (https://github.com/schollz/croc, MIT, by Zack Scholl). CrocApp is unofficial and unaffiliated with croc or its author; the croc maintainer was informed by email. Source: https://github.com/bakirgdev/CrocApp

ACCOUNT: none. There is no login, sign-up, purchase or subscription, so there is no demo account. Sign-in required is off.

NETWORK: transfers connect two devices through croc's public relay pool (1.getcroc.com to 4.getcroc.com, TCP port 9009), which only forwards ciphertext. Links ("Send as Link", optional) use https://getcroc.com. The croc maintainer runs both, not CrocApp. Settings lets a user pick their own relay and link server. No analytics, ads or developer-side servers. If your network blocks outbound port 9009 the app reports "No public relay answered"; please test on an open network.

PERMISSIONS (first use, both optional):
- Local network: "CrocApp uses the local network to discover nearby devices for direct, faster transfers." Used only to find another device on the same network. Denying it leaves relay transfers working.
- Camera (iPhone and iPad only): "CrocApp uses the camera to scan the QR code for a code phrase." Used only on Receive, Scan QR Code. Typing the code works without it.

TEST WITHOUT A SECOND DEVICE: use croc's own browser client at https://getcroc.com as the other device. Use a browser on your computer. For the macOS build, use a browser on the same Mac. Use the default settings.

1. App sends, browser receives.
   a. In CrocApp tap Send, Add Files (or type text), then tap Send. A code phrase like cape-junky-widow and a QR code appear.
   b. In the browser open https://getcroc.com, choose Receive, enter the code, and accept. The browser saves the file.
   c. Or tap Share Link in CrocApp, open that https://crocapp.dev/r/ link in a browser, and tap "Receive in your browser".
2. Browser sends, app receives.
   a. At https://getcroc.com choose Send, choose a file, and note the code the page shows.
   b. In CrocApp tap Receive, type the code (or paste the getcroc.com link; the app keeps only the code), and tap Receive.
   c. The file list appears. Tap Accept. The file is saved to the receive folder (on iPhone and iPad, On My iPhone, CrocApp, in the Files app).
3. Link flow: tap the link https://crocapp.dev/r/#cape-junky-widow in Notes or Messages with CrocApp installed (iOS does not open the app for a URL typed into Safari), or open that page in a browser and press Open in CrocApp. CrocApp opens on Receive with the code filled in and does not connect until you tap Receive.
4. Optional, Send as Link: in Send choose files, turn on "Send as Link", then tap Send as Link. A link and QR code appear. Open the link in a browser to get the file. In History, Revoke Link makes it stop working.

The browser UI at getcroc.com is the croc project's and may change wording; the flow stays: one device shows a code, the other enters it.

Please keep CrocApp in the foreground during a transfer on iPhone and iPad. A transfer can continue briefly in the background through a system Live Activity.

Questions: https://crocapp.dev/support/
```

Check the notes by hand before pasting, as listed in "Open checks before submitting".

## Export compliance

Status: written after re-reading Apple's, ANSSI's and eCFR's pages as listed in "Sources". The App Store Connect encryption screens themselves could not be read, so the on-screen wording below comes from third parties and is flagged as such.

### Recommended answers (what to click)

Keep `ITSAppUsesNonExemptEncryption` = `false` in both App Store Info.plists, and exclude France from availability. Then:

| Step | Action |
| :--- | :--- |
| 1 | Pricing and Availability: remove France (see "Availability"). |
| 2 | Open each uploaded build (iOS, macOS). With the key set to `false`, Apple documents that the encryption questions are bypassed. Expect no "Missing Compliance" status. If a build does show it, go to step 3. |
| 3 | Fallback only if App Store Connect still asks. Answers, using the question flow third parties report (wording may differ today, so read each question): "Does your app use encryption?" Yes. "Does your app qualify for any of the exemptions provided in Category 5, Part 2 of the U.S. Export Administration Regulations?" No (the listed exemptions are medical end-use, IP and copyright protection, authentication/signature/decryption only, banking, fixed data compression; file transfer is none of these). "Is your app going to be available on the App Store in France?" No. Type of algorithms: "standard encryption algorithms instead of, or in addition to, using or accessing the encryption within Apple's operating system", not "proprietary". |
| 4 | If, after step 3, App Store Connect demands documentation upload for a "standard algorithm" answer with France excluded, stop and do not guess: that contradicts Apple's own table (documented) and means the flow changed. Ask Apple Developer Support. |

**Must anything be filed before submitting?** For a submission that excludes France: no declaration is needed by Apple's own rule (documented: the French form "is only required if you're distributing your app on the App Store in France"). For the US side the owner's position is the open-source exemption (below). No BIS email is required on the standard-algorithm reading. CrocApp offers no curve choice, so the SIEC curve is not a setting of the app (see "Unknown"). **With France included:** a French declaration would be needed first (see "Documented facts (France)").

### Documented facts (Apple)

- Apple: if your app "uses, accesses, contains, implements, or incorporates encryption", it is an export of encryption software subject to US export rules and to the import rules of the countries where it is distributed. Apple: "you're responsible for all liabilities associated with misinterpretation of export regulations or claiming exemption inaccurately."
- Apple's table ("Export compliance documentation for encryption"): encryption limited to the OS needs no documentation; "an industry standard algorithm, not provided within the Apple operating system" needs the French encryption declaration uploaded; proprietary algorithms not accepted by IEEE, IETF or ITU need a CCATS and the French declaration. Footnote: the French form is only required for distribution in France.
- Info.plist key: set `ITSAppUsesNonExemptEncryption` to NO if the app, "including any third-party libraries it links against", does not use encryption "or if it only uses forms of encryption that are exempt from export compliance documentation requirements". After Apple approves documentation it issues a code for `ITSEncryptionExportComplianceCode`. The same pages say the key lets you skip the per-submission questions.
- Apple on France: controls focus on "Secure Storage, Secure Communications, and Security Anti-Virus applications. Exemptions include Banking and Medical applications." CrocApp is secure communications (inference on the category).
- Apple's definition of "non-standard cryptography" (quoted from its overview): proprietary or unpublished cryptographic functionality, including algorithms or protocols not adopted or approved by a duly recognized standards body (IEEE, IETF, ISO, ITU, ETSI, 3GPP, TIA, GSMA) and not otherwise published.

### Documented facts (US law, eCFR)

- 15 CFR 742.15(b): publicly available encryption source code (ECCN 5D002) "is not subject to the EAR". If that code provides or performs "non-standard cryptography", you must notify BIS and the NSA ENC coordinator by email (`crypt@bis.doc.gov`, `enc@nsa.gov`) with the code's internet location, and again when the location changes or cryptographic functionality is updated.
- 15 CFR 734.3 note: publicly available encryption object code is not subject to the EAR when its source meets the 742.15(b) criteria.
- The eCFR pages read carry amendment citations up to 89 FR 23885 (for 742.15) and 61 FR 12746 (for 734.3). Whether later amendments changed these paragraphs is unknown.

### Documented facts (France)

- ANSSI (cyber.gouv.fr): "L'utilisation d'un moyen de cryptologie est libre. En revanche, la fourniture, l'importation, le transfert intracommunautaire et l'exportation d'un moyen de cryptologie sont soumis, sauf exception, à déclaration ou à demande d'autorisation." The duty falls on "le fournisseur ou le primo-importateur".
- The ANSSI pages say procedures run on the demarches.numeriques platform, where a form "Déclaration relative à un moyen de cryptologie" is linked. An older ANSSI page lists the file contents (company presentation, Kbis under 3 months or foreign equivalent, brochure, technical description, guides) and the address `controle@ssi.gouv.fr`.
- Décret 2007-663 (original 2 May 2007 text, read in full):
  - Art. 3 puts the supply of cryptology means that are not exclusively authentication or integrity under prior declaration, unless Annex 1 dispenses them.
  - Art. 4: file "un mois au moins avant l'opération"; ANSSI issues a receipt with a registration number.
  - Art. 5: after one month of silence the declarant may proceed; ANSSI may issue an attestation sooner.
  - Art. 6: a supplier's declaration also covers the intermediaries that distribute the means (this is why Apple, as distributor, asks for it).
  - Art. 7: within a year the Prime Minister may ask for the technical characteristics and the source code, and two copies for up to six months.
  - Annex 1 (dispensed) lists smart cards, broadcast receivers, banking equipment, mobile phones' network encryption, copy-protection, and similar. General file-transfer or secure-communication software is not in it.
- This is the 2007 text as published. A later consolidated version was not readable (Légifrance returned 403). Annex 1 may have been amended; unknown.

### Verified locally (project facts)

- The two App Store Info.plists set `ITSAppUsesNonExemptEncryption` to `false` (`../RELEASING.md`, "Export compliance"). The Direct build plist and the share extension plist do not set it.
- Engine: croc v11.5.5 with `pake/v3` v3.2.0. Traffic encryption is AES-256-GCM (`crypt.go`, `crypto/aes`), with ChaCha20-Poly1305, PBKDF2 and Argon2 from `golang.org/x/crypto` in the same package. The session key comes from PAKE2, then HKDF-SHA256. The curve is p256 on CrocApp's side (`crocCurve` in `crocmobile/network.go`, the croc CLI default). Available curves in `pake.AvailableCurves()`: p521, p256, p384, **siec**, ed25519. The engine is built with croc's `croc_no_tailcat` tag (`scripts/build-xcframework.sh`), so Tailcat and its Tailscale WireGuard path are not in the binary. No `wireguard-go` or gVisor package is in the build (`go list -tags croc_no_tailcat -deps` in `crocmobile/`: 0 matches for each, against 42 gVisor packages without the tag). A few `tailscale.com/types` helper packages stay linked, because croc's stub for the tag still names Tailscale's key types; they run no tunnel (inference). TLS to getcroc.com uses the platform or Go stack (inference; not traced).
- CrocApp has no curve setting: it always starts the key exchange on p256. croc still links the other curves, and a sender adopts the curve its receiver announces (`croc.go`, "initialize curve based on the recipient's choice"), so a CLI receiver can make a CrocApp sender use siec. CrocApp neither offers nor requests it (read from source, not observed on the wire).
- The app source is public under MIT, so "publicly available" holds for the app's own code (inference that the whole build qualifies, since the Go modules are public too).

### Inference

- **Declaring `false` is consistent with Apple's own table only while France is excluded.** The key means "only exempt forms". The table makes the French declaration the documentation for standard algorithms outside the OS, and removes the requirement outside France. So `false` plus France excluded is coherent. `false` plus France available is not: you would be claiming no documentation is needed where Apple's table says it is.
- Apple's table has no open-source branch. The open-source exemption is a US-law argument that Apple accepts through the plist; Apple's table and the French law do not mention it.
- The French requirement probably applies to a free open-source app supplied from outside France by an individual, because Décret 2007-663 turns on "fourniture" of a means that does more than authenticate, with no open-source or free-software dispense in Annex 1. Whether ANSSI would treat a free, source-published app differently in practice is unknown.
- If you later offer France, the key must change to `true` and carry an `ITSEncryptionExportComplianceCode`, because uploaded documentation produces a code that goes in the plist. That is a change to both Info.plists and a new build upload.
- If the owner files with ANSSI, the filing identity matters: ANSSI asks for a Kbis or the foreign equivalent, which an individual developer account may not have. Unknown how ANSSI treats it.

### Unknown (not found, not guessed)

- The exact current on-screen App Store Connect questions. Apple's help pages describe them but do not list them. The question text above comes from third-party forum threads and a GitHub pull request, not from Apple.
- Whether App Store Connect accepts a French declaration receipt, an attestation, or only the form, and whether Apple's review rejects `false` when France is available.
- Whether CrocApp's PAKE composition counts as "non-standard cryptography" for 742.15(b)(2) notification.
  - The P-256, AES-GCM, ChaCha20-Poly1305, HKDF, HMAC, PBKDF2 and Argon2 parts are standard.
  - SIEC is published open source but not from a standards body. It was the largest open risk while the app offered it as a setting. With the setting gone the question is moot for CrocApp's own behavior, because the app starts every exchange on p256. The curve code stays linked inside croc, and a CLI receiver can still request it from a CrocApp sender (read from source). Whether that residual use matters is unknown.
- Whether other countries have import rules that matter. Apple's pages mention only France. Apple removes or restricts regions on its own for legal reasons ("Your app may not be available ... due to legal or regulatory requirements").
- The current consolidated French decree and ANSSI's current filing steps, delays and fees.

### Conflicts between sources

- Apple's plist wording ("exempt from export compliance documentation requirements") and Apple's own table (standard non-OS algorithms need the French declaration) conflict when France is available. They agree when France is excluded.
- Third-party guides say a one-month wait applies and France stays out until a complete file is received. The ANSSI pages read do not state it, but Décret 2007-663 Art. 4 and 5 do. Consistent, but the decree text read is the 2007 one.
- A developer blog (Cryptomator, found by search, not read) says a US ERN may also be needed. Apple's current table names CCATS only for proprietary algorithms and mentions no ERN. Not resolved.

### What to do and when

1. Before submitting: remove France from availability, keep the key `false`, and confirm no build shows "Missing Compliance". Nothing else must be filed for the first App Store release.
2. Track a `future` item: file the ANSSI declaration (demarches.numeriques platform), switch the key to `true` with the issued code, upload new builds, and add France back. Allow at least a month from a complete file (Décret 2007-663 Art. 4, 2007 text).
3. SIEC needs no decision for the app's own behavior: the curve picker is gone. If the owner wants certainty about the residual case (a CLI receiver choosing siec), the options are the notification email to `crypt@bis.doc.gov` and `enc@nsa.gov` with `https://github.com/bakirgdev/CrocApp`, or advice. This is the owner's judgement; Apple states the owner is responsible for the classification.

This is research, not legal advice. `../known-issues.md`, "Release", tracks the owner actions.

## Open checks before submitting

Still to do:

- Run the Accessibility Inspector and VoiceOver audit on iOS and macOS (`../known-issues.md`, "Release"). Until it passes, keep VoiceOver and "largest text sizes" claims out of the description and What's New.
- Send a file from getcroc.com in a browser and receive it in the app on a real device. The browser-sends, app-receives direction in the review notes (step 2) is not verified anywhere in the repo. The other direction, "Receive in your browser" from an app sender, is covered in `device-test-checklist.md`, "Links and web receive".
- Read getcroc.com's current labels (Send, Receive, Choose files, "Croc code or stored link", Copy code) and compare them with the review notes. The page belongs to the croc project and can change.
- Fill in the contact name, phone and email in App Review Information. They are not in the repo, and the developer-account address is not necessarily the public support contact.
- Confirm `https://crocapp.dev/support/` and `https://crocapp.dev/privacy/` return HTTP 200.
- Decide whether to add the croc maintainer's written reply to the review notes. The reply text is not in the repo; the notes say only that the maintainer was informed. Ask the owner before submitting.
- State on the privacy page that getcroc.com is the croc project's site and runs its own analytics (Umami) and ads (Google AdSense), as seen in the page source. The reviewer opens that page, and the `/r/` page links to it. The app does not load it (no web view). Re-check the page before relying on this.
- Make the Export compliance decision above: France out of availability.
- Take the screenshots (`screenshots.md`).

## Sources

Apple's pages change. Re-read them before you rely on a limit or a rule.

- App information (name 30, subtitle 30, privacy URL): https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- Platform version information (promo 170, description 4000, keywords 100 bytes, What's New 4000, notes 4000 bytes, copyright, URLs): https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Age ratings values and definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- Set an app age rating: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating
- Manage app privacy: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- App privacy details (definition of collect, third-party partners): https://developer.apple.com/app-store/app-privacy-details/
- Overview of export compliance: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
- Export compliance documentation for encryption (the table): https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption
- Determine and upload app encryption documentation: https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation
- Complying with encryption export regulations (key semantics, read from the JSON behind the page): https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
- Provide export compliance information for beta builds: https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds
- Manage availability: https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/manage-availability-for-your-app-on-the-app-store
- ANSSI, contrôle relatif à un moyen de cryptologie: https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/
- ANSSI, formulaires: https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/controle-reglementaire-cryptographie-formulaires/
- ANSSI, FAQ (file contents): https://cyber.gouv.fr/reglementation/reglementation-identite-confiance-numerique/controles-reglementaires-cryptographie/controle-moyen-de-cryptologie/faq-demande-dautorisation/
- Décret 2007-663 (2007 text, PDF): https://www.arcep.fr/fileadmin/reprise/textes/decrets/d2007-663.pdf
- 15 CFR 742.15: https://www.ecfr.gov/current/title-15/part-742/section-742.15
- 15 CFR 734.3: https://www.ecfr.gov/current/title-15/part-734/section-734.3
- 15 CFR 772.1 (non-standard cryptography): https://www.ecfr.gov/current/title-15/part-772/section-772.1
- Third party, App Store Connect question wording (not Apple): https://developer.apple.com/forums/thread/127505 and https://github.com/straff2002/OpenGlasses/pull/472
- Third party, French filing practice: https://developer.apple.com/forums/thread/741830 and https://gist.github.com/safaiyeh/f6ee55b19eeaa81354275046803e69af
- getcroc.com page and its bundled script (labels, Umami, AdSense): https://getcroc.com
- Local: `app/Config/*.plist`, `app/CrocApp/PrivacyInfo.xcprivacy`, `app/CrocApp.xcodeproj/project.pbxproj` (purpose strings, category), `LICENSE`, croc v11.5.5 and pake v3.2.0 in the Go module cache, `../known-issues.md`, `../RELEASING.md`.
