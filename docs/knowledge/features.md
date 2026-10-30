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
| Transfer history (local only), with a **Save Transfer History** setting (on by default; off records nothing new and keeps what is there) | app-native | all | shipped |

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
| SOCKS5 proxy (Settings > Advanced) | `--socks5` | all | shipped |
| HTTP proxy | `--connect` | all | shipped |
| Upload speed limit (sender side) | `--throttleUpload` | all | shipped |
| Sender IP, direct connect (receive side) | `--ip` | all | shipped |
| Custom multicast address | `--multicast` | all | shipped |

## App-native features

| Feature | Platform | Status |
|---|---|---|
| Share extension (send from any app) | iOS and iPadOS | shipped |
| Add Photos, paste and drop of images and text on Send. Photos keep their names, ask no library permission, and stage in a folder that is deleted with the row or the screen | iOS and iPadOS (Photos), all (paste, drop). Paste from a hardware keyboard on iPad needs iOS 27 | shipped |
| Receive links: `crocapp://receive?code=`, `https://crocapp.dev/r/#<code>` (universal link), and `https://getcroc.com/?code=`. One parser, `TransferLink`. Opening a link prefills Receive and never connects. | all | shipped |
| Trust UI: encryption badge, "How it works", active-relay indicator | all | shipped |
| Failure screen: what happened, what to do, and **Try Again** or **Open Settings** when one can help | all | shipped |
| **Recent transfers** on Home: the latest three records below Send and Receive, hidden while **Save Transfer History** is off. A row opens the History list, not the record's detail. Home exists only at compact width, so a wide iPad window and the Mac show the History sidebar row instead; the dates refresh each minute | iPhone, and iPad at compact width | shipped |
| Waiting-screen QR and **Share Link** encode `https://crocapp.dev/r/#<code>` (see below) | all | shipped |
| Send as Link (stored transfers; see below) | all | shipped |
| **Haptics** setting (on by default): a short tap for a copied or scanned code and for a transfer that finishes, fails or needs your answer | iPhone only | shipped |
| Menu bar quick send and receive, with an icon that shows the transfer state (see below) | macOS only | shipped |
| **Notifications** and **Show File Names in Notifications** settings: a local notification when a transfer finishes, fails or needs your answer while the app is in the background (see below) | all | shipped, not verified on a device |
| Dock tile: the percent while bytes move, a badge while a request waits for an answer | macOS only | shipped, not verified by eye |
| Shortcuts and Siri actions (see below) | all | shipped |
| Past transfers as Shortcuts entities (**Find Transfers**, **Open Transfer**), and in Spotlight behind **Show History in Spotlight** (off by default) | all | shipped, not verified in the system UI |
| **Send with CrocApp** in the Services menu (selected files and text) | macOS | shipped |
| **Show Receive Folder in Finder** (macOS) or **Show Receive Folder in Files** (iPadOS) in the File menu | iPadOS (Files) and macOS (Finder) | shipped |
| Sidebar layout: **Send**, **Receive**, **History** (and **Settings** on iPad) beside the screen, whenever the window is wide enough for two columns. A narrow window, Slide Over and iPhone keep Home | iPad and macOS | shipped |
| Menu bar commands for everything a toolbar button does, with shortcuts (see below) | macOS; iPad with a hardware keyboard | shipped |

Details:

- **Link page.** The `web/landing/r/` page reads the code from the URL fragment, so no request carries it. It offers **Open in CrocApp**, **Get CrocApp** (the download section of the landing page), **Mac Disk Image**, and **Receive in your browser**. The last one goes through croc's own web app at getcroc.com and needs the default relays.
- **Send as Link.**
  - Files only, up to 100 files and 1 GiB.
  - The link lasts 1 hour, 1 day or 7 days, with 1 to 100 downloads, on the server set in Settings (`https://getcroc.com` by default).
  - The result screen shows the link and a QR code, and offers **Revoke Link**, which works with Save Transfer History off. It warns when this device could not save the receipt to the Keychain, because revoke then works only until the app quits. Receiving from a pasted or scanned link goes through the normal incoming preview.
  - History shows the expiry and offers **Revoke Link** (context menu, detail) and **Revoke** (swipe on iOS). Deleting a row whose link still works asks whether to revoke it first.
  - Device checks are in `device-test-checklist.md`, "Stored transfers".
- **Received files list.**
  - A finished receive lists the top-level files and folders it wrote, with sizes. A Keep Both copy shows under its new name.
  - Tap for Quick Look, share, reveal in Finder or Files, and drag out on Mac and iPad. Names are drawn in their shown form.
  - A transfer croc did not mark successful reads as a failure, and the user's own Cancel or Decline and a revoked link read as neutral (`StatusBlock` kinds).
