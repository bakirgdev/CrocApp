# Content

How the words are written. `brand.md` sets the voice; this sets the mechanics, binding on the app, the landing page, the docs site, the README and the App Store listing.

Most of this product is text and one progress bar. A wrong byte count is more visible than a wrong shadow.

## Capitalization

One rule on every surface, so a page that names an app control spells it exactly as the app does:

| Kind | Case | Examples |
|---|---|---|
| **Controls**: buttons, links styled as buttons, menu items, toolbar items, nav bar and footer links, navigation titles, segment labels, skip links | Title Case | "Send Again", "Clear All", "Open Settings", "How It Works", "View Source", "Skip to Content" |
| **Content**: headings, page and document titles, descriptions, hints, empty-state bodies, banners, alerts, errors, captions, prose, the docs sidebar (it mirrors page titles) | Sentence case | "Security and privacy", "Finished sends and receives appear here." |
| The eyebrow above the code phrase | Uppercase | "READY TO SEND" |

Title Case follows Apple's style: capitalize every word except articles, coordinating conjunctions and prepositions of three letters or fewer, unless first or last ("Skip to Content", "Send as Link"). The eyebrow is the only uppercase label in the system (`typography.md`).

When prose names a control, quote its exact label in bold: tap **Copy Code**.

## Sentences

- **One line, then stop.** A description that needs two sentences usually needs one shorter one.
- **Second person, present tense.** "Enter it on the other device", not "The code should be entered".
- **No period on a fragment**, a period on a full sentence. Empty-state bodies and alert messages are full sentences.
- **Ellipsis means "this opens something"**: "Change…" opens a picker. A button that acts immediately never takes one. Use the `…` character.
- **No exclamation marks**, anywhere.
- **No internal IDs** (feature IDs like F12, requirement IDs like R40) in anything a user reads.

## Errors

A failure has two parts, on every surface that shows one (StatusBlock, StatusBanner, alert, notification): what happened, then what to do. Without blame.

| Part | Rule | Example |
|---|---|---|
| Title | what happened, in words: sentence case, no period, six words at most, never "invalid" or "oops" | "Couldn't reach the relay" |
| Detail | what to do, one sentence with a period | "Check your internet connection." |

More pairs: "The other device declined" and "Ask them to send it again."; "The code phrases don't match" and "Check the code phrase on both devices."; "Sending was interrupted" and "Keep CrocApp in the foreground and try again."

- No error codes, stack traces or croc output in either part. A useful technical detail goes in a secondary `--type-footnote` line under the actions.
- If the user can fix it, the detail names the fix. A fix that lives in Settings gets an adjacent **Open Settings**, a retry gets **Try Again** (`components.md` → StatusBlock).
- If the user cannot fix it, say so and offer no button that will not help.
- A banner's title and body are the same pair.
- A cancel or decline the user made is not a failure: its title stands alone ("Transfer cancelled"), with **Done**.

## Settings

A row's label names the thing, in Title Case, as a noun phrase: never "Enable" or "Allow". A footer is one sentence in sentence case that says what the row changes, and makes no claim outside Claims below.

| Row | Footer |
|---|---|
| **Save Transfer History** | Finished transfers are listed in History, which stays on this device. |
| **Show History in Spotlight** (off by default; disabled while Save Transfer History is off) | Spotlight on this device can find past transfers by their file names. |
| Section "Notifications": **Incoming Transfers**, **Finished Transfers** | Shown only while CrocApp is in the background. |
| **Haptics** (iPhone only) | A short tap when you copy or scan a code, and when a transfer finishes, fails or needs your answer. |

When the system has notifications off for CrocApp, both Notifications rows are disabled and the footer reads "Notifications are off for CrocApp in Settings." ("System Settings" on a Mac) with an **Open Settings** button.

## Numbers

| Thing | Format | Why |
|---|---|---|
| File and transfer sizes | decimal kB, MB, GB, exactly as `.byteCount(style: .file)` writes them | matches Finder; never hand-format a size |
| Speed | the same units plus `/s`: "4.2 MB/s" | |
| Speed at rest or unknown | an em-dash placeholder, never "0 B/s" | a zero reads as a stall |
| Exact technical thresholds | binary MiB or GiB: "128 MiB", "1 GiB" | croc defines these in binary; "128 MB" would be false and "134 MB" unrecognizable. Never for a measured size |
| Progress percent | integer | |
| Counts | "File 3 of 12"; inflected nouns ("1 file", "3 files"), never "file(s)" | |
| Every live readout | tabular figures | a reflowing counter is a bug |

