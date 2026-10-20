---
sidebar_position: 5
title: Contribute
description: How to build and contribute to CrocApp, how it was made, and the projects that inspired it.
---

# Contribute

Contributor and internals documentation lives in the repository, not on this site, because it has to track the code as it changes. This site covers using the app. The repository covers building and changing it.

Pull requests are welcome: bugs, features, docs, design and the landing page. Start with `CONTRIBUTING.md`.

## Build from source

```bash
git clone https://github.com/bakirgdev/CrocApp.git
cd CrocApp
scripts/build-xcframework.sh   # Go engine -> CrocKit/Croc.xcframework
open app/CrocApp.xcodeproj
```

:::warning
A fresh clone builds nothing until the xcframework exists. The `CrocKit` binary target points at a file that is not committed, so `scripts/build-xcframework.sh` is required. [`docs/BUILDING.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/BUILDING.md) lists the exact toolchain versions.
:::

## Where things are

- [`CONTRIBUTING.md`](https://github.com/bakirgdev/CrocApp/blob/main/CONTRIBUTING.md): setup, branches, commits, style, verification, pull request flow
- [`CODE_OF_CONDUCT.md`](https://github.com/bakirgdev/CrocApp/blob/main/CODE_OF_CONDUCT.md): Contributor Covenant 3.0
- [`SECURITY.md`](https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md): scope and private reporting for vulnerabilities
- [`docs/README.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/README.md): index of every contributor and internals doc
- [`docs/ARCHITECTURE.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/ARCHITECTURE.md): system map, layers, event flow
- [`docs/BUILDING.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/BUILDING.md): toolchain, fresh-clone steps, verification harnesses
- [`docs/GLOSSARY.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/GLOSSARY.md): the contributor and internals vocabulary
- [Issue templates](https://github.com/bakirgdev/CrocApp/tree/main/.github/ISSUE_TEMPLATE): where to file bugs, features and other reports

## How it was made

croc's Go library is compiled to an XCFramework with `gomobile` and driven from a Swift actor. It is not a subprocess, because iOS does not allow those. The interface is SwiftUI throughout, targeting iOS 26 and macOS 26. [`docs/ARCHITECTURE.md`](https://github.com/bakirgdev/CrocApp/blob/main/docs/ARCHITECTURE.md) has the full picture.

## Inspirations

CrocApp exists because of these. Some are the foundation, and some showed what good looks like on other platforms.

- [croc](https://github.com/schollz/croc): the engine and the protocol. Everything CrocApp does, croc does underneath.
- [magic-wormhole](https://github.com/magic-wormhole/magic-wormhole): the original code-phrase transfer, and croc's own inspiration.
- [LocalSend](https://github.com/localsend/localsend): proof that a cross-platform transfer app can be genuinely pleasant to use.
- [croc-app](https://github.com/Dking08/croc-app): the Android client, and the best mobile reference for what a croc GUI should feel like.
- [crock](https://github.com/KD-MM2/crock): a desktop croc GUI, and where the QR deeplink idea comes from.
- [crocgui](https://github.com/howeyc/crocgui): the long-running cross-platform croc GUI.
