---
sidebar_position: 3
title: Security and privacy
description: What CrocApp claims about security, how a transfer is protected, what each server can see, and how to report a vulnerability.
---

# Security and privacy

## What CrocApp claims

These six statements are the entire claim:

1. Transfers are end-to-end encrypted.
2. The code phrase authenticates both devices (PAKE).
3. The relay only ever sees ciphertext.
4. Send as link: files are encrypted on your device before they reach the link server, and the key travels in the link's `#` fragment, which browsers never send to a server.
5. When the two devices connect over the local network, the data stays on that network.
6. CrocApp has no accounts, analytics, ads or tracking, and history stays on the device.

:::warning
CrocApp has **not had a formal third-party security audit**. Do not treat it as audited or certified.
:::

## How a transfer is protected

Both devices run PAKE (password-authenticated key exchange) with the code phrase. That proves both sides know the same phrase, and turns it into a strong encryption key. The phrase itself never crosses the network, and a wrong code fails at once. Files are encrypted on your device and decrypted only on the other one.

CrocApp tries the local network and the relay at once, and the faster one carries the transfer. When the two devices cannot connect directly, a relay forwards the encrypted stream and sees only ciphertext. By default that is one of croc's public relays. You can [run your own](guide/settings.md#relay).

Every transfer uses a fresh code. Whoever has it before the transfer completes can join, so share it over a channel you trust. A `crocapp.dev/r/#<code>` link keeps the code after the `#`, which browsers never send to a server. The page makes no network request and sets a `no-referrer` policy. Anyone who sees the link still has the code.

You stay in control: a receive shows the file list and waits for you to accept or decline, unless you turn on **Auto-Accept Transfers**.

## What each server sees

| Server | When | What it can see |
|---|---|---|
| croc public relays (`1.getcroc.com` to `4.getcroc.com`) | Every transfer with a code, unless you use your own relay or **Local Network Only** | Both devices' IP addresses, timing, amount of data, and a room name hashed from the code's first word. The data is ciphertext |
| Link server (`getcroc.com` by default) | **Send as Link**, and opening or revoking a link | The encrypted files and their size, the lifetime and download count you chose, and your IP address |
| `github.com` | Update checks in the Mac disk image build only | The usual details of a web request. The request carries no system profile |

An operator decides what its own server logs, so this is what each can see by design. The [privacy policy](https://crocapp.dev/privacy/) has the full list, including servers you choose yourself.

## Send as link

Files are encrypted on your device before they reach the link server. The key travels in the link's `#` fragment, which browsers never send to a server. The default link server, `https://getcroc.com`, is run by croc's author, not by CrocApp. Anyone with the whole link can decrypt the files, and you can revoke the link from [History](guide/history.md). See [Send as link](guide/send-as-link.md).

## Receiving in a browser

The link page offers **Receive in Your Browser**, which opens `https://getcroc.com/?code=<code>`. That is croc's own web app, not run by CrocApp.

- The code is in the query string, so it reaches the getcroc.com server, along with your IP address.
- getcroc.com serves the JavaScript that decrypts the file, so this path trusts that site fully.
- That site's own pages also load third-party analytics and advertising scripts (Umami and Google AdSense when last checked), which CrocApp does not control.
- It reaches only croc's default relays.

The CrocApp and croc command line paths have none of these dependencies. If that is more than you want to trust, receive in CrocApp.

## Privacy

- CrocApp has no accounts, analytics, ads or tracking.
- [History](guide/history.md) stays on the device and never stores file contents or the full code phrase.
- The Mac disk image checks github.com for updates and installs only updates signed with the key built into the app. The App Store builds contain no updater. See [Verify a release](getting-started/verify-downloads.md).
- The camera is used only to scan a QR code, and nothing is saved.

For where data lives and how to remove it, see [Uninstall and data](uninstall.md).

## Report a vulnerability

Report privately through [GitHub Security Advisories](https://github.com/bakirgdev/CrocApp/security/advisories/new). Never open a public issue, discussion or pull request for a suspected vulnerability.

Useful to include: what an attacker gains and what access they need, steps to reproduce (code phrase flow, relay, platform), the CrocApp and OS versions and device, and whether the upstream `croc` command line behaves the same.

The full policy, scope, and what is out of scope (the transfer protocol itself belongs to croc upstream) is in [`SECURITY.md`](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md).
