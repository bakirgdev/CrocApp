#!/usr/bin/env bash
# Machine verification of the share-extension handoff path on iOS simulator:
# stage files into the App Group container the way CrocShare does, launch the
# app with --auto-share-send, receive with croc CLI, diff bytes.
# The extension UI itself (share sheet invocation) is device/manual territory.
#
# Ordering note: the app is the SENDER here, so it's launched (and its code
# registered with the relay) before the CLI receiver connects -- mirrors the
# sender-first ordering in scripts/verify-app-mac.sh direction 2.
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
CODE="shr-sim-$$"
SIM="${SIM:-iPhone 17 Pro}"   # adjust to an available runtime: xcrun simctl list devices
BUNDLE=com.bakirgdev.CrocApp
GROUP=group.com.bakirgdev.CrocApp

xcrun simctl boot "$SIM" 2>/dev/null || true
( cd app && xcodebuild -scheme CrocApp \
    -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath /tmp/dd-sim build ) > /tmp/share-sim-build.log 2>&1
APP=$(find /tmp/dd-sim/Build/Products -name "CrocApp.app" -maxdepth 3 | head -1)
xcrun simctl install "$SIM" "$APP"

# Clear stale artifacts from a previous run so a crashed/no-op app can't
# leave behind a result file or a leftover staged batch that would make this
# run look like it passed. get_app_container can fail here (app not yet
# installed on a fresh simulator) -- tolerate.
STALE_CONTAINER=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data 2>/dev/null || true)
if [ -n "$STALE_CONTAINER" ]; then
  rm -f "$STALE_CONTAINER/Documents/verify-result.txt"
fi
# `get_app_container <device> <bundle> <group-id>` mis-parses the group
# identifier as a flag on this simctl version and prints usage instead --
# list all group containers and pick the line for ours.
GROUP_DIR=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" groups 2>/dev/null \
  | awk -v g="$GROUP" '$1 == g { print $2 }')
if [ -n "$GROUP_DIR" ]; then
  rm -rf "$GROUP_DIR/ShareInbox"
fi

# Stage a batch the way CrocShare's ShareStager does: batch dir + payload +
# manifest.json written last.
BATCH="batch-$(uuidgen)"
mkdir -p "$GROUP_DIR/ShareInbox/$BATCH"
head -c 1048576 /dev/urandom > "$GROUP_DIR/ShareInbox/$BATCH/payload.bin"
cat > "$GROUP_DIR/ShareInbox/manifest.json" <<EOF
{"batch":"$BATCH","files":["payload.bin"]}
EOF

xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$SIM" "$BUNDLE" --auto-share-send "$CODE"
sleep 3

DST=$(mktemp -d)
# CROC_SECRET (not a positional code arg): v10.5.0's non-classic receive mode
# refuses a code passed positionally and tells you to use CROC_SECRET instead
# -- same fix already applied throughout verify-interop.sh / verify-app-mac.sh.
( cd "$DST" && CROC_SECRET="$CODE" timeout 120 "$CROC" --ignore-stdin --yes ) > /tmp/share-sim-recv.log 2>&1

CONTAINER=""
for _ in $(seq 1 60); do
  sleep 2
  CONTAINER=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data 2>/dev/null || true)
  [ -n "$CONTAINER" ] && [ -f "$CONTAINER/Documents/verify-result.txt" ] && break
done
RESULT=$(cat "$CONTAINER/Documents/verify-result.txt" 2>/dev/null || echo "missing")
echo "result: $RESULT"

DIFF_OK=0; diff "$GROUP_DIR/ShareInbox/$BATCH/payload.bin" "$DST/payload.bin" >/dev/null 2>&1 || DIFF_OK=$?
[ "$DIFF_OK" -eq 0 ] && echo SHARE-SIM-OK
[ "$RESULT" = "ok success=true" ] && [ "$DIFF_OK" -eq 0 ]
