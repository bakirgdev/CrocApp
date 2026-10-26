#!/usr/bin/env bash
# Verifies the iOS app on a simulator via launch arguments, in two scenarios:
#   1. CLI -> app receive (--auto-receive).
#   2. The share-extension handoff (--auto-share-send): files staged into the
#      App Group container the way CrocShare does, sent by the app, received
#      by the CLI. The extension UI itself (share sheet invocation) is
#      device/manual territory.
# Each gates on the app's verify-result.txt AND a byte-identical diff.
#
# Whichever side sends must register its code before the receiver joins: a
# receiver that arrives first corrupts the PAKE handshake ("problem with
# decoding: invalid character", or "flate: corrupt input" when it times out
# croc's 500 ms local-endpoint probe and decodes the late reply as data).
#
# Both scenarios send through a `croc relay` this script starts on free loopback
# ports (scripts/lib.sh, "The relay a harness sends through"); the simulator
# shares the Mac's network, so it reaches that relay on 127.0.0.1. PUBLIC_POOL=1
# uses the public relay pool instead; RELAY=host:port a relay that is already
# running.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc}"
require_croc

SIM="${SIM:-iPhone 17 Pro}"   # list runtimes with: xcrun simctl list devices
BUNDLE=com.bakirgdev.CrocApp
GROUP=group.com.bakirgdev.CrocApp
DD="$TMPROOT/dd-sim"

TMP=$(mktemp -d)
trap 'kill_jobs; rm -rf "$TMP"' EXIT

use_relay "$TMPROOT/sim-relay.log"
CLI_R=${RELAY:+--relay=$RELAY}                     # one word, empty on the public pool: the CLI takes --relay before its command

xcrun simctl bootstatus "$SIM" -b > /dev/null
logged "$TMPROOT/sim-build.log" xcodebuild -project app/CrocApp.xcodeproj -scheme CrocApp \
  -destination "platform=iOS Simulator,name=$SIM" -derivedDataPath "$DD" build
APP=$(find "$DD/Build/Products" -maxdepth 3 -name CrocApp.app | head -1)
[ -n "$APP" ] || fail "no CrocApp.app in $DD (see $TMPROOT/sim-build.log)"
xcrun simctl install "$SIM" "$APP"

DOCS="$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)/Documents"
RESULT="$DOCS/verify-result.txt"
READY="$DOCS/verify-code-ready.txt"

launch() {                                          # launch ARGS...
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch "$SIM" "$BUNDLE" "$@" ${RELAY:+--relay "$RELAY"} > /dev/null
}

check_result() {                                    # check_result LABEL
  local got
  await_file "$RESULT" 120 || true
  got=$(cat "$RESULT" 2>/dev/null || echo missing)
  echo "$1 result: $got"
  [ "$got" = "ok success=true" ] || fail "$1: expected 'ok success=true', got '$got'"
}

# --- 1: CLI -> app ------------------------------------------------------------
# Results from a previous run are cleared first, so a crashed or no-op app
# cannot leave behind a file that makes this run look like it passed.
C="sim-$$-recv"
rm -f "$RESULT" "$READY" "$DOCS/simfile.txt"
echo "sim transfer $$" > "$TMP/simfile.txt"
mark_relay
( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" ${CLI_R:+"$CLI_R"} --disable-clipboard --ignore-stdin send simfile.txt ) \
    > "$TMPROOT/sim-send.log" 2>&1 &
await_sender
launch --auto-receive "$C"
check_result receive
cmp -s "$TMP/simfile.txt" "$DOCS/simfile.txt" || fail "receive: received bytes differ"
echo SIM-INTEROP-OK

# --- 2: share-extension handoff, app -> CLI ------------------------------------
# `get_app_container <device> <bundle> <group-id>` mis-parses the group
# identifier as a flag on this simctl version, so list the groups and pick ours.
C="shr-$$-send"
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

mark_relay
launch --auto-share-send "$C"
# A fixed sleep lost the sender-first race whenever the app launched slowly.
# The marker fires before croc dials the relay, so the relay's own log says
# when the app is in its room (lib.sh, await_sender; on the public pool it
# sleeps 3 s instead, which 1 s once failed to cover).
await_file "$READY" 60 || fail "app never reported its code (no $READY)"
await_sender

# CROC_SECRET rather than a positional code: the croc CLI refuses a positional
# receive code and points at CROC_SECRET.
( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" ${CLI_R:+"$CLI_R"} --ignore-stdin --yes ) \
    > "$TMPROOT/share-sim-recv.log" 2>&1 || {
  rc=$?
  tail -n 30 "$TMPROOT/share-sim-recv.log" >&2
  fail "share: croc receive exited $rc (log: $TMPROOT/share-sim-recv.log)"
}
check_result share
cmp -s "$GROUP_DIR/ShareInbox/$BATCH/payload.bin" "$TMP/payload.bin" || fail "share: received bytes differ"
echo SHARE-SIM-OK
