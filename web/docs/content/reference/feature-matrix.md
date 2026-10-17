---
sidebar_position: 2
title: Feature matrix
description: Every CrocApp feature, grouped and marked with its ship status.
---

# Feature matrix

"Shipped" means the feature is in CrocApp 1.0 (see [Install](../getting-started/install.md) for where to get it).

## Core (shipped)

| Feature | croc flag / origin |
|---|---|
| Send files (multi) | positional args, drag-drop + file picker |
| Send folders | positional args |
| Send text/clipboard | `--text` |
| Receive via code | positional args |
| Custom code phrase (min 6 chars) | `--code` |
| QR show on send + QR scan on receive | `--qrcode` + GUI-native |
| Choose output folder; iOS default is a Files-visible app folder | `--out` |
| Keep Both / Replace on receive, resume with Replace | `--rename` (Keep Both), `--overwrite` (Replace) + resume |
| File list preview, then accept or decline | interactive prompt equivalent |
| Progress, speed, cancel; Live Activity on iOS | polled from engine |
| Local network and relay race | croc default |
| Transfer history (local only) | GUI-native |

## Power options (shipped)

| Feature | croc flag |
|---|---|
| Custom relay + password + IPv6 | `--relay --relay6 --pass` |
| Force local-only | `--local` |
| Disable compression | `--no-compress` |
| Zip folder before send | `--zip` |
| Exclude patterns / respect `.gitignore` | `--exclude --git` |
| Auto-accept toggle (off by default, warning shown) | `--yes` |
| Both-sides confirm | `--ask` |
| Connection: Automatic or Relay only (the sender's choice applies, a receive follows it) | `--transport auto\|relay` |
| SOCKS5 proxy (Settings > Advanced) | `--socks5` |
| HTTP proxy | `--connect` |
| Send speed limit (sender-side) | `--throttleUpload` |
| Curve choice (the receiving device's choice wins; the sender adopts it) | `--curve` |
| Hash algorithm choice (sender-side) | `--hash` |
| Sender IP, direct connect (receive-side) | `--ip` |
| Custom multicast address (macOS only: iOS has no multicast entitlement) | `--multicast` |
| Base port, parallel connections, multiplexing toggle (sender-side) | `--port --transfers --no-multi` |
| Built-in DNS resolver | `--internal-dns` |

## GUI-native (shipped)

| Feature | Status |
|---|---|
| Share extension (send from any app) | shipped, iOS only |
| Receive links: `crocapp://` scheme, `crocapp.dev/r/` universal links, and `croc://` QR codes from earlier builds | shipped |
| Trust UI: end-to-end badge, "how it works", active-relay indicator | shipped |
| Share Link, a QR code that is a web link, and a `crocapp.dev/r/` page with an option to receive in a browser | shipped |
| Send as link: files encrypted on your device and sent to a link server, a link with a chosen lifetime and number of downloads, receive from the link, and revoke from History | shipped |
| macOS menu bar quick send: drop or choose files, or send clipboard text, from a menu-bar window; Show in menu bar and Open at login settings (see [Menu bar](../guide/menu-bar.md)) | shipped, macOS only |
| Shortcuts and Siri actions: Send Files, Send Text and Receive with CrocApp (see [Shortcuts](../guide/shortcuts.md)) | shipped |
| iPad File menu: Show Receive Folder in Files | shipped, iPad only |

## After 1.0, not started

None of these are built yet.

| Feature | croc flag / origin |
|---|---|
| Run own relay from Mac app (menu-bar relay) | `croc relay` |
| Saved codes / favorite devices | GUI-native |
| Relay health check + diagnostics screen | GUI-native |

## Later

| Feature | Note |
|---|---|
| Wi-Fi Aware direct path | iOS/iPadOS 26 only, absent on macOS 26; app-to-app fast path |

## Deliberately left out

| Feature | Reason |
|---|---|
| `--stdout` piping | CLI-only concept |
| `--classic` mode | weaker by design |
| `--remember` | GUI settings persist anyway |
