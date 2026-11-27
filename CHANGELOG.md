# Changelog

All notable changes to CrocApp are recorded here. Each version's section is
also the body of its GitHub release, so it is written for someone deciding
whether to download, not as a summary of commits.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), with
extra sections where a release needs them, and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.2] - 2026-11-27

### Changed

- The transfer engine is now croc 11.6.7.

## [1.3.1] - 2026-11-21

### Added

- On iPhone Duo, the inner display shows the sidebar in landscape, as iPad does, with each transfer's state in words, and the tabs in portrait. The outer display keeps the tab bar, on the side as the system places it. Partially open like a book, a code phrase, a QR code and **Accept** and **Decline** sit beside the fold, never across it, and what you picked or typed stays when you fold or open the device.

### Changed

- The transfer engine is now croc 11.6.6. A batch of small files now shows how far it has got, as a percent, a byte count and the file it has reached, on both the sending and the receiving device, instead of "A batch of small files" with no percent.

### Fixed

- Files you accepted that lose their connection partway now pick up where they left off when the connection comes back, instead of saying you declined them. If the sending device offers different files after reconnecting, or the transfer is text, the receive ends with **Lost connection to the other device** and **Try Again**.
- **Replace** now replaces the files already in a zipped folder you receive again. Before, it kept them and skipped the matching files in the archive.
- Receiving a zipped folder again no longer fails when more than 4096 of its files already exist.
- History opens with far less memory when it holds many past sends of many files: the list no longer loads the bookmarks behind **Send Again** for every row, only for the send you send again. The first time this version opens, it moves the bookmarks your History already holds, and every past transfer stays.
- **Send Speed Limit** holds sends to the limit you set. Before, a limit of hundreds of megabytes per second let sends run faster than set, and a limit of about 1 GB per second or more set no limit at all.
- **Respect .gitignore** skips a folder the `.gitignore` names with a trailing slash, such as `node_modules/`, which it used to send, and matches patterns against the path from the `.gitignore` as git does.
- An empty file you receive keeps the permissions it had on the sending device.

## [1.3.0] - 2026-11-15

### Changed

- CrocApp navigates with tabs on iPhone (**Send**, **Receive**, **History** and **Settings**) and a sidebar on iPad and Mac. iPad opens with the sidebar in landscape and a floating tab bar in portrait, and the sidebar button switches between them. On a Mac, Settings stays its own window and the menu bar window is unchanged.
- Files you picked, text you typed, a code and the link options on Send and Receive stay where they are when you switch tabs, and when the window changes between the tab bar and the sidebar. They are not kept after you quit, and a transfer that succeeds empties them.
- In the sidebar on iPad and Mac, a transfer shows on its row as **Connecting**, **Waiting**, **Sending** or **Receiving**. When someone's files wait for your answer, the **Receive** tab comes forward and keeps a badge if you go elsewhere: **Review** in the sidebar, a number on the tab bar. VoiceOver announces each state once.
- **How It Works** opens as a sheet from the first row of the About section in Settings, and from the Help menu on a Mac.
- History fills the window width instead of a narrow column.
- Advanced settings explain each option in one short line, and the note that proxy addresses are saved in the Keychain appears once, under the proxies.
- Buttons, colors, spacing and motion now use the system's own styles, so they match macOS and iOS 26, with one olive accent for controls, links and progress. The accent is a little deeper in dark mode, so button labels stay readable.
- The buttons that answer a screen sit at the bottom of it, in the same place in every state: **Send**, **Receive**, **Cancel**, **Decline** and **Accept** (or **Replace** and **Keep Both**), **Done**, **Try Again** and **Revoke Link**. The content scrolls above them, from the top, so a long file list or the largest text size never pushes **Accept** or **Cancel** out of reach, and **Cancel** no longer sits under the home indicator on a small iPhone.
- **Add Files**, **Add Folder** and **Add Photos** are one **Add** menu with **Files** and **Folder**, and **Photos** on iPhone and iPad. Dropping and pasting work as before.
- At the largest text sizes, every file you picked is reachable by scrolling the page and no button covers a row, a progress line puts its label above its byte count instead of cutting it off, and the welcome screen opens at its first line.

