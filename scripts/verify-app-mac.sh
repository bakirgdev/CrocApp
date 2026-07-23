#!/usr/bin/env bash
# Verifies the macOS app's UI state machine end-to-end via launch arguments:
#   1. CLI send -> app --auto-receive (accept prompt exercised via respond())
#   2. app --auto-send (custom code, F5) -> CLI receive
# Both directions gate on byte-identical diff + the app's verify-result.txt.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v timeout >/dev/null 2>&1; then
  timeout() {
    local dur="$1"; shift
    "$@" &
    local pid=$!
    ( sleep "$dur" 2>/dev/null; kill -TERM "$pid" 2>/dev/null ) &
    local watcher=$!
    local rc=0
    wait "$pid" 2>/dev/null || rc=$?
    kill "$watcher" 2>/dev/null || true
    wait "$watcher" 2>/dev/null || true
    return "$rc"
  }
fi

CROC="${CROC:-$HOME/go/bin/croc}"
# First 4 chars differ between the two codes (relay room hashing rule).
CODE_RECV="r2m$$-mac-recv"
CODE_SEND="s2m$$-mac-send"
CONTAINER="$HOME/Library/Containers/com.bakirgdev.CrocApp/Data"
DOCS="$CONTAINER/Documents"

( cd app && xcodebuild -scheme CrocApp -destination 'platform=macOS' \
    -derivedDataPath /tmp/dd-mac build ) > /tmp/mac-build.log 2>&1
APP=$(find /tmp/dd-mac/Build/Products -name "CrocApp.app" -maxdepth 3 | head -1)
BIN="$APP/Contents/MacOS/CrocApp"

mkdir -p "$DOCS"
rm -f "$DOCS/verify-result.txt" "$DOCS/macfile.txt"

# --- Direction 1: CLI -> app ------------------------------------------------
TMP=$(mktemp -d); echo "mac transfer $$" > "$TMP/macfile.txt"
( cd "$TMP" && CROC_SECRET="$CODE_RECV" timeout 120 "$CROC" --ignore-stdin send macfile.txt ) \
    > /tmp/mac-cli-send.log 2>&1 &
sleep 3
"$BIN" -ApplePersistenceIgnoreState YES --auto-receive "$CODE_RECV" > /tmp/mac-app-recv.log 2>&1 &
APP_PID=$!
for _ in $(seq 1 60); do
  sleep 2
  [ -f "$DOCS/verify-result.txt" ] && break
done
kill "$APP_PID" 2>/dev/null || true
RESULT=$(cat "$DOCS/verify-result.txt" 2>/dev/null || echo missing)
echo "receive result: $RESULT"
diff "$TMP/macfile.txt" "$DOCS/macfile.txt"
[ "$RESULT" = "ok success=true" ]
echo MAC-RECEIVE-OK

# --- Direction 2: app -> CLI (custom code) -----------------------------------
rm -f "$DOCS/verify-result.txt"
echo "mac app send $$" > "$DOCS/sendme.txt"
"$BIN" -ApplePersistenceIgnoreState YES --auto-send "$DOCS/sendme.txt" --code "$CODE_SEND" > /tmp/mac-app-send.log 2>&1 &
APP_PID=$!
sleep 3
DST=$(mktemp -d)
# CROC_SECRET (not a positional code arg): v10.5.0's non-classic receive mode
# refuses a code passed positionally and tells you to use CROC_SECRET instead
# -- same fix already applied throughout verify-interop.sh.
( cd "$DST" && CROC_SECRET="$CODE_SEND" timeout 120 "$CROC" --ignore-stdin --yes ) > /tmp/mac-cli-recv.log 2>&1
for _ in $(seq 1 30); do
  sleep 1
  [ -f "$DOCS/verify-result.txt" ] && break
done
kill "$APP_PID" 2>/dev/null || true
RESULT=$(cat "$DOCS/verify-result.txt" 2>/dev/null || echo missing)
echo "send result: $RESULT"
diff "$DOCS/sendme.txt" "$DST/sendme.txt"
[ "$RESULT" = "ok success=true" ]
echo MAC-SEND-OK

# --- Direction 3: app -> CLI, local-only (sandbox LAN listener) --------------
# App sends with croc onlyLocal: opens the local relay listener (port 9009)
# inside the sandbox -- the com.apple.security.network.server proof. CLI
# receiver connects via --ip (multicast discovery unreliable on this machine;
# same bypass as verify-interop.sh scenario 9).
local_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
}
LOCAL_IP=$(local_ip)
if [ -z "$LOCAL_IP" ]; then
  echo "MAC-LOCAL-SEND-SKIPPED (no local IP)"
else
  CODE_LOCAL="l2m$$-mac-local"
  rm -f "$DOCS/verify-result.txt"
  echo "mac local send $$" > "$DOCS/localme.txt"
  "$BIN" -ApplePersistenceIgnoreState YES --auto-send "$DOCS/localme.txt" --code "$CODE_LOCAL" --local > /tmp/mac-app-local.log 2>&1 &
  APP_PID=$!
  sleep 3
  DST=$(mktemp -d)
  ( cd "$DST" && CROC_SECRET="$CODE_LOCAL" timeout 120 "$CROC" --ignore-stdin --yes --ip "$LOCAL_IP:9009" ) > /tmp/mac-cli-local.log 2>&1
  for _ in $(seq 1 30); do
    sleep 1
    [ -f "$DOCS/verify-result.txt" ] && break
  done
  kill "$APP_PID" 2>/dev/null || true
  RESULT=$(cat "$DOCS/verify-result.txt" 2>/dev/null || echo missing)
  echo "local send result: $RESULT"
  diff "$DOCS/localme.txt" "$DST/localme.txt"
  [ "$RESULT" = "ok success=true" ]
  echo MAC-LOCAL-SEND-OK
