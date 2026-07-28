---
sidebar_position: 3
title: Code Phrases
description: What a CrocApp code phrase is, why it doubles as address and password, and the safe ways to share one.
---

# Code phrases

A code phrase looks like `8412-mirage-cobalt-fresco`: a short PIN followed by a few words. It is generated fresh for every transfer, unless you set a custom one on the [Send screen](sending.md).

## It is both the address and the password

Entering the code on the other device is all that's needed — it is simultaneously how the two devices find each other and the secret that secures the transfer. There is nothing else to configure for a normal transfer.

## How it secures the transfer

Both devices run **PAKE** (password-authenticated key exchange) over the code phrase to turn it into a strong encryption key:

- The code itself never crosses the network in the clear.
- A wrong code fails immediately, before any file data moves.
- Everything is encrypted on the sending device and decrypted only on the receiving one; nothing in between can read it.

## One-time and expiring

Every transfer uses a one-time code phrase. Whoever has the code is treated as the transfer partner for that transfer, and the code expires with it — it is not reusable for a later transfer.

## Sharing it: QR code and paste

CrocApp shows the code as text and as a QR code (F6). The QR payload is `croc://<code>`, so scanning it also works with other tools that understand the same deeplink form.

To bring a code into the **Receive** field, you have two explicit options: use the **Paste** button, or (iOS) tap **Scan QR Code**. CrocApp does not silently read the clipboard; pasting is always something you trigger yourself. Pasted or scanned text can include the `croc://` prefix or be a bare code — both are accepted, as long as what's left is at least 6 characters with no whitespace.

## Custom codes

A custom code must be at least 6 characters. Set it in the **Custom code** field on the Send screen so you can share it through a channel you already trust (a phone call, an existing encrypted chat) instead of relying on the generated one.

## Sharing a code safely

Share it over a channel you trust, the same way you'd share a one-time passcode: speak it, send it through a chat you already trust, or let the receiver scan the QR code directly off your screen. Because the code is both address and password, anyone who obtains it before the transfer completes can join it.
