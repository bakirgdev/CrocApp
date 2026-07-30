# 0034. The local-network probe runs on macOS too

Status: accepted
Date: 2026-07-30

## Context

`LocalNetworkChecker` advertises a Bonjour service and browses for it, treating "saw my own service" as granted and "browser still waiting at the timeout" as denied. It existed for iOS, which has no public local-network authorization API.

Its macOS branch was two empty function bodies. `status` therefore never left `.unknown`, and `TransferStatusView` gates the whole local-network-denied banner on `status == .denied` — so on macOS that banner was unreachable. Dead code, not a feature flag.

That was correct when it was written and stopped being correct with macOS 15. Sequoia added a Local Network privacy pane. It is not TCC-backed; it is enforced as a Network Extension packet filter, and there is still no dedicated public status API. Denial surfaces through exactly the probe already implemented, as `.waiting(NWError.dns(-65570))` — `kDNSServiceErr_PolicyDenied` — which the existing state machine already resolves to `.denied` at its timeout.

## Decision

Delete the `#if os(iOS)` split. `import Network` unconditionally and let both platforms run the same probe. Nothing in it touches UIKit, the `checkIfNeeded()` / `recheckIfDenied()` call sites already run unconditionally, and the macOS target already carries `com.apple.security.network.client` and `network.server`.

The banner's action button diverges: iOS opens `UIApplication.openSettingsURLString`, macOS opens `x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork` via `NSWorkspace`. That URL scheme is community-standard and not formally documented by Apple — the same category this codebase already accepts for `shareddocuments://`.

`NSLocalNetworkUsageDescription` already ships unscoped, so it covers macOS. `NSBonjourServices` is an iOS-only scope restriction; its absence from the macOS plist is not a blocker.

## Consequences

- One code path instead of two, and the denied banner is reachable on both platforms.
- **Enforcement reportedly only engages for builds resident in `/Applications`.** This comes from a single developer-forum thread (FB16077972), not from Apple documentation, so treat it as strong inference. A DerivedData-launched Debug build may sit at `.ready` and read as falsely granted, which makes the denial path awkward to exercise during development: copy the app to `/Applications` first.
- The probe costs an advertise plus a browse on macOS where it previously cost nothing. It runs once per process, and `recheckIfDenied` refuses to stack a second in-flight probe, so the cost is bounded.
