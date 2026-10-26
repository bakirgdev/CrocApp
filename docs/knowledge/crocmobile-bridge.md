# crocmobile / CrocKit engine bridge

The engine contract between Go and Swift, and the croc behaviours it has to work around. UI side: `app-ui-architecture.md`. Terms: `../GLOSSARY.md`.

## Layers

```
croc v11.5.5 (go.mod pin) → crocmobile/ (Go wrapper) → gomobile bind →
CrocKit/Croc.xcframework (gitignored, scripts/build-xcframework.sh) →
CrocKit Swift package (CrocEngine actor, AsyncStream<TransferEvent>) → app
```

The app sees `CrocEngine` through the `TransferEngine` protocol (`CrocKit/Sources/CrocKit/CrocEngine.swift`), so its tests can drive `TransferController` with a fake. A fake has to keep the part of the contract the controller relies on, which the protocol's doc comment lists.

## gobind surface (naming)

- The xcframework is `Croc.xcframework`. The framework module is `Croc` (from the `-o` basename), so Swift writes `import Croc`.
- The ObjC symbol prefix is `Crocmobile` (from the Go package name): `CrocmobileOptions`, `CrocmobileTransfer`, `CrocmobileStartSend` and `CrocmobileStartReceive` (both take an `NSError**`). The protocol `CrocmobileDelegate` becomes `CrocmobileDelegateProtocol` in Swift.
- gobind type rules: no `[]string`, no unsigned types, no struct slices. Paths are newline-joined, ports are comma-joined, structured payloads are JSON strings.
- Delegate callbacks arrive on Go threads. `DelegateBridge` only yields into the `AsyncStream`; consumers hop to the main actor.

## Event and JSON contract

Go side: `crocmobile/session.go`. Swift side: `CrocKit/Sources/CrocKit/Models.swift`.

| Event | Payload |
|---|---|
| fileList | `{"files":[{"name","size"}],"emptyFolders","totalSize"}` |
| progress | `{"currentFile","totalFiles","fileName","fileSent","fileSize","bytesFinished","totalSize","step"}` |
| summary (`done`) | `{"success","files","totalSize"}` |
| error | `{"code","message"}` (see "Failure codes") |
| stored receipt | `{"id","origin","uploadToken","link","expiresAt","downloads"}` (see "Stored transfers") |

Rules that follow from the payloads:

- `step` is `waiting`, `connected` or `transferring`. A stored upload also reports `preparing` while it hashes files.
- `fileSent` counts bytes of the current file only, because croc resets `TotalSent` for each file.
- An undecodable `done` summary becomes a `.failed` event (code `other`, message `malformed done payload`) and finishes the stream.
- An undecodable `progress` payload is dropped silently. Progress is advisory and the next tick retries.
- A transfer under about 100 ms can deliver `done` with no `connected`, `progress` or `fileList` event. The UI keys off `done` and `failed` only.

### Progress cadence

- `poll()` samples at 10 Hz but emits only when a field changed. Idle stretches stay quiet, notably an unanswered accept prompt where nothing moves.
- The schema is unchanged, and no consumer may treat a tick as a heartbeat.
- A tick must never overwrite a consumer's prompt state: croc blocks in `GetInput` until `Respond`.

### Respond

`Respond(accept bool, policy string)` returns at once and answers on its own goroutine.

- `policy` is `PolicyKeepBoth` (`"keepBoth"`) or `PolicyReplace` (`"replace"`). It is read only on a receive accept. Swift mirrors the strings as `FilePolicy` and `CrocEngine.respond(accept:policy:)`.
- A sender-side Ask accept writes one `y\n` per file. A large batch can fill the pipe buffer and block until croc drains it over the network.
- The caller is the `CrocEngine` actor, which runs queued work to completion. A synchronous write would hold up a following `Cancel`.
- Do not make it synchronous for "ordering": `session.respond` serialises on `promptM`, and `closePrompt` is idempotent.

## Failure codes

`OnError` receives `{"code","message"}` JSON (`crocmobile/errors.go`). `StartSend` and `StartReceive` errors carry the same JSON as their text, because gobind exposes only the text (as `NSError.localizedDescription`). CrocKit decodes both into `EngineFailure`.

- `code` is one of `peerVersion`, `relayUnreachable`, `noPublicRelay`, `declined`, `refused`, `roomFull`, `badPassword`, `wrongCode`, `cancelled`, `connectionLost`, `storeLimit`, `storeExpired`, `invalidSetting`, `transferActive`, `engineStuck`, `joinedEarly`, `other`.
- An unknown code, or a payload that is not JSON, decodes as `other` with the raw text.
- `message` is croc's text and is for logs only. The UI maps wording from the code.
- A recovered panic reports `other`.