### Removed

- The **End-to-end encrypted** badge on the waiting, confirm, incoming and transferring screens, and its repeat among the points in **How It Works**. **How It Works** states it once, with the relay in use.
- The Home screen is gone, with its large **Send** and **Receive** buttons, the encryption badge above them and the **Recent transfers** list. **History** is a tab.
- **Multicast Address**, **Built-in DNS Resolver**, **Single Connection** and **Exact Paths** are gone from Advanced settings, which keeps the SOCKS5 and HTTP proxies, **Sender IP**, **Send Speed Limit** and **Skip Local Network**. Their saved values are deleted the first time 1.3.0 opens, except your **Exact Paths**, which are added to the patterns under **Exclude from sends**, each with a leading `/`, so those files stay out of folder sends. If you had a custom multicast address, devices find each other on croc's default one again, and if you had the built-in DNS resolver on, relay names are looked up by your system again. If you had **Single Connection** on, a send now uses several connections, as croc does by default. The patterns under **Exclude from sends** in Settings still work.
- **Run a Relay** and **Check Relay…** are gone, with the Relay tab in Mac Settings and the switch in the menu bar window. The relay address, IPv6 address and password you set in Settings still work as before. To host a relay, run `croc relay` on a machine you control. The port, password and launch setting the relay left behind are deleted the first time 1.3.0 opens.
- **Show History in Spotlight** is gone, and Spotlight no longer finds past transfers by their file names. If you had it on, the entries CrocApp added to Spotlight are removed each time CrocApp opens. The **Find Transfers** and **Open Transfer** actions in Shortcuts still work.

### Fixed

- After a send or receive succeeds, its files, text, code and link options are cleared, so the next transfer no longer carries the last one's code or sends its text again, and photos you added are deleted from CrocApp's temporary folder. A failed or cancelled transfer keeps them for Try Again.
- On a Mac, opening the window while files wait for your answer opens on the **Receive** (or **Send**) tab instead of the last one you used.
- **Send** and **Receive** are dimmed while a transfer in the other direction runs, instead of doing nothing when tapped.
- While files wait for your answer, the Receive screen says **Review** instead of **Receiving**.
- The patterns under **Exclude from sends** now apply to every folder you send. Before, they only took effect when the folder was sent as a zip, so a matching file in a folder sent the usual way still went to the other device. A file you pick yourself is always sent. When every file in the folders you picked matches a pattern, the send stops and says so.
- On iPhone and iPad, buttons that were shorter than Apple's 44 point minimum, such as **Change…**, **Cancel**, **Copy Code**, the saved-code chips and the action in a banner, are now at least that tall.
- The code field has a visible border that gets stronger with Increase Contrast, and the file remove and share buttons answer to a short name in Voice Control.
- Choosing a receive folder that CrocApp can't use now says so and keeps the current folder, instead of closing the picker with no message.
- History stops offering **Revoke** on a link that expires while History is open, and **Clear All** says when links that still work stay active.
- A transfer that iOS stopped in the background is recorded as **Failed** in History, not **Cancelled**.
- **Open Transfer** in Shortcuts opens that transfer's details in History instead of the list.
- On iPhone and iPad, the relay **Address**, **IPv6 Address** and **Password** rows in Settings show their names. Before, an empty row showed only its placeholder.

### Security

- croc's relay code, which CrocApp runs on your local network while it sends, could be crashed by a malformed connection before any password check. The transfer engine is now croc 11.6.5, whose relay turns such a connection away.

## [1.2.1] - 2026-11-12

### Fixed

