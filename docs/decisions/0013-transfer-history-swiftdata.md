# 0013 — Transfer history on SwiftData, privacy-bounded, harness-isolated

Date: 2026-07-24. Status: accepted. Context: Phase 6 (F12).

## Decision

- **SwiftData** for history (`TransferRecord` @Model + `HistoryStore` wrapper): the only V1 persistence need beyond UserDefaults; zero new dependencies; @Query gives live list updates for free.
- **Privacy bounds baked into the model:** at most 20 file names (`maxNames`), code *hint* = first segment only ("7291-…"), never file contents, never full code phrases. Bookmarks (for re-send) stored **all-or-nothing at capture** — complete set or empty, capped at 200 items (`maxBookmarks`) — so "Send Again" can never silently re-stage a partial selection; records without bookmarks simply don't offer re-send. Re-send still drops files that vanished since capture (user sees the staged list before sending).
- **Harness isolation at container level:** `--auto-*` launches get an in-memory `ModelContainer` (`HistoryStore.makeContainer(inMemory:)`, gated on `AutoVerify.isHarnessRun`) — the SwiftData parallel of `settings.persist = false`. AutoVerify writes `verify-history.txt` (`records=<n>`) and `verify-app-mac.sh` gates `MAC-HISTORY-OK` on `records=1`, which doubles as a regression alarm for the isolation itself.
- **Re-send routes through `AppRouter.openSend(with:)`** — same path as dock drops, inheriting busy-queueing. Bookmark existence probes must `startAccessingSecurityScopedResource()` before `fileExists` on BOTH platforms (sandbox denies even stat on an unopened scope; found on macOS in task review, the iOS twin found by final review).
- **Corrupt store fallback = memory-only container**, not a launch crash.

## Rejected

- Index-pairing `names[i]`↔`bookmarks[i]` (capped names vs uncapped bookmarks made alignment a trap — all-or-nothing removed the pairing entirely).
- Custom history file/JSON (reinvents change tracking @Query already provides).
- Recording harness transfers into the real store (dev-machine history pollution).
