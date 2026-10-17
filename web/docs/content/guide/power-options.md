---
sidebar_position: 5
title: Power options
description: The shipped power-user settings and the croc CLI flag each one maps to.
---

# Power options

![CrocApp Settings on iOS showing the power options under the settings screen](/img/screenshots/iphone/settings-light.png#gh-light-mode-only)![CrocApp Settings on iOS showing the power options under the settings screen](/img/screenshots/iphone/settings-dark.png#gh-dark-mode-only)

CrocApp exposes a set of power options with sane defaults. On macOS they live in the Settings scene (⌘,); on iOS they're under the settings screen from the home toolbar. All eight below are shipped. The croc options most people never need, such as proxies and ports, are on a separate page: [Advanced settings](advanced-settings.md).

| Option | Control | croc equivalent |
|---|---|---|
| Custom relay, password, IPv6 | **Address**, **IPv6 Address**, **Password** fields under Relay | `--relay --relay6 --pass` |
| Connection: Automatic or Relay only | **Connection** picker | `--transport auto\|relay` |
| Force local-only transfers | **Local Network Only** toggle | `--local` |
| Disable compression | **Disable Compression** toggle | `--no-compress` |
| Zip a folder before sending | **Zip Folders Before Sending** toggle | `--zip` |
| Exclude patterns, respect `.gitignore` | **Patterns, One per Line** field, **Respect .gitignore** toggle | `--exclude --git` |
| Auto-accept, off by default | **Auto-Accept Transfers** toggle | `--yes` |
| Require confirmation on both sides | **Confirm on Both Sides** toggle | `--ask` |

## Relay

The **Address** and **IPv6 Address** fields read "Public relay pool" as placeholder text; leave them blank to use croc's public relay pool, the same one the croc command line uses. Leave **Password** blank to use croc's default relay password.

## Connection

The **Connection** picker has its own section after Relay. **Automatic** is the default. **Relay Only** sends every transfer through croc's relays.

With **Automatic**, a send of 128 MiB or more also tries a direct path between the two devices. This path is called Tailcat. It is set up through `tailcat.dev`, and it uses its own relays (`*.ipn.dev`) when the devices cannot reach each other. CrocApp starts it next to croc's relay, and whichever path connects first carries the transfer. The data is still end-to-end encrypted on either path. Smaller sends never start it.

With **Relay Only**, a send never contacts `tailcat.dev` or the `*.ipn.dev` servers. A receive can still use them when the sender chose Automatic (or the croc CLI's default, `auto`).

Only the sender's choice applies. A receive follows whatever the sender uses, so the picker has no effect when you receive. The picker is disabled while **Local Network Only** is on, because local-only transfers always use **Automatic**. The footer under the picker reads: "Automatic can carry files of 128 MiB or more directly between devices. Only the sender's choice applies; a receive follows it."

## Local network only

When on, transfers never touch a relay on the internet: CrocApp only uses the local network. If a direct local connection cannot be made, the transfer fails rather than falling back to a relay.

## Exclude patterns

Patterns go one per line in the **Patterns, One per Line** field. **Respect .gitignore** additionally excludes anything your `.gitignore` would.

## Auto-accept

Auto-accept is off by default. With it on, a picker, **When a File Already Exists**, chooses what happens to received files whose names are already taken: **Keep Both** (the default) saves them under a new name such as `name (1).ext`, **Replace** overwrites the existing file. See [Receiving files](receiving.md) for how each choice behaves. With auto-accept on, CrocApp warns that files from anyone who has your code are saved without preview or confirmation, that Keep Both saves a new copy next to an existing file while Replace overwrites it, that unsafe file names still cancel the transfer, and that **Confirm on Both Sides** overrides auto-accept. With it off, the footer says to leave it off unless you fully trust the sender.

## Confirm on both sides

When on, the sender also has to approve the transfer, through a prompt reading **The other device is connected**, before it starts. That comes in addition to the other device's normal accept step.

## Not in the app

The app cannot run a relay itself. To use your own relay, run `croc relay` on a machine you control and enter its address under Relay. The other croc options (proxies, send speed limit, curve and hash choice, sender IP, multicast address, ports and the internal DNS resolver) are under [Advanced settings](advanced-settings.md).
