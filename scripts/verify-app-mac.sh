#!/usr/bin/env bash
# Verifies the macOS app's UI state machine end-to-end via launch arguments.
# Six directions: CLI -> app receive (+ history), app -> CLI send, local-only
# send, custom-relay send, no-compress send, both-sides-confirm send. Every
# one gates on a byte-identical diff AND the app's verify-result.txt.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-$HOME/go/bin/croc}"
require_croc

DOCS="$HOME/Library/Containers/com.bakirgdev.CrocApp/Data/Documents"
RESULT="$DOCS/verify-result.txt"
HISTORY="$DOCS/verify-history.txt"

TMP=$(mktemp -d)
trap 'kill_jobs; rm -rf "$TMP"' EXIT

( cd app && xcodebuild -scheme CrocApp -destination 'platform=macOS' \
    -derivedDataPath /tmp/dd-mac build ) > /tmp/mac-build.log 2>&1
APP=$(find /tmp/dd-mac/Build/Products -maxdepth 3 -name CrocApp.app | head -1)
[ -n "$APP" ] || fail "no CrocApp.app in /tmp/dd-mac (see /tmp/mac-build.log)"
BIN="$APP/Contents/MacOS/CrocApp"

mkdir -p "$DOCS"
rm -f "$RESULT" "$HISTORY" "$DOCS/macfile.txt"

# The app declares document types, so a bare argv token next to a path is
# treated as a document to open -- pass everything as a flag. Window-state
# restoration hangs a headless launch, hence -ApplePersistenceIgnoreState.
run_app() {
  "$BIN" -ApplePersistenceIgnoreState YES "$@" &
  APP_PID=$!
}

await_app() {                                       # await_app SECONDS
  local i
  for (( i = 0; i < $1; i++ )); do
    [ -f "$RESULT" ] && break
    sleep 1
  done
  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true   # reap quietly; unreaped kills print "Terminated: 15"
}

check_result() {                                    # check_result LABEL
  local got
  got=$(cat "$RESULT" 2>/dev/null || echo missing)
  echo "$1 result: $got"
  [ "$got" = "ok success=true" ] || fail "$1: expected 'ok success=true', got '$got'"
}

# Every code's first 4 characters must be unique: the relay hashes that prefix
# into a room name.
code() { echo "$1$$-mac"; }

# --- 1: CLI -> app, plus SwiftData history isolation -------------------------
C=$(code recv)
echo "mac transfer $$" > "$TMP/macfile.txt"
( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin send macfile.txt ) \
    > /tmp/mac-cli-send.log 2>&1 &
sleep 3
run_app --auto-receive "$C" > /tmp/mac-app-recv.log 2>&1
await_app 120
check_result receive
diff "$TMP/macfile.txt" "$DOCS/macfile.txt"
# --auto-* launches get an in-memory ModelContainer, so records=1 proves the
# transfer was recorded and that the harness isolation still holds.
got=$(cat "$HISTORY" 2>/dev/null || echo missing)
echo "history result: $got"
[ "$got" = "records=1" ] || fail "history: expected 'records=1', got '$got'"
echo MAC-RECEIVE-OK

# --- 2: app -> CLI, custom code ----------------------------------------------
# The source file must live inside the app container (sandbox). CROC_SECRET
# rather than a positional code: v10.5.0's non-classic receive mode refuses a
# positional one and points at CROC_SECRET.
C=$(code send)
rm -f "$RESULT" "$HISTORY"
echo "mac app send $$" > "$DOCS/sendme.txt"
run_app --auto-send "$DOCS/sendme.txt" --code "$C" > /tmp/mac-app-send.log 2>&1
sleep 3
DST="$TMP/d2"; mkdir -p "$DST"
( cd "$DST" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin --yes ) > /tmp/mac-cli-recv.log 2>&1
await_app 30
check_result send
diff "$DOCS/sendme.txt" "$DST/sendme.txt"
echo MAC-SEND-OK

