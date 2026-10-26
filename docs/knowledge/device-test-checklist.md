# Physical-device test checklist

A repeatable procedure for what the simulator and the verify scripts cannot check: real iPhone, iPad and Mac hardware. This file records no results. Tick items on your own copy or in the pull request.

Run the whole list before each App Store submission, and run the matching section after any change to that area (background handling, share extension, links, stored transfers, menu bar, Shortcuts, large files).

Setup unless a section says otherwise: an iPhone or iPad on iOS or iPadOS 26 or later, a Mac on macOS 26 or later with CrocApp, and the croc CLI v11 for the other end. Hash files with `shasum -a 256`. To hash a file received on the iPhone, copy it to the Mac first.

## Background continuation

- [ ] Start a multi-GB receive, then background the app. The system Live Activity shows the title, progress and a cancel control.
- [ ] The transfer completes in the background. This is best effort: iOS may kill low-progress transfers under pressure.
- [ ] Force an expiry (a long time in the background under memory pressure), then reopen the app. It shows "iOS paused the transfer…". Start the same transfer again and choose Replace: the partial file resumes. With Keep Both the app saves a new copy instead.
- [ ] Cancel from the system Live Activity. The app shows the cancelled state.
- [ ] The wildcard task identifier registers on the device. The fallback static identifier is the backstop, so check the console for `register()` failures.

## Share extension

- [ ] Photos > share sheet > CrocApp: the files are staged and the "Open CrocApp" instruction shows.
- [ ] Files app > share several files > CrocApp: all are staged.
- [ ] Open the app afterwards. The staged sheet appears, and Send completes to another device.
- [ ] A large video (over 500 MB) stages without the extension being killed (memory cap).

## Files app visibility

- [ ] "On My iPhone > CrocApp" appears after the first receive, and the received files are visible.
- [ ] **Open in Files** on the receive-done screen lands in the right folder.
- [ ] Choose a provider folder (such as iCloud Drive) as the output folder and receive a file. The **Open in Files** button is not shown.

## Local network

- [ ] The first transfer triggers the local-network permission prompt.
- [ ] Deny it. A banner with a Settings shortcut appears, and a relay transfer still succeeds.
- [ ] LAN discovery on iOS depends on the multicast entitlement (`apple-platform-constraints.md`, "Hard constraints", item 2). Without it, expect the LAN path to lose the race to the relay.

## Idle timer

- [ ] The screen stays awake during a long foreground transfer and sleeps normally afterwards.

## Links and web receive

Use an iPhone and a Mac running CrocApp as the sender (start a send and leave it on the waiting screen). The simulator has no camera and cannot resolve universal links.

- [ ] 1. With CrocApp installed on the iPhone, point the Camera app at the waiting-screen QR on the Mac. Pass: CrocApp opens on Receive with the code filled in, and nothing connects until you tap **Receive**. After you tap it, the transfer completes.
- [ ] 2. Delete CrocApp from the iPhone (or use an iPhone without it) and scan the same QR with the Camera app. Pass: Safari opens `https://crocapp.dev/r/`, the page shows the code, and it has the **Open in CrocApp**, **Get CrocApp**, **Mac Disk Image** and **Receive in your browser** buttons.
- [ ] 3. Install CrocApp again, open the page from step 2 (scan again, long-press the link and open it in Safari, or open it from Notes), and tap **Open in CrocApp**. Pass: CrocApp opens on Receive with the code filled in and does not connect by itself.
- [ ] 4. In CrocApp, tap **Scan QR Code** and scan a `croc://<code>` QR (make one with any QR generator, text `croc://word-word-word`). Pass: the code field fills with `word-word-word` and nothing connects.
- [ ] 5. Copy `https://getcroc.com/?code=<code>` (a link the croc CLI shows with `--qrcode`, or typed by hand) and tap **Paste** on Receive. Pass: the code field shows only `<code>`, not the link.
- [ ] 6. On the page from step 2, tap **Receive in your browser** while the Mac sender uses the default relays. Pass: Safari opens `https://getcroc.com/?code=<code>` and the croc web app offers the transfer. This is croc's own web app, not CrocApp.

## Stored transfers

Use an iPhone with the default server (`https://getcroc.com`) and the public internet. Item 3 needs a second phone, and item 4 needs a way to hash the received file.

- [ ] 1. Send a 1 to 2 MB file as a link: Send > Files > turn on **Send as Link** > **Send as Link**. Background the app mid-send, then return. Pass: the send completes and shows "Link ready", or it shows "Sending was interrupted: iOS stopped it in the background. Try again." and sending again completes.
- [ ] 2. Tap **Copy Link** on the result screen, then paste on a Mac signed in to the same iCloud account (Handoff and Universal Clipboard on). Pass: nothing pastes on the Mac, because the link is copied for this device only.
- [ ] 3. On a second phone with CrocApp, open Receive > **Scan QR Code** and scan the result-screen QR of a stored link. Pass: Receive shows a **Receive from Link** row with the server host in place of the code field, and nothing downloads until you tap **Receive**.
- [ ] 3b. Point the Camera app at the same QR on a phone with CrocApp and on a phone without it. The stored link points at the server, not at `crocapp.dev/r/`, so the Camera is expected to open the server's page in the browser on both phones, not CrocApp. Note what each phone does and what the page shows.
- [ ] 4. In CrocApp, receive the link (tap **Receive**). Pass: the incoming preview lists the file, **Accept** saves it, and its SHA-256 equals the source file's.
- [ ] 5. In History, open the sent row and choose **Revoke** (swipe) or **Revoke Link** (touch and hold), then confirm. Pass: the row reads "Link revoked", and reopening the link in a browser reports the link as gone.