fi

# --- Direction 4: app -> CLI, custom relay (F13) -----------------------------
# App sends via a local croc relay, with harnessDisableLocal set by --relay
# (killing the LAN race), so success proves traffic went through this relay.
CODE_RELAY="rly4$$-mac-relay"
RELAY_LOG="/tmp/mac-relay.log"
"$CROC" relay --ports 9021,9022,9023 > "$RELAY_LOG" 2>&1 &
RELAY_PID=$!
sleep 1
rm -f "$DOCS/verify-result.txt"
echo "mac relay send $$" > "$DOCS/relayme.txt"
"$BIN" -ApplePersistenceIgnoreState YES --auto-send "$DOCS/relayme.txt" --code "$CODE_RELAY" --relay "localhost:9021" > /tmp/mac-app-relay.log 2>&1 &
APP_PID=$!
sleep 3
DST=$(mktemp -d)
( cd "$DST" && CROC_SECRET="$CODE_RELAY" timeout 120 "$CROC" --ignore-stdin --yes --relay "localhost:9021" ) > /tmp/mac-cli-relay.log 2>&1
for _ in $(seq 1 30); do
  sleep 1
  [ -f "$DOCS/verify-result.txt" ] && break
done
kill "$APP_PID" 2>/dev/null || true
kill "$RELAY_PID" 2>/dev/null || true
RESULT=$(cat "$DOCS/verify-result.txt" 2>/dev/null || echo missing)
echo "relay send result: $RESULT"
diff "$DOCS/relayme.txt" "$DST/relayme.txt"
[ "$RESULT" = "ok success=true" ]
[ -s "$RELAY_LOG" ]
echo MAC-RELAY-OK

# --- Direction 5: app -> CLI, no compress (F15) ------------------------------
# Interop success proves the flag flows through croc without breaking the
# wire format; compression-off itself is asserted at the Go layer.
CODE_NOCOMP="ncp5$$-mac-nocomp"
rm -f "$DOCS/verify-result.txt"
echo "mac nocomp send $$" > "$DOCS/nocompme.txt"
"$BIN" -ApplePersistenceIgnoreState YES --auto-send "$DOCS/nocompme.txt" --code "$CODE_NOCOMP" --no-compress > /tmp/mac-app-nocomp.log 2>&1 &
APP_PID=$!
sleep 3
DST=$(mktemp -d)
( cd "$DST" && CROC_SECRET="$CODE_NOCOMP" timeout 120 "$CROC" --ignore-stdin --yes ) > /tmp/mac-cli-nocomp.log 2>&1
for _ in $(seq 1 30); do
  sleep 1
  [ -f "$DOCS/verify-result.txt" ] && break
done
kill "$APP_PID" 2>/dev/null || true
RESULT=$(cat "$DOCS/verify-result.txt" 2>/dev/null || echo missing)
echo "nocomp send result: $RESULT"
diff "$DOCS/nocompme.txt" "$DST/nocompme.txt"
[ "$RESULT" = "ok success=true" ]
echo MAC-NOCOMP-OK

# --- Direction 6: app -> CLI, both-sides confirm (F19) -----------------------
# Sender confirm is auto-answered by AutoVerify's .confirmSend case; the CLI
# receiver gets the forced prompt (senderInfo.Ask) and must answer on piped
# stdin, so --ignore-stdin is dropped here (it would refuse the prompt).
CODE_ASK="ask6$$-mac-ask"
rm -f "$DOCS/verify-result.txt"
echo "mac ask send $$" > "$DOCS/askme.txt"
"$BIN" -ApplePersistenceIgnoreState YES --auto-send "$DOCS/askme.txt" --code "$CODE_ASK" --ask > /tmp/mac-app-ask.log 2>&1 &
APP_PID=$!
sleep 3
DST=$(mktemp -d)
# `timeout`'s fallback backgrounds the CLI process ("$@" &); bash auto-redirects
# a backgrounded command's stdin to /dev/null unless it's explicitly redirected,
# which silently eats a piped `y`. Use an explicit `<` file redirect instead so
# the answer survives, and bound it by hand the same way the fallback does.
printf 'y\n' > "$DST/.ask-answer"
( cd "$DST" && CROC_SECRET="$CODE_ASK" "$CROC" --yes < "$DST/.ask-answer" ) > /tmp/mac-cli-ask.log 2>&1 &
CLI_PID=$!
( sleep 60; kill -TERM "$CLI_PID" 2>/dev/null ) &
CLI_WATCHER=$!
wait "$CLI_PID" 2>/dev/null || true
kill "$CLI_WATCHER" 2>/dev/null || true
wait "$CLI_WATCHER" 2>/dev/null || true
for _ in $(seq 1 30); do
  sleep 1
  [ -f "$DOCS/verify-result.txt" ] && break
done
kill "$APP_PID" 2>/dev/null || true
RESULT=$(cat "$DOCS/verify-result.txt" 2>/dev/null || echo missing)
echo "ask send result: $RESULT"
diff "$DOCS/askme.txt" "$DST/askme.txt"
[ "$RESULT" = "ok success=true" ]
echo MAC-ASK-OK
