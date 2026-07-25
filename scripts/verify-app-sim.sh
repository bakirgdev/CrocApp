#!/usr/bin/env bash
# Boots an iOS simulator, installs CrocApp, drives a croc CLI -> app transfer
# via the --auto-receive launch argument, gates on the result file and a
# byte-identical diff.
#
# The CLI send starts first and gets a moment to register its code before the
# app's receive launches. Starting the receiver first races the sender's setup
# and corrupts the PAKE handshake ("problem with decoding: invalid character").
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-$HOME/go/bin/croc}"
require_croc

CODE="sim-$$-recv"
SIM="${SIM:-iPhone 17 Pro}"   # list runtimes with: xcrun simctl list devices
BUNDLE=com.bakirgdev.CrocApp

TMP=$(mktemp -d)
trap 'kill_jobs; rm -rf "$TMP"' EXIT

xcrun simctl boot "$SIM" 2>/dev/null || true
( cd app && xcodebuild -scheme CrocApp \
    -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath /tmp/dd-sim build ) > /tmp/sim-build.log 2>&1
APP=$(find /tmp/dd-sim/Build/Products -maxdepth 3 -name CrocApp.app | head -1)
[ -n "$APP" ] || fail "no CrocApp.app in /tmp/dd-sim (see /tmp/sim-build.log)"
xcrun simctl install "$SIM" "$APP"

# Clear artifacts from a previous run so a crashed or no-op app cannot leave
# behind a result file that makes this run look like it passed.
CONTAINER=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)
rm -f "$CONTAINER/Documents/verify-result.txt" "$CONTAINER/Documents/simfile.txt"

echo "sim transfer $$" > "$TMP/simfile.txt"
( cd "$TMP" && CROC_SECRET="$CODE" timeout 120 "$CROC" --ignore-stdin send simfile.txt ) \
    > /tmp/sim-send.log 2>&1 &
sleep 3
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$SIM" "$BUNDLE" --auto-receive "$CODE"

for _ in $(seq 1 120); do
  [ -f "$CONTAINER/Documents/verify-result.txt" ] && break
  sleep 1
done
RESULT=$(cat "$CONTAINER/Documents/verify-result.txt" 2>/dev/null || echo missing)
echo "result: $RESULT"
[ "$RESULT" = "ok success=true" ] || fail "expected 'ok success=true', got '$RESULT'"
diff "$TMP/simfile.txt" "$CONTAINER/Documents/simfile.txt" || fail "received bytes differ"
echo SIM-INTEROP-OK
