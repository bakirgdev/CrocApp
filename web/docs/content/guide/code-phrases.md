---
sidebar_position: 3
title: Code phrases and links
description: What a CrocApp code phrase is, how to share one by voice, QR code or link, and what to know about custom codes.
---

# Code phrases and links

A code phrase looks like `cape-junky-widow`: three random words, new for every transfer. Entering it on the other device is all that is needed. It finds the other device and proves both sides know the same phrase, so a wrong code fails at once. [Security and privacy](../security-and-privacy.md#how-a-transfer-is-protected) explains why.

Each code works for one transfer and expires with it. Anyone who has the code before the transfer completes can join it, so share it only over a channel you trust.

## Share a code

CrocApp shows the code as text and as a QR code, with **Copy Code** and **Share Link** beside it. The QR code and the link are the same address, `https://crocapp.dev/r/#<code>`. A phone camera that scans it opens CrocApp, or a page that explains the options if the app is not installed.

On the other device, bring the code into **Receive** by typing it, tapping **Paste**, or on iOS tapping **Scan QR Code**. CrocApp never reads the clipboard on its own.

## Accepted forms

Whatever you paste, scan or open, CrocApp reads the code out of it:

- a bare code of at least 6 characters with no spaces
- `https://crocapp.dev/r/#<code>`, the link CrocApp shares
- `crocapp://receive?code=<code>`
- `https://getcroc.com/?code=<code>`, the link the croc command line's `--qrcode` shows
- `croc://<code>`, from QR codes in earlier CrocApp builds

## Receiving a link

Opening, pasting or scanning a link takes you to **Receive** with the code filled in. Nothing connects until you tap **Receive**. If a transfer is already running, the link is kept and CrocApp stays on the current transfer.

The page at `crocapp.dev/r/` reads the code from the part of the address after the `#`. Browsers never send that part to a server, and the page makes no network request. It offers to open CrocApp, get it, or receive in a browser.

**Receive in Your Browser** goes to croc's own web app, not part of CrocApp. See [Receiving in a browser](../security-and-privacy.md#receiving-in-a-browser) for what that means for your code.

## Custom codes

Type your own into **Custom code (optional)** on the Send screen to share it by a channel you already trust, such as a phone call. Three things to know:

- It must be at least 6 characters. A short, guessable code is easier for someone else to join.
- Codes that start with the same word can land in the same relay room. Generated codes rarely collide: two share a first word about once in 1296.
- Start the sender before the receiver. A receiver that joins first can fail with a generic error. See [Troubleshooting](../troubleshooting.md#the-receiver-started-first).
