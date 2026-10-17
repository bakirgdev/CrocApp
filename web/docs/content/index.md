---
slug: /
sidebar_position: 1
title: CrocApp documentation
description: Send files, folders and text to another device with a short code phrase. Free, open source and end-to-end encrypted.
---

# CrocApp documentation

![CrocApp's first-run welcome screen on iOS, explaining the code phrase in three lines](/img/screenshots/iphone/onboarding-light.png#gh-light-mode-only)![CrocApp's first-run welcome screen on iOS, explaining the code phrase in three lines](/img/screenshots/iphone/onboarding-dark.png#gh-dark-mode-only)

CrocApp sends files, folders and text to another device with a short code phrase like `cape-junky-widow`. Transfers are end-to-end encrypted. There is no account, and the two devices do not need to share a network.

It is a graphical front end for [croc](https://github.com/schollz/croc), the command-line file-transfer tool by Zack Scholl. CrocApp embeds croc's Go library rather than shelling out to the binary, so a code phrase from the croc CLI works in the app, and a code phrase from the app works in the CLI.

:::note
CrocApp is unofficial and unaffiliated. Nothing here implies endorsement by croc's author.
:::

## How it works, in short

The sender picks files, a folder or a snippet of text. CrocApp generates a code phrase, which can be spoken, messaged or shown as a QR code. The other device enters the phrase, sees the file list and accepts. The code phrase authenticates both devices (PAKE, password-authenticated key exchange), and the transfer is end-to-end encrypted. The relay only ever sees ciphertext. When the two devices connect over the local network, the data stays on that network.

## Platform requirements

CrocApp requires **iOS 26**, **iPadOS 26**, or **macOS 26**, meaning `26.0` or any later version. It is Apple-platform only: there is no Windows, Linux or Android client.

:::note
The other device needs **croc 11 or newer**, whether it runs CrocApp or the croc CLI. croc 10 cannot complete a transfer with CrocApp.
:::

CrocApp 1.0 comes as an app for iPhone and iPad, an app on the Mac App Store and a notarized disk image for Mac. The store listings and the 1.0 disk image arrive at launch. See [Install](getting-started/install.md) for where to get each one.

## Where to go next

- [Install](getting-started/install.md): the three channels, updates, and how to build from source
- [Your first transfer](getting-started/first-transfer.md): a walkthrough of one send and one receive
- [Sending files](guide/sending.md), [Receiving files](guide/receiving.md), [Code phrases](guide/code-phrases.md), [Send as link](guide/stored-transfers.md)
- [Power options](guide/power-options.md), [Advanced settings](guide/advanced-settings.md), [Settings and trust](guide/settings-and-trust.md), [History](guide/history.md)
- [Menu bar](guide/menu-bar.md) and [Shortcuts](guide/shortcuts.md)
- [croc CLI interoperability](reference/croc-cli-interop.md) and the [feature matrix](reference/feature-matrix.md)
- [Security and privacy](security-and-privacy.md), [Troubleshooting](troubleshooting.md), [FAQ](faq.md)
- [Contribute](contribute.md)
