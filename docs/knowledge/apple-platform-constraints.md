# Apple platform constraints

Research digest 2026-07-22. Shapes architecture; verify APIs against current docs (context7/web) before coding.

## Hard constraints

1. **iOS background = raw TCP dies.** No background mode for arbitrary sockets; background URLSession is HTTP-only. Lifeline: `BGContinuedProcessingTask` (iOS 26+, not macOS) — user-initiated in foreground, system Live Activity progress UI mandatory, `Progress` reporting mandatory, identifier in `BGTaskSchedulerPermittedIdentifiers`, best-effort runtime (killed under pressure, low-progress killed first, field reports of unpredictable expiry). Transfers must be resumable + checkpoint on expiry. Foreground: use `isIdleTimerDisabled`. Verified Phase 3: system renders the Live Activity itself (title/subtitle/progress/cancel — custom ActivityKit widget redundant); NO `UIBackgroundModes` needed; permitted-identifiers wildcard (`prefix.*`) supported for continued-processing; handlers register dynamically right before submit (no didFinishLaunching constraint); simulator `submit` always throws (foreground-only fallback mandatory). Implementation: ADR 0010, `BackgroundCoordinator`.
2. **croc LAN discovery = UDP multicast** (schollz/peerdiscovery) → needs restricted entitlement `com.apple.developer.networking.multicast` on iOS. Apply via Apple form (~days-2 weeks, per-team, must be enabled per profile type incl. TestFlight). Alternative: Bonjour (`NWBrowser`/`NWListener`) needs no entitlement but stock croc CLI peers stay undiscoverable (protocol mismatch). Without entitlement croc's relay path still works — LAN race just loses.
3. **Share extension:** ~120 MB memory cap, no long-running work, no BGContinuedProcessingTask. Pattern: `NSItemProvider.loadFileRepresentation` → stream-copy to App Group container → main app runs transfer.
4. **iOS cannot spawn processes** → croc linked as library only (ADR 0006).
5. **Mac App Store = sandbox mandatory:** `com.apple.security.network.client` + `.server` (server needed for local relay listener), plus `files.user-selected.read-write` and `files.downloads.read-write` (default output folder `~/Downloads/CrocApp`). Direct DMG: notarization + hardened runtime, sandbox optional.
6. **Wi-Fi Aware** (iOS/iPadOS 26): AirDrop-class direct Wi-Fi, absent on macOS 26 → optional iOS↔iOS fast path only, never primary transport.

## Papercuts

- Local network privacy prompt (`NSLocalNetworkUsageDescription` + `NSBonjourServices` required in Info.plist): triggers on first LAN op; relay traffic (WAN) doesn't trigger it. Denial fails silently; known flakiness (no re-prompt after reinstall, granted-but-broken until toggle/reboot) → ship pre-flight/diagnostics UX. TN3179 is the authority. Verified Phase 3: NO official authorization-check API exists (incl. iOS 26); detection = Bonjour self-probe (`LocalNetworkChecker`, ADR 0010) — browser stuck `.waiting` until timeout ⇒ denied; the probe itself raises the prompt, so never treat first `.waiting` as denial.
- Security-scoped URLs from `fileImporter`: `startAccessingSecurityScopedResource`, keep bookmarks for resume-across-launch.
- Received files visible in Files app: `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`.
- gomobile breaks occasionally on new Xcode majors (history: golang issues #53316, #55028, #66500) — budget fiddling time. Status 2026-07: Xcode 26.6 + Go 1.26.5 + x/mobile@latest bind clean; macOS slice must be arm64-only (#73119); #66500 (device framework layout vs App Store validation) still open — revisit at release engineering.
- BGContinuedProcessingTask lowers QoS in background → slower transfers, fine.
- Liquid Glass: standard SwiftUI controls restyle free on Xcode 26; custom chrome needs `.glassEffect()`; compatibility opt-out flag dies next major OS.
- New in 26, prefer: Network framework Swift API (`NetworkConnection`/`NetworkListener`/`NetworkBrowser`, structured concurrency) over NWConnection callbacks.
- Verified Phase 4 (macOS): declaring `CFBundleDocumentTypes` makes AppKit treat bare launch argv tokens as document-open candidates (two adjacent bare args ⇒ no default window; harness must use flag-style args) and makes Xcode auto-inject `LSSupportsOpeningDocumentsInPlace = NO` (build-invalid — override with `INFOPLIST_KEY_...[sdk=macosx*] = YES`). Headless/scripted app launches hang in window restoration without `-ApplePersistenceIgnoreState YES`. `xcodebuild archive` for generic macOS ignores `ONLY_ACTIVE_ARCH` — pass `ARCHS=arm64` while the xcframework macOS slice is arm64-only (#73119). Sandbox `network.server` verified: croc's local relay listener binds TCP 9009 in-sandbox (lsof-proven, `MAC-LOCAL-SEND-OK`). `syspolicy_check distribution` = notarization pre-check without submitting.

## App Store review

Category proven: iCroc (croc client, iOS+macOS store), Destiny, LocalSend, wormhole-william-mobile. Go runtime fine. Residual low risks: explain code-phrase model + default public relay in review notes; avoid implying official croc endorsement without schollz blessing (naming/branding, guideline 5.2).
