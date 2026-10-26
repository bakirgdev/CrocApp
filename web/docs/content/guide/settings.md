---
sidebar_position: 5
title: Settings
description: Every CrocApp setting in the order the app lists them, with defaults, what each one affects and whether the other device has to match.
---

# Settings

![CrocApp Settings on macOS, General tab, showing the Transfer, Exclude from sends, Confirmation and About sections](../../screenshots/mac/settings-light.webp#gh-light-mode-only)![CrocApp Settings on macOS, General tab, showing the Transfer, Exclude from sends, Confirmation and About sections](../../screenshots/mac/settings-dark.webp#gh-dark-mode-only)

On a Mac, open Settings with ⌘, and use the **General** and **Advanced** tabs. On iOS, tap the gear on the home screen. **Advanced** is a row at the bottom of that screen.

Settings stay on the device. There is no sync and no account. Defaults suit most people.

## Receive and Menu bar (Mac)

The **Receive** section shows **Save Received Files To**, with **Change…**, **Reset** and **Show in Finder**. On iOS, change the destination from the **Receive** screen instead.

The **Menu bar** section has **Show in Menu Bar** (on by default) and **Open at Login** (off by default). **Open at Login** follows what macOS reports, so a change in System Settings > General > Login Items shows up here. If macOS needs your approval, an **Open Settings** button takes you to Login Items. See [Mac menu bar and keyboard shortcuts](menu-bar.md).

## History and haptics

- **Save Transfer History** (on by default): finished transfers are listed in [History](history.md), which stays on this device. Turn it off and new transfers are no longer recorded. What is already in History stays until you delete it, and the History screen says "History is off" while it is empty. A [Send as link](send-as-link.md) upload sent while this is off leaves no row, so you cannot revoke that link later. It stops working when it expires.
- **Haptics** (iPhone only, on by default): a short tap when you copy or scan a code, and when a transfer finishes, fails or needs your answer. Turn it off to silence all of them. Each event still shows on screen.

## Relay

By default CrocApp uses croc's public relay pool, the same one the croc command line uses. **Address** and **IPv6 Address** show "Public relay pool" when empty, and **Password** shows "Default".

To use your own relay, run `croc relay` on a machine you control and enter its address, and its password if you set one. The other device must use the same relay. The app cannot run a relay itself. Reasons to run your own: your transfers route through infrastructure you control, or you would rather not depend on an external service.

## Send as link

**Link Server** holds the server for [Send as link](send-as-link.md). The default is `https://getcroc.com`, run by croc's author, not by CrocApp. **Reset to https://getcroc.com** appears once you change it.

The address is checked as you type. It must use `https` (plain `http` is allowed only for `localhost`), and it can have nothing after the host name: no path, query or fragment. The server must speak croc's stored-transfer protocol.

## Transfer

- **Local Network Only**: transfers never use a relay on the internet. If a direct local connection cannot be made, the transfer fails instead of falling back.
- **Disable Compression**: sends file data uncompressed.
- **Zip Folders Before Sending**: packs a folder into one archive before sending.

## Exclude from sends

Type patterns in **Patterns, one per line** to skip matching files when you send a folder. **Respect .gitignore** also skips whatever your `.gitignore` would.

## Confirmation

- **Confirm on Both Sides**: the sender also approves each transfer, through the prompt **The other device is connected**, on top of the other device's accept step. It overrides **Auto-Accept Transfers**.
- **Auto-Accept Transfers**: off by default. When on, files from anyone who has your code are saved without a preview. Turn it on only for senders you fully trust. **When a File Already Exists** then decides between **Keep Both** (the default) and **Replace**. Unsafe file names still cancel the transfer.

## Advanced

![CrocApp Settings on macOS showing the Advanced tab with the proxy fields](../../screenshots/mac/settings-advanced-light.webp#gh-light-mode-only)![CrocApp Settings on macOS showing the Advanced tab with the proxy fields](../../screenshots/mac/settings-advanced-dark.webp#gh-dark-mode-only)

**Advanced** holds croc options most people never need. Every default is croc's own. Each field checks what you type and shows a message under it. If a saved value is not usable, a transfer fails with "An Advanced setting can't be used" instead of falling back to something else. **Reset to Defaults** at the bottom puts every setting back after a confirmation, and removes the saved proxies.

| Setting | Default | Affects | Does the other device have to match? |
|---|---|---|---|
| SOCKS5 Proxy | None | This device | No |
| HTTP Proxy | None | This device | No |
| Multicast Address (Mac only) | `239.255.255.250` | Both devices | Yes, to find each other on the local network |
| Sender IP | None | Receiving | No, but it must be the sender's address and port |
| Send Speed Limit | No limit | Sending | No |

**Network.**

- **SOCKS5 Proxy** and **HTTP Proxy** send this device's connections through a proxy. Enter `host:port` or an address such as `socks5://user:password@host:1080` (SOCKS5 takes `socks5://` or `socks5h://`, HTTP takes `http://` or `https://`). If both are set, SOCKS5 wins. Connections to your local network skip the proxy. They also apply to [Send as link](send-as-link.md). A proxy address can contain a password, so CrocApp keeps both in the Keychain, never in the settings file or an error message.
- **Multicast Address** is the group croc uses to find devices on the local network. It must be an IPv4 multicast address, `224.0.0.0` to `239.255.255.255`.
- **Sender IP** is for receiving. Enter the sender's address and port, such as `192.168.1.20:9009` or `[fe80::1]:9009`, and CrocApp connects straight to it, skipping relays and discovery. A CrocApp sender listens on port 9009 and the four ports after it. If something else on the sender's device uses 9009, croc takes the next free ports, so the port you need can be higher. If nothing answers, the receive fails at once. It does not fall back to a relay.

**Performance.**

- **Send Speed Limit** caps this device's sending speed in bytes per second: digits with an optional `k`, `m` or `g`, such as `500k` or `2m`.

## The trust badge

Waiting, confirming and transferring screens, and the home screen, show **End-to-end encrypted** with one line naming the route you configured:

- "Local network only: nothing leaves your network"
- "Via custom relay `<address>`, which sees only encrypted data"
- "Via the public croc relay, which sees only encrypted data"
- "Straight to the sender, no relay in between" (a receive with **Sender IP** set)

The badge reads your settings. It does not report which path carried the data. A transfer that croc moved over the local network can still say "Via the public croc relay". The statement that the server sees only encrypted data holds on every path.

## About

**About** shows the app version and links to the privacy policy and support page.

## What is stored

Settings are stored on the device. The relay password, the two proxies and Send as link receipts are in the Keychain. If the relay password or a proxy cannot be saved there, its field shows "Couldn't save to the Keychain": the new value works until you quit CrocApp, so edit the field to try again. Nothing in Settings, no transfer content and no code phrase is sent anywhere except as part of a transfer you start. See [Uninstall and data](../uninstall.md) for where it all lives.
