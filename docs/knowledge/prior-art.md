# Prior art and growth notes

Competitor facts here change. Re-check any of them (status, price, popularity) before you quote or rely on it.

## Landscape

No other well-maintained, open-source Apple-native app for croc was known when this was written. What exists:

| Project | Platform | Notes |
| --- | --- | --- |
| iCroc | iOS and macOS | Paid, closed source, embeds an old croc (10.x). The only Apple-native croc client found. |
| [crocgui](https://github.com/howeyc/crocgui) | Android, desktop | Go with Fyne. |
| [croc-app](https://github.com/Dking08/croc-app) | Android | Kotlin and Compose. Best mobile UX reference, but it runs the croc binary as a subprocess, which iOS forbids. |
| [crock](https://github.com/KD-MM2/crock) | Desktop | Best desktop UX reference. |
| LocalSend | All | Local network only, so it fails on guest networks and when iOS suspends the app. croc's relay model is the difference. |
| PairDrop, Rymdport, Destiny, Winden, Blip | Various | Adjacent tools, not croc clients. |

## UX patterns worth following

- Two-verb home: one big Send and one big Receive.
- QR code in both directions, and clipboard code detection on Receive.
- Clipboard and text transfer is the most common real use (croc-app's author says so).
- Transfer history for repeat partners.
- Custom relay as a first-class setting, with a visible relay indicator. Users worry about trust, so explain PAKE and end-to-end encryption in the app.
- File list and sizes before accepting, sanitized file names, and an explicit overwrite choice. This answers the class of issues in croc's public security audit, and is a selling point.
- Links that carry the code. The QR code encodes a `https://crocapp.dev/r/` link, which opens the app or a page that explains what to do.
- Positioning: it works when AirDrop and LocalSend do not, across networks and continents.

## Growth ideas

- Repo description is the pitch line. Screenshots at the top of the README, plus store badges.
- Ship small, iterate in public. Donations only.
- Distribute through the App Store, TestFlight and the direct download.
- Ask for a CrocApp entry in croc's README list of GUIs, which is how the other GUIs get found.
- Announce on Hacker News, r/selfhosted, r/opensource and Mac blogs. Translate early (`../ROADMAP.md`).
