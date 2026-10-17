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

State what happened and what to do, in one line, without blame.

- "The other device declined the transfer." Not "Transfer failed (code 3)."
- Never blame the user, never "invalid", never "oops".
- No error codes, stack traces or croc output in the primary line. A useful detail goes in a secondary `--type-footnote` line.
- If the user can fix it, the fix is in the sentence or in an adjacent button ("Open Settings").
- If the user cannot fix it, say so and offer no button that will not help.

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

"Password" is right only for the relay password, a real password a user types for their own relay. Explaining PAKE ("password-authenticated key exchange") on How It Works is a protocol name, not a name for the code phrase.

**Send as link** (stored transfers) is still sending: "Send as Link", "Sending", "Link ready". The link server is the croc project's server, or one you run, that holds the encrypted files. The one place "download" appears is as the noun for one fetch of a link: "Downloads allowed: 5", "2 of 5 downloads used".

## Claims

The security claim is an approved list. Each statement is true as written, under its condition; nothing outside the list appears on any surface, marketing included.

1. Transfers are end-to-end encrypted.
2. The code phrase authenticates both devices (PAKE).
3. The relay only ever sees ciphertext.
4. Send as link: files are encrypted on your device before they reach the link server, and the key travels in the link's `#` fragment, which browsers never send to a server.
5. When the two devices connect over the local network, the data stays on that network.
6. CrocApp has no accounts, analytics, ads or tracking, and history stays on the device.

Always paired with the caveat where security is discussed at length: CrocApp has not had a formal third-party security audit. Never "secure", "unhackable", "anonymous" or "zero-knowledge".
