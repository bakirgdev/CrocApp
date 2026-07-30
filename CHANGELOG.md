# v0.9.9

First public build of CrocApp. It is a symbolic release: the app does everything V1 is meant to do, but it is not signed with an Apple Developer ID and it is not notarized, so macOS refuses to open it until you allow it by hand. Read "Opening it the first time" below before downloading.

**macOS 26 or later, Apple silicon only.** No Intel build, and no iPhone or iPad build in this release.

## What CrocApp does

A native SwiftUI front end for [croc](https://github.com/schollz/croc). It embeds croc's Go library rather than shelling out to the binary, so a code phrase from the croc CLI works in the app and the other way round.

- Send files, several at once, whole folders, or a snippet of text
- Receive with a code phrase, or by scanning a QR code
- See the file list before accepting, resume interrupted transfers, confirm overwrites
- Direct transfer when both devices share a network, relay otherwise; the relay only ever sees ciphertext
- Point it at your own croc relay, with password and IPv6
- Local-only mode, auto-accept off by default, optional confirmation on both sides
- Transfer history, stored only on your device
- Send from any app through the share extension
- Drag and drop, light and dark, Dynamic Type and VoiceOver

Transfers are end-to-end encrypted and the code phrase authenticates both sides. That is the whole security claim. croc has had no formal third-party audit and CrocApp does not claim one.

## Opening it the first time

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

## Downloads

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

## Not in this release

- No App Store or TestFlight builds; those need a paid Apple Developer account
- No notarization, so no clean first launch
- No Intel or Rosetta build. The Go engine's macOS slice is arm64 only
- No screenshots in the README or on the docs site yet
