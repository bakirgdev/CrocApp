# 0005. Native SwiftUI, single multiplatform codebase

Status: accepted
Date: 2026-07-21

## Context

App needs iOS + macOS. Alternatives: React Native/Flutter/Electron (cross-platform), Catalyst, or separate AppKit/UIKit apps. A core project goal is learning native Apple development; another is a small, polished, native-feeling utility.

## Decision

One SwiftUI multiplatform target for iOS and macOS. No cross-platform framework, no Catalyst. Drop to UIKit/AppKit only where SwiftUI genuinely can't (e.g. NSOpenPanel specifics).

## Consequences

- Native look, small binary, direct access to share extensions, App Intents, Liquid Glass.
- Platform divergence (file pickers, backgrounding, menu bar) handled with `#if os(...)` — kept isolated in dedicated files.
- No web/Android reuse; accepted per project non-goals.
