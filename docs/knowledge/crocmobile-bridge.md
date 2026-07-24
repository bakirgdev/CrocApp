# crocmobile / CrocKit engine bridge

Facts from Phase 1 (2026-07-23). Architecture rationale: ADR 0006, ADR 0008.

## Layers

```
croc v10.5.0 (go.mod pin) → crocmobile/ (Go wrapper) → gomobile bind →
CrocKit/Croc.xcframework (gitignored, scripts/build-xcframework.sh) →
CrocKit Swift package (CrocEngine actor, AsyncStream<TransferEvent>) → app
```

## gobind surface (naming)

- xcframework: `Croc.xcframework`; framework MODULE is `Croc` (from `-o` basename) → `import Croc`. ObjC symbol prefix is `Crocmobile` (from package name): `CrocmobileOptions`, `CrocmobileTransfer`, `CrocmobileStartSend/StartReceive` (NSError**), protocol `CrocmobileDelegate` → Swift `CrocmobileDelegateProtocol`. Don't use `initWithRef:`.
- gobind type rules: no `[]string`/unsigned/struct slices. Paths newline-joined, ports comma-joined, structured payloads as JSON strings.
- Delegate callbacks arrive on Go threads; DelegateBridge only yields into AsyncStream; consumers hop to MainActor.

## Event/JSON contract (Go session.go ↔ Swift Models.swift)

- fileList `{"files":[{"name","size"}],"emptyFolders","totalSize"}`
- progress `{"currentFile","totalFiles","fileName","fileSent","fileSize","bytesFinished","totalSize","step"}`, step ∈ waiting|connected|transferring; `fileSent` is per-current-file (croc `TotalSent` resets per file)
- summary `{"success","files","totalSize"}`; a malformed/undecodable `done` summary yields `.failed("malformed done payload")` and finishes the stream. Malformed `progress` payloads are dropped silently (advisory; next 10 Hz tick retries).
- Sub-100ms transfers may deliver `done` with no `connected`/`progress`/`fileList` events — UI keys off `done`/`failed` only.
- `progress` keeps ticking (~10 Hz, step `connected`) while the accept prompt raised by `fileList` is unanswered — consumers must not let it clobber their prompt state (croc blocks in GetInput until `Respond`).
- `.failed` semantics: local cancel during the accept-prompt window surfaces croc's `"refused files"` string, not "cancelled" — map wording in UI layer.

## Engine behavior invariants

- One transfer at a time (ADR 0008); second start → `CrocEngineError.transferActive`. Brief window after `done` where the next start can still throw — retry once.
- Receiver MUST set `outDir`; sender sets `workDir` (writable, for text/zip temp files; iOS cwd is `/`).
- Abandoning the event stream cancels the Go session (`onTermination`); `Cancel()` also unblocks a pending accept prompt (closes prompt pipe → croc declines).
- `Options.Ask` is exposed since Phase 5: sender sessions with Ask install the same dup2 fd0 pipe as receive (sender-only helper), and `Respond(true)` writes one `y\n` PER FILE (`promptAnswers = len(filesInfo)`) — croc's sender prompt fires per `TypeRecipientReady`, once per file; a single answer starves multi-file sends at file 2 (EOF ⇒ "refusing files"). Decline/cancel close the pipe; EOF at the Ask prompt refuses safely (croc checks the input error before its default-yes).
- `Quiet` stays false (true redirects process stderr to /dev/null globally); croc progress bar noise on stderr is accepted.
- Go `crocmobile.Options` exports more knobs than Swift wires: `RelayPorts`, `Curve`, `HashAlgorithm`, `ThrottleUpload`, `NoMultiplexing` are settable from Go/`croctest` only — `EngineOptions`/`crocOptions(from:)` never set them. Exposing them in the GUI means plumbing CrocKit first.
- Relay values: `effective*` (AppSettings) always resolve to explicit values for display, since croc's `models/constants.go` does blocking DNS at import and may blank `DEFAULT_RELAY`. What actually reaches the engine is `engineRelayAddresses`, which deliberately blanks the *non*-customized side when only one of v4/v6 is customized (CLI parity, cli.go: customizing one address blanks the other) — croc skips empty relay addresses when dialing, so this stops a custom relay from losing the dial race to the public default. Never leave both empty.