- A send of thousands of files with **Confirm on Both Sides** on no longer hangs after you tap **Send** when the other device stops answering or you tap **Cancel**. The transfer ends and CrocApp is ready for the next one.
- Sharing to CrocApp twice before opening it no longer loses the first share. Each share waits its turn in the **Shared Files** sheet.
- A share that arrives while a transfer is running is kept and offered in the **Shared Files** sheet once the transfer ends, instead of being dropped. If the sheet is already open, **Send** is off until then.
- The copies CrocApp keeps of shared files are deleted once they are sent, rather than an hour later.
- On a Mac, a receive folder you chose is kept when it is moved or its drive mounts again, instead of quietly going back to Downloads/CrocApp. If CrocApp can no longer open it at all, **Settings** now says the folder was reset.
- Receiving a text longer than 1 MB now says **This text is too long** and suggests sending it as a file, instead of a general failure that suggested trying again.

### Security

- The transfer engine is built with Go 1.27.4, which fixes a `net/http` vulnerability (GO-2026-6859).

## [1.2.0] - 2026-11-06

### Added

- **Clear History…** in the File menu opens the same confirmation as the **Clear History** button on History. It is available while History is open and has entries.
- The App Store builds ask for a rating after a transfer succeeds, from the third success on, at most once per version and never after a failed transfer. The system decides whether the prompt shows. **Rate CrocApp** in Settings, About opens the review page at any time.
- The disk image build has a **Support CrocApp** link in Settings, About, which opens the sponsor options on the project site. The App Store builds have no such link.

### Fixed

- History shows a file name that contains text-direction or line-break characters with those characters spelled out, as the accept sheet does, including entries an earlier version recorded.
- Sending a file whose name contains a line break now says the file name can't be sent and to rename the file, instead of pointing to an Advanced setting.
- At the largest text sizes, saved codes under the code field stack in a column instead of running off the edge of the screen.
- At the largest text sizes, the iPad sidebar is wider, so "Receive" and "Settings" no longer break across two lines.
- The border of the code field and of the text box on Send is darker, so it is easier to see, and darker again when Increase Contrast is on.
- The two paste buttons on Send are named **Paste code** and **Paste text**, so VoiceOver and Voice Control can tell them apart.
- **Add Files**, **Add Folder**, **Add Photos** and **Scan QR Code** are taller on iPhone and iPad, so they are easier to tap.
- The text fields on the Advanced settings page are named for VoiceOver, so each reads with its label.
- Voice Control accepts "How It Works" and "Privacy" for the privacy button in the toolbar.

## [1.1.1] - 2026-11-06

### Changed

- The transfer engine is now croc 11.6.4. When both devices run croc 11.6 or newer, four or more small files travel together as one batch. croc does not report how far a batch has got, so while one moves CrocApp shows "A batch of small files" with no percent, beside a spinner on iPhone and iPad and over a moving bar on Mac.
- A receive started before the send now waits up to 5 seconds for the sender, and a send started in that time goes through.

### Fixed

- The Last Transfer widget's time and empty-state icon use a darker secondary color in light mode, so they are easier to read.
- The share sheet on iPhone and iPad has a **Cancel** button while it prepares a large share.
- Deleting a saved code from its context menu asks first. A swipe still deletes at once.
- A transfer no longer shows "File 0 of 0" before the file count is known.

## [1.1.0] - 2026-11-01

