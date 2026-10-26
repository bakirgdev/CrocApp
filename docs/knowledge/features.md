# Features

What CrocApp does, what it deliberately skips, and which croc option each feature maps to. Plans live in `docs/ROADMAP.md`.

Status is checked against the code, not against intent. **Shipped** means the feature exists and works in the app. It does not mean it was tested on physical hardware (`device-test-checklist.md`) or that it has no open defects (`docs/known-issues.md`).

Statuses: **shipped** (in the code) and **skipped** (deliberately not offered).

## Core

| Feature | croc option or origin | Platform | Status |
|---|---|---|---|
| Send files (several at once) | positional; drag and drop plus file picker | all | shipped |
| Send folders | positional | all | shipped |
| Send text or clipboard | `--text` | all | shipped |
| Receive with a code | positional | all | shipped |
| Custom code phrase (at least 6 characters) | `--code` | all | shipped |
| QR code on send, QR scan on receive | `--qrcode` plus app-native scanner | all; scanning is iOS and iPadOS only | shipped |
| Choose the output folder (iOS default is the Files-visible app folder) | `--out` | all | shipped |
| Keep Both or Replace on receive, answered on the incoming sheet; Replace resumes a partial file | `--rename`, `--overwrite`, resume | all | shipped |
| Incoming file list preview with Accept and Decline | croc's interactive prompt | all | shipped |
| Progress, speed and Cancel; system Live Activity while backgrounded | engine progress events | Live Activity on iOS and iPadOS | shipped |
| LAN and relay race | croc default | all | shipped |
| Transfer history (local only) | app-native | all | shipped |

## Power options

| Feature | croc option | Platform | Status |
|---|---|---|---|
| Custom relay, relay password, IPv6 relay | `--relay`, `--relay6`, `--pass` | all | shipped |
| Local Network Only | `--local` | all | shipped |
| Disable Compression | `--no-compress` | all | shipped |
| Zip folders before sending | `--zip` | all | shipped |
| Exclude patterns, respect `.gitignore` | `--exclude`, `--git` | all | shipped |
| Auto-Accept Transfers (off by default, warning shown) | `--yes` | all | shipped |
| Confirm on Both Sides | `--ask` | all | shipped |
| Connection: Automatic or Relay Only (sender side; a receive follows the sender) | `--transport auto\|relay` | all | shipped |
| SOCKS5 proxy (Settings > Advanced) | `--socks5` | all | shipped |
| HTTP proxy | `--connect` | all | shipped |
| Upload speed limit (sender side) | `--throttleUpload` | all | shipped |
| Sender IP, direct connect (receive side) | `--ip` | all | shipped |
| Custom multicast address | `--multicast` | macOS only; iOS has no multicast entitlement | shipped |

## App-native features

| Feature | Platform | Status |
|---|---|---|
| Share extension (send from any app) | iOS and iPadOS | shipped |
| Receive links: `crocapp://receive?code=`, `https://crocapp.dev/r/#<code>` (universal link), `https://getcroc.com/?code=`, and `croc://<code>` (QR payload of older CrocApp builds). One parser, `TransferLink`. Opening a link prefills Receive and never connects. | all | shipped |
| Trust UI: encryption badge, "How it works", active-relay indicator | all | shipped |
| Waiting-screen QR and **Share Link** encode `https://crocapp.dev/r/#<code>` (see below) | all | shipped |
| Send as Link (stored transfers; see below) | all | shipped |
| Menu bar quick send (see below) | macOS only | shipped |
| Shortcuts and Siri actions (see below) | all | shipped |
| **Show Receive Folder in Finder** (macOS) or **Show Receive Folder in Files** (iPadOS) in the File menu | iPadOS (Files) and macOS (Finder) | shipped |

Details:

- **Link page.** The `web/landing/r/` page reads the code from the URL fragment, so no request carries it. It offers **Open in CrocApp**, **Get CrocApp** (the download section of the landing page), **Mac Disk Image**, and **Receive in your browser**. The last one goes through croc's own web app at getcroc.com and needs the default relays.
- **Send as Link.**
  - Files only, up to 100 files and 1 GiB.
  - The link lasts 1 hour, 1 day or 7 days, with 1 to 100 downloads, on the server set in Settings (`https://getcroc.com` by default).
  - The result screen shows the link and a QR code. Receiving from a pasted or scanned link goes through the normal incoming preview.
  - History shows the expiry and offers **Revoke Link** (context menu) and **Revoke** (swipe on iOS).
  - Device checks are in `device-test-checklist.md`, "Stored transfers".
- **Menu bar quick send.**
  - A `MenuBarExtra` window with a drop zone, **Choose Files…** and **Send Clipboard Text**, then the code, QR and progress of the one shared transfer. Codes are always generated.
  - The **Show in Menu Bar** setting is on by default and **Open at Login** (`SMAppService`) is off by default.
  - Covered by unit tests and by `scripts/verify-app-mac.sh` (menu-bar send, clipboard send, Open at Login). The checks that need a real Mac are in `device-test-checklist.md`, "Menu bar on a Mac".
- **Shortcuts and Siri.** **Send Files with CrocApp**, **Send Text with CrocApp** and **Receive with CrocApp** (App Intents), also offered as App Shortcuts. They run in the foreground. The send actions return the code and Receive returns the files. Not verified on a device. That the Finder Quick Action works is inferred, not tested (`device-test-checklist.md`, "Shortcuts actions").
- **File menu item.** On iPadOS the hand-off to the Files app is not verified on a device. A user-picked provider folder is expected to do nothing there.

## Skipped

| Feature | Reason |
|---|---|
| `--stdout` piping | CLI-only concept |
| `--classic` mode | insecure by design |
| `--remember` | app settings persist anyway |

What stands between the shipped feature set and the first App Store release is listed in `docs/known-issues.md`, "Release".
