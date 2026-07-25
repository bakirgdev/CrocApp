# Feature roadmap

Approved 2026-07-22 by Bakir. Tier = target release. Numbers are stable — reference them as F1..F40 in plans, issues, and code comments (several views already carry them).

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
| F8 | Overwrite/resume handling via confirm sheets | `--overwrite` + resume | shipped |
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

### GUI-native

| # | Feature | Status |
|---|---|---|
| F30 | Share extension (send from any app) | shipped, iOS only |
| F36 | Trust UI: E2E badge, "how it works", active-relay indicator | shipped |

The whole V1 set is implemented. What stands between it and release is in `../known-issues.md` under "Blocking release", not in this table.

## V1.x (approved, post-V1 fast follow)

None started. The engine already exposes several of these from Go (`RelayPorts`, `Curve`, `HashAlgorithm`, `ThrottleUpload`, `NoMultiplexing`); wiring them means plumbing `EngineOptions` in CrocKit first (`crocmobile-bridge.md`).

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
