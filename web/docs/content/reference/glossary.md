---
sidebar_position: 3
title: Glossary
description: User-facing terms used throughout the CrocApp documentation.
---

# Glossary

| Term | Means |
|---|---|
| Code phrase / secret | The `NNNN-word-word-word` string both sides use to find each other and derive the session key. Custom codes are at least 6 characters. |
| PAKE | Password-Authenticated Key Exchange. Turns the weak code phrase into a strong encryption key without the relay ever learning it. |
| Relay | The server both sides connect to when a direct local-network path isn't available. Sees ciphertext only, never the key. |
| Room | The rendezvous channel on the relay, derived from the first 4 characters of the code phrase. Two codes sharing those characters can collide into the same room. |
| Curve | The elliptic curve PAKE runs over. CrocApp uses croc's default. |
| Hash algorithm | The integrity check used on transferred files. |
| LAN peer discovery | The mechanism that lets same-network transfers skip the relay entirely; not guaranteed to work on every network. |
| Local-only | A setting that forces a transfer to stay on the local network, refusing the relay if a direct path isn't available. |
| Compression | File data is compressed by default in transit; it can be turned off. |
| Trust badge | The on-screen indicator showing that a transfer is end-to-end encrypted and which relay path it's using. |
| Transfer history | CrocApp's local, on-device-only log of past transfers. |

For the full contributor and internals glossary (croc protocol internals, the Go/gomobile bridge, app architecture, and repo conventions), see [`docs/GLOSSARY.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/GLOSSARY.md) on GitHub.