## Dates

Relative inside a week ("yesterday", "3 days ago"), short absolute after. Never a raw timestamp.

## The code phrase

- Always lowercase, mono, `--tracking-code`. Never autocapitalized, autocorrected or spell-checked.
- Wraps only between words.
- Called the **code phrase** on first mention on a screen or page, then "the code".

## Terminology

| Use | Not |
|---|---|
| code phrase | password, key, PIN, passphrase, secret, transfer code |
| the other device | peer, remote, client, receiver, the other side |
| transfer, send, receive | upload, download (see Send as link) |
| Sending, Receiving | outgoing, incoming, TX, RX, Uploading, Downloading |
| relay | server, cloud (for the relay) |
| link server | server, cloud, upload server |
| direct connection, local network | peer-to-peer, P2P, LAN peer |
| end-to-end encrypted (always hyphenated) | end to end encrypted, secure, military-grade, bank-level |
| croc | Croc, CROC |
| CrocApp | Croc App, CrocAPP |
| notification | alert, push, toast. "Banner" is only the in-app StatusBanner |
| haptics | vibration, buzz |

"Incoming" appears in one place: the label **Incoming Transfers** (Settings → Notifications) and the notification kind it names. Nothing is being received before the user says yes, so "Receiving" would be false there. Everywhere else direction stays Sending and Receiving.

The code phrase rule covers accessibility labels and hints as well as visible text: a VoiceOver label reads "Code phrase", never "Transfer code".

"Password" is right only for the relay password, a real password a user types for their own relay. Explaining PAKE ("password-authenticated key exchange") on How It Works is a protocol name, not a name for the code phrase.

**Send as link** (stored transfers) is still sending: "Send as Link", "Sending", "Link ready". The link server is the croc project's server, or one you run, that holds the encrypted files. The one place "download" appears is as the noun for one fetch of a link: "Downloads allowed: 5", "2 of 5 downloads used".

## System surfaces

Copy for what the app shows outside its windows (`platforms.md` → System surfaces). The two app rules hold: direction in words, and never a code phrase, a link or file contents. A notification shows a count and a size, written as the result screen writes them (`3 files • 24 MB`; a text payload is "Text snippet"), and never file names: a name is the first thing a bystander reads on a Lock Screen, and the count is enough to decide to review.

| Surface | Title | Body |
|---|---|---|
| Notification: a request waits | Files are waiting for your answer | `3 files • 24 MB` |
| the same, previews hidden | | Open CrocApp to review. |
| Notification action | **Review** | |
| Notification: a send finished | Sending complete | `3 files • 24 MB` |
| Notification: a receive finished | Receiving complete | `3 files • 24 MB` |
| Notification: a link is ready | Link ready | Open CrocApp to copy or share it. |
| Notification: a transfer failed | the failure's title | the failure's detail (Errors) |
| a result (sent, received, link ready or failed), previews hidden | | Open CrocApp to see the result. |
| Widget, no transfers | No transfers yet | |
| Widget, Save Transfer History off | History is off | |
| Widget and control labels | Send, Receive | |
| Menu bar icon, spoken | CrocApp, then the state: "waiting for the other device", "sending 42 percent", "receiving 42 percent", "needs your answer", "transfer failed". Idle is "CrocApp" | |

## Claims

The security claim is an approved list. Each statement is true as written, under its condition; nothing outside the list appears on any surface, marketing included.

1. Transfers are end-to-end encrypted.
2. The code phrase authenticates both devices (PAKE).
3. The relay only ever sees ciphertext.
4. Send as link: files are encrypted on your device before they reach the link server, and the key travels in the link's `#` fragment, which browsers never send to a server.
5. When the two devices connect over the local network, the data stays on that network.
6. CrocApp has no accounts, analytics, ads or tracking, and history stays on the device.

Always paired with the caveat where security is discussed at length: CrocApp has not had a formal third-party security audit. Never "secure", "unhackable", "anonymous" or "zero-knowledge".
