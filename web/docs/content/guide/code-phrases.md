---
sidebar_position: 3
title: Code Phrases
description: What a CrocApp code phrase is, why it doubles as address and password, and the safe ways to share one.
---

# Code phrases

A code phrase looks like `cape-junky-widow`: three random words. It is generated fresh for every transfer, unless you set a custom one on the [Send screen](sending.md).

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

CrocApp shows the code as text and as a QR code (F6), and a **Share Link** button next to it. The QR code and the shared link are the same web link, `https://crocapp.dev/r/#<code>`. A phone camera that scans it opens CrocApp if it is installed, or a page that explains the options if it is not (see [Receiving a link](#receiving-a-link)).

To bring a code into the **Receive** field, you have two explicit options: use the **Paste** button, or (iOS) tap **Scan QR Code**. CrocApp does not silently read the clipboard; pasting is always something you trigger yourself.

## Accepted forms

Whatever you paste, scan, or open, CrocApp reads the code out of it. These forms are accepted:

- a bare code, as long as it is at least 6 characters with no whitespace
- `https://crocapp.dev/r/#<code>`, the link CrocApp itself shares
- `crocapp://receive?code=<code>`
- `https://getcroc.com/?code=<code>`, the link the croc CLI's `--qrcode` shows
- `croc://<code>`, the form in the QR codes of CrocApp 0.9.9, which still scan

## Receiving a link

Opening a link, or pasting or scanning one, takes you to **Receive** with the code filled in. Nothing connects until you tap **Receive**. If a transfer is already running, the link is kept and CrocApp does not move you away from it.

The page at `crocapp.dev/r/` reads the code from the part of the address after the `#`. Browsers never send that part to a server, and the page makes no network request. From the page you can open CrocApp, get it from the App Store or as a disk image, or receive in your browser.

**Receive in your browser** opens `https://getcroc.com/?code=<code>`, which is croc's own web app, not part of CrocApp. That path trusts getcroc.com fully, because getcroc.com serves the JavaScript that decrypts the file. It also needs the default relays, so the sender's waiting screen shows a note when a custom relay or Local network only is active. For the strongest guarantee, receive in CrocApp or the croc CLI.

## Custom codes

A custom code must be at least 6 characters. Set it in the **Custom code** field on the Send screen so you can share it through a channel you already trust (a phone call, an existing encrypted chat) instead of relying on the generated one.

## Sharing a code safely

Share it over a channel you trust, the same way you'd share a one-time passcode: speak it, send it through a chat you already trust, or let the receiver scan the QR code directly off your screen. A shared link carries the code too, so send it only over a channel you would trust with the code itself. Because the code is both address and password, anyone who obtains it before the transfer completes can join it.