# --- 3: app -> CLI, local-only (sandbox LAN listener) ------------------------
# croc onlyLocal opens the local relay listener (port 9009) inside the sandbox,
# which is the com.apple.security.network.server proof. The CLI connects via
# --ip because multicast discovery is unreliable here.
LOCAL_IP=$(local_ip)
if [ -z "$LOCAL_IP" ]; then
  echo "MAC-LOCAL-SEND-SKIPPED (no local IP)"
else
  C=$(code locl)
  rm -f "$RESULT"
  echo "mac local send $$" > "$DOCS/localme.txt"
  run_app --auto-send "$DOCS/localme.txt" --code "$C" --local > /tmp/mac-app-local.log 2>&1
  sleep 3
  DST="$TMP/d3"; mkdir -p "$DST"
  ( cd "$DST" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin --yes --ip "$LOCAL_IP:9009" ) \
      > /tmp/mac-cli-local.log 2>&1
  await_app 30
  check_result "local send"
  diff "$DOCS/localme.txt" "$DST/localme.txt"
  echo MAC-LOCAL-SEND-OK
fi

# --- 4: app -> CLI, custom relay ---------------------------------------------
# --relay also sets harnessDisableLocal, killing the LAN race, so success here
# proves traffic really went through this relay.
C=$(code rlay)
RELAY_LOG=/tmp/mac-relay.log
"$CROC" relay --ports 9021,9022,9023 > "$RELAY_LOG" 2>&1 &
RELAY_PID=$!
sleep 1
rm -f "$RESULT"
echo "mac relay send $$" > "$DOCS/relayme.txt"
run_app --auto-send "$DOCS/relayme.txt" --code "$C" --relay localhost:9021 > /tmp/mac-app-relay.log 2>&1
sleep 3
DST="$TMP/d4"; mkdir -p "$DST"
( cd "$DST" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin --yes --relay localhost:9021 ) \
    > /tmp/mac-cli-relay.log 2>&1
await_app 30
kill "$RELAY_PID" 2>/dev/null || true
check_result "relay send"
diff "$DOCS/relayme.txt" "$DST/relayme.txt"
[ -s "$RELAY_LOG" ] || fail "relay send: relay logged nothing"
echo MAC-RELAY-OK

# --- 5: app -> CLI, no compress ----------------------------------------------
# Interop success proves the flag flows through croc without breaking the wire
# format; compression-off itself is asserted at the Go layer.
C=$(code ncmp)
rm -f "$RESULT"
echo "mac nocomp send $$" > "$DOCS/nocompme.txt"
run_app --auto-send "$DOCS/nocompme.txt" --code "$C" --no-compress > /tmp/mac-app-nocomp.log 2>&1
sleep 3
DST="$TMP/d5"; mkdir -p "$DST"
( cd "$DST" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin --yes ) > /tmp/mac-cli-nocomp.log 2>&1
await_app 30
check_result "nocomp send"
diff "$DOCS/nocompme.txt" "$DST/nocompme.txt"
echo MAC-NOCOMP-OK

# --- 6: app -> CLI, both-sides confirm ---------------------------------------
# AutoVerify's .confirmSend answers the sender prompt. The CLI receiver gets
# the forced senderInfo.Ask prompt and must answer on stdin, so --ignore-stdin
# is dropped here. Two files, not one: croc's Ask prompt fires once per file,
# which pins the regression where one answer starved every later prompt and
# aborted the send with "refusing files".
C=$(code ask7)
rm -f "$RESULT"
rm -rf "$DOCS/askdir"; mkdir -p "$DOCS/askdir"
echo "mac ask send 1 $$" > "$DOCS/askdir/askme1.txt"
echo "mac ask send 2 $$" > "$DOCS/askdir/askme2.txt"
run_app --auto-send "$DOCS/askdir" --code "$C" --ask > /tmp/mac-app-ask.log 2>&1
sleep 3
DST="$TMP/d6"; mkdir -p "$DST"
printf 'y\ny\n' > "$TMP/ask-answers"
( cd "$DST" && CROC_SECRET="$C" timeout 120 "$CROC" --yes < "$TMP/ask-answers" ) > /tmp/mac-cli-ask.log 2>&1
await_app 30
check_result "ask send"
diff -r "$DOCS/askdir" "$DST/askdir"
echo MAC-ASK-OK