How `classify` picks a code:

| Code | Trigger |
|---|---|
| `peerVersion` | text `unsupported PAKE protocol version` |
| `declined` | the peer's `peer error: refusing files`. A peer's cancel looks the same on the wire. |
| `refused` | this side's `refused files` (prompt answered no, or EOF) |
| `cancelled` | `errors.Is(err, context.Canceled)`. croc returns the context error unwrapped. |
| `roomFull` | `room full`, and the control connection's `relay admission rejected` |
| `badPassword` | the relay rejected the relay password (`bad password`), not the code phrase |
| `wrongCode` | peers met with different codes: `password mismatch` (sender), `could not secure channel` (receiver), `pake not successful`, `message authentication failed` |
| `relayUnreachable` | `croc.ErrRelayConnection`, `croc.ErrDERPConnection`, `tcp.ErrAdmissionLimited`, rate limiting, dial and DNS failures |
| `connectionLost` | unexpected EOF, reset, broken pipe, `transfer disconnected` |
| `joinedEarly` | text `problem with decoding: decompress message`, on a receiver that joined before the sender (see "Start order: sender first") |
| `noPublicRelay` | this package's own `codedError`, raised by `generatePublicCode`. A start cancelled during the probe reports `cancelled` instead |
| `transferActive` | this package's own `codedError`: a start while another transfer holds `activeMu`. CrocKit throws `CrocEngineError.transferActive` for it |
| `engineStuck` | this package's own `codedError`: the cancel watchdog's terminal event, and every start while a stuck session holds `activeMu` (see "Cancel and teardown") |
| `storeLimit`, `storeExpired` | stored-transfer HTTP refusals (see "Stored transfers") |
| `invalidSetting` | an Advanced option failed validation, or `ValidateSetting` refused a link server (see "Validating a setting") |

Notes:

- Order matters in `classify`: a peer's refusal also cancels croc's context, and a bad relay password is reported as `could not connect to`.
- croc exports sentinels for relay failures only, so the rest is matched on croc v11.5.5 text. `errors_test.go` pins the live ones against real croc clients and an in-process relay.
- A local `Cancel()` during the accept prompt cancels the context before it closes the prompt pipe, and `GetInputContext` returns the context error whenever the context is done. By reading the source that failure is `cancelled`, not `refused`. Not verified live.

## Stored transfers

Code: `crocmobile/store.go`. They wrap croc v11's `storeclient`.

- API: `StartStoreSend(paths, *StoreOptions, Delegate)`, `StartStoreReceive(link, outDir, *StoreOptions, Delegate)` and the blocking `RevokeStored(origin, id, token, *StoreOptions)`. For receive and revoke, `StoreOptions` carries only the proxies.
- A stored transfer uses the same `Transfer` handle and `activeMu` as a live one, but no cwd, stdin or stdout.
- A send ends with `OnStored(receiptJSON)` then `OnDone`. The receipt is the only copy of the revoke token and of the key inside `link`, so the app keeps it in the Keychain. `expiresAt` is RFC 3339 UTC.
- A receive reads the manifest without claiming it, raises `OnFileList` (same payload as a live receive) and waits for `Respond`. A decline ends with `refused` and leaves the transfer unclaimed.
- `RevokeStored` takes no lock and treats HTTP 404 and 410 as success. It passes a zero key: `storeclient` validates a whole share, and revoke authenticates by token only (the croc CLI does the same).
- `storeclient`'s callbacks run on its worker goroutines, so each is wrapped in a recover.

Conflicts on receive:

- `storeclient` installs each file with a rename that replaces whatever exists, so Replace needs no work.
- Keep Both is settled before the download, by renaming manifest entries to `name (1).ext` (`keepBothNames`). The names are local: the server and the chunk encryption never see them.
- A failed or cancelled receive leaves `storeclient`'s resume state (`.croc-store-<id>.json` and `.<name>.croc-<id>.part`) in `outDir`. That is the only way back in within the server's 30-minute claim lock.
- Resuming after Keep Both renamed an installed file starts fresh state and a new claim. The lock refuses it until it expires.

Limits and error mapping:

- `StartStoreSend` refuses more than 100 files or more than 1 GiB before hashing (`storeLimit`). These match croc's store defaults, so a server with lower limits still refuses at upload time.
- It also refuses more than 100 downloads. That cap is crocmobile's own: the croc store default is 1 download.
- Server refusals map in `storeHTTPCode`: 404 and 410 give `storeExpired`; 413, 429, 507 and 400 with "declaration" in the message give `storeLimit`.
- Network failures reuse `relayUnreachable`, so the app words that copy by context.

