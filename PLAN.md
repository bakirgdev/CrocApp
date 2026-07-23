# CrocApp Master Plan

> **For agentic workers:** This is the phase roadmap, not a task-level plan. Each phase is executed in a **fresh Claude Code session**. That session must: (1) read this file, `CLAUDE.md`, and the Required reading for its phase, (2) produce a detailed task-level plan via `superpowers:writing-plans` (save to `docs/superpowers/plans/`), (3) execute it via `superpowers:subagent-driven-development`, (4) verify builds/tests, (5) run docs self-heal per `CLAUDE.md`, (6) check the phase checkbox here and note deviations under it.

**Goal:** Ship CrocApp V1 — free OSS native SwiftUI GUI for croc — to iOS App Store, Mac App Store, notarized DMG, brew cask.

**Architecture:** croc embedded as Go library via gomobile xcframework (ADR 0006); thin Go wrapper `crocmobile` with delegate callbacks; Swift `CrocEngine` actor marshals to MainActor; single SwiftUI multiplatform target (ADR 0005); platform divergence isolated in `#if os(...)` files.

**Tech stack:** Swift 6 / SwiftUI (iOS 26 + macOS 26 min, ADR 0003), Go 1.22+ / gomobile, croc v10.5.0 pinned, SwiftData (history), BGContinuedProcessingTask + ActivityKit (iOS background), Network framework Swift API where raw networking needed.

## Global constraints

- Min targets iOS 26 / macOS 26; no availability shims (ADR 0003).
- Feature scope + IDs (F1..F40): `docs/knowledge/features.md`. V1 = F1-F19, F30, F36.
- Platform hard constraints: `docs/knowledge/apple-platform-constraints.md` — reread every phase.
- Look up, don't guess: context7/web for every uncertain API, especially Xcode 26-era SwiftUI (CLAUDE.md rule).
- Token economy: rtk prefix, subagents for exploration, noisy output → files (ADR 0004).
- Never auto-accept incoming files by default; receive preview + confirm is a product pillar (F9, F18).
- Git: imperative subjects, no AI footers, stage only what changed.
- Docs self-heal at end of every session.

## Standing human actions (Bakir, start early — lead times)

- [ ] Paid Apple Developer account active under intended team.
- [ ] Apply for `com.apple.developer.networking.multicast` entitlement (form, ~days-2 weeks). Needed for croc-CLI LAN discovery parity (F11 best case). App works via relay without it.
- [ ] Contact schollz: blessing for name/branding + eventual README link (before store submission).

---

## Phase 1 — Engine bridge (crocmobile + CrocEngine)

**Goal:** Swift code can send and receive real croc transfers on macOS and iOS simulator, interoperating with brew-installed croc CLI.

**Scope:**
- `crocmobile/` Go module at repo root: `StartSend(paths, opts, delegate)`, `StartReceive(code, opts, delegate)`, `Cancel(id)`; wraps `croc.NewCtx`, sets `NoPrompt/Overwrite/Quiet`, polls `Client` fields (`TotalSent`, step flags, `SuccessfulTransfer`) in goroutine → gobind delegate callbacks (progress, code-ready, file-list, confirm-request, done, error). Options struct covers all V1 flags (F13-F19 fields included now — scalar fields, cheap).
- `scripts/build-xcframework.sh`: `gomobile bind -target ios,iossimulator,macos` → `Croc.xcframework`; document Go toolchain setup.
- Xcode integration of xcframework; Swift package/layer `CrocKit`: `CrocEngine` actor, `TransferState` model, delegate→AsyncStream bridge, MainActor marshaling.
- Interop verification: app↔croc CLI both directions, file + folder + text, LAN and forced-relay.

**Exit criteria:** scripted build passes clean checkout → xcframework; macOS app target + iOS sim exchange files with croc CLI v10.5.0; cancel works both directions; no stdin hangs (empty-folder prompt path guarded).

**Risks/notes:** gomobile/Xcode 26 friction budget; `src/models/constants.go` does DNS + os.Args parsing at import — wrapper must tolerate; progress = polling, pick ~10 Hz; delegate calls arrive on Go threads.

