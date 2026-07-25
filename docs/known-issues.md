# Known issues

Triaged defects, accepted papercuts, and deferred work in the shipped app. Every item here was found during review and consciously not fixed. None block V1 unless marked.

This exists so a session does not re-discover and re-report the same thing. If you fix one, delete the line. If you decide one is permanent, move it to "Accepted" and say why.

Engine and bridge invariants live in `knowledge/crocmobile-bridge.md`; UI state-machine facts in `knowledge/app-ui-architecture.md`.

## Blocking release

- **Notarization is not real.** `scripts/build-devid.sh` stops at `syspolicy_check distribution`, a dry run. No `notarytool submit --wait`, no `stapler staple`. Homebrew requires codesigning + notarization for official casks since 2026-09-01, so the cask channel in ADR 0007 is blocked (`knowledge/tooling.md`).
- **`AutoVerify` compiles into Release.** The launch-argument harness and its settings overrides ship in the store binary. Gate behind a build flag before submission.
- **`ExportOptions-MAS.plist` is committed but never exercised.** First real MAS export is its first test.
- **Encryption declaration must match.** `ITSAppUsesNonExemptEncryption=false` is in both Config plists; the BIS/ASC answer at submission has to agree.
- **App accent is `#2BA35A`, the design system says `#1E9E6A`.** `app/CrocApp/Assets.xcassets/AccentColor.colorset` predates `design/`, carries a single universal colour, and has no dark variant (`design/brand.md` specifies `#1E9E6A` light / `#2DC585` dark). The design system is canonical; the app has not been restyled yet.

## Transfer controller

- Auto-accept against a remote sender running `--ask` auto-declines, and the resulting copy blames the wrong side ("the other side declined").
- `blockedAutoAccept` is mostly dormant — croc has sanitised incoming names since v10 — and a tiny transfer can reach `.done` before the block is evaluated.
- `respond()` writes prompt answers synchronously, one per file. At ~8k+ files with Ask enabled this could block the actor.
- The async conflict scan's write-back guard is shape-based (`if case .incoming`), not generation-based: a stale scan from a previous transfer could in principle land on a new `.incoming`.
- The resend condition is triplicated across `HistoryView`.
- Cross-flow status bleed: an active Send renders on the Receive screen, because `isActive` is direction-agnostic. One-at-a-time is still enforced.
- No Cancel during `.incoming` — Decline is the only exit, and the terminal event can lag while croc auto-reconnects.

## Settings and trust

- Relay password is stored in plaintext `UserDefaults`. Keychain is the fix.
- iOS relay-password `TextField` lacks `.textInputAutocapitalization(.never)` and `autocorrectionDisabled`.
- When both relay addresses are customised, both are sent. The croc CLI blanks `relay6` in that case. Deliberate divergence, revisit if a peer ever disagrees.

## History

- `HistoryStore.clear()` uses `delete(model:)`. Whether a live `@Query` updates from it is unconfirmed in manual QA; fallback is a fetch-and-delete loop.
- Up to 200 synchronous `bookmarkData` calls run on the main actor at send tap.
- `blockedAutoAccept` transfers record as `.cancelled`.
- `AutoVerify` duplicates the history-write path.

## iOS

- A queued `BGContinuedProcessingTask` request is not cancelled when the transfer ends before the system adopts it.
- `backgroundExpired` is ignored in `run()`'s catch, so an expiry that surfaces as a thrown error gets generic copy.
- Manifest-name validation in `ShareInbox` does not match `ReceivedName`'s rules.
- "Open in Files" silently no-ops for provider-picked folders (`shareddocuments://` resolves local paths only). Consider hiding the button there.
- `UIFileSharingEnabled` is declared twice.
- `ShareStagingView`'s cancel closure is unused.
- The staged-files sheet is only offered on the next foregrounding, and starting a send from it does not route to a status view.
- Onboarding's `onDismiss` re-offer of the staged sheet has no `!controller.isActive` gate.

## macOS

- Dock-drop URLs queue invisibly: no badge, no route once the running transfer completes. The user has to visit Send to find them.
- `isBusy` mirrors `controller.isActive` one cycle late.
- `SendView`'s drop handler returns `true` even when every dropped file was already staged.
- `createDirectory` failure is swallowed in `OutputFolderStore.defaultFolder`.
- The receive-folder guard is duplicated across the iOS and macOS `doneView` branches.
- `pendingSendURLs` deduplicates against already-picked URLs but not within a single dropped batch.
- `AppRouter` is a singleton with no reset hook; multiple windows share one navigation path.

## Landing page

- **`web/landing/assets/img/og.jpg` is hand-maintained.** The Chrome-headless renderer that built it from an HTML source is gone, so a colour or type token change no longer propagates to the social card. Redraw it by hand, or rebuild the renderer, before the token set moves again.

## Accepted

- **`OutputFolderStore.select` silently no-ops if bookmarking fails.** Rare, and the alternative is an error path for a condition the user cannot act on.
- **Receive list identity is by file name.** Duplicate names within one transfer are a croc-level concern, not a UI one.
- **No explicit `stopScanning` when the QR scanner sheet dismisses.** VisionKit tears down with the view controller.
- **`.combine` on the transfer progress view may hide the percentage from VoiceOver.** Worth a real accessibility pass, not a spot fix.
- **Gesture-level flows are not machine-verified.** Drag-and-drop, camera QR, and taps have no XCUITest coverage by project rule. Verify them by hand.