## Engine behavior invariants

- One transfer at a time. A start while another transfer holds `activeMu` fails with `transferActive`, and CrocKit throws `CrocEngineError.transferActive`.
- A start made once the previous transfer's terminal event has arrived succeeds, with no retry:
  - Go frees `activeMu` after it restores every process global and before `OnDone` or `OnError` (`run` in `session.go`, `runStore` in `store.go`). Each transfer has its own delegate, so the last event of one cannot reach the next.
  - `DelegateBridge` records the terminal call (`hasEnded`). `CrocEngine` frees its slot on it instead of waiting for `onTermination`'s task. A stream finished early on a malformed payload does not count, because its Go session still runs.
  - `TestStartFromTheTerminalEventGetsTheEngine` (a start from inside `OnError`) and `crockit-verify twice` prove it.
- A receiver must set `outDir`. A sender sets `workDir` (writable, for text and zip temp files; the iOS cwd is `/`).
- `os.Chdir` restore failures are logged (`restoreWD` in `session.go`), and an `os.Getwd` failure fails the start.
- `Quiet` stays false, because `Quiet = true` replaces `os.Stderr` process-wide with `/dev/null`. croc's progress bar noise on stderr is accepted.

### Cancel and teardown

- Abandoning the event stream cancels the Go session (`onTermination`).
- `Cancel()` cancels the context and also closes the prompt pipe. After a context cancel, `GetInputContext` returns, but its read goroutine stays blocked until the pipe closes.

A start is cancellable before it returns:

- `startSession` creates the session's context before its slow setup, and `CancelStart()` (`CrocmobileCancelStart`) cancels it while `StartSend` or `StartReceive` has not returned. The same context then carries the transfer, so a cancel that lands late in setup is not lost.
- The setup step that matters is the generated-code relay probe: `generatePublicCode` runs on that context, so a cancel ends it at once and the start fails with `cancelled` instead of waiting up to 1 s (`publicrelay.ProbeTimeout`).
- `CancelStart` is process-wide, not tied to a transfer, because there is no `Transfer` yet. CrocKit calls it from the task-cancellation handler of its start, which runs one at a time on the `CrocEngine` actor. `TransferController` cancels the task awaiting the start when **Cancel** is tapped before it has an ID.

The cancel watchdog (`watchCancel`, `session.go`):

- A cancel arms it. If croc's call has not returned 15 s later (`stuckAfter`), the delegate gets `engineStuck` as its terminal event and the session is marked stuck. Every later start then fails at once with `engineStuck`.
- The lock stays held. Forcing it open would let a new session change the cwd, stdin and stdout under a croc that still runs. Only a relaunch frees it (`../known-issues.md`, "Accepted").
- A session sends one terminal event (`session.terminal`). If croc returns after all, `run` clears the mark and frees the lock without a second event.
- Why 15 s: croc v11.5.5's dials and reads follow its context, its reconnect backoff is capped at 5 s, and `run`'s own teardown waits (the stdin drain and the poller join) are bounded at 2 s each.

### Ask (both sides confirm)

- `Options.Ask` is exposed. A sender session with Ask installs the same `dup2` fd 0 pipe as a receive.
- `Respond(true)` writes one `y\n` per file (`promptAnswers = len(filesInfo)`), because croc's sender prompt fires once per file. A single answer starves a multi-file send at file 2: EOF reads as "refusing files".
- Decline and cancel close the pipe. EOF at the Ask prompt refuses safely, because croc checks the input error before its default of yes.

### File policy

What a receive does with a file whose name is taken: `keepBoth` or `replace` (`filePolicy`, `session.go`).

- `buildCrocOptions` always hands croc exactly one of `Rename` and `Overwrite`. Neither set, both set, or an unknown policy string all mean keep both (Rename wins).
- croc's third state (both false) is never passed. It prompts `Overwrite ...? (y/N)` on stdin, which on a closed pipe skips the file and, during a zipped-folder unzip, aborts the transfer.
- A file that already exists with identical content is left as is under either policy (croc counts it unchanged).
- Keep Both names come from `utils.UnusedFilename`: `name (1).ext`, `name (2).ext`.

Answers queued for croc's stdin prompts:

