---
sidebar_position: 1
title: Install
description: CrocApp has not been released yet. Here is the current status of every planned distribution channel and how to build from source today.
---

# Install

:::warning
**Not released yet.** No download exists on any channel today. The source is public and buildable now; see [Build from source](#build-from-source) below.
:::

## Distribution channels

CrocApp is planned for four channels. None are live yet.

| Channel | State |
|---|---|
| iOS / iPadOS App Store | Planned |
| Mac App Store | Planned |
| macOS direct download (notarized DMG) | Planned |
| Homebrew cask | Blocked on notarization |

Notes on the blockers:

- **Notarization is not real yet.** The project's notarization script currently stops at a dry-run check (`syspolicy_check distribution`) and does not submit for or staple a real notarization ticket.
- **Homebrew requires codesigning and notarization for official casks** as of 2026-09-01, so the cask channel stays blocked until real notarization lands.
- A TestFlight beta is also planned, for when there is a build to distribute.

Every V1 feature is implemented; what stands between the app and a release is tracked in the project's [known issues](https://github.com/bakirgdev/CrocApp/blob/main/docs/known-issues.md) under "Blocking release".

## Build from source

Requires:

- **macOS 26**
- **Xcode 26.6**
- **Go 1.26.5** or newer (`gomobile` and `gobind` install themselves on first run)

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

:::warning
A fresh clone builds nothing until the xcframework exists. `CrocKit`'s binary target points at a gitignored artifact, so `scripts/build-xcframework.sh` is not optional.
:::

The app itself requires **iOS 26**, **iPadOS 26**, or **macOS 26** to run.

Full toolchain reference, build settings, and troubleshooting: [`docs/BUILDING.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/BUILDING.md) on GitHub.
