# 0012. Settings, power options and trust UI choices (Phase 5)

Date: 2026-07-23. Status: accepted.

## Context

F13-F19 needed a persisted settings layer feeding `EngineOptions`, F19 (croc `--ask`) needed sender-side prompt plumbing the engine deliberately lacked (ADR 0008 era), and F36 needed a truthful relay indicator.

## Decisions

1. **`AppSettings` @Observable store, UserDefaults-backed, didSet persistence.** Matches the `OutputFolderStore` pattern; no @AppStorage (controller needs non-View access). Relay string fields store `""` for "use croc default" so the UI can show defaults as placeholders; `effective*` accessors always hand the engine explicit values. `persist` flag gates writes so AutoVerify can override per-run; the flag is only flipped when a harness `--auto-*` arg is present (a Phase 5 final-review Critical: unconditional `persist = false` silently killed all real persistence).
2. **Sender Ask bridge = fd0 pipe + early confirm + per-file answers.** croc's sender `--ask` prompt is gated only on `Options.Ask`, not `NoPrompt`, and fires once PER FILE (`TypeRecipientReady` handler). So: sender sessions with Ask install the same dup2 stdin pipe as receive (sender-only helper, receive path untouched); the app shows `.confirmSend` at `.connected` (pipe writes buffer, answering before croc asks is safe); `respond(true)` writes one `y\n` per `filesInfo` entry before closing (single answer starved multi-file sends, second final-review Critical). Decline = `cancel()` (EOF at the prompt refuses safely; croc checks the input error before its default-yes).
3. **Relay pair blanking for CLI parity.** Customizing one relay address blanks the other (`engineRelayAddresses`), mirroring croc's cli.go; otherwise croc dials the public IPv6 relay first and can win the race while the trust badge claims the custom relay (final-review Important). Never both empty. Deliberate divergence: when BOTH are customized we keep both (CLI blanks relay6 unconditionally); user-favorable, no public leak.
4. **Ask beats autoAccept on receive** (`autoAccept && !bothSidesConfirm`): the engine's autoAccept path closes the prompt pipe, and croc forces the receiver prompt when either side set Ask, so EOF would auto-decline.
5. **Auto-accept (F18) skips `.incoming` but keeps the unsafe-name brake**: with autoAccept croc proceeds immediately; the controller cancels with a dedicated message if `ReceivedName.isUnsafe` fires (defense-in-depth; croc v10.5.0 sanitizes names itself, so this is mostly dormant).
6. **Trust UI reads `controller.activeRelay`, captured at transfer start** (not live settings), so mid-transfer settings edits cannot make the badge lie. `relayKind` classifies custom if either address is customized.

## Consequences

- Settings UI is one shared `PowerSettingsSections` embedded in the macOS Settings scene and an iOS `Route.settings` screen; routes grew `settings`/`howItWorks`.
- Harness spot-proofs: `MAC-RELAY-OK` (local `croc relay` on 9021-9023 + `harnessDisableLocal` kills the LAN race + relay log), `MAC-NOCOMP-OK`, `MAC-ASK-OK` (2-file directory pins the per-file regression). Ask CLI receive needs piped stdin WITHOUT `--ignore-stdin`, and backgrounded commands need an explicit stdin redirect (bash silently rebinds background stdin to /dev/null).
- Backlog: autoAccept + remote-ask decline copy blames the wrong side; iOS relay password field wants autocap/autocorrect off; relay password sits in plaintext UserDefaults (sandboxed container, croc relay passwords are low-sensitivity; keychain later); `respond()` writes block the actor at ~8k+ files with Ask.
