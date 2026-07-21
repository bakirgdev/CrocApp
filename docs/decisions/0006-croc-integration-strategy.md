# 0006. croc integration strategy

Status: proposed
Date: 2026-07-21

## Context

iOS forbids spawning bundled executables, so "shell out to croc CLI" only works on macOS. Options:

1. **gomobile bind** croc's Go core (`github.com/schollz/croc/v10/src/croc`) into an xcframework, one integration for both platforms.
2. Bundle CLI binary on macOS + something else on iOS (two codepaths).
3. Reimplement the croc protocol in Swift (large effort, permanent drift risk vs upstream, conflicts with wrap-not-fork non-goal).

croc's core is pure Go + x/crypto, so option 1 is plausible but unproven; upstream ships a native Kotlin Android client (since v10.4.14) as a mobile reference.

## Decision (proposed)

Option 1: gomobile-built xcframework wrapping croc's Go package, shared by iOS and macOS. Validate with a spike (send + receive between iPhone and Mac) before accepting.

## Consequences

- One integration, always protocol-current by bumping the croc dependency.
- Adds Go toolchain + gomobile to the build; binary size grows (Go runtime).
- Known iOS risks to spike: multicast discovery entitlement, local-relay listening sockets, background transfer limits.
