---
sidebar_position: 5
title: Power Options
description: The shipped power-user settings and the croc CLI flag each one maps to.
---

# Power options

![CrocApp Settings on iOS showing the power options under the settings screen](/img/screenshots/ios-settings-light.png#gh-light-mode-only)![CrocApp Settings on iOS showing the power options under the settings screen](/img/screenshots/ios-settings-dark.png#gh-dark-mode-only)

CrocApp exposes a set of power options with sane defaults. On macOS they live in the Settings scene (⌘,); on iOS they're under the settings screen from the home toolbar. All eight below are shipped. The croc options most people never need, such as proxies and ports, are on a separate page: [Advanced settings](advanced-settings.md).

| # | Option | Control | croc equivalent |
|---|---|---|---|
| F13 | Custom relay, password, IPv6 | **Address**, **IPv6 address**, **Password** fields under Relay | `--relay --relay6 --pass` |
| F41 | Connection: Automatic or Relay only | **Connection** picker | `--transport auto\|relay` |
| F14 | Force local-only transfers | **Local network only** toggle | `--local` |
| F15 | Disable compression | **Disable compression** toggle | `--no-compress` |
| F16 | Zip a folder before sending | **Zip folders before sending** toggle | `--zip` |
| F17 | Exclude patterns, respect `.gitignore` | **Patterns, one per line** field, **Respect .gitignore** toggle | `--exclude --git` |
| F18 | Auto-accept incoming, off by default | **Auto-accept incoming files** toggle | `--yes` |
| F19 | Require confirmation on both sides | **Confirm on both sides** toggle | `--ask` |

## Relay (F13)

The **Address** and **IPv6 address** fields read "Public relay pool" as placeholder text; leave them blank to use croc's public relay pool, the same one the croc command line uses. Leave **Password** blank to use croc's default relay password.

## Connection (F41)

The **Connection** picker has its own section after Relay. **Automatic** is the default. **Relay only** sends every transfer through croc's relays.

With **Automatic**, a send of 128 MB or more also tries a direct path between the two devices. This path is called Tailcat. It is set up through `tailcat.dev`, and it uses its own relays (`*.ipn.dev`) when the devices cannot reach each other. CrocApp starts it next to croc's relay, and whichever path connects first carries the transfer. The data is still end-to-end encrypted on either path. Smaller sends never start it.

With **Relay only**, a send never contacts `tailcat.dev` or the `*.ipn.dev` servers. A receive can still use them when the sender chose Automatic (or the croc CLI's default, `auto`).

Only the sender's choice applies. A receive follows whatever the sender uses, so the picker has no effect when you receive. The picker is disabled while **Local network only** is on, because local-only transfers always use **Automatic**. The footer under the picker reads: "Automatic can carry files of 128 MB or more directly between devices. Only the sender's choice applies; a receive follows it."

## Local network only (F14)

When on, transfers never touch a relay on the internet — CrocApp only uses the local network. If a direct local connection can't be made, the transfer fails rather than falling back to a relay.

## Exclude patterns (F17)

Patterns go one per line in the **Patterns, one per line** field. **Respect .gitignore** additionally excludes anything your `.gitignore` would.

## Auto-accept (F18)

Auto-accept is off by default. With it on, a picker, **When a file already exists**, chooses what happens to incoming files whose names are already taken: **Keep Both** (the default) saves them under a new name such as `name (1).ext`, **Replace** overwrites the existing file. See [Receiving files](receiving.md) for how each choice behaves. With auto-accept on, CrocApp shows this warning: "Files from anyone who has your code are saved without preview or confirmation. Keep Both saves a new copy next to an existing file; Replace overwrites it. Unsafe file names still cancel the transfer. Both-sides confirm overrides auto-accept." With it off: "Auto-accept skips the incoming-files preview. Leave it off unless you fully trust the sender."

## Confirm on both sides (F19)

When on, the sender also has to approve the transfer (via a **Receiver connected** prompt) before it starts, in addition to the receiver's normal accept step.

## Not yet built

Running your own relay from the Mac app is planned for a later release but has not been started. The other croc options (proxies, upload throttling, curve and hash choice, sender IP, multicast address, ports and the internal DNS resolver) are under [Advanced settings](advanced-settings.md).