- **Menu bar quick send.**
  - A `MenuBarExtra` window with a drop zone, **Choose Files…** and **Send Clipboard Text**, then the code, QR and progress of the one shared transfer. Codes are always generated.
  - **Receive**: a code field and a **Receive** button start a receive into the configured folder. A code or any link CrocApp opens is accepted. An incoming file list is answered in the main window: the window offers **Open CrocApp to Accept**.
  - The icon follows the phase (`MenuBarIcon`): idle, active with the percent beside it, waiting, needs your answer, done, failed. The accessibility label names the state.
  - A drop on the icon itself is not possible (`known-issues.md`, "Menu bar").
  - The **Show in Menu Bar** setting is on by default and **Open at Login** (`SMAppService`) is off by default.
  - Covered by unit tests and by `scripts/verify-app-mac.sh` (menu-bar send, clipboard send, Open at Login). The checks that need a real Mac are in `device-test-checklist.md`, "Menu bar on a Mac".
- **Notifications and the Dock.**
  - `TransferNotifier` watches the controller from outside and posts a local notification for a finished, failed or waiting-for-answer transfer, only while the app is not active (Mac: not frontmost; iOS: not in the foreground). The user's own cancel or decline posts nothing.
  - **Notifications** is on by default. The system permission prompt comes when the first transfer starts or when the switch is turned on, not at launch. **Show File Names in Notifications** is off by default, so the text is "Transfer complete"; with it on, a receive names its file, or counts several.
  - A notification never carries a code phrase or link. The category supplies a generic body for when the user hides previews on the lock screen. A tap opens the Send or Receive screen of that transfer (on a Mac it also reopens a closed window).
  - The Mac Dock tile shows the percent while bytes move and "1" while a request waits. It has no switch of its own: it shows no names, and it is not a notification.
  - Not verified on a device or by eye: delivery, the permission prompt and the tap.
- **Shortcuts and Siri.** **Send Files with CrocApp**, **Send Text with CrocApp** and **Receive with CrocApp** (App Intents), also offered as App Shortcuts. They run in the foreground. The send actions return the code and Receive returns the files. Not verified on a device. That the Finder Quick Action works is inferred, not tested (`device-test-checklist.md`, "Shortcuts actions").
- **History in Shortcuts and Spotlight.** A transfer is an entity with a name, direction, status, date, file names and size, never a code or its hint. Shortcuts gets **Find Transfers** (filters: date, direction, status, name) and **Open Transfer**, which opens History. Both answer with nothing while **Save Transfer History** is off. Spotlight indexing is a separate setting, **Show History in Spotlight**, off by default because it puts file names in a system index; turning it or Save Transfer History off removes what was indexed. Spotlight indexing and the entities were exercised by unit tests and a real-index test; the Spotlight search UI and a device were not (`known-issues.md`, "History entities").
- **Send with CrocApp (Mac Services menu).** Selected files in Finder, or selected text in any app, stage in Send and bring CrocApp forward. Never starts a transfer. Text over 1 MiB is refused. Listed in the system's Services after a registration refresh (`known-issues.md`).
- **Sidebar layout.**
  - A sidebar of **Send**, **Receive** and **History**, and **Settings** on iPad (the Mac keeps its Settings window). **How It Works** is a toolbar button that opens inside the screen.
  - The layout follows the window width, live: a Mac window, an iPad at full width or in a wide Split View gets the sidebar, and iPhone, Slide Over and a narrow Split View get Home.
  - While a transfer runs, its row says **Connecting**, **Waiting**, or the percent. When a request waits for an answer the row carries a **Review** badge and every other screen shows the same banner at its top, so a hidden sidebar never hides it.
  - Design: `design/principles.md`, "Platform adaptation". Code and measurements: `app-ui-architecture.md`, "Layout by width".
- **Menu bar commands.** **Send…** (⌘1), **Send Clipboard Text…** (⌥⌘1), **Receive…** (⌘2), **Paste Code…** (⌥⌘2), **History** (⌘3), **Show Receive Folder** (⇧⌘R), **Cancel Transfer** (⌘.), **Copy Code** (⇧⌘C), **How It Works** (⌘?), and **Settings…** (⌘,) on iPad. The two clipboard commands only fill in Send and Receive, and a transfer starts when you tap the button. iPad has them in the hardware-keyboard menu bar, not verified on a device.
- **File menu item.** On iPadOS the hand-off to the Files app is not verified on a device. A user-picked provider folder is expected to do nothing there.

## Skipped

| Feature | Reason |
|---|---|
| `--stdout` piping | CLI-only concept |
| `--classic` mode | insecure by design |
| `--remember` | app settings persist anyway |
| Tailcat, `--transport` | The engine is croc's relay-only build (`croc_no_tailcat`). It halves the app, and the relay and the LAN carry every transfer, so there is no Connection setting. See `crocmobile-bridge.md`, "Transport" |

What stands between the shipped feature set and the first App Store release is listed in `docs/known-issues.md`, "Release".
