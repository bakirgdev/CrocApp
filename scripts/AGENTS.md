# scripts/

Build, release, verification and screenshot scripts. Each script's header is its documentation (usage, what it proves, what it needs); `docs/BUILDING.md` summarizes them.

## Conventions

- Bash with `set -euo pipefail`. Every script `cd`s to the repo root first, so path arguments are relative to the root, not the caller's directory.
- Source `lib.sh` instead of re-implementing what it has: `fail`, `logged`, `kill_jobs`, `await_file`, `await_log`, `local_ip`, `TMPROOT`, the relay helpers (`use_relay`, `mark_relay`, `await_sender`, `free_port`), and the `timeout` shim (macOS has no `timeout`).
- Run every build or archive step as `logged LOG cmd...`. A bare `> log 2>&1` under `set -e` exits without saying what failed or where the log is.
- Scratch goes in `mktemp -d`, removed by the EXIT trap. Logs worth reading after a failure go under `$TMPROOT` (per-user on macOS), never at a fixed path in `/tmp`.
- A harness undoes in its EXIT trap everything it writes outside its temp dir (the app's Documents, `~/Downloads/CrocApp`, the pasteboard), so a failed run leaves nothing behind. Every croc CLI send takes `--disable-clipboard`: croc otherwise copies its code over the user's pasteboard.
- A transfer passes on the app's `verify-result.txt` (or croctest's `EVENT done`) and a byte comparison, never on an exit code alone. Every failure prints a `FAIL:` line naming the scenario.
- A transfer harness sends through its own `croc relay` (`use_relay LOG` in `lib.sh`; `PUBLIC_POOL=1` and `RELAY=host:port` opt out). The sender goes first: `mark_relay` before it starts, `await_sender` after, which waits for the relay's debug log to show the sender's room. A receiver that arrives first fails with `flate: corrupt input`. Where the relay's log is not readable (public pool, `RELAY=`, a `--local` send) the wait is a fixed 3 s, with a comment saying why.
- Custom codes (the legacy `NNNN-word` shape) differ in their first 4 characters within a run: the relay derives the room from that prefix (`docs/knowledge/what-is-croc.md`, "Rendezvous").
- `shellcheck -x scripts/*.sh` passes on default checks (CI `shellcheck` job). Disable a rule only on the line that needs it, with the reason beside it.
- A script or file CI reads goes into the `changes` regex in `.github/workflows/ci.yml` (`.github/AGENTS.md`).
