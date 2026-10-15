---
sidebar_position: 2
title: Feature Matrix
description: Every CrocApp feature, numbered, grouped, and marked with its ship status.
---

# Feature matrix

Feature numbers (`F1`…) are stable identifiers used across the project. "Shipped" means the feature is in CrocApp 1.0 (see [Install](../getting-started/install.md) for where to get it).

## Core (shipped)

| # | Feature | croc flag / origin |
|---|---|---|
| F1 | Send files (multi) | positional args, drag-drop + file picker |
| F2 | Send folders | positional args |
| F3 | Send text/clipboard | `--text` |
| F4 | Receive via code | positional args |
| F5 | Custom code phrase (min 6 chars) | `--code` |
| F6 | QR show on send + QR scan on receive | `--qrcode` + GUI-native |
| F7 | Choose output folder; iOS default is a Files-visible app folder | `--out` |
| F8 | Keep Both / Replace on receive, resume with Replace | `--rename` (Keep Both), `--overwrite` (Replace) + resume |
| F9 | Incoming file list preview + accept/decline | interactive prompt equivalent |
| F10 | Progress, speed, cancel; Live Activity on iOS | polled from engine |
| F11 | LAN + relay auto race | croc default |
| F12 | Transfer history (local only) | GUI-native |

## Power options (shipped)

| # | Feature | croc flag |
|---|---|---|
| F13 | Custom relay + password + IPv6 | `--relay --relay6 --pass` |
| F14 | Force local-only | `--local` |
| F15 | Disable compression | `--no-compress` |
| F16 | Zip folder before send | `--zip` |
| F17 | Exclude patterns / respect `.gitignore` | `--exclude --git` |
| F18 | Auto-accept toggle (off by default, warning shown) | `--yes` |
| F19 | Both-sides confirm | `--ask` |
| F41 | Connection: Automatic or Relay only (the sender's choice applies, a receive follows it) | `--transport auto\|relay` |
| F20 | SOCKS5 proxy (Settings > Advanced) | `--socks5` |
| F21 | HTTP proxy | `--connect` |
| F22 | Upload speed limit (sender-side) | `--throttleUpload` |
| F23 | Curve choice (the receiver's wins; the sender adopts it) | `--curve` |
| F24 | Hash algorithm choice (sender-side) | `--hash` |
| F25 | Sender IP, direct connect (receive-side) | `--ip` |
| F26 | Custom multicast address (macOS only: iOS has no multicast entitlement) | `--multicast` |
| F27 | Base port, parallel connections, multiplexing toggle (sender-side) | `--port --transfers --no-multi` |
| F28 | Built-in DNS resolver | `--internal-dns` |

## GUI-native (shipped)

| # | Feature | Status |
|---|---|---|
| F30 | Share extension (send from any app) | shipped, iOS only |
| F32 | Receive links: `crocapp://` scheme, `crocapp.dev/r/` universal links, and `croc://` QR codes from earlier builds | shipped |
| F36 | Trust UI: end-to-end badge, "how it works", active-relay indicator | shipped |
| F42 | Share Link, a QR code that is a web link, and a `crocapp.dev/r/` page with an option to receive in a browser | shipped |
| F43 | Send as link: encrypted upload of files to a stored-transfer server, a link with a chosen lifetime and download count, receive from the link, and revoke from History | shipped |
| F31 | macOS menu bar quick send: drop or choose files, or send clipboard text, from a menu-bar window; Show in menu bar and Open at login settings (see [Menu bar](../guide/menu-bar.md)) | shipped, macOS only |
| F34 | Shortcuts and Siri actions: Send Files, Send Text and Receive with CrocApp (see [Shortcuts](../guide/shortcuts.md)) | shipped |
| F44 | iPad File menu: Show Receive Folder in Files | shipped, iPad only |

## After 1.0, not started

None of these are built yet.

| # | Feature | croc flag / origin |
|---|---|---|
| F29 | Run own relay from Mac app (menu-bar relay server) | `croc relay` |
| F33 | Saved codes / favorite peers | GUI-native |
| F35 | Relay health check + diagnostics screen | GUI-native |

## Later

| # | Feature | Note |
|---|---|---|
| F37 | Wi-Fi Aware direct path | iOS/iPadOS 26 only, absent on macOS 26; app-to-app fast path |

## Deliberately left out

| # | Feature | Reason |
|---|---|---|
| F38 | `--stdout` piping | CLI-only concept |
| F39 | `--classic` mode | insecure by design |
| F40 | `--remember` | GUI settings persist anyway |
