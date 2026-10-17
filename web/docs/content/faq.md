---
sidebar_position: 7
title: FAQ
description: Frequently asked questions about CrocApp, cost, security, accounts, and platform support.
---

# FAQ

## Where do I get it, and how does it update?

CrocApp 1.0 comes through the App Store, the Mac App Store and as a notarized disk image for Mac, all arriving at launch. The listings are linked from [crocapp.dev](https://crocapp.dev) once they are live. App Store builds update through the App Store. The disk image updates itself: choose **Check for Updates…** in the CrocApp menu. See [Install](getting-started/install.md).

## What does it cost?

Nothing. No purchase, no subscription, no advertising and no analytics. CrocApp is free, MIT-licensed, and stays that way. Monetization is limited to optional sponsorship.

## What does CrocApp guarantee?

Transfers are end-to-end encrypted, the code phrase authenticates both devices, and the relay only ever sees ciphertext. CrocApp has not had a formal third-party security audit. The code is open if you want to look.

## Do I need an account?

No. CrocApp has no accounts, analytics, ads or tracking.

## Does my file go through the relay?

Usually, when the two devices cannot reach each other directly. The relay forwards the encrypted transfer and only ever sees ciphertext. You can point CrocApp at your own relay instead.

## What if both devices are on the same Wi-Fi?

Then the two devices connect over the local network and the data stays on that network. CrocApp tries the local network and the relay at once and uses whichever connects first.

## Can large files go directly between devices?

Yes, with the default **Automatic** connection setting. A send of 128 MiB or more also tries a direct connection, set up through `tailcat.dev`, and whichever path connects first carries the transfer. It is end-to-end encrypted either way. Choose **Relay Only** under [power options](guide/power-options.md) to keep your sends on croc's relays and away from those servers. A receive follows the sender's choice.

## Can the other device use a browser instead of the app?

Yes. The QR code on the sender's screen and the **Share Link** button open a page at `crocapp.dev/r/` that offers CrocApp and **Receive in Your Browser**. The browser option is croc's own web app at getcroc.com, not CrocApp, and it only works when the sender uses the default relays. It also depends on getcroc.com to serve the code that decrypts the file; see [Security and privacy](security-and-privacy.md#receiving-in-a-browser).

## How is this different from AirDrop?

AirDrop needs two Apple devices close to each other. CrocApp works between any two devices running croc or CrocApp, on any network, including from a Mac to a Linux machine on the other side of the world.

## Does it work with the croc command line tool?

Yes, in both directions. CrocApp embeds croc v11.5.4 as a library, so it speaks the same protocol. Run `croc send` on a laptop and receive in the app on a phone, or the reverse. The other device needs croc 11 or newer; croc 10 cannot complete a transfer with it.

## Can I run my own relay?

Yes. Point CrocApp at any croc relay, with a relay password and an IPv6 address if you want them. Running `croc relay` on a machine you control is enough.

## Why iOS 26 and macOS 26 only?

CrocApp is a greenfield app with no existing users. Supporting older releases would mean availability checks everywhere and giving up current SwiftUI APIs and the Liquid Glass design language. The minimum is `26.0`, and every later version works. The floor is pinned at `26.0` rather than at a later minor so nobody running 26.0 through 26.4 is locked out.

## Is it free? Will it ever have a paid tier?

Free, MIT-licensed, and it stays that way. Monetization is limited to optional [sponsorship](https://github.com/sponsors/bakirgdev).

## Will there be a Windows, Linux or Android version?

No. CrocApp is Apple-platform only by design. Use the [croc CLI](https://github.com/schollz/croc) elsewhere: it works with this app.
