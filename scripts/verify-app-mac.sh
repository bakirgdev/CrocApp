#!/usr/bin/env bash
# Verifies the macOS app's UI state machine end-to-end via launch arguments,
# in 12 scenarios: CLI -> app receive (+ history), app -> CLI send, local-only
# send, custom-relay send, no-compress send, both-sides-confirm send, a receive
# onto an existing file with Keep Both and with Replace, a 130 MiB transfer in
# each direction that must not use Tailcat, stored transfers against a
# local store server, menu-bar quick send, Open at login and the Shortcuts
# actions. Every transfer gates on a byte-identical diff AND the app's
# verify-result.txt.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc}"
require_croc

BUNDLE=com.bakirgdev.CrocApp
DOCS="$HOME/Library/Containers/$BUNDLE/Data/Documents"
RESULT="$DOCS/verify-result.txt"
HISTORY="$DOCS/verify-history.txt"
READY="$DOCS/verify-code-ready.txt"
DD="$TMPROOT/dd-mac"

RECV_DIR="$HOME/Downloads/CrocApp"                 # the Receive action's real folder
RECV_NAME="intent-recv-$$.txt"

TMP=$(mktemp -d)
SAVED_PASTE=""
# Everything a run writes outside $TMP, so a failed run leaves none of it: the
# app's Documents (also its receive folder), the Receive action's file, and the
# user's pasteboard, which step 10 overwrites.
cleanup() {
  kill_jobs
  if [ -n "$SAVED_PASTE" ]; then pbcopy < "$SAVED_PASTE"; fi
  rm -rf "$DOCS"/{macfile,sendme,localme,relayme,nocompme,collide,menubar,intentsend}.txt \
    "$DOCS/collide (1).txt" "$DOCS"/{bigsend,bigrecv,storeme}.bin "$DOCS"/{askdir,store-src} \
    "$DOCS"/verify-*
  rm -f "$RECV_DIR/$RECV_NAME"
  rm -rf "$TMP"
}
trap cleanup EXIT

logged "$TMPROOT/mac-build.log" xcodebuild -project app/CrocApp.xcodeproj -scheme CrocApp \
  -destination 'platform=macOS' -derivedDataPath "$DD" -allowProvisioningUpdates build
APP=$(find "$DD/Build/Products" -maxdepth 3 -name CrocApp.app | head -1)
[ -n "$APP" ] || fail "no CrocApp.app in $DD (see $TMPROOT/mac-build.log)"
BIN="$APP/Contents/MacOS/CrocApp"

mkdir -p "$DOCS"
rm -f "$RESULT" "$HISTORY" "$DOCS/macfile.txt"

# The app declares document types, so a bare argv token next to a path is
# treated as a document to open -- pass everything as a flag. Window-state
# restoration hangs a headless launch, hence -ApplePersistenceIgnoreState.
run_app() {
  rm -f "$READY"
  "$BIN" -ApplePersistenceIgnoreState YES "$@" &
  APP_PID=$!
}

# The receiver must join the relay room after the app: one that arrives first
# fails with "flate: corrupt input". The marker fires before croc dials the
# relay, hence the extra sleep.
await_ready() {
  await_file "$READY" 60 || fail "app never reported its code (no $READY)"
  sleep 3
}

await_app() {                                       # await_app SECONDS
  await_file "$RESULT" "$1" || true
  kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true   # reap quietly; unreaped kills print "Terminated: 15"
}

check_result() {                                    # check_result LABEL
  local got
  got=$(cat "$RESULT" 2>/dev/null || echo missing)
  echo "$1 result: $got"
  [ "$got" = "ok success=true" ] || fail "$1: expected 'ok success=true', got '$got'"
}