CrocApp 1.1.0 is the first release: a native app for [croc](https://github.com/schollz/croc) on Mac, iPhone and iPad. It embeds croc's Go library, so a code phrase from the croc command line works in the app and the other way round. The other device needs croc 11 or newer.

**macOS 26 or later, Apple silicon only** for the disk image. iOS 26 and iPadOS 26 or later in the App Store.

The disk image is signed with a Developer ID, notarized and stapled, and updates itself with Sparkle. Verify a download with `gh attestation verify <file> --repo bakirgdev/CrocApp`; `SHA256SUMS.txt` lists the checksums of the disk image and the engine archive.

### Send and receive

- Send files, folders, photos and videos (without a Photos permission prompt), or text, by drag and drop, paste, the share sheet, Finder's Share menu, the Services menu or Shortcuts. Nothing is sent until you press **Send**.
- Receive with a code phrase, a scanned QR code or a link (`crocapp.dev/r/`, `getcroc.com/?code=`). The file list shows before anything is saved, a taken name offers **Keep Both** or **Replace**, and auto-accept is off by default.
- **Send as Link**: upload files end-to-end encrypted to a transfer server and share a link and QR code, valid for 1 hour, 1 day or 7 days and up to 100 downloads. The key stays in the part of the link after the `#`, so the server cannot read the files. **Revoke Link** ends it early.
- **Saved codes**: keep a custom code phrase for a peer under their name and pick it in one tap. Codes stay in this device's Keychain, and Settings explains that a reused code is not single-use.
- A receive lists what arrived with sizes, Quick Look, share and **Show in Finder** (**Show in Files** on iOS).
- A failed transfer says what happened and offers the one action that helps: **Try Again**, **Open Settings** or **Done**.
- iPhone, iPad and Mac find each other on the same network, so a transfer can stay local, also with **Local Network Only**.

### On every screen

- History with a detail screen, **Send Again**, **Revoke Link** and **Delete**; **Save Transfer History** turns it off, and History never keeps a whole code.
- Notifications for a transfer that finishes, fails or needs your answer, asked for on your first transfer. They never show a code or link, and show file names only if you turn that on.
- The **Last Transfer** widget, **Send** and **Receive** controls for Control Center, and a Live Activity for a background iPhone transfer, all without file names unless you turn them on.
- Shortcuts and Siri: send files or text, receive, and find past transfers. **Show History in Spotlight** is off by default.
- A sidebar on iPad and Mac, menu bar commands with keyboard shortcuts on Mac and on iPad with a keyboard, haptics on iPhone (with a switch), and every screen at the largest text sizes.

### Mac

- A menu bar icon that shows the transfer state and opens a small window to send files or clipboard text and to receive with a code. **Open at Login** is off by default.
- The Dock shows the percent during a transfer and a badge while a request waits (**Show Progress in the Dock**).
- **Run a Relay**: start a croc relay on this Mac for devices on your network, with a port and an optional password kept in the Keychain. It is off by default and listens on every network connection, so set a password.
- **Check for Updates Automatically** in Settings for the disk image build.

### Settings and privacy

- **Check Relay…** tests the relay your transfers use over IPv4 and IPv6, and its password. It sends nothing and asks first while a proxy is set.
- Advanced settings: your own relay with a password, SOCKS5 and HTTP proxies, **Sender IP**, **Send Speed Limit**, **Skip Local Network**, **Single Connection**, **Built-in DNS Resolver** (off by default), **Exact Paths** and, on Mac, **Multicast Address**. **Reset to Defaults** puts them back.
- The relay password, proxies, saved codes and Send as Link receipts stay in this device's Keychain: never synced, and not restored from a backup to a new device.
- **Copy Code** and **Copy Link** ask the system to clear the clipboard after 5 minutes.
- No analytics and no account. Transfers go through croc's relays, your own relay or your local network.

### Security

- Transfers are end-to-end encrypted and the code phrase authenticates both sides. croc has had no formal third-party audit and CrocApp does not claim one.
- Incoming file names with path separators, control, hidden or text-direction characters are blocked, and hidden characters are shown as code points wherever a name appears.
- The transfer engine is croc v11.5.5, built with Go 1.27.3, without the Tailcat direct-connection path. The update checker is Sparkle 2.10.1 and installs only updates signed with the app's EdDSA key.

[1.3.2]: https://github.com/bakirgdev/CrocApp/releases/tag/v1.3.2
[1.3.1]: https://github.com/bakirgdev/CrocApp/releases/tag/v1.3.1
[1.3.0]: https://github.com/bakirgdev/CrocApp/releases/tag/v1.3.0
[1.2.1]: https://github.com/bakirgdev/CrocApp/releases/tag/v1.2.1
[1.2.0]: https://github.com/bakirgdev/CrocApp/releases/tag/v1.2.0
[1.1.1]: https://github.com/bakirgdev/CrocApp/releases/tag/v1.1.1
[1.1.0]: https://github.com/bakirgdev/CrocApp/releases/tag/v1.1.0
