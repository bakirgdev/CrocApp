#!/usr/bin/env bash
# Machine verification of the share-extension handoff path on iOS simulator:
# stage files into the App Group container the way CrocShare does, launch the
# app with --auto-share-send, receive with croc CLI, diff bytes. The extension
# UI itself (share sheet invocation) is device/manual territory.
#
# The app is the sender here, so it launches and registers its code before the
# CLI receiver connects (sender-first ordering, see the wait below).
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc}"
require_croc

CODE="shr-$$-send"
SIM="${SIM:-iPhone 17 Pro}"   # list runtimes with: xcrun simctl list devices
BUNDLE=com.bakirgdev.CrocApp
GROUP=group.com.bakirgdev.CrocApp
DD="$TMPROOT/dd-sim"

TMP=$(mktemp -d)
trap 'kill_jobs; rm -rf "$TMP"' EXIT

xcrun simctl boot "$SIM" 2>/dev/null || true
( cd app && xcodebuild -scheme CrocApp \
    -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath "$DD" build ) > "$TMPROOT/share-sim-build.log" 2>&1
APP=$(find "$DD/Build/Products" -maxdepth 3 -name CrocApp.app | head -1)
[ -n "$APP" ] || fail "no CrocApp.app in $DD (see $TMPROOT/share-sim-build.log)"
xcrun simctl install "$SIM" "$APP"

# Clear artifacts from a previous run so a crashed or no-op app cannot leave
# behind a result file or a staged batch that makes this run look like it
# passed. `get_app_container <device> <bundle> <group-id>` mis-parses the group
# identifier as a flag on this simctl version, so list the groups and pick ours.
CONTAINER=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)
RESULT="$CONTAINER/Documents/verify-result.txt"
READY="$CONTAINER/Documents/verify-code-ready.txt"
rm -f "$RESULT" "$READY"
GROUP_DIR=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" groups | awk -v g="$GROUP" '$1 == g { print $2 }')
[ -n "$GROUP_DIR" ] || fail "could not resolve app group container $GROUP"
rm -rf "$GROUP_DIR/ShareInbox"

# Stage a batch the way CrocShare's ShareStager does: batch dir, payload, then
# manifest.json written last.
BATCH="batch-$(uuidgen)"
mkdir -p "$GROUP_DIR/ShareInbox/$BATCH"
head -c 1048576 /dev/urandom > "$GROUP_DIR/ShareInbox/$BATCH/payload.bin"
printf '{"batch":"%s","files":["payload.bin"]}\n' "$BATCH" > "$GROUP_DIR/ShareInbox/manifest.json"

xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$SIM" "$BUNDLE" --auto-share-send "$CODE"
# The receiver must join the room after the app. One that arrives first times
# out croc's 500 ms local-endpoint probe, then decodes the app's late reply to
# it as transfer data and fails with "flate: corrupt input". A fixed sleep lost
# that race whenever the app launched slowly. The extra second covers the relay
# dial after the code is ready.
await_file "$READY" 60 || fail "app never reported its code (no $READY)"
sleep 1

# CROC_SECRET rather than a positional code: the croc CLI refuses a positional
# receive code and points at CROC_SECRET.
( cd "$TMP" && CROC_SECRET="$CODE" timeout 120 "$CROC" --ignore-stdin --yes ) \
    > "$TMPROOT/share-sim-recv.log" 2>&1

await_file "$RESULT" 120 || true
GOT=$(cat "$RESULT" 2>/dev/null || echo missing)
echo "result: $GOT"
[ "$GOT" = "ok success=true" ] || fail "expected 'ok success=true', got '$GOT'"
diff "$GROUP_DIR/ShareInbox/$BATCH/payload.bin" "$TMP/payload.bin" || fail "received bytes differ"
echo SHARE-SIM-OK
