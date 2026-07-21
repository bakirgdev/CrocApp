# Project Overview

## What

CrocApp: free, open-source, native SwiftUI GUI wrapper for [croc](https://github.com/schollz/croc), the file-transfer CLI. Targets Apple devices: iOS and macOS. Covers all/most croc features behind a simple GUI.

## Why

- croc has clever architecture (PAKE-secured, relay-assisted, end-to-end encrypted transfers) but is CLI-only — inaccessible to basic users.
- A polished native GUI brings croc's design to a broader audience.
- No official or well-maintained native Apple GUI exists.

## Goals

1. Real, working, shippable app — not a demo.
2. Successful OSS project: stars, users, contributors, healthy repo hygiene.
3. Author learns Apple development (Swift, SwiftUI, Xcode) and adjacent tech along the way.

## Constraints & context

- Sole developer: Bakir Gracic, under the sanjacklee-digital GitHub org. Public repo.
- AI-first development: built almost entirely with Claude Code (Claude Max plan), minimal manual coding. Tooling and docs are token-optimized (see ADR 0004).
- Toolchain: macOS 26, Xcode 26, iOS 26. Minimum OS = iOS 26 / macOS 26 (see ADR 0003).
- License: MIT (see ADR 0001).

## Non-goals (for now)

- Windows/Linux/Android clients.
- Reimplementing or forking croc itself — CrocApp wraps it.
- Paid features. App stays free; monetization limited to optional sponsorship.
