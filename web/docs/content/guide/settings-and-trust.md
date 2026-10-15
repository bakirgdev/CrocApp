---
sidebar_position: 6
title: Settings and Trust
description: Where CrocApp's settings live, why you might run your own relay, and what the trust badge tells you.
---

# Settings and trust

![CrocApp Settings on macOS showing the receive folder and the relay address fields](/img/screenshots/mac-settings-light.png#gh-light-mode-only)![CrocApp Settings on macOS showing the receive folder and the relay address fields](/img/screenshots/mac-settings-dark.png#gh-dark-mode-only)

## Where settings live

On macOS, settings are in the Settings scene (⌘,), with a **Receive** section (destination folder, plus a **Show in Finder** button) above the [power options](power-options.md). On iOS, the settings screen (reached from the home toolbar) holds the power options; the receive destination folder is changed from the **Receive** screen itself instead.

Settings persist locally on the device. There is no sync and no account to sign into.

## Custom relay

By default, CrocApp uses croc's public relay. You can point it at a relay you run yourself instead, under the [Relay power option](power-options.md). Reasons to run your own:

- You want transfers to route through infrastructure you control rather than the shared public relay.
- You're operating on a network where you'd rather not depend on an external service.

Running `croc relay` on a machine you control is enough; then enter its address (and password, if you set one) in CrocApp's relay fields.

## Send as link server

The **Send as link** section holds the **Server** field for [stored transfers](stored-transfers.md#the-server-setting). It defaults to `https://getcroc.com`, which is run by croc's author, not by CrocApp, and it accepts an `https` address (or `http` on localhost) with nothing after the host. A **Reset** button restores the default. The relay and Connection settings do not apply to a stored upload.

## Connection

The **Connection** picker under the [power options](power-options.md) chooses how a send carries large files. **Automatic** (the default) can also use a direct path between the devices for a send of 128 MB or more, set up through `tailcat.dev`. A send set to **Relay only** never contacts those servers; a receive follows the sender's choice. The data is end-to-end encrypted either way.

## Advanced

Proxies, ports, the encryption curve and similar options are under **Advanced**; see [Advanced settings](advanced-settings.md). The two proxy addresses can contain a password, so they are kept in the Keychain.

## Menu bar (macOS)

The **Menu bar** section of Settings has **Show in menu bar** and **Open at login**; see [Menu bar](menu-bar.md#settings).

## The trust badge

During a waiting, confirming, or transferring screen, CrocApp shows a trust badge: an **End-to-end encrypted** label plus a line describing the relay path actually in use for that transfer:

- "Local network only — nothing leaves your network"
- "Via custom relay `<address>` — it sees only encrypted data"
- "Via the public croc relay — it sees only encrypted data"
- "Straight to the sender, no relay in between" (a receive with a [sender IP](advanced-settings.md#network) set)

This is captured at the moment the transfer starts, so changing settings mid-transfer can't make the badge say something that isn't true for the transfer in progress.

## What is stored

Settings (relay address, relay password, connection, send-as-link server, local-only, compression, zip, exclude patterns, gitignore, both-sides confirm, auto-accept, and the Advanced options) are stored locally on the device. The relay password and the two proxy addresses are in the Keychain. No settings, transfer content, or code phrases are sent anywhere except as part of an actual transfer you initiate.
