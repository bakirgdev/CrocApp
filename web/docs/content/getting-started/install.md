---
sidebar_position: 1
title: Install
description: "The three ways to get CrocApp 1.0: the App Store, the Mac App Store and a notarized disk image for Mac, plus how updates work and how to build from source."
---

# Install

CrocApp 1.0 comes through three channels. Pick the one that matches your device. All of them need **iOS 26**, **iPadOS 26** or **macOS 26** (`26.0` or any later version).

| Channel | For | Where |
|---|---|---|
| App Store | iPhone and iPad | The listing is linked from [crocapp.dev](https://crocapp.dev) when it is live |
| Mac App Store | Mac | The listing is linked from [crocapp.dev](https://crocapp.dev) when it is live |
| Disk image | Mac with Apple silicon | `CrocApp-<version>-arm64.dmg` on [GitHub Releases](https://github.com/bakirgdev/CrocApp/releases/latest), from version 1.0.0 |

The store listings arrive at launch, so this page does not link them yet. There is no Intel build and no package-manager channel (Homebrew and the like).

## Disk image

Open the disk image from GitHub Releases and drag **CrocApp** onto **Applications**. Use version 1.0.0 or later: the 0.9.x disk images are not notarized and use croc 10. From 1.0.0 on, the app is signed with a Developer ID certificate, notarized by Apple and stapled, so macOS opens it with the standard first-launch confirmation and nothing else.

To check that a disk image came from this project's release workflow, run:

```bash
gh attestation verify CrocApp-<version>-arm64.dmg --repo bakirgdev/CrocApp \
  --signer-workflow bakirgdev/CrocApp/.github/workflows/release.yml
```

See [Verify a release](../verify-downloads.md) for what the attestation covers and the other checks.

## Updates

- **App Store builds** update through the App Store, like any other app.
- **The disk image build** updates itself with Sparkle. Choose **Check for Updates…** in the CrocApp menu. From the second launch on, Sparkle asks whether it may check automatically. Each update is signed, and the app installs it only when the signature matches the key built into the app. The check reads a feed on github.com and sends no system profile.
- Building from source does not update itself.

The App Store builds contain no updater, so they never contact github.com to look for updates.

## The other device

The device you transfer with needs **croc 11 or newer**, whether it runs CrocApp or the croc CLI. croc 10 cannot complete a transfer with CrocApp; see [croc CLI interoperability](../reference/croc-cli-interop.md).

## Build from source

Requires:

- **macOS 26**
- **Xcode 27.1**
- **Go 1.27.2** or newer (`gomobile` and `gobind` are rebuilt from the `go.mod` `tool` block on every run)

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

:::warning
A fresh clone builds nothing until the xcframework exists. `CrocKit`'s binary target points at a gitignored artifact, so `scripts/build-xcframework.sh` is not optional.
:::

Full toolchain reference, build settings, and troubleshooting: [`docs/BUILDING.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/BUILDING.md) on GitHub.
