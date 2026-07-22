#!/usr/bin/env bash
# Boots an iOS simulator, installs CrocApp, drives a croc CLI -> app transfer
# via the --auto-receive launch argument, checks the result file.
#
# Ordering note: the CLI send is started first and given a moment to
# register its code with the relay/local listener before the app's receive
# is launched. Starting the receiver first races the sender's setup and can
# corrupt the PAKE handshake (observed as "problem with decoding: invalid
# character ... looking for beginning of value" on the receive side) --
# mirrors the proven sender-first ordering in scripts/verify-interop.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

# macOS ships no timeout(1) (no GNU coreutils); shim the `timeout SECONDS
# cmd...` form (see scripts/verify-interop.sh for the same fix).
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
CODE="phase1-sim-$$"
SIM="${SIM:-iPhone 17 Pro}"   # adjust to an available runtime: xcrun simctl list devices
BUNDLE=com.bakirgdev.CrocApp

xcrun simctl boot "$SIM" 2>/dev/null || true
( cd CrocApp && xcodebuild -scheme CrocApp \
    -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath /tmp/dd-sim build ) > /tmp/sim-build.log 2>&1
APP=$(find /tmp/dd-sim/Build/Products -name "CrocApp.app" -maxdepth 3 | head -1)
xcrun simctl install "$SIM" "$APP"

# Clear stale artifacts from a previous run so a crashed/no-op app can't
# leave behind a result file or a leftover received file that would make
# this run look like it passed. get_app_container can fail here (app not
# yet installed on a fresh simulator) -- tolerate.
STALE_CONTAINER=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data 2>/dev/null || true)
if [ -n "$STALE_CONTAINER" ]; then
  rm -f "$STALE_CONTAINER/Documents/verify-result.txt" "$STALE_CONTAINER/Documents/simfile.txt"
fi

TMP=$(mktemp -d); echo "sim transfer $$" > "$TMP/simfile.txt"
( cd "$TMP" && CROC_SECRET="$CODE" timeout 120 "$CROC" --ignore-stdin send simfile.txt ) > /tmp/sim-send.log 2>&1 &
sleep 3
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$SIM" "$BUNDLE" --auto-receive "$CODE"

CONTAINER=""
for _ in $(seq 1 60); do
  sleep 2
  CONTAINER=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data 2>/dev/null || true)
  [ -n "$CONTAINER" ] && [ -f "$CONTAINER/Documents/verify-result.txt" ] && break
done
RESULT=$(cat "$CONTAINER/Documents/verify-result.txt" 2>/dev/null || echo "missing")
echo "result: $RESULT"

diff "$TMP/simfile.txt" "$CONTAINER/Documents/simfile.txt" > /dev/null 2>&1; DIFF_OK=$?
[ "$DIFF_OK" -eq 0 ] && echo SIM-INTEROP-OK
[ "$RESULT" = "ok success=true" ] && [ "$DIFF_OK" -eq 0 ]