# The app is already running as sender: receive with the CLI, gate, diff.
recv_from_app() {                                   # recv_from_app LABEL SRC DST [croc-args...]
  local label=$1 src=$2 dst=$3
  shift 3
  mkdir -p "$dst"
  ( cd "$dst" && CROC_SECRET="$C" timeout "${RECV_TIMEOUT:-120}" "$CROC" --ignore-stdin --yes "$@" ) \
      > "$TMPROOT/mac-cli-$label.log" 2>&1 || fail "$label: croc receive exited $? (log: $TMPROOT/mac-cli-$label.log)"
  await_app 30
  check_result "$label"
  cmp -s "$src" "$dst/${src##*/}" || fail "$label: received bytes differ"
}

# Every code's first 4 characters must be unique: the relay hashes that prefix
# into a room name.
code() { echo "$1$$-mac"; }

# --- 1: CLI -> app, plus SwiftData history isolation -------------------------
C=$(code recv)
echo "mac transfer $$" > "$TMP/macfile.txt"
( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" --disable-clipboard --ignore-stdin send macfile.txt ) \
    > "$TMPROOT/mac-cli-send.log" 2>&1 &
sleep 3
run_app --auto-receive "$C" > "$TMPROOT/mac-app-recv.log" 2>&1
await_app 120
check_result receive
cmp -s "$TMP/macfile.txt" "$DOCS/macfile.txt" || fail "receive: received bytes differ"
# --auto-* launches get an in-memory ModelContainer, so records=1 proves the
# transfer was recorded and that the harness isolation still holds.
got=$(cat "$HISTORY" 2>/dev/null || echo missing)
echo "history result: $got"
[ "$got" = "records=1" ] || fail "history: expected 'records=1', got '$got'"
echo MAC-RECEIVE-OK

# --- 2: app -> CLI, custom code ----------------------------------------------
# The source file must live inside the app container (sandbox). CROC_SECRET
# rather than a positional code: the CLI's non-classic receive mode refuses a
# positional one and points at CROC_SECRET.
C=$(code send)
rm -f "$RESULT" "$HISTORY"
echo "mac app send $$" > "$DOCS/sendme.txt"
run_app --auto-send "$DOCS/sendme.txt" --code "$C" > "$TMPROOT/mac-app-send.log" 2>&1
await_ready
recv_from_app send "$DOCS/sendme.txt" "$TMP/d2"
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
  run_app --auto-send "$DOCS/localme.txt" --code "$C" --local > "$TMPROOT/mac-app-local.log" 2>&1
  await_ready
  recv_from_app local "$DOCS/localme.txt" "$TMP/d3" --ip "$LOCAL_IP:9009"
  echo MAC-LOCAL-SEND-OK
fi

# --- 4: app -> CLI, custom relay ---------------------------------------------
# --relay also sets harnessDisableLocal, killing the LAN race, so success here
# proves traffic really went through this relay.
C=$(code rlay)
RELAY_LOG="$TMPROOT/mac-relay.log"
"$CROC" relay --ports 9021,9022,9023 > "$RELAY_LOG" 2>&1 &
RELAY_PID=$!
sleep 1
rm -f "$RESULT"
echo "mac relay send $$" > "$DOCS/relayme.txt"
run_app --auto-send "$DOCS/relayme.txt" --code "$C" --relay localhost:9021 > "$TMPROOT/mac-app-relay.log" 2>&1
await_ready
recv_from_app relay "$DOCS/relayme.txt" "$TMP/d4" --relay localhost:9021
kill "$RELAY_PID" 2>/dev/null || true
wait "$RELAY_PID" 2>/dev/null || true
[ -s "$RELAY_LOG" ] || fail "relay send: relay logged nothing"
echo MAC-RELAY-OK

# --- 5: app -> CLI, no compress ----------------------------------------------
# Interop success proves the flag flows through croc without breaking the wire
# format; compression-off itself is asserted at the Go layer.
C=$(code ncmp)
rm -f "$RESULT"
echo "mac nocomp send $$" > "$DOCS/nocompme.txt"
run_app --auto-send "$DOCS/nocompme.txt" --code "$C" --no-compress > "$TMPROOT/mac-app-nocomp.log" 2>&1
await_ready
recv_from_app nocomp "$DOCS/nocompme.txt" "$TMP/d5"
echo MAC-NOCOMP-OK

# --- 6: app -> CLI, both-sides confirm ---------------------------------------
# AutoVerify's .confirmSend answers the sender prompt. The CLI receiver gets the
# forced senderInfo.Ask prompt and must answer on stdin, so --ignore-stdin is
# dropped here. Two files, not one: croc's Ask prompt fires once per file, which
# pins the regression where one answer starved every later prompt and aborted
# the send with "refusing files".
C=$(code ask7)
rm -f "$RESULT"
rm -rf "$DOCS/askdir"; mkdir -p "$DOCS/askdir"
echo "mac ask send 1 $$" > "$DOCS/askdir/askme1.txt"
echo "mac ask send 2 $$" > "$DOCS/askdir/askme2.txt"
run_app --auto-send "$DOCS/askdir" --code "$C" --ask > "$TMPROOT/mac-app-ask.log" 2>&1
await_ready
DST="$TMP/d6"; mkdir -p "$DST"
printf 'y\ny\n' > "$TMP/ask-answers"
( cd "$DST" && CROC_SECRET="$C" timeout 120 "$CROC" --yes < "$TMP/ask-answers" ) > "$TMPROOT/mac-cli-ask.log" 2>&1 \
  || fail "ask send: croc receive exited $? (log: $TMPROOT/mac-cli-ask.log)"
await_app 30
check_result "ask send"
diff -r "$DOCS/askdir" "$DST/askdir" > /dev/null || fail "ask send: received folder differs"
echo MAC-ASK-OK

# --- 7: CLI -> app onto an existing file, Keep Both and Replace --------
# --when-exists is the answer AutoVerify gives the incoming sheet; the setting
# stays Keep Both, so a Replace proves the late answer reaches croc. Keep Both
# leaves the existing file and adds "collide (1).txt"; Replace overwrites it.
collide() {                                         # collide POLICY
  local policy=$1
  C=$(code "cl${policy:0:1}")
  rm -f "$RESULT" "$DOCS/collide.txt" "$DOCS/collide (1).txt"
  echo "existing file" > "$DOCS/collide.txt"
  echo "mac collide $policy $$" > "$TMP/collide.txt"
  ( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" --disable-clipboard --ignore-stdin send collide.txt ) \
      > "$TMPROOT/mac-cli-collide-$policy.log" 2>&1 &
  sleep 3
  run_app --auto-receive "$C" --when-exists "$policy" > "$TMPROOT/mac-app-collide-$policy.log" 2>&1
  await_app 120
  check_result "collide $policy"
  if [ "$policy" = keepBoth ]; then
    [ "$(cat "$DOCS/collide.txt")" = "existing file" ] || fail "keepBoth: existing file changed"
    cmp -s "$TMP/collide.txt" "$DOCS/collide (1).txt" || fail "keepBoth: no collide (1).txt with the new content"
  else
    cmp -s "$TMP/collide.txt" "$DOCS/collide.txt" || fail "replace: file not replaced"
    [ ! -e "$DOCS/collide (1).txt" ] || fail "replace: renamed copy written"
  fi
}
collide keepBoth
collide replace
echo MAC-COLLIDE-OK

# --- 8: 130 MiB in each direction, no Tailcat ----------------------
# The app is built without Tailcat (croc_no_tailcat), so a transfer of 128 MiB
# or more, which the stock CLI would race over Tailcat against a capable peer,
# goes over the relay. The CLI runs on its default --transport auto, and its
# --debug log must show the plain relay line and no Tailcat offer. The CLI still
# logs "selected=derp" for its size decision on a send: that is not Tailcat.
# The observed log lines are in docs/knowledge/crocmobile-bridge.md,
# "Transport and Tailcat".
head -c 136314880 /dev/urandom > "$TMP/bigrecv.bin"
no_tailcat() {                                      # no_tailcat LOG LABEL
  grep -aq "selected croc relay data transport$" "$1" || fail "$2: CLI log has no plain relay data transport line"
  ! grep -aEq "tailcat-offer|starting Tailcat server|Tailcat fallback|selected staged" "$1" || fail "$2: CLI log shows a Tailcat offer"
}
big_app_send() {
  C=$(code xsend)
  rm -f "$RESULT" "$DOCS/bigsend.bin"
  head -c 136314880 /dev/urandom > "$DOCS/bigsend.bin"
  run_app --auto-send "$DOCS/bigsend.bin" --code "$C" > "$TMPROOT/mac-app-xsend.log" 2>&1
  await_ready
  RECV_TIMEOUT=300 recv_from_app "xsend" "$DOCS/bigsend.bin" "$TMP/d8s" --debug
  cmp -s "$DOCS/bigsend.bin" "$TMP/d8s/bigsend.bin" || fail "large send: 130 MiB differs"
  rm -f "$DOCS/bigsend.bin" "$TMP/d8s/bigsend.bin"
}
big_app_receive() {
  local log="$TMPROOT/mac-cli-xr.log" cli_pid
  C=$(code xrecv)
  rm -f "$RESULT" "$DOCS/bigrecv.bin"
  ( cd "$TMP" && CROC_SECRET="$C" timeout 300 "$CROC" --debug --disable-clipboard --ignore-stdin send bigrecv.bin ) \
      > "$log" 2>&1 &
  cli_pid=$!
  sleep 3
  run_app --auto-receive "$C" > "$TMPROOT/mac-app-xr.log" 2>&1
  await_app 300
  wait "$cli_pid" || true
  check_result "large receive"
  cmp -s "$TMP/bigrecv.bin" "$DOCS/bigrecv.bin" || fail "large receive: 130 MiB differs"
  rm -f "$DOCS/bigrecv.bin"
}
big_app_send
no_tailcat "$TMPROOT/mac-cli-xsend.log" "large send"
big_app_receive
no_tailcat "$TMPROOT/mac-cli-xr.log" "large receive"
rm -f "$TMP/bigrecv.bin"
echo MAC-TRANSPORT-OK

# --- 9: stored transfers through the app ---------------------------
# A local croc store server (croctest store-server), so no relay and no
# internet. One app instance uploads and keeps its receipt in memory, so the
# revoke has to come from that same process: the script signals it with
# verify-store-revoke.go once the CLI and a second app instance have downloaded.
# The source sits in a subfolder because the second instance receives into
# Documents itself.
CT="$TMP/croctest"
( cd crocmobile && go build -tags croc_no_tailcat -o "$CT" ./cmd/croctest )
mkdir -p "$TMP/store9" "$DOCS/store-src"
"$CT" store-server "$TMP/store9" > "$TMP/9srv.log" 2>&1 &
STORE=""
for _ in $(seq 1 50); do
  STORE=$(sed -n 's/^STORE-URL //p' "$TMP/9srv.log")
  [ -n "$STORE" ] && break
  sleep 0.2
done
[ -n "$STORE" ] || fail "store server did not start"
STORE_LINK="$DOCS/verify-store-link.txt"
rm -f "$RESULT" "$STORE_LINK" "$DOCS/verify-store-revoke.go" "$DOCS/storeme.bin"
# 5 MiB spans two upload chunks.
head -c 5242880 /dev/urandom > "$DOCS/store-src/storeme.bin"

run_app --auto-store-send "$DOCS/store-src/storeme.bin" --store-server "$STORE" --store-downloads 3 \
    > "$TMPROOT/mac-app-store-send.log" 2>&1
SENDER_PID=$APP_PID
await_file "$STORE_LINK" 60 || fail "stored upload: the app never wrote its link"
LINK=$(cat "$STORE_LINK")
[ -n "$LINK" ] || fail "stored upload: empty link"

mkdir -p "$TMP/d9cli"
CROC_STORE_TOKEN="$LINK" timeout 60 "$CROC" --yes --out "$TMP/d9cli" > "$TMPROOT/mac-cli-store.log" 2>&1 \
    || fail "stored upload -> CLI download failed (see $TMPROOT/mac-cli-store.log)"
cmp "$DOCS/store-src/storeme.bin" "$TMP/d9cli/storeme.bin" || fail "stored upload -> CLI download: file differs"

rm -f "$RESULT"
run_app --auto-store-receive "$LINK" > "$TMPROOT/mac-app-store-recv.log" 2>&1
await_app 60
check_result "stored receive"
cmp "$DOCS/store-src/storeme.bin" "$DOCS/storeme.bin" || fail "stored upload -> app download: file differs"

rm -f "$RESULT"
touch "$DOCS/verify-store-revoke.go"
await_file "$RESULT" 30 || fail "stored revoke: the app wrote no result"
got=$(cat "$RESULT")
echo "stored revoke result: $got"
[ "$got" = "ok success=true revoked=true" ] || fail "stored revoke: got '$got'"
kill "$SENDER_PID" 2>/dev/null || true
wait "$SENDER_PID" 2>/dev/null || true

mkdir -p "$TMP/d9gone"
CROC_STORE_TOKEN="$LINK" timeout 60 "$CROC" --yes --out "$TMP/d9gone" > "$TMPROOT/mac-cli-store-gone.log" 2>&1 \
    && fail "revoked upload still downloads (CLI)"
[ -z "$(ls -A "$TMP/d9gone")" ] || fail "revoked upload wrote files (CLI)"
rm -f "$RESULT" "$DOCS/storeme.bin"
run_app --auto-store-receive "$LINK" > "$TMPROOT/mac-app-store-gone.log" 2>&1
await_app 60
got=$(cat "$RESULT" 2>/dev/null || echo missing)
echo "revoked receive result: $got"
case "$got" in
  "error This link has expired"*) ;;
  *) fail "revoked upload: the app should report an expired link, got '$got'" ;;
