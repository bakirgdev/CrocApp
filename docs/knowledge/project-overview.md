# Project overview

## What

CrocApp is a free, open-source, native SwiftUI app for [croc](https://github.com/schollz/croc), the file-transfer command line tool. It runs on iOS, iPadOS and macOS, and covers most of croc's features behind a simple interface.

## Status

The first public release is 1.1.0: a notarized direct download for the Mac (Sparkle updates), followed by the iOS, iPadOS and Mac App Store builds, which exist in TestFlight only until then. `../ROADMAP.md` lists what comes next, and `../RELEASING.md` covers the channels.

## Why

- croc has a strong design (PAKE-secured, relay-assisted, end-to-end encrypted transfers), but it is command line only, so most people cannot use it.
- A native app brings that design to a wider audience.
- No official, maintained native Apple app for croc exists (see `prior-art.md`).

## Goals

1. A real, working, shippable app, not a demo.
2. A healthy open-source project: users, contributors, good repo hygiene.
3. The author learns Apple development (Swift, SwiftUI, Xcode) along the way.

## Constraints and context

- One developer: Bakir Gracic. The repo is public at `github.com/bakirgdev/CrocApp`.
- Built almost entirely with Claude Code, with minimal manual coding. Tooling and docs are written to keep AI sessions cheap and accurate.
- Minimum OS: iOS 26.0, iPadOS 26.0 and macOS 26.0. Toolchain: Xcode 27 (`tooling.md`).
- License: MIT.

## Non-goals

- Windows, Linux or Android clients.
- Reimplementing or forking croc. CrocApp wraps it.
- Paid features. The app stays free; the only money is optional donations.
