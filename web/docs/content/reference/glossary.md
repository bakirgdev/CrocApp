---
sidebar_position: 3
title: Glossary
description: User-facing terms used throughout the CrocApp documentation.
---

# Glossary

| Term | Means |
|---|---|
| Code phrase | The `word-word-word` string both devices use to find each other and to authenticate. Custom codes are at least 6 characters. |
| PAKE | Password-authenticated key exchange. The protocol that lets the code phrase authenticate both devices. |
| Link | A `https://crocapp.dev/r/#<code>` address that carries a code phrase after the `#`. The QR code on the sender's screen and **Share Link** are this link. Opening one fills in **Receive** and never connects by itself. |
| Relay | The machine both devices connect to when a direct local-network path is not available. It only ever sees ciphertext. |
| Room | The rendezvous channel on the relay, derived from the first word of the code phrase. Two codes sharing that word can collide into the same room. |
| Curve | The elliptic curve PAKE runs over. CrocApp uses croc's default, P-256; the receiving device's choice wins and the sender adopts it, so the devices never have to match (see [Advanced settings](../guide/advanced-settings.md)). |
| Sender IP | The sender's address and port, entered on the receiving device to connect straight to it and skip relays. See [Advanced settings](../guide/advanced-settings.md#network). |
| Hash algorithm | The integrity check used on transferred files. |
| Local network discovery | How two devices on the same network find each other without the relay; not guaranteed to work on every network. |
| Connection | The setting that chooses how a send carries large files: Automatic (default) or Relay only. Only the sender's choice applies; a receive follows it. |
| Tailcat | The direct connection that Automatic can use for a send of 128 MiB or more. It is set up through `tailcat.dev` and falls back to its own relays when the devices cannot reach each other. Still end-to-end encrypted. |
| Local network only | A setting that keeps a transfer on the local network and refuses the relay if a direct path is not available. |
| Link server | The server that holds the encrypted files of a [Send as link](../guide/stored-transfers.md) transfer until the link ends. By default `https://getcroc.com`, run by croc's author. |
| Compression | File data is compressed by default in transit; it can be turned off. |
| Menu bar quick send | The CrocApp icon in the Mac menu bar. Its window sends files or clipboard text and shows the code and progress. See [Menu bar](../guide/menu-bar.md). |
| Shortcuts action | One of three CrocApp actions (Send Files, Send Text, Receive) for the Shortcuts app, Siri and Spotlight. See [Shortcuts](../guide/shortcuts.md). |
| Trust badge | The on-screen indicator showing that a transfer is end-to-end encrypted and which relay path it is using. |
| Transfer history | CrocApp's local, on-device-only log of past transfers. |

For the full contributor and internals glossary (croc protocol internals, the Go/gomobile bridge, app architecture, and repo conventions), see [`docs/GLOSSARY.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/GLOSSARY.md) on GitHub.
