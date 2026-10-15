# Physical-device test checklist

The simulator cannot verify any of these. Run them on a real iOS 26 device before store submission — this is the hardware gate. Run so far (owner, 2026-10-14, on a physical iPhone): "Links and web receive" 1-6 and "Transport and Tailcat gate" (a)-(d), all passed. Every other section, including "Stored transfers (R18-R21)", is still unrun.

## Background continuation (BGContinuedProcessingTask)
- [ ] Start multi-GB receive, background the app → system Live Activity shows title + progress + cancel
- [ ] Transfer completes in background (best-effort; low-progress kills expected under pressure)
- [ ] Force-expire (long background under memory pressure) → reopen app shows "iOS paused the transfer…" message; restarting same transfer and choosing Replace resumes partial file (croc resume; Keep Both saves a new copy instead)
- [ ] Cancel from the system Live Activity → app shows cancelled state
- [ ] Wildcard identifier registers OK on-device (fallback static id is the backstop; check console for register() failures)

## Share extension
- [ ] Photos → share sheet → CrocApp: stages, "Open CrocApp" instruction shown
- [ ] Files app → share multiple files → CrocApp: all staged
- [ ] Open app afterwards → staged sheet appears → Send completes to another device
- [ ] Large video (>500 MB) stages without extension being killed (memory cap)

