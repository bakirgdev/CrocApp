---
sidebar_position: 5
title: Settings and Trust
description: Where CrocApp's settings live, why you might run your own relay, and what the trust badge tells you.
---

# Settings and trust

## Where settings live

On macOS, settings are in the Settings scene (⌘,), with a **Receive** section (destination folder, plus a **Show in Finder** button) above the [power options](power-options.md). On iOS, the settings screen (reached from the home toolbar) holds the power options; the receive destination folder is changed from the **Receive** screen itself instead.

Settings persist locally on the device. There is no sync and no account to sign into.

## Custom relay

By default, CrocApp uses croc's public relay. You can point it at a relay you run yourself instead, under the [Relay power option](power-options.md). Reasons to run your own:

- You want transfers to route through infrastructure you control rather than the shared public relay.
- You're operating on a network where you'd rather not depend on an external service.

Running `croc relay` on a machine you control is enough; then enter its address (and password, if you set one) in CrocApp's relay fields.

## The trust badge

During a waiting, confirming, or transferring screen, CrocApp shows a trust badge: an **End-to-end encrypted** label plus a line describing the relay path actually in use for that transfer:

- "Local network only — nothing leaves your network"
- "Via custom relay `<address>` — it sees only encrypted data"
- "Via the public croc relay — it sees only encrypted data"

This is captured at the moment the transfer starts, so changing settings mid-transfer can't make the badge say something that isn't true for the transfer in progress.

## What is stored

Settings (relay address, relay password, local-only, compression, zip, exclude patterns, gitignore, both-sides confirm, auto-accept) are stored locally on the device. No settings, transfer content, or code phrases are sent anywhere except as part of an actual transfer you initiate.
