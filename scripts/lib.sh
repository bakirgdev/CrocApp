#!/usr/bin/env bash
# Shared helpers for scripts/verify-*.sh. Source it; do not run it.

# macOS ships no timeout(1). Shim the `timeout SECONDS cmd...` form and keep
# the real one where it exists (Linux CI). `<&0` is an explicit redirect, so
# the background job inherits the caller's stdin instead of bash's default
# /dev/null -- a redirect on the timeout call still reaches the command.
if ! command -v timeout >/dev/null 2>&1; then
  timeout() {
    local dur=$1 pid watcher rc=0
    shift
    "$@" <&0 &
    pid=$!
    ( sleep "$dur"; kill -TERM "$pid" 2>/dev/null ) &
    watcher=$!
    wait "$pid" 2>/dev/null || rc=$?
    kill "$watcher" 2>/dev/null || true
    wait "$watcher" 2>/dev/null || true
    return "$rc"
  }
fi

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

require_croc() {
  command -v "$CROC" >/dev/null 2>&1 || fail "croc not found at '$CROC' (set CROC=/path/to/croc)"
}

# Kill every background job this shell started, so a failed assertion cannot
# leak a croc process, a relay or an app. Registered on EXIT by each harness.
kill_jobs() {
  local pids
  pids=$(jobs -p)
  # shellcheck disable=SC2086  # deliberate split: one word per pid
  [ -n "$pids" ] && kill $pids 2>/dev/null
  return 0
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
