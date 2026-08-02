# Content

How the words are written. `brand.md` sets the voice; this sets the mechanics, and the mechanics are binding on the app, the landing page and the docs site.

Most of this product is text and one progress bar. Getting a byte count wrong is more visible than getting a shadow wrong.

## Capitalization

| Kind | Case | Examples |
|---|---|---|
| Anything that **acts or names a destination** — buttons, menu items, toolbar items, navigation titles, segment labels | Title Case | "Send Again", "Clear All", "Open Settings", "Scan Code", "History" |
| Anything that **explains** — descriptions, hints, empty-state bodies, banner bodies, alert messages, errors, captions | Sentence case | "Finished sends and receives appear here." |
| The eyebrow above the code phrase | Uppercase | "READY TO SEND" |

One uppercase label exists in the whole system and it is that eyebrow (`typography.md`). Nothing else is shouted.

## Sentences

- **One line, then stop.** A description that needs two sentences usually needs one shorter sentence.
- **Second person, present tense.** "Enter it on the other device", not "The code should be entered".
- **No terminal period on a fragment**, period on a full sentence. Empty-state bodies and alert messages are full sentences.
- **Ellipsis means "this opens something".** "Change…" opens a picker. A button that acts immediately never takes one. Use the real character, not three dots.

## Errors

State what happened and what to do, in one line, without blame.

- "The other side declined the transfer." Not "Transfer failed (code 3)."
- Never blame the user, never say "invalid", never say "oops".
- No error codes, stack traces or croc CLI output in the primary line. If a detail helps, it goes in a secondary line at `--type-footnote`.
- If the user can fix it, the fix is in the sentence or in an adjacent button ("Open Settings").
- If the user cannot fix it, say so plainly and do not offer a button that will not help. Camera *denied* offers Settings; camera *restricted* does not.

## Numbers

| Thing | Format | Why |
|---|---|---|
| File and transfer sizes | Decimal: KB, MB, GB. Never MiB | Matches Finder and the croc CLI |
| Speed | Same unit family plus `/s` | "4.2 MB/s" |
| Speed at rest or unknown | An em-dash placeholder, never "0 B/s" | A zero reads as a stall |
| Progress percent | Integer, no decimals | |
| Counts | "File 3 of 12", spelled with "of" | |
| Every live readout | Tabular figures | `typography.md`; a reflowing speed counter is a bug |

## Dates

Relative inside a week ("yesterday", "3 days ago"), short absolute after. Never a raw timestamp in the UI.

## The code phrase

- Always lowercase, always `--font-mono`, always `--tracking-code`.
- Never auto-capitalized, autocorrected or spell-checked.
- Wraps only at a group boundary, never mid-word.
- Called a **code phrase** on first mention in a screen, then "the code". Never "password", never "key", never "PIN".

## Terminology

| Use | Not |
|---|---|
| code phrase | password, key, PIN, passphrase |
| the other device | peer, remote, client, recipient's machine |
| transfer | upload, download |
| Sending / Receiving | outgoing / incoming, TX / RX |
| relay | server, cloud |
| end-to-end encrypted | secure, military-grade, bank-level |
| croc | Croc, CROC |
| CrocApp | Croc App, CrocAPP |

## Claims

The security claim is capped at three true statements (`brand.md`): transfers are end-to-end encrypted, the code phrase authenticates both sides, the relay only ever sees ciphertext. Do not extend past that, in any surface, including marketing copy.