- [x] Phase 1 complete (2026-07-23)
  - Deviations: `Cancel(id)` became handle method `Transfer.Cancel()`; accept/decline bridged by `syscall.Dup2` pipe on fd 0 (plain `os.Stdin` swap insufficient — croc caches the reader at init; ADR 0008); transfers serialized one-at-a-time (process-global cwd/fd mutations; ADR 0008); framework module is `Croc` not `Crocmobile` (`import Croc`); macOS slice arm64-only (golang/go#73119); verification via harness scripts + `croctest`/`crockit-verify` executables, no test targets. gomobile/Xcode 26: zero friction. Engine facts + croc gotchas: `docs/knowledge/crocmobile-bridge.md`. Phase 2 carry-overs: UI keys off done/failed only (fast transfers skip events); map cancel-during-prompt error string "refused files" → "cancelled" in UI copy; keep `Ask` unexposed until sender stdin bridge exists; apply for iOS multicast entitlement early (device LAN discovery).

## Phase 2 — Core transfer UI

**Goal:** Usable two-verb app on both platforms: full send/receive happy path. Features F1-F11.

**Scope:**
- Home: Send / Receive split (prior-art pattern, `docs/knowledge/prior-art.md`).
- Send: fileImporter + drag-drop (F1, F2), text/clipboard send (F3), auto code + custom code ≥6 chars (F5), code display with copy + QR (F6), waiting/connected states.
- Receive: code entry with clipboard auto-detect, QR scan on iOS (F6), incoming file-list preview + accept/decline (F9), output folder (F7; iOS default Files-visible app folder), overwrite/resume confirm sheets (F8).
- Progress screen: per-file + total, speed, cancel (F10, Live Activity deferred to Phase 3).
- Security-scoped resource handling; filename sanitization on receive.
- Liquid Glass default styling; no custom chrome yet.

**Exit criteria:** end-to-end transfers driven purely from UI on both platforms; decline actually notifies sender (`SendError` path); state machine handles peer-vanished + relay-unreachable errors with readable messages.

- [x] Phase 2 complete (2026-07-23)
  - Deviations: F8 = accept-sheet conflict model, `overwrite` always on, Accept means replace (per-file skip needs engine work; ADR 0009); "clipboard auto-detect" → explicit `PasteButton` (iOS paste-privacy banner; ADR 0009); QR payload `croc://<code>`. Real bug found by harness and fixed: progress ticks (~10 Hz) clobbered the unanswered accept prompt — `.incoming` guard in `TransferController.handle` (also documented as engine contract note). CLI custom-code receive needs `CROC_SECRET` env (not positional) — verify-app-mac.sh + bridge doc updated. `fileImporter` without `allowsMultipleSelection` returns single-URL Result (plan's folder-picker snippet didn't compile as written). Verification: MAC-RECEIVE-OK + MAC-SEND-OK (`scripts/verify-app-mac.sh`, new), SIM-INTEROP-OK, interop 11/11 incl. decline; gesture-level flows (drag-drop, camera QR, taps) left to manual device testing (no XCUITest by rule). UI facts: `docs/knowledge/app-ui-architecture.md`. Phase 3+ carry-overs: cross-flow status bleed (active Send renders on Receive screen) acceptable V1; no Cancel during accept prompt; iOS Files-visibility plist keys still pending (Phase 3); `CrocApp/` wrapper dir renamed → `app/` post-phase (triple-name nesting caused two subagent misplacements); Xcode project now at `app/CrocApp.xcodeproj`, sources `app/CrocApp/`.

## Phase 3 — iOS platform integration

**Goal:** iOS behaves like a real iOS app: survives backgrounding, integrates with Files + share sheet. F30 + platform work.

**Scope:**
- BGContinuedProcessingTask wrapping active transfers: identifier registration, submit-on-user-action, Progress reporting, expiry checkpoint → resume UX (`apple-platform-constraints.md` §1).
- Live Activity for transfer progress (F10 completion).
- Files app visibility (`UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace`); received-files handoff.
- Share extension (F30): App Group container, stream-copy staging (120 MB cap rule), main-app pickup flow.
- Local network permission UX: Info.plist keys, pre-flight check, diagnostics hint on silent denial.
- `isIdleTimerDisabled` during foreground transfers.

**Exit criteria:** multi-GB transfer continues in background on device (best-effort) and resumes cleanly after kill; share-sheet send from Photos/Files works; local-network denial produces guidance not silence.

**Risks:** BGContinuedProcessingTask field flakiness — resume is the real safety net; device testing mandatory (simulator lies about background + multicast).

- [ ] Phase 3 complete

## Phase 4 — macOS platform integration

**Goal:** Mac app feels Mac-native and is ready for both distribution styles.

**Scope:**
- Sandbox entitlements (`network.client`, `network.server`); verify LAN relay listener under sandbox.
- Two build configs groundwork: MAS (sandboxed) vs Developer ID (hardened runtime, notarization-ready).
- Drag-drop onto window + dock icon; menu commands + keyboard shortcuts; Settings scene; window sizing/restoration.
- Finder integration: reveal received files, default Downloads/CrocApp folder with user override (F7).

**Exit criteria:** sandboxed build transfers both directions incl. LAN path; Developer ID build runs notarization dry-run clean; drag-drop send works.

- [ ] Phase 4 complete

## Phase 5 — Settings, power options, trust UI

**Goal:** F13-F19 + F36 complete → V1 feature surface done except history.

**Scope:**
- Settings: custom relay/pass/IPv6 (F13), local-only (F14), no-compress (F15), zip (F16), exclude/.gitignore (F17), auto-accept with warning copy (F18), both-sides confirm (F19). Persisted; engine Options already plumbed in Phase 1.
- Trust UI (F36): E2E badge on transfer screens, active-relay indicator (public/custom/local), "How it works" screen (PAKE, relay-sees-ciphertext, code-phrase model — source `docs/knowledge/what-is-croc.md`).

**Exit criteria:** every V1 flag reachable + effective (spot-verify against CLI behavior: custom relay, local-only, no-compress); settings survive relaunch; defaults match croc CLI defaults.

- [ ] Phase 5 complete

## Phase 6 — History + product polish

**Goal:** F12 + release-grade fit and finish.

**Scope:**
- Transfer history (SwiftData): direction, names, sizes, peer code hint, status, timestamps; re-send from history; clear/delete. Local only.
- Error/empty states pass; interrupted-transfer recovery UX audit.
- Accessibility: VoiceOver labels, Dynamic Type, contrast.
- App icon + accent; Liquid Glass polish pass (`.glassEffect()` only where warranted); onboarding-lite first-run explaining code phrases.
- Performance: many-file sends, progress-update batching, memory during multi-GB.

**Exit criteria:** app passes self-run `apple-appstore-reviewer` skill audit; VoiceOver-navigable core flows; no jank at 10k-file send.

- [ ] Phase 6 complete

## Phase 7 — Release engineering + V1 launch

**Goal:** V1 live on all channels (ADR 0007).

**Scope:**
- CI (GitHub Actions, path-filtered per ADR 0002): xcframework build, app build + tests both platforms, release pipeline producing MAS upload, notarized DMG, TestFlight.
- Prebuilt xcframework attached to GitHub Releases (contributor path, ADR 0006).
- TestFlight beta round; fix cycle.
- Store metadata: screenshots, description, review notes (code-phrase model, default public relay, OSS), privacy labels (no data collection).
- iOS App Store + Mac App Store submission; DMG on GitHub Releases; brew cask PR.
- README with screenshots + badges (repo = pitch, `prior-art.md` playbook).

**Exit criteria:** both store approvals, DMG downloadable + brew installable, tagged v1.0.0 release.

**Post-launch (not this phase's exit):** croc README PR, HN/Reddit/Mac-blog launch — separate marketing effort, out of app scope.

- [ ] Phase 7 complete

## Phase 8+ — V1.x backlog (unplanned, plan when reached)

F20-F29, F31-F35 per `docs/knowledge/features.md`; F37 (Wi-Fi Aware) later. Suggested clusters: proxies/tuning (F20-F28), Mac relay server (F29), quick-send + deeplinks + saved codes + Shortcuts (F31-F34), diagnostics (F35).

---

## Phase session protocol (copy into each phase kickoff prompt)

```
Read PLAN.md, CLAUDE.md, docs/knowledge/features.md, docs/knowledge/apple-platform-constraints.md, and phase-specific Required reading. Execute Phase N: write detailed plan with superpowers:writing-plans, then implement with superpowers:subagent-driven-development. Verify per exit criteria. End with docs self-heal + tick PLAN.md checkbox + note deviations. Give simple summary of all things done.
```

Required reading per phase: 1 → ADR 0006, `what-is-croc.md`; 2 → `prior-art.md`; 3-4 → `apple-platform-constraints.md` (again); 5 → `what-is-croc.md`; 6 → `prior-art.md`; 7 → ADR 0007.
