# 0003. Minimum OS: iOS 26 / macOS 26

Status: accepted
Date: 2026-07-21

## Context

Greenfield app, no existing users. Dev machine runs macOS 26 + Xcode 26. Supporting older OS versions means availability checks and forgoing current SwiftUI APIs and the Liquid Glass design language.

## Decision

Minimum deployment target: iOS 26 and macOS 26. Always latest SwiftUI APIs, no back-deployment shims.

Pinned as `26.0` exactly, never a minor version — in the pbxproj, in `Package.swift`, and in `gomobile bind` (`-iosversion 26.0 -macosversion 26.0`) so the xcframework floor matches. The Xcode template default is a minor (`26.5`), which silently locks out everyone on 26.0-26.4; treat any minor pin as drift, not a decision.

Swift 6 language mode (`SWIFT_VERSION = 6.0`) on every target, matching `CrocKit` (swift-tools 6.0). New targets default to Swift 5 mode and have to be flipped.

## Consequences

- Cleanest possible codebase; best default look; ideal for learning current-generation Apple development.
- Excludes devices stuck on older OS versions; acceptable for a new OSS app. Revisit only if adoption clearly suffers.
- iOS 26 itself needs A13 or later (iPhone 11 / SE 2nd gen and up); every such device is arm64, so the `ios-arm64` slice covers all of them.
- Swift 6 mode means complete strict concurrency is enforced, not merely warned about. Anything crossing an isolation boundary must be `Sendable` or explicitly `nonisolated(unsafe)`.
- Bumping the floor to a minor (e.g. for a 26.x-only API) is a deliberate change, not drift. Rewrite this ADR when it happens, and check all three pin sites move together.