- On accept, `respond` sets the policy on the live `croc.Client` before writing `y`, because croc reads `Rename` and `Overwrite` only once the accept prompt is answered.
- It then queues 4096 more answers (`promptPolicyAnswers`) for the prompts that ignore both flags: the empty-folder prompt and the per-member unzip prompt `Overwrite '<path>'? (y/N)`.
- Every queued answer is `n`, under either policy (`keptPromptAnswers`). The unzip then skips an existing member and keeps the local copy. So Replace overwrites files through `Overwrite` but never a zip member.
- Never `y`: croc v11 re-runs the accept prompt on the sender's new file list after each reconnect, and a queued `y` would accept a list the user never saw. As a result, a reconnect after a manual accept is refused (`../known-issues.md`, "Accepted").
- 4096 two-byte lines fit a fresh pipe buffer on Darwin and Linux, so the write never blocks.
- With `AutoAccept` there is no accept prompt. The same `n` batch is written at session start and the pipe is closed (`answerUngatedPrompts`). It must be `n` because croc still forces the accept prompt when the remote sender ran `--ask`. That prompt reads the first queued line, and `y` would accept a transfer the sender wanted confirmed by hand.
- Past 4096 colliding zip members an unzip hits EOF and fails, leaving the received zip (`../known-issues.md`, "Accepted").

### Options that Swift wires

- `crocOptions(from:)` sets every `crocmobile.Options` field. `Rename` and `Overwrite` both come from the one knob `EngineOptions.whenFileExists` (`FilePolicy`, default `.keepBoth`).
- Advanced options (throttle, multicast group, sender IP, proxies) are the ones the app sets. See "Advanced options on the wire". `buildCrocOptions` fixes the rest to what the croc CLI defaults to (`cli.go`), because the library does not default them itself: curve `p256`, local relay ports 9009 to 9013 (`crocBasePort`, `crocTransfers` in `network.go`). The hash is left empty, so croc picks xxhash (`sendCollectFiles` in `croc.go`).
- `croctest` can set the same fields from the command line.

### Transport

There is no transport option. The engine is built with croc's `croc_no_tailcat` tag, so `Options` carries no `Transport` and `buildCrocOptions` leaves croc's at the default `auto`. Under the tag `auto` uses the relay and the LAN, never Tailcat. "Transport and Tailcat" has the details and the checks.

### Relay values

Swift passes the relay settings as stored. `crocmobile/relay.go` resolves them for send and receive alike, mirroring the v11 CLI (`cli.go`: `usesPublicRelay`, `assignPublicRelayForCode`, `selectPublicRelay`).

- A relay setting that is blank or equals `models.DEFAULT_RELAY` or `DEFAULT_RELAY6` (`croc.schollz.com:9009`, `croc6.schollz.com:9009`) is not custom (`customRelays`). `models` no longer resolves relay DNS at import, so those are plain strings.
- With no custom relay and **Local Network Only** off, the relay is `publicrelay.Relays()[codephrase.RelayIndex(code, len(relays))]`, with v6 blanked and `PublicRelay` set.
- A custom relay is passed as set and the other side is blanked. A custom pair keeps both (`../known-issues.md`, "Accepted").
- A blank password means croc's default.
- `RelayForCode` exposes the code's pool relay.

Generated codes on the public pool:

- The code is drawn with `codephrase.GenerateForRelay` for the first relay to answer a ping. The choice is cached in memory and forgotten after a send fails with `croc.ErrRelayConnection`.
- If no relay answers, the send fails like the CLI, with `noPublicRelay`. The app shows its own copy pointing to **Local Network Only**.
- The probe runs on the session's context, so `CancelStart` ends it at once (see "Cancel and teardown").
- There is deliberately no "draw a code anyway" fallback. After the relay dial fails, croc waits only about 10 s for a LAN peer (`defaultAlternateSenderRouteTimeout`), so a code shown offline would expire before the receiver could type it.

## croc v11.5.5 gotchas (verified against source)

### Rooms and codes

- How a code selects the room, and when two codes collide: `what-is-croc.md`, "Rendezvous". In the bridge, `codephrase.Parse` does the split, and the legacy split makes `code[5:]` the PAKE passphrase.
- Custom codes and test scripts must vary the selector.

### Transport and Tailcat

How Tailcat works, its 128 MiB threshold and the servers it contacts: `what-is-croc.md`, "Transport". CrocApp ships without it.

