---
sidebar_position: 3
title: Code phrases
description: What a CrocApp code phrase is, how the two devices use it, and how to share one.
---

# Code phrases

A code phrase looks like `cape-junky-widow`: three random words. It is generated fresh for every transfer, unless you set a custom one on the [Send screen](sending.md).

## One phrase finds the other device and authenticates it

Entering the code on the other device is all that is needed. It is how the two devices find each other, and it authenticates both of them. There is nothing else to configure for a normal transfer.

## How the code phrase is used

Both devices run **PAKE** (password-authenticated key exchange) with the code phrase, so the code phrase authenticates both devices:

- A wrong code fails immediately, before any file data moves.
- The transfer is end-to-end encrypted.

## One transfer, then it expires

Every transfer uses a fresh code phrase. Whoever has the code can join that transfer, and the code expires with it. It is not reusable for a later transfer.

## Sharing it: QR code and paste

CrocApp shows the code as text and as a QR code, and a **Share Link** button next to it. The QR code and the shared link are the same web link, `https://crocapp.dev/r/#<code>`. A phone camera that scans it opens CrocApp if it is installed, or a page that explains the options if it is not (see [Receiving a link](#receiving-a-link)).

To bring a code into the **Receive** field, you have two explicit options: use the **Paste** button, or (iOS) tap **Scan QR Code**. CrocApp does not silently read the clipboard; pasting is always something you trigger yourself.

## Accepted forms

Whatever you paste, scan, or open, CrocApp reads the code out of it. These forms are accepted:

- a bare code, as long as it is at least 6 characters with no whitespace
- `https://crocapp.dev/r/#<code>`, the link CrocApp itself shares
- `crocapp://receive?code=<code>`
- `https://getcroc.com/?code=<code>`, the link the croc CLI's `--qrcode` shows
- `croc://<code>`, the form in the QR codes of earlier CrocApp builds, which still scan

## Receiving a link

Opening a link, or pasting or scanning one, takes you to **Receive** with the code filled in. Nothing connects until you tap **Receive**. If a transfer is already running, the link is kept and CrocApp does not move you away from it.

The page at `crocapp.dev/r/` reads the code from the part of the address after the `#`. Browsers never send that part to a server, and the page makes no network request. From the page you can open CrocApp, get it from the App Store or as a disk image, or receive in your browser.

**Receive in Your Browser** opens `https://getcroc.com/?code=<code>`, which is croc's own web app, not part of CrocApp. The code is in the query string there, so getcroc.com's server receives it. That path depends on getcroc.com fully, because getcroc.com serves the JavaScript that decrypts the file. It also needs the default relays, so the sender's waiting screen shows a note when a custom relay or **Local Network Only** is active. To avoid that dependency, receive in CrocApp or the croc CLI.

## Custom codes

A custom code must be at least 6 characters. Set it in the **Custom Code** field on the Send screen so you can share it through a channel you already trust, such as a phone call, instead of relying on the generated one.

## Sharing a code safely

Share it over a channel you trust: speak it, send it through a chat you already trust, or let the other device scan the QR code directly off your screen. A shared link carries the code too, so send it only over a channel you would trust with the code itself. Anyone who obtains the code before the transfer completes can join the transfer.
