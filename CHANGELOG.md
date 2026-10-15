# Changelog

All notable changes to CrocApp are recorded here. Each version's section is
also the body of its GitHub release, so it is written for someone deciding
whether to download, not as a summary of commits.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-15

CrocApp 1.0 is on three channels: the iOS and iPadOS App Store, the Mac App Store, and a notarized disk image for Mac. The App Store listings are linked from crocapp.dev when they are live. The other device needs croc 11 or newer.

**iOS 26, iPadOS 26 or macOS 26 or later. The disk image is Apple silicon only.**

### Added

- iPhone and iPad apps through the App Store, and a Mac App Store build. 0.9.9 was macOS only.
- The macOS direct download is now signed with a Developer ID certificate, notarized and stapled, so it opens with only the standard first-launch confirmation. It updates itself with Sparkle: choose "Check for Updates…" in the app menu. Sparkle installs an update only when its EdDSA signature matches the key built into the app, and the update check sends no system profile. Only this build has Sparkle; the App Store builds update through the App Store. The release no longer ships the separate app zip; the disk image is the download. Verify a download with `gh attestation verify <file> --repo bakirgdev/CrocApp`: the release workflow attests the disk image, the update feed and the engine archive after stapling, so the attestation covers the bytes you download.
- Receiving a file whose name is already taken now offers Keep Both (saves the new one as `name (1).ext`) or Replace. With auto-accept on, the setting "When a file already exists" under Confirmation chooses; it defaults to Keep Both.
- A Connection setting, Automatic (the default) or Relay only. With Automatic, a send of 128 MB or more can also take a direct path between the devices; Relay only keeps every transfer on croc's relays. The sender's choice applies, and a receive follows it.
- Links. Opening a CrocApp link, a `crocapp.dev/r/` link or a `getcroc.com/?code=` link, or pasting one into the Receive field, opens Receive with the code filled in; nothing connects until you tap Receive. The sender's waiting screen has a Share Link button. The page at `crocapp.dev/r/` reads the code in your browser (it never reaches a server) and offers to open CrocApp, get the app, or receive in your browser through croc's own web app, which needs the default relays.
- Send as link. Turn it on in Send to upload files (not folders or text) encrypted to a transfer server and get a link and QR code instead of a code, so the receiver can download later without being online at the same time. You choose how long the link lasts (1 hour, 1 day or 7 days) and how many downloads it allows (1 to 100), up to 100 files and 1 GiB. Receive takes the link like a code and shows the file list before anything is saved. History shows when each link expires and can revoke it. The files are encrypted on your device and the key is the part of the link after the `#`, so the server cannot read them. The server is set in Settings and defaults to `https://getcroc.com`, which croc's author runs; CrocApp does not.

- Advanced settings (Settings > Advanced on iOS, the Advanced tab of the macOS Settings window): SOCKS5 and HTTP proxies, a built-in DNS resolver option, the encryption curve, the file hash, an upload speed limit, the base port and number of parallel connections, a multiplexing switch, a sender IP to receive from directly, and, on macOS, a multicast address. Each shows its default, checks what you type, and says which device it affects and whether the other device must match. Reset to Defaults puts them all back. The proxies also apply to Send as link and are kept in the Keychain, never in the settings file. A receive with a sender IP connects straight to the sender and skips relays. iOS has no multicast setting, because the multicast entitlement is not granted.
- Menu bar quick send on macOS. A CrocApp icon in the menu bar opens a small window: drop files or folders on it, choose them with Choose Files…, or send the clipboard text. It then shows the code, a QR code, Copy Code, progress and Cancel. It shares the one active transfer with the main window, so it also shows a transfer started there or from Shortcuts. Quick send always uses a generated code. Settings > General has Show in menu bar (on by default) and Open at login (off by default; it follows System Settings > General > Login Items and offers a shortcut there when macOS needs your approval).
- Shortcuts and Siri actions: Send Files with CrocApp, Send Text with CrocApp and Receive with CrocApp. The send actions return the code as soon as croc has one, so keep CrocApp open until the receiver finishes. Receive takes a code or any link CrocApp opens and returns the received files; it does not answer the incoming-files prompt, so turn on Auto-accept or answer it in the app. The actions also appear in Spotlight and Siri with the phrases "Send files with CrocApp", "Send text with CrocApp" and "Receive with CrocApp".
- The iPad menu bar has Show Receive Folder in Files (⇧⌘R) in the File menu next to Send… and Receive…. On a Mac the same shortcut shows the folder in Finder.

### Changed

- The transfer engine is croc v11.5.4. A croc 10 device can no longer complete a transfer with CrocApp, in either direction: the other device needs croc 11 or newer. Relays are picked from croc's public relay pool the way the croc 11 command line does, and a send fails with a clear message when no public relay answers.
- Failures say what went wrong: a wrong code, a refused transfer, a lost connection, a peer on an older croc, or no public relay available, instead of one generic message.
- The relay password is kept in the Keychain instead of the settings file. History keeps only the first segment of a code phrase, never the whole code.
- Every 1.0 screen works at the largest text sizes and with VoiceOver, including the transfer percentage.
- The QR code on the sender's waiting screen now encodes a `https://crocapp.dev/r/` link instead of `croc://<code>`, so a phone camera opens CrocApp, or a page that explains what to do when the app is missing. QR codes from 0.9.9 still scan in the app.

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