## Files app visibility
- [ ] "On My iPhone → CrocApp" appears after first receive; received files visible
- [ ] "Open in Files" button lands in the right folder
- [ ] "Open in Files" with a user-picked provider folder (iCloud Drive etc.): known silent no-op (shareddocuments:// resolves local paths only) — confirm no crash, consider hiding button there later

## Local network
- [ ] First transfer triggers local-network permission prompt
- [ ] Deny → banner appears with Settings shortcut; relay transfer still succeeds
- [ ] Multicast entitlement still pending Apple approval → LAN discovery expected to lose the race even when granted (constraint doc §2)

## Idle timer
- [ ] Screen stays awake during a long foreground transfer; sleeps normally after

## Links and web receive (R22, R23)
Owner-run on a physical iPhone, with a Mac running CrocApp as the sender (start a send and leave it on the waiting screen). The simulator has no camera and cannot resolve universal links.
- [x] 1. CrocApp installed on the iPhone. Point the Camera app at the waiting-screen QR on the Mac. Pass: CrocApp opens on Receive with the code filled in, and nothing connects until you tap Receive; after you tap Receive the transfer completes
- [x] 2. Delete CrocApp from the iPhone (or use an iPhone without it) and scan the same QR with the Camera app. Pass: Safari opens `https://crocapp.dev/r/`, the page shows the code, and it has the "Open in CrocApp", "Get CrocApp" (the download section of crocapp.dev), "Mac disk image" and "Receive in your browser" buttons
- [x] 3. Install CrocApp again, open the page from step 2 (scan the QR once more, long-press the link and open it in Safari, or open it from Notes), and tap "Open in CrocApp". Pass: CrocApp opens on Receive with the code filled in and does not connect by itself
- [x] 4. In CrocApp, tap Scan QR Code and scan an old-style `croc://<code>` QR (make one from any QR generator with text `croc://word-word-word`). Pass: the code field fills with `word-word-word` and nothing connects
- [x] 5. Copy `https://getcroc.com/?code=<code>` (a link the croc CLI shows with `--qrcode`, or typed by hand), tap Paste on Receive. Pass: the code field shows only `<code>`, not the link
- [x] 6. On the page from step 2, tap "Receive in your browser" while the Mac sender uses default relays. Pass: Safari opens `https://getcroc.com/?code=<code>` and the croc web app offers the transfer. Informational: this is croc's own web app, not CrocApp

## Stored transfers (R18-R21)
Owner-run on a physical iPhone, with the default server (`https://getcroc.com`) and the public internet. Items 3 and 4 need a second phone (3) and any device that can hash the received file (4). Use `shasum -a 256` on the Mac; copy a file received on the iPhone to the Mac to hash it.
- [ ] 1. Send as link a 1-2 MB file (Send > Files > Send as link > Upload). Background the app mid-upload, then return. Pass: the upload completes and shows "Link ready", or it shows "Upload interrupted: iOS stopped it in the background. Try again." and sending again completes
- [ ] 2. On the iPhone tap Copy Link on the result screen, then paste on a Mac signed in to the same iCloud account (Handoff and Universal Clipboard on). Pass: nothing pastes on the Mac, because the link is copied for this device only
- [ ] 3. On a second phone with CrocApp, open Receive > Scan QR Code and scan the result-screen QR of a stored link. Pass: Receive shows "Download link from <host>" in place of the code field, and nothing downloads until you tap Receive. Then, on the same QR, point the Camera app of a phone with CrocApp at it and of a phone without CrocApp. Informational: the stored link points at the server, not at `crocapp.dev/r/`, so the Camera is expected to open the server's page in the browser on both phones, not CrocApp. Record what each phone does and what the page shows
- [ ] 4. In CrocApp, receive the link (tap Receive). Pass: the incoming preview lists the file, Accept saves it, and its SHA-256 equals the source file's
- [ ] 5. In History, open the upload's row, choose Revoke Link (swipe or touch and hold) and confirm. Pass: the row reads "Link revoked", and reopening the link in a browser reports the link as gone

## Menu bar on a Mac (R26)
Owner-run on a real Mac, with the croc CLI as the receiver (`croc --yes <code>` in an empty folder). `verify-app-mac.sh` scenarios 10 and 11 already cover a menu-bar send of a file and of clipboard text received by the CLI, and Open at login following the system status; these items cover the real gestures and the real login. Compare SHA-256 with `shasum -a 256`. VoiceOver on the menu-bar window is part of owner step O12, not repeated here.
- [ ] 1. Click the menu-bar icon, then drag a file from Finder onto "Drop files to send". Pass: the window shows the code, a QR and Copy Code, the CLI receives the file, and its SHA-256 equals the source's. Also try dropping onto the icon itself: expected to do nothing (`../known-issues.md`)
- [ ] 2. Click Choose Files…, pick a file and a folder in the open panel. Pass: the panel stays open until you confirm, the send starts, and the CLI receives both with equal SHA-256
- [ ] 3. Copy some text, click Send Clipboard Text. Pass: the CLI receives the text. With an empty clipboard the window says "The clipboard has no text to send."
- [ ] 4. Start a send from the main window. Pass: the menu-bar window shows the same transfer, and its drop zone and buttons are not offered until it ends
- [ ] 5. Settings > General > Show in menu bar off, then on. Pass: the icon disappears and returns without a relaunch
- [ ] 6. Turn Open at login on, log out and back in. Pass: CrocApp starts at login. Then remove it in System Settings > General > Login Items and reopen CrocApp Settings. Pass: the toggle is off
- [ ] 7. If macOS asks for approval (the toggle is on and the setting says to allow CrocApp in Login Items), click Open Settings. Pass: System Settings opens at Login Items; after you allow CrocApp the note disappears

## Shortcuts actions (R27)
Owner-run on a Mac and on an iPhone, each against the croc CLI (`croc` v11). Hash with `shasum -a 256`; copy a file received on the iPhone to the Mac to hash it. The actions are not verified on a device yet.
- [ ] 1. Mac, Shortcuts app: run "Send Files with CrocApp" with a file. Pass: CrocApp comes to the front, the action returns the code and shows "The code is X. Keep CrocApp open until the transfer ends.", `croc --yes <code>` receives the file, and the SHA-256 equals the source's
- [ ] 2. iPhone: same as 1. Pass: the same, with CrocApp in the foreground for the whole transfer
- [ ] 3. Mac and iPhone: run "Send Text with CrocApp" with a short text. Pass: the code comes back and `croc --yes <code>` prints the text
- [ ] 4. Mac and iPhone: start `croc send <file>` on the CLI and run "Receive with CrocApp" with its code. Pass: the incoming prompt appears in the app (or is skipped with Auto-accept on), the action waits for the end, returns the file, shows "Received 1 item.", and the SHA-256 equals the source's
- [ ] 5. Receive with a `crocapp.dev/r/#<code>` link and with a Send as link link. Pass: both work as in 4
- [ ] 6. Receive a text sent with `croc send --text hi`. Pass: the action returns a file named "Received text.txt"
- [ ] 7. Receive a file whose name already exists in the receive folder, once with Keep Both and once with Replace. Pass: the returned file is the new copy (`name (1).ext` for Keep Both)
- [ ] 8. Start a transfer, then run any of the three actions. Pass: it fails with "CrocApp is already sending or receiving. Wait for it to finish."
- [ ] 9. Run "Send files with CrocApp" and "Receive with CrocApp" from Siri and Spotlight. Pass: each starts the action
- [ ] 10. Mac: build a shortcut that uses "Send Files with CrocApp" and enable it as a Quick Action in Finder (shortcut details > Use as Quick Action). Pass: it appears in Finder's Quick Actions for selected files and returns the code. Inferred to work, never run

## iPad File menu (R28)
Owner-run on a real iPad with iPadOS 26 and a keyboard or the pointer to open the menu bar.
- [ ] 1. Open the menu bar, File. Pass: Send… (⌘1), Receive… (⌘2) and Show Receive Folder in Files (⇧⌘R) are listed
- [ ] 2. After a receive, choose Show Receive Folder in Files, or press ⇧⌘R. Pass: the Files app opens at the CrocApp receive folder. Record what happens when the receive folder is a user-picked folder from a provider such as iCloud Drive: the `shareddocuments://` scheme resolves local paths only, so a silent no-op is expected there (see "Files app visibility")

## Transport and Tailcat gate
Owner-run on a physical iPhone, against the Mac CLI (`/opt/homebrew/bin/croc`, v11). Use a file of at least 130 MiB, because croc starts Tailcat only for sends of 128 MiB or more (`crocmobile-bridge.md`, "Transport"). Under Automatic croc races Tailcat against its relay, so the CLI `--debug` log shows which side offered it. Report each SHA-256 (`shasum -a 256` on the Mac; copy a file received on the iPhone to the Mac to hash it) so Claude can compare them with the source file's. Pass for the gate is (a) to (c) complete with equal SHA-256 and no crash or hang. (d) is informational.
- [x] (a) Settings > Connection = Automatic. Send the file from the iPhone to `croc --debug --yes` on the Mac, once with the app in the foreground and once switching to another app mid-transfer and back. Pass: both transfers complete, the SHA-256 matches the source, and the CLI log contains `tailcat-offer`
- [x] (b) Connection = Relay only. Same send, foreground. Pass: the transfer completes, the SHA-256 matches, and the CLI log has no `tailcat-offer`
- [x] (c) On the Mac run `croc --debug --ignore-stdin send --transport auto <file>` and receive on the iPhone, once in the foreground and once backgrounded mid-transfer. Pass: both complete and the SHA-256 matches
- [x] (d) Informational: on the Mac run `croc --debug --ignore-stdin send --transport derp <file>` and receive on the iPhone. Note whether it completes. This records whether Tailcat's own data path works on iOS; on the development Mac the same flag failed CLI to CLI (`../known-issues.md`, Harnesses)
- Archived iOS app size, with Tailcat (measured 2026-10-14 with `scripts/build-appstore.sh ios`, export only): `CrocApp.ipa` 18.5 MB (18,471,600 bytes); `CrocApp.app` in the archive 25 MB, of which the main executable (Go engine linked in) is 20.3 MB (20,332,352 bytes)

(a) to (d) passed on 2026-10-14 (the owner reported "all pass"; the SHA-256 values were not sent to Claude, so the hash matches rest on the owner's check). The gate passes: the Connection setting stays and no `croc_no_tailcat` build is needed. (d) passing means Tailcat's own data path completed on iOS.

If (a) to (c) had failed: build the engine with `-tags croc_no_tailcat` in `scripts/build-xcframework.sh`, remove the Connection setting and the "Direct path for large files" item in How it works (its relay item stays), and file a `future` issue. A build without Tailcat downgrades croc's `derp` to `relay` (`what-is-croc.md`).
