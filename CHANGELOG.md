# Changelog

All notable changes to CrocApp are recorded here. Each version's section is
also the body of its GitHub release, so it is written for someone deciding
whether to download, not as a summary of commits.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- The macOS direct download is now signed with a Developer ID certificate, notarized and stapled, and updates itself with Sparkle: choose "Check for Updates…" in the app menu. The release no longer ships the separate app zip; the disk image is the download.
- Receiving a file whose name is already taken now offers Keep Both (saves the new one as `name (1).ext`) or Replace. With auto-accept on, the setting "When a file already exists" under Confirmation chooses; it defaults to Keep Both.
- A Connection setting, Automatic (the default) or Relay only. With Automatic, a send of 128 MB or more can also take a direct path between the devices; Relay only keeps every transfer on croc's relays. The sender's choice applies, and a receive follows it.
- Links. Opening a CrocApp link, a `crocapp.dev/r/` link or a `getcroc.com/?code=` link, or pasting one into the Receive field, opens Receive with the code filled in; nothing connects until you tap Receive. The sender's waiting screen has a Share Link button. The page at `crocapp.dev/r/` reads the code in your browser (it never reaches a server) and offers to open CrocApp, get the app, or receive in your browser through croc's own web app, which needs the default relays.

### Changed

- The QR code on the sender's waiting screen now encodes a `https://crocapp.dev/r/` link instead of `croc://<code>`, so a phone camera opens CrocApp, or a page that explains what to do when the app is missing. QR codes from 0.9.9 still scan in the app.

### Fixed

- A receive no longer overwrites existing files by default. A zipped folder received into a folder that already holds it no longer fails. Answers left over from one transfer can no longer answer the next transfer's accept prompt.

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

[unreleased]: https://github.com/bakirgdev/CrocApp/compare/v0.9.9...HEAD
[0.9.9]: https://github.com/bakirgdev/CrocApp/releases/tag/v0.9.9
