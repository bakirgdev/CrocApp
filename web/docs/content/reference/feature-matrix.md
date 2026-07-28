---
sidebar_position: 2
title: Feature Matrix
description: Every planned CrocApp feature, numbered, grouped, and marked with its real ship status.
---

# Feature matrix

Feature numbers (`F1`…) are stable identifiers used across the project. "Shipped" means the feature exists and works in the app today; the project has not released a build yet (see [Install](../getting-started/install.md)).

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
| F8 | Overwrite/resume handling via confirm sheets | `--overwrite` + resume |
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

## GUI-native (shipped)

| # | Feature | Status |
|---|---|---|
| F30 | Share extension (send from any app) | shipped, iOS only |
| F36 | Trust UI: end-to-end badge, "how it works", active-relay indicator | shipped |

## Planned, not started (V1.x)

None of these are built yet.

| # | Feature | croc flag / origin |
|---|---|---|
| F20 | SOCKS5 / Tor proxy | `--socks5` |
| F21 | HTTP proxy | `--connect` |
| F22 | Upload throttle | `--throttleUpload` |
| F23 | Curve choice | `--curve` |
| F24 | Hash algorithm choice | `--hash` |
| F25 | Direct IP connect | `--ip` |
| F26 | Custom multicast address | `--multicast` |
| F27 | Ports/transfers tuning, disable multiplexing | `--port --transfers --no-multi` |
| F28 | Internal DNS resolver | `--internal-dns` |
| F29 | Run own relay from Mac app (menu-bar relay server) | `croc relay` |
| F31 | macOS menu bar quick-send (drag-drop) | GUI-native |
| F32 | `croc://code` deeplink + universal links | GUI-native |
| F33 | Saved codes / favorite peers | GUI-native |
| F34 | App Intents / Shortcuts ("Send via croc") | GUI-native |
| F35 | Relay health check + diagnostics screen | GUI-native |

## Later

| # | Feature | Note |
|---|---|---|
| F37 | Wi-Fi Aware direct path | iOS/iPadOS 26 only, absent on macOS 26; app-to-app fast path |

## Deliberately not planned

| # | Feature | Reason |
|---|---|---|
| F38 | `--stdout` piping | CLI-only concept |
| F39 | `--classic` mode | insecure by design |
| F40 | `--remember` | GUI settings persist anyway |