- `scripts/build-xcframework.sh` passes `-tags croc_no_tailcat` to `gomobile bind`. The tag swaps croc's `tailcattransport` for a stub (`src/tailcattransport/transport_unsupported.go` in croc; `Available()` is false), which drops Tailscale's WireGuard, gVisor and DERP from the binary. `go list -tags croc_no_tailcat -deps` in `crocmobile/` finds 0 gVisor packages and 0 `wireguard-go` packages (42 gVisor packages without the tag).
- Every other Go build of `crocmobile/` carries the same tag, so tests match what ships (`BUILDING.md`, "What build-xcframework.sh does"). `TestBuildIsRelayOnly` fails a test run without it by checking `tailcattransport.Available()`.
- Size: the shipped executable halves (`BUILDING.md`; measured sizes are in `CHANGELOG.md`).
- Effect on a transfer, observed with the stock croc v11.5.5 CLI (`verify-interop.sh` scenario 13):
  - A CLI on its default `--transport auto` still logs `Tailcat bootstrap region prepared` and `auto transport size decision: ... selected=derp` for a send of 128 MiB or more, because it prepares Tailcat before it knows the peer. Neither line means Tailcat carried data.
  - The peer does not advertise Tailcat, so the CLI logs the plain line `selected croc relay data transport` and sends no `tailcat-offer`. Against a Tailcat-capable CLI the same send logs `tailcat-offer`, `starting Tailcat server` and `selected staged croc relay data transport` or `... after Tailcat fallback`.
  - With `tailcat.dev` unreachable (a dead proxy in the CLI's environment) the transfer still completes over the relay, in the same time.
- A CLI sender with `--transport derp` (Tailcat only, no relay fallback) cannot send to this build. The CLI fails with `--transport derp requires a Tailcat-capable peer` and exits 1. A CrocApp receiver fails within seconds with `EVENT error {"code":"other","message":"peer requires Tailcat, but Tailcat is disabled or unavailable locally"}` (`activateSecureChannel` in `tailcat_negotiation.go`). It does not hang. The code is `other`: `classify` in `errors.go` has no case for it. `--transport` exists only on a send, so the wrapper cannot be the `derp` side.
- A receive from a CLI sender on `auto` or `relay` works as before.

### CLI behaviour that bites scripts

- Custom codes need `CROC_SECRET=...` in the environment on both send and receive. On Unix, `send --code X` without it prints instructions and exits 0 without sending. A receive code given as an argument without it prints a message and returns. `croc --classic` lifts both.
- A non-tty CLI run needs the global `--ignore-stdin` before the subcommand. Otherwise a piped stdin is read as the thing to send.

### LAN discovery

- UDP multicast peer discovery can be dead on a LAN and return zero peers. It was seen on one AP-isolated network, with the previous croc pin, and not re-tested on v11. Root cause not isolated.
- Fallbacks: the relay (automatic: the receiver races discovery against the relay dial) or `--ip` for a direct connection.
- Physical iOS devices also need the restricted multicast entitlement (`apple-platform-constraints.md`, "Hard constraints", item on multicast).

### Reconnects

croc retries a dropped transfer up to 10 times (backoff from 100 ms, doubling, capped at 5 s). Only then it fails with `transfer disconnected after 10 reconnect attempts`. Peer death therefore surfaces slowly, and scripts must bound their waits with timeouts.

### Start order: sender first

- On joining the room, the receiver sends a `pake1` local probe and waits 500 ms for the reply (`localProbeResponseTimeout`).
- If the sender is not there yet, the probe times out and the receiver carries on with its main PAKE and enters the transfer loop.
- When the sender arrives, it answers the old `pake1`. The receiver decodes that frame as a transfer message and fails with `problem with decoding: decompress message: decompress data: flate: corrupt input before offset 6`. `classify` reports it as `joinedEarly`.
- The receiver sends the probe only with LAN on (`DisableLocal` false), so only then does the race exist. `errors_test.go`, "receiver joined before the sender", reproduces it against an in-process relay.
- The sender fails too. A croc v11.5.5 CLI sender with LAN on reports `could not secure channel`, which `classify` cannot tell from a real code mismatch (`wrongCode`). A sender with LAN off keeps waiting.
- Generated-code GUI flows are sender-first. Custom codes are not: a receiver who types an agreed code before the sender taps Send, or an app receiver waiting on a CLI sender using `CROC_SECRET`, hits it (`../known-issues.md`, "Accepted").
- Harnesses start the receiver only after the sender reported its code: see "Verification harnesses".

### Prompts beyond the accept prompt

The empty-folder overwrite prompt and the unzip overwrite prompt ignore `Rename` and `Overwrite` and read stdin. The unzip prompt appears once per archive member that already exists, in a zipped-folder receive. crocmobile answers both from the policy batch (see "File policy").

Without an answer:

- The empty-folder prompt takes EOF as "no".
- The existing-file prompt skips that file.
- The unzip prompt returns the read error, and croc v11 treats that as an extraction error. The transfer ends `received archive failed validation or extraction`, with the received `.zip` left in the out dir. croc v10 skipped the member instead.

The batch fixes this. `verify-interop.sh` scenario 12 covers it.

### Stdin plumbing

- `utils.GetInputContext` reads from a package-level `bufio.Reader` built over fd 0 at init (`stdinReader`). Replacing `os.Stdin` later changes nothing, so the fd 0 `dup2` stays required.
- That reader is process-wide and buffers ahead. Answers croc never asked for (the policy batch, extra sender-Ask `y` lines) would sit in it and answer the next transfer's accept prompt. A Go unit test showed the next transfer reading `n`, a decline.
- `drainPromptInput` (`session.go`) therefore reads `stdinReader` to EOF through `utils.GetInputContext`, with a 2 s timeout. It runs at session end, after the prompt pipe closes and before fd 0 is restored.

### Zipped-folder sends

- A zipped-folder send writes `<folder>.zip` into the send cwd (`Options.WorkDir`) and marks it with `utils.MarkFileForRemoval`.
- The library deletes it itself only after a successful send. The CLI's `main.go` sweeps the rest with `utils.RemoveMarkedFiles()` on exit.
- crocmobile calls `RemoveMarkedFiles` after every send (success, failure, cancel) and when session setup fails after the zip was made.

## Advanced options on the wire

`Options.MulticastAddress`, `PeerIP`, `Socks5Proxy` and `HTTPProxy` map one to one onto croc's flags of the same name (`buildCrocOptions` and `network.go`). `croctest` takes `-multicast -ip -socks5 -connect`, plus `-no-multi` for `NoMultiplexing`, which only the harness sets.

The curve, hash, base port, transfers and internal DNS are not options. croc settles the curve and hash between the peers itself: a sender adopts the receiver's curve (`c.pakeCurve = string(m.Bytes2)` in `croc.go`, "initialize curve based on the recipient's choice") and a receiver adopts the sender's hash (receiver `--debug`: `using hash algorithm: md5`), so two devices never need to match. The ports matter only to a receiver that dials the sender by `PeerIP`, which a CrocApp sender serves on 9009. A busy port is skipped and the next free ones bind, scanning at most 200 ports (`reserveLocalRelayListeners` in `local_relay.go`, read from source, not observed), so the announced port can differ. If croc cannot bind them all, the send fails at start with `start local relay: not enough open ports to run local relay: reserved N of M` (code `other`).

`verify-interop.sh` scenario 15 runs each against the croc v11.5.5 CLI. The table records what that scenario observed, with the croc source (`src/croc/croc.go`, `comm/comm.go`) read for the reason.

| Option | Which side it matters on | Peer must match? | Mismatch |
|---|---|---|---|
| PeerIP | **Receiver** only (`--ip host:port`). It connects straight to the sender's local relay and skips the public relay and discovery. It works only with a sender whose local relay is on (not `NoLocal`) and reachable. | The sender must listen there. | Nothing listening: it fails at once with `relayUnreachable` (`could not connect to 127.0.0.1:<port>: ... connection refused`), with no fallback to a relay. |
| Multicast address | Both sides of **LAN discovery**. A sender announces `croc<port>` (`croc9009` for a CrocApp sender) on the group, a receiver announces `ok` and listens. The default is `239.255.255.250`, UDP port 9999. | Yes, for discovery: peers on different groups never hear each other. The relay path still works. | Silent: discovery finds nobody, then the relay or `PeerIP` path carries the transfer. |
| SOCKS5, HTTP proxy | The local side's own dials only (CONNECT; SOCKS5 before HTTP). Invisible to the peer. | No | croc bypasses the proxy for local addresses (`utils.IsLocalIP`: loopback, link-local, private ranges). A proxy therefore affects only a public relay dial. With a local relay or a LAN transfer it is never used, with no error. Observed: with the public pool, connections went through a `croctest` proxy on both send and receive. |

Two limits of the harness:

- A transfer across two hosts on a shared multicast group is not covered. croc drops discovery packets from the host's own addresses (`peerdiscovery` `AllowSelf` false), so two peers on one host never find each other, not even two CLIs.
- `NoMultiplexing` and `ThrottleUpload` are sender-side only. They are not a mismatch case; scenarios 6, 7 and 11 use them.
- The sender-IP case needs ports 9009 to 9013 free on the host, because a wrapper sender no longer takes a different base port. The harness waits up to 30 s for them and then fails.

### Validating a setting

`ValidateSetting(field, value string) error` in `network.go` is how the app's settings form asks the engine whether a value is valid, so the form keeps no copy of the rules.

- **One code path.** `settingChecks` maps each field name to its check. `validateNetworkOptions` (run by `startSession` before it takes the lock) loops over it for the five network fields, and `ValidateSetting` looks the field up in the same map. `TestValidateSettingMatchesTransferStart` checks that the two accept and refuse alike.
- **Fields**, as constants: `SettingSocks5Proxy`, `SettingHTTPProxy`, `SettingThrottleUpload`, `SettingMulticastAddress`, `SettingPeerIP` (the `Options` field names) and `SettingStoreServer` (`StoreOptions.Server`). CrocKit's `EngineSetting` reads them through gobind.
- **Result.** `nil`, or the `startError` JSON payload. A refused value has code `invalidSetting`; an unknown field name has code `other`. The call takes no lock, so it works during a transfer.
- **Normalization.** Each check trims the value the way the engine does: `buildCrocOptions` trims the upload limit, sender IP and multicast address, `proxyURL` and `setNetworkGlobals` trim the proxies, and croc's `normalizeOrigin` trims the server. The app passes the text as typed. Blank is valid for every field except `SettingStoreServer`, which needs an origin.
- **Proxy errors never quote the value**, which can carry credentials. `TestValidateSettingNeverQuotesAProxy` includes refusals that come from `url.Parse`.
- **`SettingStoreServer` wraps `validateStoreOrigin`**, the check `StartStoreSend` runs, in code `invalidSetting`. `StartStoreSend` keeps the plain error, so a refused server there still has code `other`.
- **The rules are the engine's, not a mirror of them.** Checked on Go 1.27.3 and croc v11.5.5: `normalizeOrigin` compares the loopback host case-sensitively (`http://LOCALHOST` is refused) and accepts an empty query or fragment (`https://host?`) and an empty host name before a port (`https://:8080`), which `validateStoreOrigin` refuses on top. `net/url` refuses an unbracketed colon in a host for `http` and `https` only and allows a non-ASCII space in any host, so `proxyURL` refuses both for every scheme (`::1:1080`, `socks5://host:1080:2`, a no-break space in the host).

## Verification harnesses

Each harness checks a different layer. `BUILDING.md`, "Verification harnesses" says how to run them. Shell traps are in `tooling.md`, "Shell and harness traps".

### `scripts/lib.sh`

Sourced by `verify-interop.sh`, `verify-app-mac.sh`, `verify-app-sim.sh`, `capture-screenshots.sh`, `build-appstore.sh` and `build-devid.sh`. It provides:

- the `timeout(1)` shim;
- `fail` and `pass`;
- `logged`, which runs a build step into a log and shows its tail on failure;
- `require_croc`;
- `kill_jobs`, run from an EXIT trap so a failed assertion cannot leak a croc, relay or app process;
- `await_file` and `local_ip`.

### `scripts/verify-interop.sh`

15 scenarios, crocmobile against the croc CLI.

| Scenario | What it covers |
|---|---|
| 1 to 4 | File, folder and text, in both directions |
| 5 | Decline notifies the sender |
| 6, 7 | Receiver cancels, then sender cancels, mid-wire (`--throttleUpload 200k`). They assert a received-file mismatch, which log noise cannot fake. |
| 8 | Forced relay (LAN off on both sides) |
| 9 | LAN, via `--ip` |
| 10 | A croc v10 peer, both ways, expecting `peerVersion` |
| 11 | Every public pool relay (see below) |
| 12 | File policy (see below) |
| 13 | Large files without Tailcat (see below) |
| 14 | Stored transfers (see below) |
| 15 | Advanced options, described in "Advanced options on the wire" |

`RELAY=host:port` routes every transfer through one relay. It skips the pool scenario (11) and the proxy cases of scenario 15. Scenario 13 runs, because the relay carries its data and the CLI finishes without `tailcat.dev`. Scenario 15's sender IP and multicast cases still run.

Start order in the harness (see "Start order: sender first"):

- With a croctest sender, it waits for croctest's `EVENT code` line, plus 3 s, before a CLI receiver joins.
- When the CLI sends, it waits a fixed 3 s.

Scenario 11 (pool):

- Each of the 4 pool relays gets a custom code that maps to it, sent wrapper to CLI and CLI to wrapper, and a wrapper-generated code forced onto it with `croctest send -relay-index N`. One CLI-generated code is added (the CLI caches its probed relay, so that covers one index).
- LAN is off on both sides (`-no-local` and `send --no-local`) so only matching relays meet. It asserts croctest's `EVENT relay <addr>` and the CLI `--debug` line `public relay index N selected: <addr>`.
- It waits 60 s first, runs with multiplexing off (`-no-multi`, `--no-multi`), and makes one pass over the pool per kind of transfer. A relay admits 30 connections a minute from one address (`../known-issues.md`, "Accepted").

Scenario 12 (file policy), which also runs under `RELAY`, so CI covers it:

- A CLI sends a file onto an existing one and `croctest` receives with Keep Both and with Replace, answered at the prompt and preset with `-yes` (4 cases).
- Then a zipped folder (`croc send --zip`) is received twice into one folder with each policy and each accept mode (4 cases).
- `croctest receive` takes `-policy keepBoth|replace` (default `keepBoth`, other values exit 2).

Scenario 13 (large files without Tailcat):

- A 130 MiB transfer, wrapper to CLI and CLI to wrapper, with the CLI on its default `--transport auto`. It asserts byte equality, and in the CLI `--debug` log the plain `selected croc relay data transport` line with no `tailcat-offer`, `starting Tailcat server`, `Tailcat fallback` or `selected staged` line ("Transport and Tailcat").
- Then a CLI sender with `--transport derp` to the wrapper: the wrapper must exit non-zero within 30 s with the peer-requires-Tailcat error above, and receive nothing.

Scenario 14 (stored transfers), which needs neither a relay nor the internet, so it runs under `RELAY` too:

- It starts `croctest store-server` on a loopback port.
- It checks wrapper upload then CLI download, wrapper revoke then CLI download fails, CLI upload then wrapper download, and CLI revoke giving `storeExpired`.
- It checks an existing name with Keep Both, Replace and a declined preview.
- The CLI's revoke receipts go to a throwaway `CROC_CONFIG_DIR`.

`croctest` also has `relay CODE` and `relays`. The relay cache lives in `crocmobile/internal/relaycache`, so `croctest` can seed it without adding to the gobind API.

### `scripts/verify-app-sim.sh`

Boots the simulator and installs the app. It runs two scenarios: CLI to app via the `--auto-receive CODE` launch argument, then the share-extension handoff via `--auto-share-send CODE`. Each gates on an exact `ok success=true` plus a byte diff.

The launch arguments drive the real UI state machine (`AutoVerify` and `TransferController`, accepting through `respond(true)`), not engine-level auto-accept. The point is that the verified path is the one users take.

### `scripts/verify-app-mac.sh`

12 scenarios, the macOS app through launch arguments. Every transfer gates on a byte-identical diff and the app's `verify-result.txt`.

- CLI to app receive (with history)
- app to CLI send with a custom code (`--auto-send PATH --code CODE`; the source file must live in the app container because of the sandbox)
- local-only send (`--local`; a sandboxed relay-listener proof, the CLI receives via `--ip`)
- send through a custom self-hosted relay (`croc relay --ports 9021,9022,9023`, then `--relay localhost:9021`)
- `--no-compress` send
- `--ask` both-sides confirm (auto-answered by `AutoVerify` through `.confirmSend`)
- receive onto an existing file in the app's Documents, with `--when-exists keepBoth|replace` (the answer `AutoVerify` gives the incoming sheet; prints `MAC-COLLIDE-OK`)
- a 130 MiB transfer in each direction against a CLI on `--transport auto`, which must show the plain relay line and no Tailcat offer (prints `MAC-TRANSPORT-OK`; same log assertions as interop scenario 13)
- stored transfers against a local store server
- menu-bar quick send
- Open at login
- the Shortcuts actions

Traps:

- The app declares document types, so bare adjacent argv tokens are document-open candidates. Pass flags only (`--code CODE`).
- Every launch needs `-ApplePersistenceIgnoreState YES`, or a headless window restoration hangs.
- App-as-sender scenarios wait for the `verify-code-ready.txt` marker that `AutoVerify` writes when a send reaches its code, then 3 s (see "Start order: sender first").
- The container Documents folder is `~/Library/Containers/com.bakirgdev.CrocApp/Data/Documents/`.

### `crockit-verify`

A CrocKit executable for the Swift layer. Subcommands: `send`, `receive` (optionally answering `y` or `n` and cancelling after a number of milliseconds) and `twice`.

`twice` runs two transfers in one process, the second receiving with `.replace`. It proves that the restoration of fd 0, stdout, cwd and the mutex composes across transfers, and that the second start succeeds right after the first one's terminal event, with no retry.

## Toolchain

- Go: `crocmobile/go.mod` pins `go 1.27.3` (install with Homebrew). The build script builds gomobile and gobind from the `tool` block in `crocmobile/go.mod`.
- Xcode 27.1 binds cleanly.
- The macOS slice is arm64 only (golang/go#73119).
- gomobile still writes `MinimumOSVersion = 100.0` into the iOS framework. App Store Connect accepted it on upload validation. The iOS device layout issue golang/go#66500 is closed.
- A fresh clone must run `scripts/build-xcframework.sh` before any Swift build, because the `binaryTarget` points at the gitignored artifact.
- Verify scripts need outbound network (public relay) and the `CROC` and `SIM` environment variables.
