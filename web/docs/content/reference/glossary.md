---
sidebar_position: 3
title: Glossary
description: User-facing terms used throughout the CrocApp documentation.
---

# Glossary

| Term | Means |
|---|---|
| Code phrase / secret | The `word-word-word` string both sides use to find each other and derive the session key. Custom codes are at least 6 characters. |
| PAKE | Password-Authenticated Key Exchange. Turns the weak code phrase into a strong encryption key without the relay ever learning it. |
| Link | A `https://crocapp.dev/r/#<code>` address that carries a code phrase after the `#`. The QR code on the sender's screen and **Share Link** are this link. Opening one fills in **Receive** and never connects by itself. |
| Relay | The server both sides connect to when a direct local-network path isn't available. Sees ciphertext only, never the key. |
| Room | The rendezvous channel on the relay, derived from the first word of the code phrase. Two codes sharing that word can collide into the same room. |
| Curve | The elliptic curve PAKE runs over. CrocApp uses croc's default, P-256; the receiver's choice wins and the sender adopts it, so the devices never have to match (see [Advanced settings](../guide/advanced-settings.md)). |
| Sender IP | The sender's address and port, entered on the receiving device to connect straight to it and skip relays. See [Advanced settings](../guide/advanced-settings.md#network). |
| Hash algorithm | The integrity check used on transferred files. |
| LAN peer discovery | The mechanism that lets same-network transfers skip the relay entirely; not guaranteed to work on every network. |
| Connection | The setting that chooses how a send carries large files: Automatic (default) or Relay only. Only the sender's choice applies; a receive follows it. |
| Tailcat | The direct, peer-to-peer path that Automatic can use for a send of 128 MB or more. It is set up through `tailcat.dev` and falls back to its own relays when the devices cannot reach each other. Still end-to-end encrypted. |
| Local-only | A setting that forces a transfer to stay on the local network, refusing the relay if a direct path isn't available. |
| Compression | File data is compressed by default in transit; it can be turned off. |
| Menu bar quick send | The CrocApp icon in the Mac menu bar. Its window sends files or clipboard text and shows the code and progress. See [Menu bar](../guide/menu-bar.md). |
| Shortcuts action | One of three CrocApp actions (Send Files, Send Text, Receive) for the Shortcuts app, Siri and Spotlight. See [Shortcuts](../guide/shortcuts.md). |
| Trust badge | The on-screen indicator showing that a transfer is end-to-end encrypted and which relay path it's using. |
| Transfer history | CrocApp's local, on-device-only log of past transfers. |

For the full contributor and internals glossary (croc protocol internals, the Go/gomobile bridge, app architecture, and repo conventions), see [`docs/GLOSSARY.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/GLOSSARY.md) on GitHub.
