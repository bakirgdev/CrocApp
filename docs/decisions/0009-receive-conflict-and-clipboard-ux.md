# 0009. Receive conflicts via accept-sheet with overwrite on; explicit paste; croc:// QR payload

Status: accepted
Date: 2026-07-23

## Context

Phase 2 UI needed concrete semantics for three underspecified areas: F8 (overwrite/resume confirm), the prior-art "clipboard auto-detect" pattern, and the QR payload format. Engine constraint: `overwrite` is set at `startReceive` time, before the file list (and thus any conflict) is known; croc cannot re-prompt per file through the bridge.

## Decision

- **F8:** receive always starts with `overwrite = true`. Conflicts are detected Swift-side when `.fileList` arrives (existence check against outDir) and surfaced in the accept sheet: "N item(s) already exist and will be replaced. Partially received files resume." Accept means replace; the only refusal is declining the whole transfer. Unsafe names (absolute, `..`, backslash, NUL) block Accept entirely (`ReceivedName.isUnsafe`, defense-in-depth over croc's own post-2023-audit sanitization).
- **Clipboard:** no silent pasteboard reads. `PasteButton` on both platforms (avoids iOS paste-privacy banner); pasted/scanned strings go through `ReceiveView.extractCode` (strict: optional `croc://` prefix, ≥6 chars, no whitespace).
- **QR payload:** `croc://<code>` — future-proofs F32 deeplinks, matches crock's convention; scanner accepts bare codes too.

## Consequences

- Per-file skip/rename is out of scope for V1; would need engine-side prompt bridging per file.
- "Clipboard auto-detect" (prior-art wording) is deliberately weakened to an explicit affordance for privacy.
- UI accept prompt must never be clobbered while unanswered: progress events keep ticking during the prompt (see `TransferController.handle` guard).