## Menu bar on a Mac

Use a real Mac with the croc CLI as the receiver (`croc --yes <code>` in an empty folder). `scripts/verify-app-mac.sh` already covers a menu-bar send of a file and of clipboard text received by the CLI, and Open at Login following the system status. These items cover the real gestures and the real login. Compare SHA-256 values. VoiceOver in the menu-bar window belongs to the accessibility audit in `docs/known-issues.md`, "Release".

- [ ] 1. Click the menu-bar icon, then drag a file from Finder onto "Drop files to send". Pass: the window shows the code, a QR code and **Copy Code**, the CLI receives the file, and its SHA-256 equals the source's. Dropping onto the icon itself is expected to do nothing (`docs/known-issues.md`, "Accepted").
- [ ] 2. Click **Choose Files…** and pick a file and a folder in the open panel. Pass: the panel stays open until you confirm, the send starts, and the CLI receives both with equal SHA-256.
- [ ] 3. Copy some text and click **Send Clipboard Text**. Pass: the CLI receives the text. With an empty clipboard the window says "The clipboard has no text to send."
- [ ] 4. Start a send from the main window. Pass: the menu-bar window shows the same transfer, and its drop zone and buttons are not offered until it ends.
- [ ] 5. Turn Settings > General > **Show in Menu Bar** off, then on. Pass: the icon disappears and returns without a relaunch.
- [ ] 6. Turn **Open at Login** on, then log out and back in. Pass: CrocApp starts at login. Then remove it in System Settings > General > Login Items and reopen CrocApp Settings. Pass: the toggle is off.
- [ ] 7. If macOS asks for approval (the toggle is on and a note says to allow CrocApp in Login Items), click **Open Settings**. Pass: System Settings opens at Login Items, and after you allow CrocApp the note disappears.

## Shortcuts actions

Run on a Mac and on an iPhone, each against the croc CLI (v11).

- [ ] 1. Mac, Shortcuts app: run **Send Files with CrocApp** with a file. Pass: CrocApp comes to the front, the action returns the code and shows "The code is X. Keep CrocApp open until the transfer ends.", `croc --yes <code>` receives the file, and the SHA-256 equals the source's.
- [ ] 2. iPhone: same as 1. Pass: the same, with CrocApp in the foreground for the whole transfer.
- [ ] 3. Mac and iPhone: run **Send Text with CrocApp** with a short text. Pass: the code comes back and `croc --yes <code>` prints the text.
- [ ] 4. Mac and iPhone: start `croc send <file>` on the CLI and run **Receive with CrocApp** with its code. Pass: the incoming prompt appears in the app (or is skipped with Auto-Accept Transfers on), the action waits for the end, returns the file, shows "Received 1 item.", and the SHA-256 equals the source's.
- [ ] 5. Receive with a `crocapp.dev/r/#<code>` link and with a Send as Link link. Pass: both work as in 4.
- [ ] 6. Receive a text sent with `croc send --text hi`. Pass: the action returns a file named "Received text.txt".
- [ ] 7. Receive a file whose name already exists in the receive folder, once with Keep Both and once with Replace. Pass: the returned file is the new copy (`name (1).ext` for Keep Both).
- [ ] 8. Start a transfer, then run any of the three actions. Pass: it fails with "CrocApp is already sending or receiving. Wait for it to finish."
- [ ] 9. Run the send-files and receive actions from Siri and from Spotlight ("Send files with CrocApp", "Receive with CrocApp"). Pass: each starts its action.
- [ ] 10. Mac: build a shortcut that uses **Send Files with CrocApp** and enable it as a Quick Action in Finder (shortcut details > Use as Quick Action). Pass: it appears in Finder's Quick Actions for selected files and returns the code. This is inferred to work and has not been run.

## iPad File menu

Use an iPad on iPadOS 26 with a keyboard, or the pointer to open the menu bar.

- [ ] 1. Open the menu bar, then File. Pass: **Send…** (⌘1), **Receive…** (⌘2) and **Show Receive Folder in Files** (⇧⌘R) are listed.
- [ ] 2. After a receive, choose **Show Receive Folder in Files** or press ⇧⌘R. Pass: the Files app opens at the CrocApp receive folder.
- [ ] 3. Repeat with a user-picked provider folder (such as iCloud Drive) as the receive folder. The `shareddocuments://` scheme resolves local paths only, so a silent no-op is expected. Note what happens and confirm there is no crash.

## Large files without Tailcat

Use an iPhone and the Mac CLI at `/opt/homebrew/bin/croc` (v11). Use a file of at least 130 MiB, the size at which the stock CLI would try Tailcat. CrocApp is built without it (`crocmobile-bridge.md`, "Transport and Tailcat"), so the relay and the LAN carry the data, and the CLI `--debug` log shows `selected croc relay data transport` with no `tailcat-offer`.

- [ ] 1. Send the file from the iPhone to `croc --debug --yes` on the Mac, once with the app in the foreground and once switching to another app mid-transfer and back. Pass: both complete, the SHA-256 matches the source, the CLI log has the plain `selected croc relay data transport` line and no `tailcat-offer`.
- [ ] 2. On the Mac run `croc --debug --ignore-stdin send <file>` and receive on the iPhone, once in the foreground and once backgrounded mid-transfer. Pass: both complete, the SHA-256 matches, and the CLI log has no `tailcat-offer`.
- [ ] 3. On the Mac run `croc --debug --ignore-stdin send --transport derp <file>` and receive on the iPhone. Pass: the app shows a failure within seconds (`peer requires Tailcat, but Tailcat is disabled or unavailable locally`), not a spinner that never ends.
