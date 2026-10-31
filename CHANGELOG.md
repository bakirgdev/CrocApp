# Changelog

All notable changes to CrocApp are recorded here. Each version's section is
also the body of its GitHub release, so it is written for someone deciding
whether to download, not as a summary of commits.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), with
extra sections where a release needs them, and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Saved codes**: keep a custom code phrase for a peer under their name, and pick it in one tap under the code field on Send and Receive. Add, rename and delete them in Settings. Codes are stored in this device's Keychain and never synced, and nothing is saved unless you add it. A reused code is no longer single-use, so anyone who learns it and connects first can receive your next transfer, and Settings says so where you save one.
- **Run a Relay** on a Mac: a **Relay** tab in Settings (and a switch in the menu-bar window) starts a croc relay on this Mac, so devices on your network can use it instead of a relay on the internet. Choose the port (croc's 9009 and the next three), set an optional password (kept in the Keychain), and the tab lists the addresses to enter on the other device. It is off by default, starts at launch only if you turn on **Start Relay at Launch**, and stops when you quit CrocApp. The relay listens on every network connection of the Mac, so without a password anyone who can reach it can use it, over the internet too if your router or IPv6 firewall allows it. Set a password.
- **Check Relay…** in Settings, on every platform: checks the relay your transfers use, or croc's public relays if you set none. For each address it reports whether IPv4 and IPv6 connect, how fast, and whether the relay accepts your password, plus the local network permission, and says what to change. It sends nothing, and it does not use your proxies: with one set, it waits for **Check Anyway**.
- The share extension now accepts text and web links, on iPhone, iPad and Mac. Shared text or a link lands in the Send screen as text, and nothing is sent until you press **Send**. If you share files together with text, only the files are kept. Text is limited to 1 MiB.
- **CrocApp** in Finder's Share menu on a Mac. Select files or folders, choose Share, then CrocApp: the app opens with the **Shared Files** sheet, and nothing is sent until you press **Send**. Turn the extension on under System Settings, Extensions, Sharing if it is not listed.
- Notifications when CrocApp is in the background: a transfer that finishes, fails or needs your answer sends a notification, and tapping it opens that transfer's screen. **Notifications** in Settings is on by default and CrocApp asks the system for permission when you start your first transfer. A notification says "Transfer complete" and never shows a code phrase or link; turn on **Show File Names in Notifications** (off by default) to see the file name or the number of files.
- On a Mac, the Dock icon shows the percent while a transfer moves and a badge while a request waits for your answer.
- Receive from the Mac menu bar: type or paste a code or link into the menu bar window and press **Receive**. The menu bar icon now shows the state of the transfer, with the percent beside it while files move, and a request waiting for you offers **Open CrocApp to Accept**.
- Past transfers are offered to Shortcuts and Siri: a **Find Transfers** action filters them by date, direction, status or file name, and a found transfer opens CrocApp at History. They answer with nothing while **Save Transfer History** is off.
- **Show History in Spotlight** in Settings (off by default). Turn it on and Spotlight can find past transfers by their file names; turn it off, or turn off **Save Transfer History**, and CrocApp removes every transfer it added to Spotlight. Code phrases and code hints never go to Spotlight.
- **Send with CrocApp** in the Services menu on a Mac. Select files in Finder, or text in any app, choose it from the app menu's Services submenu, and CrocApp opens at Send with the selection staged. Nothing is sent until you press Send. Text over 1 MiB is refused.
- History rows open a detail screen with the status, date, size, file names and link, and **Send Again**, **Revoke Link** and **Delete**. On a Mac, double-click a row or press Return.
- Deleting a History row whose Send as Link link still works asks whether to revoke the link first, so the files do not stay on the link server with no way to revoke them. **Delete** is disabled while that link is being revoked.
- **Add Photos** on iPhone and iPad sends photos and videos from your library under their own file names, without a Photos permission prompt. **Send** waits while they load, and leaving the screen before they finish discards the copies.
- Send takes pasted and dropped images and text as well as files. On a Mac, ⌘V on the Send screen stages them, and on an iPad with a keyboard it works from iOS 27.
- Receive scans a QR code that is not from CrocApp with a message saying so, and keeps the camera running instead of closing.
- **Save Transfer History** in Settings (on by default). Turn it off and finished transfers are no longer listed in History. What is already there stays until you delete it, and History says "History is off" while it is empty.
- **Haptics** in Settings on iPhone (on by default). Turn it off to silence every tap for a copied or scanned code and for a transfer that finishes, fails or needs your answer.
- **Recent transfers** on the iPhone home screen (and on iPad in a narrow window): your latest three transfers, finished, failed, cancelled or declined, sit below Send and Receive, and a tap opens History. With no transfers yet it says so, and with **Save Transfer History** off the list is not shown.
- **Revoke Link** on the **Link ready** screen, so you can end a link right after sending it. It works with **Save Transfer History** off too, where History never lists the link. If this device could not save the link to the Keychain, the screen warns that revoking works only until CrocApp quits.
- The result of a receive lists the files and folders that arrived, with their sizes. Tap a file for Quick Look, use its share button, or use the context menu for **Show in Finder** (**Show in Files** on iOS, for the default folder). On a Mac and iPad you can also drag a file out.
- iPhone and iPad find a device on the same network the way a Mac does, so a transfer between them can stay on your local network, including with **Local Network Only**. **Multicast Address** is now in Advanced settings on iOS too.
- A sidebar on iPad and Mac. **Send**, **Receive** and **History** sit beside the screen they open, and **Settings** joins them on iPad (the Mac keeps its Settings window, ⌘,). The layout follows the window width as you resize it: a wide window gets the sidebar, and iPhone, Slide Over and a narrow Split View keep the single-column Home. While a transfer runs, its row says **Connecting**, **Waiting** or the percent, and when the other device is waiting for your answer the row shows **Review** and every other screen shows the same banner, so a hidden sidebar never hides it. Opening a link, dropping a file or an incoming request never switches the screen you are on.
- New menu bar commands, each with a shortcut: **History** (⌘3), **How It Works** (⌘?), **Cancel Transfer** (⌘.) while a transfer can be cancelled, and **Copy Code** (⇧⌘C) while a code is showing. **Send Clipboard Text…** (⌥⌘1) and **Paste Code…** (⌥⌘2) fill in Send and Receive from the clipboard and never start a transfer themselves. iPad shows them in the hardware-keyboard menu bar, with **Settings…** (⌘,).

### Changed

- The relay password, the proxies and Send as link receipts stay on this device: they are never synced, and a backup restored to a new device does not bring them back. On iPhone and iPad this applies to each one from the next time it is saved. If the relay password or a proxy cannot be saved to the Keychain, its field now says so instead of seeming saved.
- The home screen's banner for a transfer that waits for your answer now fades in and moves into place, and Send and Receive slide down with it instead of jumping. It appears at once with Reduce Motion on. The home page now sits on the grouped background and scrolls with large text.
- The welcome screen scrolls instead of clipping at the largest text sizes. It and How It Works have larger glyphs with the text aligned beside them, and at the largest sizes the glyph moves above the text so the words keep the full width. Their secondary text is darker, so it clears the 4.5:1 contrast mark.
- Send and Receive keep the caret where a keyboard is likely: in the code field on a Mac, and on an iPad with a hardware keyboard. Return starts a receive, and the code field waits until you finish typing before it says a code is too short.
- The Send and Receive screens scroll at the largest text sizes, and the Text box shows a focus ring while you type in it.
- An empty file now reads "0 bytes" in the send list.
- A failed transfer now says what happened and what to do, and offers the one action that can help. **Try Again** runs the same transfer again when it could now succeed (a dropped connection, an unreachable relay or link server, iOS stopping it in the background). **Open Settings** goes where the fix is when a setting is the cause (a rejected relay password, an Advanced setting that cannot be used, auto-accept meeting a sender who confirms). Otherwise there is only **Done**. Shortcuts and the menu bar show the same words.

- The app is about half the size. The transfer engine is now croc's relay-only build, without Tailcat, the direct-connection path croc could try for large sends. The main executable went from 22.0 MB to 10.5 MB on Mac and from 21.3 MB to 10.3 MB on iPhone and iPad (measured on unsigned release archives). Transfers use croc's relay or your local network, as they did for everything under 128 MiB.
- Buttons are easier to read in light mode: text labels and filled buttons now use the darker green, so white labels pass the 4.5:1 contrast mark, and destructive labels are no longer drawn in red text.
- The website and docs are refreshed. The docs are reorganized around what you are doing (one Settings page in the app's own order, Verify a release under Getting started, Send as link and a keyboard shortcut reference), with a new Uninstall and data page, many accuracy fixes, and redirects from the old addresses. The home page leads with "Send files with a code phrase" and shows the iPhone app beside the Mac one.
- The website and docs use the app icon as their favicon and home-screen icon, and a new social preview card.
- The screen that asks you to accept a transfer shows a Receiving header, the encryption badge and the file list as rows. Its Cancel button is gone: Decline answers the other device, leaving the screen gives no answer, and Home shows a banner to return to a request that is still waiting.
- A transfer you cancel or decline, and a link you revoke, ends on a neutral grey mark instead of a red failure. A transfer that croc finishes without marking it successful now reads **Transfer finished with problems**, with the next step, instead of **Transfer complete**.
- A file name from another device is drawn with any hidden or text-direction character shown as its code point (for example `\u{202E}`) in the file list, the progress screen, the result and History, so a name cannot pretend to be another one. A name with such a character is still blocked.
- Send as Link now says Sending and Receiving like every other transfer, and copying the code shows "Copied".
- On iPhone, a light haptic marks a finished, failed or incoming transfer and a copied or scanned code. Cancelling or declining yourself stays silent.
- Settings labels use title case, and "Auto-accept incoming files" is now "Auto-Accept Transfers".
- **Copy Code** and **Copy Link** now ask the system to remove what they copied from the clipboard after 5 minutes, unless you copied something else since. On a Mac, CrocApp does the removing itself, and only while it is running. It also marks the copy with the nspasteboard.org convention, so clipboard managers that follow it skip the copy. **Copy Link** now asks to stay on this device on a Mac too, as it already did on iPhone and iPad.
- The transfer engine is croc v11.5.5. Transfers stay compatible with croc 11 on the other device.
- The update checker in the direct-download Mac build is Sparkle 2.10.1. It fixes an update installing too early when the app sits at a path in NFC Unicode form.
- CrocApp has one main window on Mac and iPad. One transfer runs at a time, so a second window could only mirror the first and walk its own screens. On iPad the app no longer opens a second window of itself. On Mac, closing the window leaves CrocApp running in the menu bar, and a link, the Dock icon or **Open CrocApp** brings the window back.
- The Mac window opens wider (880 by 700) with a minimum of 720 by 560, to fit the sidebar. A window saved at the old size grows to the new minimum.

### Removed

- The **Connection** setting (Automatic or Relay Only) and the "Direct path for large files" note in How It Works. With no direct-connection path in the app there is nothing to choose, and CrocApp no longer contacts `tailcat.dev` or the `*.ipn.dev` servers. A croc command-line sender that forces that path (`--transport derp`) cannot send to CrocApp: the receive fails with "peer requires Tailcat". Without that flag, large files from the command line work as before.
- Six Advanced settings are gone: **Curve**, **File Hash**, **Base Port**, **Parallel Connections**, **Multiplexing** and **Built-in DNS Resolver**. croc picks the right curve and hash on its own (a sender takes the receiver's curve, a receiver takes the sender's hash), so two devices never need to match, and ports, connection count and DNS are croc internals. CrocApp now uses croc's defaults: curve P-256, ports 9009 to 9013. A **Sender IP** receive from a CrocApp sender uses port 9009. Proxies, **Sender IP**, **Send Speed Limit** and, on macOS, **Multicast Address** stay.
- CrocApp no longer reads the `croc://<code>` QR codes that 0.9.9 showed. A code phrase typed or pasted, and the `https://crocapp.dev/r/` links, still work.

### Fixed

- A send whose local ports cannot be opened (another app already uses them) now fails with a message. Before, croc could stop the whole app there.
- A new transfer started right after the last one ended now starts at once, without a short wait or a "Transfer failed" message.
- Cancel during the first second of a send with a generated code now stops it at once, before a code appears.
- If a cancelled transfer never stops, CrocApp now says so after 15 seconds and asks you to quit and reopen it, instead of staying on the transfer and failing every later one.
- A receive started before the sender now says to start the send first and enter the code again, instead of a generic failure.
- On iPhone, a transfer that auto-accept stops for an unsafe file name now plays the failure haptic.
- Send Again could pick up the files of an earlier send when two sends followed each other quickly. Each send now keeps its own files.

### Security

- An incoming file name that uses a text-direction control (which can make a name ending in `.exe` read as `.pdf`) or a line or paragraph separator is now blocked like any other unsafe name. A combining mark can no longer hide a `/` or `\` in a name from that check. A file shared to CrocApp from the iPhone or iPad share sheet under such a name is renamed `shared-file`.
- The transfer engine is built with Go 1.27.3, which stops trusting a set of compromised intermediate certificates ([GO-2026-6809](https://pkg.go.dev/vuln/GO-2026-6809)). This covers the HTTPS connections the engine makes, such as Send as link.

## [1.0.0] - 2026-10-15

CrocApp 1.0 is a notarized disk image for Mac. The iPhone, iPad and Mac App Store builds are in TestFlight and follow with the first App Store release, so the iPhone and iPad items below reach users then. The other device needs croc 11 or newer.

**macOS 26 or later, Apple silicon only.**

Verify a download with `gh attestation verify <file> --repo bakirgdev/CrocApp`: the release workflow attests the disk image, the update feed and the engine archive after stapling, so the attestation covers the bytes you download. `SHA256SUMS.txt` lists the SHA-256 checksums of the disk image and the engine archive.

### Added

- iPhone and iPad apps and a Mac App Store build, in TestFlight until the first App Store release. 0.9.9 was macOS only.
- The macOS direct download is now signed with a Developer ID certificate, notarized and stapled, so it opens with only the standard first-launch confirmation.
- The direct download updates itself with Sparkle: choose "Check for Updates…" in the app menu. Sparkle installs an update only when its EdDSA signature matches the key built into the app, and the update check sends no system profile. Only this build has Sparkle; the App Store builds update through the App Store.
- Receiving a file whose name is already taken now offers Keep Both (saves the new one as `name (1).ext`) or Replace. With auto-accept on, the setting "When a file already exists" under Confirmation chooses; it defaults to Keep Both.
- A Connection setting, Automatic (the default) or Relay only. With Automatic, a send of 128 MiB or more can also take a direct path between the devices; Relay only keeps every transfer on croc's relays. The sender's choice applies, and a receive follows it.
- Links. Opening a CrocApp link, a `crocapp.dev/r/` link or a `getcroc.com/?code=` link, or pasting one into the Receive field, opens Receive with the code filled in; nothing connects until you tap Receive. The sender's waiting screen has a Share Link button. The page at `crocapp.dev/r/` reads the code in your browser (it never reaches a server) and offers to open CrocApp, get the app, or receive in your browser through croc's own web app, which needs the default relays.
- Send as link. Turn it on in Send to upload files (not folders or text) encrypted to a transfer server and get a link and QR code instead of a code, so the receiver can download later without being online at the same time. You choose how long the link lasts (1 hour, 1 day or 7 days) and how many downloads it allows (1 to 100), up to 100 files and 1 GiB. Receive takes the link like a code and shows the file list before anything is saved. History shows when each link expires and can revoke it. The files are encrypted on your device and the key is the part of the link after the `#`, so the server cannot read them. The server is set in Settings and defaults to `https://getcroc.com`, which croc's author runs; CrocApp does not.
- Advanced settings (Settings > Advanced on iOS, the Advanced tab of the macOS Settings window): SOCKS5 and HTTP proxies, a built-in DNS resolver option, the encryption curve, the file hash, an upload speed limit, the base port and number of parallel connections, a multiplexing switch, a sender IP to receive from directly, and, on macOS, a multicast address. Each shows its default, checks what you type, and says which device it affects and whether the other device must match. Reset to Defaults puts them all back. The proxies also apply to Send as link and are kept in the Keychain, never in the settings file. A receive with a sender IP connects straight to the sender and skips relays. iOS has no multicast setting, because the multicast entitlement is not granted.
- Menu bar quick send on macOS. A CrocApp icon in the menu bar opens a small window: drop files or folders on it, choose them with Choose Files…, or send the clipboard text. It then shows the code, a QR code, Copy Code, progress and Cancel. It shares the one active transfer with the main window, so it also shows a transfer started there or from Shortcuts. Quick send always uses a generated code. Settings > General has Show in menu bar (on by default) and Open at login (off by default; it follows System Settings > General > Login Items and offers a shortcut there when macOS needs your approval).
- Shortcuts and Siri actions: Send Files with CrocApp, Send Text with CrocApp and Receive with CrocApp. The send actions return the code as soon as croc has one, so keep CrocApp open until the receiver finishes. Receive takes a code or any link CrocApp opens and returns the received files; it does not answer the incoming-files prompt, so turn on Auto-accept or answer it in the app. The actions also appear in Spotlight and Siri with the phrases "Send files with CrocApp", "Send text with CrocApp" and "Receive with CrocApp".
- The iPad menu bar has Show Receive Folder in Files (⇧⌘R) in the File menu next to Send… and Receive…. On a Mac the same shortcut shows the folder in Finder.

### Changed

- The transfer engine is croc v11.5.4. A croc 10 device can no longer complete a transfer with CrocApp, in either direction: the other device needs croc 11 or newer. Relays are picked from croc's public relay pool the way the croc 11 command line does, and a send fails with a clear message when no public relay answers.
- Failures say what went wrong: a wrong code, a refused transfer, a lost connection, a peer on an older croc, or no public relay available, instead of one generic message.
- History keeps less of a code: the first word of a code shaped like a generated one, only the first two characters of any other code, and only the server's host for Send as link. It never keeps the whole code.
- Every 1.0 screen works at the largest text sizes, including the transfer percentage.
- The QR code on the sender's waiting screen now encodes a `https://crocapp.dev/r/` link instead of `croc://<code>`, so a phone camera opens CrocApp, or a page that explains what to do when the app is missing. QR codes from 0.9.9 still scan in the app.

### Removed

- The separate app zip (`CrocApp-<version>-arm64.app.zip`). The disk image is the download.

### Fixed

- A receive no longer overwrites existing files by default. A zipped folder received into a folder that already holds it no longer fails. Answers left over from one transfer can no longer answer the next transfer's accept prompt.

### Security

- Sending a file whose name contains `*` sends only that file. Before, croc read the name as a pattern and also sent every matching file next to it.
- A file name containing a line break can no longer turn into extra send paths (a crafted name could send the app's whole data folder), and a name ending in a space is no longer sent as the file without the space (croc 11 receivers refuse such a name, so that send now fails). Received or shared names with control characters are treated as unsafe.
- After you accept a receive, a sender that reconnects cannot get a different file list accepted without you seeing it: the receive ends instead. Replace still overwrites files, but no longer overwrites existing files inside a zipped folder; they are kept.
- A sender declaring impossible file sizes can no longer crash the app during a receive.

## [0.9.9] - 2026-07-30

First public build of CrocApp. It is a symbolic release: the app does everything V1 is meant to do, but it is not signed with an Apple Developer ID and it is not notarized, so macOS refuses to open it until you allow it by hand. Read "Opening it the first time" below before downloading.

**macOS 26 or later, Apple silicon only.** No Intel build, and no iPhone or iPad build in this release.

### What CrocApp does

A native SwiftUI front end for [croc](https://github.com/schollz/croc). It embeds croc's Go library rather than shelling out to the binary, so a code phrase from the croc CLI works in the app and the other way round.

- Send files, several at once, whole folders, or a snippet of text
- Receive with a code phrase, or by scanning a QR code
- See the file list before accepting, resume interrupted transfers, confirm overwrites
- Direct transfer when both devices share a network, relay otherwise; the relay only ever sees ciphertext
- Point it at your own croc relay, with password and IPv6; the password is kept in the Keychain
- Local-only mode, auto-accept off by default, optional confirmation on both sides
- Transfer history, stored only on your device
- Send from any app through the share extension
- Drag and drop, light and dark, Dynamic Type and VoiceOver

Transfers are end-to-end encrypted and the code phrase authenticates both sides. That is the whole security claim. croc has had no formal third-party audit and CrocApp does not claim one.

### Opening it the first time

The build carries an ad-hoc signature. Enough for it to run, not enough for Gatekeeper: macOS will say the app cannot be opened because it cannot be checked for malicious software.

1. Open the disk image and drag **CrocApp** onto **Applications**
2. Try to open it once, and let macOS refuse
3. Open **System Settings → Privacy & Security**, scroll to Security, and choose **Open Anyway** next to the CrocApp message
4. Confirm at the prompt

From a terminal instead:

```
xattr -d com.apple.quarantine /Applications/CrocApp.app
```

This goes away once the app is signed with a Developer ID and notarized, which is the next release.

### Downloads

| File | What it is |
|---|---|
| `CrocApp-0.9.9-arm64.dmg` | The app, as a disk image. Start here |
| `CrocApp-0.9.9-arm64.app.zip` | The same app bundle, zipped |
| `Croc.xcframework-0.9.9.zip` | The prebuilt Go engine, for building from source |
| `SHA256SUMS.txt` | Checksums for the three files above |

Every asset carries a build provenance attestation. To check a download really came from this repository's release workflow:

```
gh attestation verify CrocApp-0.9.9-arm64.dmg --repo bakirgdev/CrocApp
```

### Not in this release

- No App Store or TestFlight builds; those need a paid Apple Developer account
- No notarization, so no clean first launch
- No Intel or Rosetta build. The Go engine's macOS slice is arm64 only

[unreleased]: https://github.com/bakirgdev/CrocApp/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/bakirgdev/CrocApp/compare/v0.9.9...v1.0.0
[0.9.9]: https://github.com/bakirgdev/CrocApp/releases/tag/v0.9.9
