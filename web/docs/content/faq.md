---
sidebar_position: 7
title: FAQ
description: Frequently asked questions about CrocApp, cost, security, accounts, and platform support.
---

# FAQ

## Where do I get it, and how does it update?

CrocApp 1.0 comes through the iOS and Mac App Stores and as a notarized disk image for Mac, all arriving at launch. The listings are linked from [crocapp.dev](https://crocapp.dev) once they are live. App Store builds update through the App Store. The disk image updates itself: choose **Check for Updates…** in the CrocApp menu. See [Install](getting-started/install.md).

## What does it cost?

Nothing. No purchase, no subscription, no advertising, and no analytics. CrocApp is free, MIT-licensed, and stays that way. Monetization is limited to optional sponsorship.

## Is it actually secure?

Transfers are end-to-end encrypted, the code phrase authenticates both sides, and the relay only ever sees ciphertext. That is the whole claim, and it's croc's design rather than anything CrocApp adds. There has been no formal third-party audit of croc, and CrocApp does not claim one. The code on both sides is open if you want to look.

## Do I need an account?

No. There is nothing to sign up for and no identity attached to a transfer.

## Does my file go through a server?

Usually yes — a relay, which forwards traffic between two devices that can't reach each other directly. It sees ciphertext and nothing else, and it does not store your file. You can point CrocApp at your own relay instead.

## What if we're on the same Wi-Fi?

Then the transfer goes straight between the two devices and skips the relay entirely. CrocApp tries both paths at once and uses whichever connects first.

## Can large files go directly between devices?

Yes, with the default **Automatic** connection setting. A send of 128 MB or more also tries a direct path, set up through `tailcat.dev`, and whichever path connects first carries the transfer. It is end-to-end encrypted either way. Choose **Relay only** under [power options](guide/power-options.md) to keep your sends on croc's relays and away from those servers. A receive follows the sender's choice.

## Can the receiver use a browser instead of the app?

Yes. The QR code on the sender's screen and the **Share Link** button open a page at `crocapp.dev/r/` that offers CrocApp, the downloads, and **Receive in your browser**. The browser option is croc's own web app at getcroc.com, not CrocApp, and it only works when the sender uses the default relays. It also trusts getcroc.com to serve code that decrypts honestly; see [Security and privacy](security-and-privacy.md#receiving-in-a-browser).

## How is this different from AirDrop?

AirDrop needs two Apple devices in physical proximity. CrocApp works between any two devices running croc or CrocApp, on any network, at any distance, including from a Mac to a Linux server across the world.

## Does it work with the croc command line tool?

Yes, in both directions. CrocApp embeds croc v11.5.4 as a library, so it speaks the same protocol. `croc send` on a laptop, receive in the app on a phone, and the reverse. The other side needs croc 11 or newer; croc 10 cannot complete a transfer with it.

## Can I run my own relay?

Yes. Point CrocApp at any croc relay, with a password and IPv6 if you want them. Running `croc relay` on a machine you control is enough.

## Why iOS 26 and macOS 26 only?

CrocApp is a greenfield app with no existing users. Supporting older releases would mean availability checks everywhere and giving up current SwiftUI APIs and the Liquid Glass design language. The minimum is `26.0`, and every later version works. The floor is pinned at `26.0` rather than at a later minor precisely so nobody running 26.0 through 26.4 is locked out.

## Is it free? Will it ever have a paid tier?

Free, MIT-licensed, and it stays that way. Monetization is limited to optional [sponsorship](https://github.com/sponsors/bakirgdev).

## Will there be a Windows, Linux, or Android version?

No. CrocApp is Apple-platform only by design. Use the [croc CLI](https://github.com/schollz/croc) elsewhere — it interoperates with this app.