esac
[ ! -e "$DOCS/storeme.bin" ] || fail "revoked upload wrote a file (app)"
echo MAC-STORE-OK

# --- 10: menu-bar quick send, files and clipboard text -----------------
# --auto-menubar-send and --auto-menubar-clipboard start the send through
# MenuBarQuickSend, the view model behind the menu-bar window. The code is
# generated, so the app writes it to verify-code.txt for the CLI receiver.
rm -f "$RESULT" "$HISTORY" "$DOCS/verify-code.txt"
echo "mac menubar send $$" > "$DOCS/menubar.txt"
run_app --auto-menubar-send "$DOCS/menubar.txt" > "$TMPROOT/mac-app-menubar.log" 2>&1
await_ready
C=$(cat "$DOCS/verify-code.txt")
recv_from_app menubar "$DOCS/menubar.txt" "$TMP/d10"

# The pasteboard is the user's: cleanup puts it back.
pbpaste > "$TMP/pasteboard.txt"
SAVED_PASTE="$TMP/pasteboard.txt"
rm -f "$RESULT" "$HISTORY" "$DOCS/verify-code.txt"
CLIP="mac menubar clipboard $$"
printf '%s' "$CLIP" | pbcopy
run_app --auto-menubar-clipboard > "$TMPROOT/mac-app-menubar-clip.log" 2>&1
await_ready
C=$(cat "$DOCS/verify-code.txt")
mkdir -p "$TMP/d10t"
( cd "$TMP/d10t" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin --yes ) \
    > "$TMPROOT/mac-cli-menubar-clip.log" 2>&1 || fail "menubar-clipboard: croc receive exited $? (log: $TMPROOT/mac-cli-menubar-clip.log)"
