# Feature roadmap

Approved 2026-07-22 by Bakir. Tier = target release. Numbers stable — reference as F1..F40 in plans/issues.

## V1 (approved, must ship)

### Core

| # | Feature | croc flag / origin |
|---|---|---|
| F1 | Send files (multi) | positional; drag-drop + fileImporter |
| F2 | Send folders | positional |
| F3 | Send text/clipboard | `--text` |
| F4 | Receive via code | positional |
| F5 | Custom code phrase (min 6 chars) | `--code` |
| F6 | QR show on send + QR scan on receive | `--qrcode` + GUI-native |
| F7 | Choose output folder; iOS default = Files-visible app folder | `--out` |
| F8 | Overwrite/resume handling via confirm sheets | `--overwrite` + resume |
| F9 | Incoming file list preview + accept/decline | interactive prompt equivalent |
| F10 | Progress, speed, cancel; Live Activity on iOS | polled from engine |
| F11 | LAN + relay auto race | croc default |
| F12 | Transfer history (local only) | GUI-native |

### Power options (settings screen, sane defaults)

| # | Feature | croc flag |
|---|---|---|
| F13 | Custom relay + password + IPv6 | `--relay --relay6 --pass` |
| F14 | Force local-only | `--local` |
| F15 | Disable compression | `--no-compress` |
| F16 | Zip folder before send | `--zip` |
| F17 | Exclude patterns / respect .gitignore | `--exclude --git` |
| F18 | Auto-accept toggle (off by default, warning shown) | `--yes` |
| F19 | Both-sides confirm | `--ask` |

### GUI-native

| # | Feature |
|---|---|
| F30 | Share extension (send from any app) |
| F36 | Trust UI: E2E badge, "how it works", active-relay indicator |

## V1.x (approved, post-V1 fast follow)

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
| F37 | Wi-Fi Aware direct path | iOS/iPadOS 26 only, absent on macOS 26 — app↔app fast path |

## Skip

| # | Feature | Reason |
|---|---|---|
| F38 | `--stdout` piping | CLI-only concept |
| F39 | `--classic` mode | insecure by design |
| F40 | `--remember` | GUI settings persist anyway |
