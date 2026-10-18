#!/usr/bin/env bash
# Shared helpers for the scripts in this directory. Source it; do not run it.

# Per-user private dir on macOS, /tmp elsewhere. Build products and logs stay
# out of the world-writable /tmp, where another local user could pre-create or
# symlink the paths these scripts write to.
TMPROOT="${TMPDIR:-/tmp}"
TMPROOT="${TMPROOT%/}"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

# Runs CMD with its output in LOG. A failure shows the log's tail and names the
# log, where a bare redirect under `set -e` would exit without a word.
logged() {                                          # logged LOG CMD...
  local log=$1
  shift
  "$@" > "$log" 2>&1 || { tail -n 40 "$log" >&2; fail "$1 failed, full log: $log"; }
}

require_croc() {
  command -v "$CROC" >/dev/null 2>&1 || fail "croc not found at '$CROC' (set CROC=/path/to/croc)"
}

# macOS ships no timeout(1). Shim the `timeout SECONDS cmd...` form and keep the
# real one where it exists (Linux CI). `<&0` is explicit because bash otherwise
# hands a background job /dev/null for stdin. The watcher gets its own fds:
# killing it orphans its `sleep`, and an orphan holding the caller's stdout
# blocks `$(timeout ...)` for the full duration after the command is long done.
if ! command -v timeout >/dev/null 2>&1; then
  timeout() {
    local dur=$1 pid watcher rc=0
    shift
    "$@" <&0 &
    pid=$!
    ( sleep "$dur"; kill -TERM "$pid" 2>/dev/null ) </dev/null >/dev/null 2>&1 &
    watcher=$!
    wait "$pid" 2>/dev/null || rc=$?
    kill "$watcher" 2>/dev/null || true
    wait "$watcher" 2>/dev/null || true
    return "$rc"
  }
fi

# Kill every background job this shell started, so a failed assertion cannot
# leak a croc process, a relay or an app. Registered on EXIT by each harness.
# `jobs -p` lists jobs that already exited and kill fails on those; under the
# caller's `set -e` that would abort the trap and skip the cleanup beside it.
kill_jobs() {
  local pids
  pids=$(jobs -p)
  # shellcheck disable=SC2086  # deliberate split: one word per pid
  [ -n "$pids" ] && kill $pids 2>/dev/null || true
  return 0
}

await_file() {                                      # await_file PATH SECONDS
  local i
  for (( i = 0; i < $2; i++ )); do
    [ -e "$1" ] && return 0
    sleep 1
  done
  return 1
}

# Best-effort LAN address, used to bypass UDP multicast peer discovery -- some
# networks (AP client isolation) never deliver it. Empty if none is found.
local_ip() {
  local ip iface
  for iface in en0 en1; do
    ip=$(ipconfig getifaddr "$iface" 2>/dev/null) && [ -n "$ip" ] && { echo "$ip"; return 0; }
  done
  hostname -I 2>/dev/null | awk 'NR==1{print $1}'
}
