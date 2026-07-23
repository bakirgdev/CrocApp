# 0011. AppRouter singleton for external entry points; universal document types for dock drop; one archive, two export plists

Status: accepted
Date: 2026-07-23

## Context

Phase 4 had to make dropped files reach the Send flow from outside the SwiftUI environment graph (dock icon → `NSApplicationDelegate`, menu bar → `Commands`), make the Dock accept drops at all, and lay distribution groundwork for MAS + Developer ID without duplicating build configuration. Verified during implementation: declaring `CFBundleDocumentTypes` on macOS makes AppKit treat bare launch argv tokens as document-open candidates, and makes Xcode auto-inject `LSSupportsOpeningDocumentsInPlace = NO` (build-invalid) unless overridden.

## Decision

- **Navigation + external send payloads = `AppRouter.shared` singleton** (`path: [Route]`, `pendingSendURLs`). Singleton because `NSApplicationDelegate` and `Commands` sit outside the environment graph; views still consume it via `.environment`. `isBusy` mirrors `TransferController.isActive`: dock drops mid-transfer queue URLs without yanking navigation (window drop refuses outright, menu items disable — three entry points, one guard policy). Known constraint: a second window would navigate in lockstep with the first (`.newItem` menu group is replaced, so no File > New Window; residual risk accepted).
- **Dock drop = universal document type.** `CFBundleDocumentTypes` with `public.item`, role Viewer, `LSHandlerRank None`, in a macOS-only `INFOPLIST_FILE` merged over the generated plist (same pattern as iOS). Side effect, accepted: CrocApp appears in Finder's "Open With" for every file type; rank None keeps it from ever being default. Required override: `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace[sdk=macosx*] = YES` in both configs.
- **Distribution groundwork = one Release archive + per-channel `ExportOptions` plists** (`app-store-connect` / `developer-id`), not separate pbxproj build configurations — entitlements (sandbox on) and hardened runtime are already correct for both channels. `scripts/build-devid.sh` archives (with `ARCHS=arm64`; xcframework macOS slice is arm64-only, golang/go#73119), exports Developer ID, `codesign --verify`, then `syspolicy_check distribution` as the notarization dry-run. No Developer ID cert installed → clean `DEVID-PENDING-CERT` degrade (human action in PLAN.md).
- **Default receive folder (macOS) = `~/Downloads/CrocApp`** via `com.apple.security.files.downloads.read-write`; user override still bookmark-persisted. Harness contract stays container-Documents (AutoVerify decoupled from the app default).
- **LAN-under-sandbox proof = app-side local-only send.** `onlyLocal` forces croc's local relay listener (TCP 9009) inside the sandbox — the `network.server` entitlement's actual job — with the CLI receiver connecting via `--ip` (multicast discovery unreliable on the dev machine). Receiver-side forced-LAN needs `--ip` plumbing in EngineOptions; deferred.

## Consequences

- Dock drops during a transfer surface only after the transfer ends (staged URLs wait in `pendingSendURLs`); no feedback at drop time — banner/toast is a Phase 5+ polish item.
- Harness launches need `-ApplePersistenceIgnoreState YES` (window-restoration hang headless) and flag-style argv (`--auto-send PATH --code CODE`) — bare adjacent tokens are now document-open candidates.
- `ExportOptions-MAS.plist` is committed but unvalidated until Phase 7's MAS export.
- AutoVerify + `forceLocalOnly` compile into Release; gate behind a build flag before store submission (Phase 7).
