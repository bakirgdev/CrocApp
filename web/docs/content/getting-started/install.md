---
sidebar_position: 1
title: Requirements and install
description: "Which devices CrocApp supports, where to get it, how updates work and how to avoid mixing the App Store and disk image builds on one Mac."
---

# Requirements and install

CrocApp needs **iOS 26**, **iPadOS 26** or **macOS 26** (`26.0` or any later version). The Mac app runs on Apple silicon only. There is no Intel build, no Windows, Linux or Android client, and no package-manager channel such as Homebrew.

The other device needs **croc 11 or newer**, whether it runs CrocApp or the croc command line. croc 10 cannot complete a transfer with CrocApp. See [croc CLI interoperability](../reference/croc-cli-interop.md).

## Where to get it

The first release, v1.1.0, is coming soon: a disk image for Mac on GitHub Releases, then the App Store and Mac App Store versions. [crocapp.dev](https://crocapp.dev) links them once they are live.

| Channel | For | Where |
|---|---|---|
| Disk image | Mac | `CrocApp-<version>-arm64.dmg` on [GitHub Releases](https://github.com/bakirgdev/CrocApp/releases/latest) |
| App Store | iPhone and iPad | Coming |
| Mac App Store | Mac | Coming |

### Disk image

Open the disk image and drag **CrocApp** onto **Applications**. Apple notarizes every release, so macOS shows only its standard first-launch confirmation.

To check a download before you run it, see [Verify a release](verify-downloads.md).

:::warning
Use one channel per Mac. The App Store and disk image builds are both named `CrocApp.app`, so dragging the disk image copy into **Applications** replaces the App Store copy. Their data is kept apart, but one app takes the other's place.
:::

## Updates

- **App Store builds** update through the App Store.
- **The disk image build** updates itself. Choose **Check for Updates…** in the CrocApp menu. From the second launch on, it asks whether it may check automatically. It installs an update only when the update's signature matches the key built into the app. The check reads a feed on github.com and sends no system profile.

The App Store builds contain no updater, so they never contact github.com to look for updates. What changed in each release is on [GitHub Releases](https://github.com/bakirgdev/CrocApp/releases).

To build from source, see the [contributor docs](../contribute.md).
