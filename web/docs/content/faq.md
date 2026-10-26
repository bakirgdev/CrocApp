---
sidebar_position: 2
title: FAQ
description: Short answers about CrocApp's cost, accounts, relays, browsers, platforms and the croc command line, plus a glossary.
---

# FAQ

## What does it cost?

Nothing. CrocApp is free and MIT-licensed, with no purchase, subscription, ads or analytics. Optional [sponsorship](https://github.com/sponsors/bakirgdev) is the only way to support it with money.

## Do I need an account?

No. CrocApp has no accounts, analytics, ads or tracking.

## Where do I get it, and how does it update?

See [Requirements and install](getting-started/install.md).

## Does my file go through a relay?

CrocApp tries the local network and the relay at once and uses whichever connects first. When the two devices connect over the local network, the data stays on that network. Otherwise the relay forwards the encrypted transfer and only ever sees ciphertext. You can point CrocApp at your own relay. See [Security and privacy](security-and-privacy.md) and [Settings](guide/settings.md#relay).

## Can the other person use a browser instead of the app?

Yes, through the QR code or **Share Link**, which open a page at `crocapp.dev/r/` with a **Receive in Your Browser** option. That option is croc's own web app at getcroc.com, which sees your code and serves the script that decrypts the file. See [Receiving in a browser](security-and-privacy.md#receiving-in-a-browser).

## How is this different from AirDrop?

AirDrop needs two Apple devices close to each other. CrocApp works between any two devices running croc or CrocApp, on any network, including from a Mac to a Linux machine on the other side of the world.

## Does it work with the croc command line?

Yes, in both directions. Send with `croc send` on a laptop and receive in the app, or the reverse. The other device needs croc 11 or newer. See [croc CLI interoperability](reference/croc-cli-interop.md).

## Why iOS 26 and macOS 26 only?

CrocApp uses the current SwiftUI and the Liquid Glass design, which need the 26 releases. The minimum is `26.0`, so every later version works.

## Will there be a Windows, Linux or Android version?

No. CrocApp is for Apple platforms only. Use the [croc command line](https://github.com/schollz/croc) elsewhere: it works with this app. The [other croc apps](contribute.md#inspirations) include an Android client.

## Glossary

| Term | Means |
|---|---|
| Code phrase | The `word-word-word` text both devices use to find each other and to prove they hold the same secret. See [Code phrases and links](guide/code-phrases.md). |
| Relay | A server both devices connect to when they cannot connect directly. It only ever sees ciphertext. |
| Direct connection | A transfer between the two devices with no relay in between, over the local network. |
| Local network | The Wi-Fi or Ethernet network both devices share. CrocApp finds devices there without the relay, though some networks block it. |
| Link | A `https://crocapp.dev/r/#<code>` address that carries a code phrase after the `#`. Opening one fills in **Receive** and never connects by itself. |
| Send as link | Sending encrypted files to a link server so the other device can receive later. See [Send as link](guide/send-as-link.md). |
| Link server | The server that holds the files of a Send as link transfer until the link ends. The default is `https://getcroc.com`. |
| Trust badge | The label that says a transfer is end-to-end encrypted and names the route you configured. See [Settings](guide/settings.md#the-trust-badge). |
| History | CrocApp's list of past transfers, kept only on your device. See [History](guide/history.md). |
