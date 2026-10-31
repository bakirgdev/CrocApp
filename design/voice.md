# Voice

How CrocApp sounds and how the words are written, on the app, the landing page, the docs site, the README and the App Store listing. Copy for system surfaces and Settings footers lives next to the behavior it describes (`docs/knowledge/app-ui-architecture.md`, "System surfaces").

## Personality

**Trustworthy, private, fast, calm.** In that order when they conflict.

- Calm over exciting: no urgency, no confetti, no exclamation marks.
- Plain language over jargon: "end-to-end encrypted", not "PAKE-derived symmetric channel". The detail lives on How It Works, one tap deeper.
- Never overstate security. Claims come only from the approved list below.
- Direction is explicit: "Sending" and "Receiving" as words, never color or position alone.
- Nothing is accepted without an explicit yes, unless the user turned on auto-accept.
- Errors say what happened and what to do, without blame.
- The mascot gives the product warmth in onboarding, empty states, About and the web, never in a transfer's critical path.

## Capitalization

One rule on every surface, so a page that names an app control spells it exactly as the app does.

| Kind | Case | Examples |
|---|---|---|
| **Controls**: buttons, menu items, toolbar items, nav and footer links, navigation titles, segment labels, skip links | Title Case | "Send Again", "Open Settings", "How It Works", "Skip to Content" |
| **Content**: headings, page titles, descriptions, hints, empty-state bodies, banners, alerts, errors, captions, prose, the docs sidebar | Sentence case | "Security and privacy", "Finished sends and receives appear here." |
| The eyebrow above the code phrase | Uppercase | "READY TO SEND" |

Title Case follows Apple's style: capitalize every word except articles, coordinating conjunctions and prepositions of three letters or fewer, unless first or last. When prose names a control, quote its exact label in bold: tap **Copy Code**.

## Sentences

- **One line, then stop.** A description that needs two sentences usually needs one shorter one.
- **Second person, present tense.** "Enter it on the other device", not "The code should be entered".
- **No period on a fragment**, a period on a full sentence. Empty-state bodies and alert messages are full sentences.
- **An ellipsis means "this opens something"**: "Change…" opens a picker, and a button that acts immediately never takes one. Use the `…` character.
- **No exclamation marks**, anywhere.
- **No internal IDs** (feature or requirement IDs) in anything a user reads.

## Errors

A failure has two parts, on every surface that shows one: what happened, then what to do.

| Part | Rule | Example |
|---|---|---|
| Title | what happened, in sentence case, no period, about six words, never "invalid" or "oops" | "Couldn't reach the relay" |
| Detail | what to do, one sentence with a period | "Check your internet connection." |

More pairs: "The other device declined" and "Ask them to send it again."; "The code phrases don't match" and "Check the code phrase on both devices."; "Sending was interrupted" and "Keep CrocApp in the foreground and try again."

- No error codes, stack traces or croc output in either part. A useful technical detail goes in a secondary footnote under the actions.
- If the user can fix it, the detail names the fix, with an adjacent **Open Settings** or **Try Again** (`components.md`, "StatusBlock"). If not, say so and offer no button that will not help.
- A cancel or decline the user made is not a failure: its title stands alone ("Transfer cancelled"), with **Done**.

## Numbers

| Thing | Format |
|---|---|
| File and transfer sizes | decimal kB, MB, GB as `.byteCount(style: .file)` writes them, matching Finder. Never hand-format a size |
| Speed | the same units plus `/s` ("4.2 MB/s"); an em-dash placeholder at rest or unknown, never "0 B/s" |
| Exact technical thresholds | binary MiB or GiB ("128 MiB"), because croc defines them that way. Never for a measured size |
| Progress | integer percent |
| Counts | "File 3 of 12"; inflected nouns ("1 file", "3 files"), never "file(s)" |
| Live readouts | tabular figures |

## Dates

Relative inside a week ("yesterday", "3 days ago"), short absolute after. Never a raw timestamp.

## The code phrase

Always lowercase and mono, never autocapitalized, autocorrected or spell-checked, and wrapped only between words. It is called the **code phrase** on first mention on a screen or page, then "the code". Accessibility labels follow too: VoiceOver reads "Code phrase", never "Transfer code".

## Terminology

| Use | Not |
|---|---|
| code phrase | password, key, PIN, passphrase, secret, transfer code |
| the other device | peer, remote, client, receiver, the other side |
| transfer, send, receive | upload, download |
| Sending, Receiving | outgoing, incoming, TX, RX, Uploading, Downloading |
| relay | server, cloud (for the relay) |
| link server | server, cloud, upload server |
| direct connection, local network | peer-to-peer, P2P, LAN peer |
| end-to-end encrypted (hyphenated) | secure, military-grade, bank-level |
| croc | Croc, CROC |
| CrocApp | Croc App, CrocAPP |
| notification | alert, push, toast ("banner" is only the in-app StatusBanner) |
| haptics | vibration, buzz |

"Password" is right only for the relay password, a real password a user types for their own relay. "Incoming" appears in no label (the Settings rows are **Notifications** and **Show File Names in Notifications**), because nothing is being received before the user says yes. **Send as Link** is still sending ("Send as Link", "Sending", "Link ready"); "download" appears only as the noun for one fetch of a link ("2 of 5 downloads used").

## Claims

The security claim is an approved list. Each statement is true as written, under its condition; nothing outside the list appears on any surface, marketing included.

1. Transfers are end-to-end encrypted.
2. The code phrase authenticates both devices (PAKE).
3. The relay only ever sees ciphertext.
4. Send as link: files are encrypted on your device before they reach the link server, and the key travels in the link's `#` fragment, which browsers never send to a server.
5. When the two devices connect over the local network, the data stays on that network.
6. CrocApp has no accounts, analytics, ads or tracking, and history stays on the device.

Where security is discussed at length, pair the claims with the caveat that CrocApp has not had a formal third-party security audit. Never "secure", "unhackable", "anonymous" or "zero-knowledge".