await_app 30
check_result menubar-clipboard
grep -qF "$CLIP" "$TMPROOT/mac-cli-menubar-clip.log" || fail "menu-bar clipboard text did not reach the CLI"
echo MAC-MENUBAR-OK

# --- 11: Open at login matches the system status -----------------------
# The check registers the app's login item and unregisters it again, so a
# stray item survives only if the run is killed between the two (a login item
# already present before the run is left unregistered). The status
# values are SMAppService.Status raw values: 0 notRegistered, 1 enabled,
# 2 requiresApproval.
rm -f "$RESULT"
run_app --auto-login-item > "$TMPROOT/mac-app-login.log" 2>&1
await_file "$RESULT" 30 || fail "login item check wrote no result"
kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true
got=$(cat "$RESULT")
echo "login item result: $got"
case "$got" in
  "ok before="?" registered=1 toggleOn=true after=0 toggleOff=true") ;;
  "ok before="?" registered=2 toggleOn=true after=0 toggleOff=true") ;;
  *) fail "login item: status did not follow register/unregister, got '$got'" ;;
esac
echo MAC-LOGIN-OK

# --- 12: the Shortcuts actions against the CLI -------------------------
# Shortcuts cannot be driven from a script, so --auto-intent calls each
# action's perform() directly (the value rides behind --intent-arg: two bare
# arguments in a row make AppKit skip the window). The send actions return
# their code, which the app writes to verify-code.txt; Receive saves into the app's receive folder
# (the real ~/Downloads/CrocApp), so the file gets a unique name and is
# removed afterwards.
rm -f "$RESULT" "$HISTORY" "$DOCS/verify-code.txt"
echo "mac intent file $$" > "$DOCS/intentsend.txt"
run_app --auto-intent send-files --intent-arg "$DOCS/intentsend.txt" > "$TMPROOT/mac-app-intent-files.log" 2>&1
await_ready
C=$(cat "$DOCS/verify-code.txt")
recv_from_app intent-send-files "$DOCS/intentsend.txt" "$TMP/d12"

