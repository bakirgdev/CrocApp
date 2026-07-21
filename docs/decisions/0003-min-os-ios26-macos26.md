# 0003. Minimum OS: iOS 26 / macOS 26

Status: accepted
Date: 2026-07-21

## Context

Greenfield app, no existing users. Dev machine runs macOS 26 + Xcode 26. Supporting older OS versions means availability checks and forgoing current SwiftUI APIs and the Liquid Glass design language.

## Decision

Minimum deployment target: iOS 26 and macOS 26. Always latest SwiftUI APIs, no back-deployment shims.

## Consequences

- Cleanest possible codebase; best default look; ideal for learning current-generation Apple development.
- Excludes devices stuck on older OS versions; acceptable for a new OSS app. Revisit only if adoption clearly suffers.
