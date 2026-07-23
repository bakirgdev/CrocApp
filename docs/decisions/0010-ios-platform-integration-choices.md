# 0010. System Live Activity via BGContinuedProcessingTask; share handoff by staging; croc-native resume

Status: accepted
Date: 2026-07-23

## Context

Phase 3 had to make transfers survive iOS backgrounding, complete F10 (Live Activity), ship F30 (share extension), and handle local-network denial. Verified during planning: BGContinuedProcessingTask (iOS 26+) renders its own system Live Activity (title/subtitle/progress/cancel); `NSExtensionContext.open` is unsupported for share extensions; iOS has no official local-network authorization API.

## Decision

- **F10 Live Activity = the system one.** Transfers are wrapped in `BGContinuedProcessingTask` (`BackgroundCoordinator`); the system activity shows progress and cancel. No custom ActivityKit widget extension — it would duplicate system UI. Identifiers: wildcard `com.bakirgdev.CrocApp.transfer.*` per transfer, static `com.bakirgdev.CrocApp.transfer` as fallback (early-iOS-26 wildcard bugs). Submit failures are swallowed: transfer continues foreground-only (simulator always takes this path). A generation token guards against late launch-handler delivery binding a stale task to a newer transfer.
- **Expiry checkpoint = croc's native resume.** On expiration the engine is cancelled and the failed message tells the user to redo the same transfer; croc resumes partially transferred files. No bespoke checkpoint format.
- **F30 handoff = stage + user opens app.** CrocShare (iOS-only appex, `platformFilters=(ios,)`) file-copies attachments into App Group `group.com.bakirgdev.CrocApp` under `ShareInbox/batch-<UUID>/` and writes `manifest.json` last (atomic signal). No openURL hacks (App Review risk). The extension never deletes existing batches (an earlier batch may be mid-send in the app); the app purges orphaned batches only while idle (`purgeStaleBatches`, gated on `!controller.isActive`).
- **Local-network state = Bonjour self-probe** (`NWListener` advertising `_crocapp._tcp` + `NWBrowser` browsing for it). Seeing own service ⇒ granted; unresolved `.waiting` at the 8 s timeout ⇒ denied (never latch denied on first `.waiting` — the probe itself raises the permission prompt and waits in `.waiting` until answered); otherwise unknown, no banner. Deliberate exception to the prefer-`NetworkListener`/`NetworkBrowser` rule: the probe heuristic depends on NW* callback state granularity and a proven reference pattern.

## Consequences

- Custom Dynamic Island layout deferred until someone wants it; would mean a widget extension + ActivityKit.
- Share-sheet UX has a manual step ("Open CrocApp to send"); accepted, review-safe.
- Repeated shares without opening the app accumulate batch dirs until the next idle refresh purges them.
- Devices where wildcard BG registration persistently fails degrade to foreground-only transfers after the first static-fallback transfer (frozen generation) — backlog, needs device evidence.
- Background/share/Files/local-network behavior is simulator-unverifiable; `docs/knowledge/device-test-checklist.md` carries the hardware gate.