rm -f "$RESULT" "$HISTORY" "$DOCS/verify-code.txt"
INTENT_TEXT="mac intent text $$"
run_app --auto-intent send-text --intent-arg "$INTENT_TEXT" > "$TMPROOT/mac-app-intent-text.log" 2>&1
await_ready
C=$(cat "$DOCS/verify-code.txt")
mkdir -p "$TMP/d12t"
( cd "$TMP/d12t" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin --yes ) \
    > "$TMPROOT/mac-cli-intent-text.log" 2>&1 || fail "intent-send-text: croc receive exited $? (log: $TMPROOT/mac-cli-intent-text.log)"
await_app 30
check_result intent-send-text
grep -qF "$INTENT_TEXT" "$TMPROOT/mac-cli-intent-text.log" || fail "Send Text action: text did not reach the CLI"

C=$(code intr)
rm -f "$RESULT" "$HISTORY"
echo "mac intent receive $$" > "$TMP/$RECV_NAME"
( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" --disable-clipboard --ignore-stdin send "$RECV_NAME" ) \
    > "$TMPROOT/mac-cli-intent-send.log" 2>&1 &
sleep 3
run_app --auto-intent receive --intent-arg "$C" > "$TMPROOT/mac-app-intent-recv.log" 2>&1
await_app 120
got=$(cat "$RESULT" 2>/dev/null || echo missing)
echo "intent receive result: $got"
cmp -s "$TMP/$RECV_NAME" "$RECV_DIR/$RECV_NAME" || fail "Receive action: file differs"
[ "$got" = "ok success=true files=$RECV_NAME" ] || fail "Receive action: expected the file name back, got '$got'"
echo MAC-INTENT-OK
