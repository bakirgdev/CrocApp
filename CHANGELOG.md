# Changelog

All notable changes to CrocApp are recorded here. Each version's section is
also the body of its GitHub release, so it is written for someone deciding
whether to download, not as a summary of commits.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), with
extra sections where a release needs them, and the project follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-01

CrocApp 1.1.0 is the first release: a native app for [croc](https://github.com/schollz/croc) on Mac, with the iPhone, iPad and Mac App Store builds following in the App Store. It embeds croc's Go library, so a code phrase from the croc command line works in the app and the other way round. The other device needs croc 11 or newer.

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

[1.1.0]: https://github.com/bakirgdev/CrocApp/releases/tag/v1.1.0
