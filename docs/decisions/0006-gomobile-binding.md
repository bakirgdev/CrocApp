# 0006. Embed croc via gomobile-built xcframework

Status: accepted
Date: 2026-07-22

## Context

iOS forbids spawning processes, so wrapping the croc CLI binary (as croc's linked Android client does via subprocess + stdout regex) is impossible there and fragile everywhere. Alternatives evaluated: pure-Swift protocol reimplementation (croc uses custom schollz/pake PAKE + nonstandard SIEC curve, no Swift port exists — months of work, permanent upstream chase), macOS-only subprocess (splits engine in two), c-archive + manual C shim (more control, more glue).

Upstream croc supports embedders: `croc.NewCtx()` (PR #1038, v10.4.5+) gives context cancellation, GUI-safe error handling, and peer decline. Progress is exposed as polled `Client` fields (`TotalSent`, step flags), not callbacks — crocgui proves the polling pattern. App Store precedent for Go runtimes: iCroc, WireGuard, Destiny.

## Decision

- Small Go wrapper package `crocmobile`: `StartSend(paths, opts, delegate)`, `StartReceive(code, opts, delegate)`, `Cancel(id)`; internally `croc.NewCtx` + `NoPrompt/Overwrite/Quiet`, goroutine polls `Client` fields → fires gobind delegate (Go interface → ObjC protocol); Swift hops callbacks to MainActor.
- `gomobile bind -target ios,iossimulator,macos` → single `Croc.xcframework`.
- croc pinned via go.mod (v10.5.0 at time of writing); bump + rebind on upstream releases. Wire compat stable within v10.x.
- xcframework built by script + CI, not committed; prebuilt published via GitHub Releases for Go-less contributors.

## Consequences

- One engine, both platforms; ~15-40 MB size overhead (Go runtime) accepted.
- **macOS build is Apple Silicon only.** golang/go#73119 breaks multi-arch macOS bind, so the script emits `macos/arm64` and the xcframework has no `x86_64` macOS slice. Intel Macs that can run macOS 26 (2019 MacBook Pro 16", 2020 iMac, 2019 Mac Pro) cannot run CrocApp. `ARCHS[sdk=macosx*] = arm64` is pinned in the pbxproj so archives do not attempt a link that must fail.
- Go toolchain becomes a build dependency (CI + release artifacts mitigate for contributors).
- gomobile lags new Xcode majors occasionally; fallback is same wrapper via `go build -buildmode=c-archive` + C shim (wireguard-apple pattern), no protocol-layer changes.
- Delegate callbacks arrive on Go threads; Swift layer must marshal to MainActor.