## croc v10.5.0 gotchas (verified against source/live)

- Relay room = `SHA-256(secret[:4]+"croc")` → two codes sharing their first 4 chars collide into one room ("room full"). Generated codes are safe (random PIN prefix); custom codes and test scripts must vary the first 4 chars.
- CLI: custom codes need `CROC_SECRET=...` env on BOTH send and receive (`--code`/positional custom codes refused in non-classic mode); non-tty CLI runs need global `--ignore-stdin` before the subcommand.
- UDP multicast peer discovery can be dead on a LAN (returns zero peers; reproduced with bare peerdiscovery). Fallbacks: relay (automatic) or `--ip` direct. iOS physical devices additionally need the restricted multicast entitlement (constraints doc §2).
- v10.5.0 auto-reconnects dropped transfers (≤10 attempts) — peer-death surfaces slowly; scripts must bound with timeouts.
- Sender-first start ordering matters: receiver connecting before the sender registered the room can corrupt the PAKE handshake (`invalid character` errors). GUI flows are naturally sender-first; scripts must be.
- Unconditional stdin prompts (empty-folder overwrite, unzip overwrite) exist beyond the accept prompt; EOF on fd 0 makes them take safe "no" defaults — the prompt-pipe close guarantees this.

## Verification harnesses

- `scripts/verify-interop.sh` — 9 scenarios crocmobile↔CLI (file/folder/text both ways, decline, cancel both ways mid-wire via `--throttleUpload 200k`, forced relay, LAN via `--ip`). Cancel scenarios assert received-file mismatch (unfakeable by log noise).
- `scripts/verify-app-sim.sh` — boots sim, installs app, CLI→app via `--auto-receive CODE` launch arg, gates on exact `ok success=true` + byte diff. Since Phase 2 the launch args drive the real UI state machine (`AutoVerify` → `TransferController`, accept via `respond(true)`), not engine-level autoAccept.
- `scripts/verify-app-mac.sh` — macOS app both directions plus local-only: CLI→app (`--auto-receive`), app→CLI (`--auto-send PATH --code CODE`, custom-code path; source file must live in the app container — sandbox), app→CLI with `--local` (sandboxed relay-listener proof, CLI receives via `--ip`), app→CLI via custom self-hosted relay (`croc relay --ports 9021,9022,9023` + `--relay localhost:9021`), `--no-compress` path, and `--ask` both-sides-confirm (auto-answered via `AutoVerify` `.confirmSend`). Since Phase 4 the app declares document types, so bare adjacent argv tokens are document-open candidates — flags only (`--code CODE`), and every launch needs `-ApplePersistenceIgnoreState YES` (headless window-restoration hang).
- `crockit-verify` (CrocKit executable) — Swift-layer send/receive/cancel-after-ms/`twice` (two transfers one process — proves fd0/stdout/cwd/mutex restoration composes).
- macOS app verified via same `--auto-receive` route; container Documents at `~/Library/Containers/com.bakirgdev.CrocApp/Data/Documents/`.

## Toolchain

- Go ≥1.26.5 (brew; `crocmobile/go.mod` pins `go 1.26.5`), gomobile+gobind auto-installed by build script (currently `@latest`, unpinned — pin when CI lands). Xcode 26.6 binds clean (no #53316-class friction). macOS slice arm64-only (golang/go#73119); iOS device App Store layout issue golang/go#66500 is a Phase 7 concern.
- CI notes: verify scripts need outbound network (public relay) + `CROC`/`SIM` env; fresh clone must run `scripts/build-xcframework.sh` before any Swift build (binaryTarget points at gitignored artifact).
- rtk gotcha: plain `rtk xcodebuild` truncates long output before shell redirection sees it (final `BUILD SUCCEEDED` line lost) — use `rtk proxy xcodebuild` for build logs.
