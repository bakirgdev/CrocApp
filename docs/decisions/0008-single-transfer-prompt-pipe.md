# 0008. One active transfer; prompts bridged via fd 0 pipe

Status: accepted
Date: 2026-07-23

## Context

croc's library API keeps CLI assumptions: no output-dir option (CLI does `os.Chdir`), interactive prompts read stdin via a `bufio.Reader` bound to fd 0 at package init (`utils.GetInput`), text receive streams to `os.Stdout`. These are process-global. Reimplementing prompt/output plumbing upstream would mean forking croc; polling-only embedding (crocgui style) loses the accept/decline product pillar (F9).

## Decision

- `crocmobile` serializes transfers: one active at a time, package mutex; second start returns "another transfer is active".
- Working directory: Chdir to `OutDir` (receive) / `WorkDir` (send) for the transfer, restored after.
- Accept/decline: `syscall.Dup2` a pipe onto fd 0 for the transfer (variable swap of `os.Stdin` is insufficient — croc's reader caches fd 0 at init). `Respond(accept)` writes `y\n`/`n\n` then closes the pipe; croc's un-gated prompts (empty folder, unzip overwrite) then hit EOF and take safe "no" defaults — no hangs. `Cancel()` also closes the pipe so a pending prompt unblocks.
- Text receive: capture `os.Stdout` via pipe (10 MB cap), restored before events are delivered.
- Cleanup (fd 0, stdout, cwd, mutex, temp file) funnels through one ownership-transfer path guarded against panics; delegate callbacks are recover-wrapped (gobind: a Go panic crossing the boundary kills the app).

## Consequences

- UI must not offer parallel transfers in V1; queueing is a UI concern.
- GUI multi-window (macOS) must share one engine instance semantics; second window's start gets a clear error.
- If upstream croc ever grows callback-based confirm/output APIs, this shim shrinks to nothing without protocol changes.
- Swift side: abandoning the event stream cancels the Go session (CrocEngine onTermination) — prevents a wedged engine.
