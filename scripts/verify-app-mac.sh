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
"$BIN" --auto-receive "$CODE_RECV" > /tmp/mac-app-recv.log 2>&1 &
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
"$BIN" --auto-send "$DOCS/sendme.txt" "$CODE_SEND" > /tmp/mac-app-send.log 2>&1 &
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
