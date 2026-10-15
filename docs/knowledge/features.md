# Feature roadmap

Approved 2026-07-22 by Bakir. Tier = target release. Numbers are stable — reference them as F1..F44 in plans, issues, and code comments (several views already carry them).

Status is verified against the code, not against intent. **Shipped** means the feature exists and works in the app; it does not mean it has been tested on physical hardware (`device-test-checklist.md`) or that it has no open defects (`../known-issues.md`).

## V1 (approved, must ship)

### Core

| # | Feature | croc flag / origin | Status |
|---|---|---|---|
| F1 | Send files (multi) | positional; drag-drop + fileImporter | shipped |
| F2 | Send folders | positional | shipped |
| F3 | Send text/clipboard | `--text` | shipped |
| F4 | Receive via code | positional | shipped |
| F5 | Custom code phrase (min 6 chars) | `--code` | shipped |
| F6 | QR show on send + QR scan on receive | `--qrcode` + GUI-native | shipped |
| F7 | Choose output folder; iOS default = Files-visible app folder | `--out` | shipped |
| F8 | Keep Both / Replace on receive, via confirm sheets; resume with Replace | `--rename` / `--overwrite` + resume | shipped |
| F9 | Incoming file list preview + accept/decline | interactive prompt equivalent | shipped |
| F10 | Progress, speed, cancel; Live Activity on iOS | polled from engine | shipped |
| F11 | LAN + relay auto race | croc default | shipped |
| F12 | Transfer history (local only) | GUI-native | shipped |

### Power options (settings screen, sane defaults)

| # | Feature | croc flag | Status |
|---|---|---|---|
| F13 | Custom relay + password + IPv6 | `--relay --relay6 --pass` | shipped |
| F14 | Force local-only | `--local` | shipped |
| F15 | Disable compression | `--no-compress` | shipped |
| F16 | Zip folder before send | `--zip` | shipped |
| F17 | Exclude patterns / respect .gitignore | `--exclude --git` | shipped |
| F18 | Auto-accept toggle (off by default, warning shown) | `--yes` | shipped |
| F19 | Both-sides confirm | `--ask` | shipped |
| F41 | Connection: Automatic or Relay only (sender-side; a receive follows) | `--transport auto\|relay` | shipped |
| F20 | SOCKS5 proxy (Settings > Advanced) | `--socks5` | shipped |
| F21 | HTTP proxy | `--connect` | shipped |
| F22 | Upload speed limit (sender-side) | `--throttleUpload` | shipped |
| F23 | Curve choice (the receiver's wins; the sender adopts it) | `--curve` | shipped |
| F24 | Hash algorithm choice (sender-side) | `--hash` | shipped |
| F25 | Sender IP, direct connect (receive-side) | `--ip` | shipped |
| F26 | Custom multicast address (macOS only: iOS has no multicast entitlement) | `--multicast` | shipped |
| F27 | Base port, parallel connections, multiplexing toggle (sender-side) | `--port --transfers --no-multi` | shipped |
| F28 | Built-in DNS resolver | `--internal-dns` | shipped |

### GUI-native

| # | Feature | Status |
|---|---|---|
| F30 | Share extension (send from any app) | shipped, iOS only |
| F32 | Receive links: `crocapp://receive?code=`, `https://crocapp.dev/r/#<code>` universal links, `https://getcroc.com/?code=`, and `croc://<code>` (0.9.9 QR codes); one parser, `TransferLink`. Opening a link prefills Receive and never connects. Universal links in the Developer ID build are unverified (`../known-issues.md`) | shipped |
| F36 | Trust UI: E2E badge, "how it works", active-relay indicator | shipped |
| F42 | Waiting-screen QR and Share Link encode `https://crocapp.dev/r/#<code>`; `web/landing/r/` page reads the code from the fragment (no network request) and offers Open in CrocApp, Get CrocApp (the landing page download section, until the store listing is live), the DMG, and receive in a browser through croc's own web app at getcroc.com (needs the default relays) | shipped |
| F43 | Send as link (stored transfers, R18-R21): files only, up to 100 files / 1 GiB, lifetime 1 hour / 1 day / 7 days, 1-100 downloads, to the server in Settings (`https://getcroc.com` by default); link and QR result screen, receive from a pasted or scanned link through the normal incoming preview, History expiry and Revoke. Needs the device checks in `device-test-checklist.md` | shipped |
| F31 | macOS menu bar quick send (R26): `MenuBarExtra` window with a drop zone, Choose Files… and Send Clipboard Text, then the code, QR and progress of the one shared transfer; generated codes only; settings Show in menu bar (default on) and Open at login (default off, `SMAppService`). Verified by unit tests and `verify-app-mac.sh` scenarios 10 and 11; the owner's Mac checks are in `device-test-checklist.md` | shipped, macOS only |
| F34 | Shortcuts and Siri actions (R27, App Intents): Send Files, Send Text and Receive with CrocApp, also offered as App Shortcuts. They run in the foreground; the send actions return the code, Receive returns the files. Not verified on a device; the Finder Quick Action is inferred (`device-test-checklist.md`) | shipped |
| F44 | iPad File menu (R28): Show Receive Folder in Files (⇧⌘R) beside Send… and Receive…. The Files hand-off is not verified on a device | shipped, iPadOS only |

The whole V1 set is implemented. What stands between it and release is in `../known-issues.md` under "Blocking release", not in this table.

## V1.x (approved, post-V1 fast follow)

The Advanced options (F20-F28) are in the power options table above: `EngineOptions` carries them, `AppSettings` stores them (the proxies in the Keychain), `Views/AdvancedSettingsView.swift` edits them (`app-ui-architecture.md`, "Advanced settings (R25)"). The menu bar quick send (F31) and App Intents (F34) shipped and moved to the GUI-native table above (`app-ui-architecture.md`, "Menu bar and Shortcuts (R26-R28)"). Nothing else in this table has been started.

| # | Feature | croc flag / origin |
|---|---|---|
| F29 | Run own relay from Mac app (menu-bar relay server) | `croc relay` |
| F33 | Saved codes / favorite peers | GUI-native |
| F35 | Relay health check + diagnostics screen | GUI-native |

## Later

| # | Feature | Note |
|---|---|---|
| F37 | Wi-Fi Aware direct path | iOS/iPadOS 26 only, absent on macOS 26 — app↔app fast path |

## Skip

| # | Feature | Reason |
|---|---|---|
| F38 | `--stdout` piping | CLI-only concept |
| F39 | `--classic` mode | insecure by design |
| F40 | `--remember` | GUI settings persist anyway |
