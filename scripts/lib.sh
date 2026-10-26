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
  # The relay (start_croc_relay) is disowned, so `jobs` does not list it.
  [ -n "$RELAY_PID" ] && kill "$RELAY_PID" 2>/dev/null || true
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

await_log() {                                       # await_log FILE REGEX SECONDS
  local i
  for (( i = 0; i < $3 * 10; i++ )); do
    grep -aq "$2" "$1" 2>/dev/null && return 0
    sleep 0.1
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

# --- The relay a harness sends through -----------------------------------------
# A harness starts its own `croc relay` on a free loopback port range and sends
# every transfer through it: no internet, none of the public pool's admission
# limits, no port collision with another run's relay, and a debug log that says
# when a sender is in its room. PUBLIC_POOL=1 opts into the public relay pool instead,
# RELAY=host:port into a relay that is already running; both leave RELAY_LOG
# empty, so `await_sender` can only sleep. Needs CROC, a v11 binary: the relay
# flags below are not in v10.
RELAY=${RELAY:-}                                    # host:port of the relay in use, empty for the public pool
RELAY_LOG=""                                        # set only for a relay this run started
RELAY_PID=""
RELAY_AT=""
ROOM_MARK=0

# A base port with COUNT (default 3) free loopback ports from it.
free_port() {                                       # free_port [COUNT]
  local count=${1:-3} p k i busy
  for (( k = 0; k < 50; k++ )); do
    p=$(( 20000 + RANDOM % 9000 ))
    busy=0
    for (( i = 0; i < count; i++ )); do
      ( exec 3<>"/dev/tcp/127.0.0.1/$((p + i))" ) 2>/dev/null && busy=1
    done
    [ "$busy" = 0 ] && { echo "$p"; return 0; }
  done
  return 1
}

# Starts a relay on 5 free ports (a control port and 4 data ports, croc's own
# shape) and sets RELAY_PID and RELAY_AT, its host:port. The join limits are
# raised because every connection comes from 127.0.0.1, which a croc v11 relay
# admits 30 times a minute by default. Call it directly, never inside $(...), so
# a failed start can exit the script. The relay is disowned so a harness's bare
# `wait` does not wait on it; kill_jobs stops it.
start_croc_relay() {                                # start_croc_relay LOG
  local log=$1 attempt base ports i p up
  for (( attempt = 0; attempt < 3; attempt++ )); do
    base=$(free_port 5) || fail "no free loopback port range for a relay"
    ports=$base
    for (( i = 1; i < 5; i++ )); do ports="$ports,$((base + i))"; done
    "$CROC" --debug relay --host 127.0.0.1 --ports "$ports" \
      --source-join-limit 1000 --room-join-limit 1000 > "$log" 2>&1 &
    RELAY_PID=$!
    disown "$RELAY_PID"
    for (( i = 0; i < 50; i++ )); do
      kill -0 "$RELAY_PID" 2>/dev/null || break
      up=1
      for (( p = 0; p < 5; p++ )); do
        ( exec 3<>"/dev/tcp/127.0.0.1/$((base + p))" ) 2>/dev/null || up=0
      done
      [ "$up" = 1 ] && { RELAY_AT="127.0.0.1:$base"; return 0; }
      sleep 0.1
    done
    kill "$RELAY_PID" 2>/dev/null || true
  done
  tail -n 20 "$log" >&2
  fail "local croc relay did not start (log: $log)"
}

# Settles which relay this run uses: sets RELAY (host:port, empty for the public
# pool) and RELAY_LOG.
use_relay() {                                       # use_relay LOG
  case "${PUBLIC_POOL:-}" in
    ''|1) ;;
    *) fail "PUBLIC_POOL must be empty or 1, not '$PUBLIC_POOL'" ;;
  esac
  if [ -n "${PUBLIC_POOL:-}" ]; then
    [ -z "$RELAY" ] || fail "PUBLIC_POOL=1 and RELAY=$RELAY exclude each other"
  elif [ -z "$RELAY" ]; then
    start_croc_relay "$1"
    RELAY=$RELAY_AT
    RELAY_LOG=$1
  fi
}

relay_rooms() { { grep -c 'room has first peer' "$RELAY_LOG" || true; } 2>/dev/null; }

# A receiver that joins a relay room before the sender fails ("flate: corrupt
# input"), so it starts only once the sender is in its room. The relay logs
# "room has first peer" once it has admitted the first client of a room, and a
# sender opens exactly one room before a receiver exists (its control
# connection; the data connections come after the receiver joins). So: mark the
# count before the sender starts, then wait for it to grow.
mark_relay() { if [ -n "$RELAY_LOG" ]; then ROOM_MARK=$(relay_rooms); fi; }

# Waits for the sender started since the last mark_relay to be in its room. On a
# relay this run cannot see (the public pool, RELAY=) nothing says when that is,
# so it sleeps FALLBACK_SECONDS, 3 by default: as long as a slow admission has
# been seen to take.
await_sender() {                                    # await_sender [FALLBACK_SECONDS]
  local i
  if [ -z "$RELAY_LOG" ]; then
    sleep "${1:-3}"
    return 0
  fi
  for (( i = 0; i < 300; i++ )); do
    [ "$(relay_rooms)" -gt "$ROOM_MARK" ] && return 0
    sleep 0.1
  done
  fail "no sender opened a room on the relay $RELAY within 30 s (relay log: $RELAY_LOG)"
}
