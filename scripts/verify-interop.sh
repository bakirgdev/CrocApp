#!/usr/bin/env bash
# Interop verification: crocmobile (via croctest) <-> croc CLI v11.
# Covers: file/folder/text both directions, decline, cancel both directions,
# forced relay (LAN disabled), LAN-only, a croc v10 peer both directions, a
# receive onto existing files with Keep Both and Replace (R24), and every public
# pool relay (custom, wrapper-generated and CLI-generated codes).
# Exits non-zero on first failure.
#
# RELAY=host:port runs every transfer through that relay instead of the public
# pool, and skips the pool scenario (CI runs this against a local `croc relay`).
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc}"
CROC_V10="${CROC_V10:-$HOME/go/bin/croc}"
require_croc
V10_VERSION=$(cat scripts/croc-v10.version)
"$CROC_V10" --version 2>/dev/null | grep -qwF "$V10_VERSION" \
  || fail "croc $V10_VERSION not found at '$CROC_V10' (go install github.com/schollz/croc/v10@$V10_VERSION, or set CROC_V10)"

# One word each, empty without RELAY: croctest takes -relay after its mode,
# the CLI takes --relay before its command.
CT_R=${RELAY:+-relay=$RELAY}
CLI_R=${RELAY:+--relay=$RELAY}

TMP=$(mktemp -d)
CT="$TMP/croctest"
# TMP is deleted on exit and holds the only copy of the logs, so a failed run
# prints the logs of the scenario it stopped in. Scenario N logs to $TMP/N.*,
# $TMP/Ns.* and the like.
SCENARIO=0
cleanup() {
  local rc=$? f
  kill_jobs
  if [ "$rc" -ne 0 ]; then
    for f in "$TMP/$SCENARIO"[!0-9]*; do
      [ -f "$f" ] || continue
      echo "--- $f" >&2
      tail -n 30 "$f" >&2
    done
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

( cd crocmobile && go build -o "$CT" ./cmd/croctest )

mkdir -p "$TMP/src/sub" "$TMP/dst"
echo "small file" > "$TMP/src/a.txt"
head -c 5242880 /dev/urandom > "$TMP/src/big.bin"
echo nested > "$TMP/src/sub/b.txt"

# Codes must differ in their first 4 characters: the relay hashes that prefix
# into a room name, so a shared prefix can collide across scenarios.
code() { echo "$1$$-interop"; }

# Every command logs to $TMP and ends `|| true`: under `set -e` a failing croc
# would otherwise exit before the assertion after it could name the scenario.

# 1. wrapper sends file -> CLI receives
SCENARIO=1
C=$(code f1)
timeout 90 "$CT" send ${CT_R:+"$CT_R"} -code "$C" "$TMP/src/a.txt" > "$TMP/1.log" 2>&1 &
sleep 3
( cd "$TMP/dst" && CROC_SECRET="$C" timeout 60 "$CROC" ${CLI_R:+"$CLI_R"} --yes --overwrite ) > "$TMP/1.cli" 2>&1 || true
diff "$TMP/src/a.txt" "$TMP/dst/a.txt" > /dev/null || fail "send file"
wait; pass "send file"

# 2. CLI sends file -> wrapper receives (accept)
# --ignore-stdin: the CLI probes stdin for piped content and a non-tty send can
# misbehave without it. CROC_SECRET (not --code): the CLI's non-classic send
# mode refuses a custom codephrase passed via --code.
SCENARIO=2
C=$(code f2)
( cd "$TMP/src" && CROC_SECRET="$C" timeout 60 "$CROC" ${CLI_R:+"$CLI_R"} --ignore-stdin send a.txt ) > "$TMP/2.cli" 2>&1 &
sleep 3
timeout 60 "$CT" receive ${CT_R:+"$CT_R"} -out "$TMP/dst2" -answer y "$C" > "$TMP/2.log" 2>&1 || true
diff "$TMP/src/a.txt" "$TMP/dst2/a.txt" > /dev/null || fail "receive file"
grep -q "EVENT filelist" "$TMP/2.log" || fail "filelist event"
wait; pass "receive file + filelist event"

# 3. folder both directions
SCENARIO=3
C=$(code d1)
timeout 150 "$CT" send ${CT_R:+"$CT_R"} -code "$C" "$TMP/src" > "$TMP/3s.log" 2>&1 &
sleep 3
mkdir -p "$TMP/dstdir"
( cd "$TMP/dstdir" && CROC_SECRET="$C" timeout 120 "$CROC" ${CLI_R:+"$CLI_R"} --yes --overwrite ) > "$TMP/3s.cli" 2>&1 || true
diff -r "$TMP/src" "$TMP/dstdir/src" > /dev/null || fail "send folder"
wait; pass "send folder"

C=$(code d2)
( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" ${CLI_R:+"$CLI_R"} --ignore-stdin send src ) > "$TMP/3r.cli" 2>&1 &
sleep 3
timeout 120 "$CT" receive ${CT_R:+"$CT_R"} -out "$TMP/dstdir2" -answer y "$C" > "$TMP/3r.log" 2>&1 || true
diff -r "$TMP/src" "$TMP/dstdir2/src" > /dev/null || fail "receive folder"
wait; pass "receive folder"

# 4. text both directions
SCENARIO=4
C=$(code t1)
timeout 90 "$CT" send ${CT_R:+"$CT_R"} -code "$C" -text "wrapper text" > "$TMP/4s.log" 2>&1 &
sleep 3
OUT=$( cd "$TMP" && CROC_SECRET="$C" timeout 60 "$CROC" ${CLI_R:+"$CLI_R"} --yes --overwrite --stdout 2> "$TMP/4s.cli" ) || true
[ "$OUT" = "wrapper text" ] || fail "send text (got: $OUT)"
wait; pass "send text"

C=$(code t2)
CROC_SECRET="$C" timeout 60 "$CROC" ${CLI_R:+"$CLI_R"} --ignore-stdin send --text "cli text" > "$TMP/4r.cli" 2>&1 &
sleep 3
timeout 60 "$CT" receive ${CT_R:+"$CT_R"} -out "$TMP/dst" -answer y "$C" > "$TMP/4.log" 2>&1 || true
grep -q "EVENT text cli text" "$TMP/4.log" || fail "receive text"
wait; pass "receive text"

# 5. decline notifies sender
# The croc v11 CLI sender exits 0 on a peer decline and reports it only in its
# debug log: "read error message" when it decodes the peer's error frame, then
# "peer error: refusing files". The CLI can exit before writing the second line,
# so either one counts.
PEER_ERROR='peer error: refusing files|read error message'

SCENARIO=5
C=$(code n1)
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC" ${CLI_R:+"$CLI_R"} --debug --ignore-stdin send a.txt > "$TMP/5s.log" 2>&1; echo "rc=$?" >> "$TMP/5s.log" ) &
sleep 3
timeout 30 "$CT" receive ${CT_R:+"$CT_R"} -out "$TMP/dst" -answer n "$C" > "$TMP/5r.log" 2>&1 || true
wait
grep -q "refused files" "$TMP/5r.log" || fail "decline receiver side"
grep -Eq "$PEER_ERROR" "$TMP/5s.log" || fail "decline sender not notified"
pass "decline notifies sender"

# 6. receiver cancels mid-transfer -> sender errors out
# Throttle to 200 KB/s so the cancel lands at ~20% sent. Unthrottled loopback
# (~250 MB/s) finishes the 5 MB file before any cancel fires, reducing this to a
# test of the receiver's post-transfer hash step. Dedicated dst dir: scenario 7
# reuses big.bin and must not see this scenario's partial copy. As in scenario
# 5, the v11 CLI sender exits 0 and logs the peer's cancel only with --debug.
SCENARIO=6
C=$(code c1)
mkdir -p "$TMP/dst6"
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC" ${CLI_R:+"$CLI_R"} --debug --ignore-stdin --throttleUpload 200k send big.bin > "$TMP/6s.log" 2>&1; echo "rc=$?" >> "$TMP/6s.log" ) &
sleep 3
timeout 30 "$CT" receive ${CT_R:+"$CT_R"} -out "$TMP/dst6" -answer y -cancel-after 6000 "$C" > "$TMP/6r.log" 2>&1 || true
wait
! diff -q "$TMP/src/big.bin" "$TMP/dst6/big.bin" > /dev/null 2>&1 || fail "receiver cancel: transfer completed anyway"
grep -q "cancelled\|error" "$TMP/6r.log" || fail "receiver cancel: receiver side"
grep -Eq "$PEER_ERROR" "$TMP/6s.log" || fail "receiver cancel: sender not notified"
pass "receiver cancel"

# 7. sender cancels mid-transfer -> receiver errors out
# Same throttle reasoning as scenario 6, mirrored. Assert the destination file
# does NOT byte-match the source: a benign reconnect warning ("error setting
# read deadline") can satisfy a bare err/refus grep even on a full transfer,
# but the content check cannot be fooled that way.
SCENARIO=7
C=$(code c2)
mkdir -p "$TMP/dst7"
timeout 60 "$CT" send ${CT_R:+"$CT_R"} -code "$C" -throttle 200k -cancel-after 6000 "$TMP/src/big.bin" > "$TMP/7s.log" 2>&1 &
sleep 3
rc=0; ( cd "$TMP/dst7" && CROC_SECRET="$C" timeout 30 "$CROC" ${CLI_R:+"$CLI_R"} --yes --overwrite ) > "$TMP/7r.log" 2>&1 || rc=$?
wait
! diff -q "$TMP/src/big.bin" "$TMP/dst7/big.bin" > /dev/null 2>&1 || fail "sender cancel: transfer completed anyway"
[ "$rc" -ne 0 ] || grep -Eqi "interruption|context canceled|refus" "$TMP/7r.log" || fail "sender cancel: receiver did not error"
pass "sender cancel"

# 8. forced relay (LAN disabled both sides)
SCENARIO=8
C=$(code r1)
timeout 120 "$CT" send ${CT_R:+"$CT_R"} -code "$C" -no-local "$TMP/src/a.txt" > "$TMP/8.log" 2>&1 &
sleep 3
mkdir -p "$TMP/dst8"
( cd "$TMP/dst8" && CROC_SECRET="$C" timeout 90 "$CROC" ${CLI_R:+"$CLI_R"} --yes --overwrite ) > "$TMP/8.cli" 2>&1 || true
diff "$TMP/src/a.txt" "$TMP/dst8/a.txt" > /dev/null || fail "forced relay"
wait; pass "forced relay"

# 9. LAN only (no internet relay)
# croc's sender-side local relay control port is the first configured relay port
# (9009 by default). --ip routes the receiver straight there, bypassing
# multicast discovery, while still never touching the public relay. Failing hard
# on a missing IP beats discovery-only, which finds zero peers on this class of
# network and hangs until timeout.
SCENARIO=9
C=$(code l1)
LOCAL_IP=$(local_ip)
[ -n "$LOCAL_IP" ] || fail "LAN only: no local IP, cannot bypass multicast discovery"
timeout 90 "$CT" send -code "$C" -only-local "$TMP/src/a.txt" > "$TMP/9.log" 2>&1 &
sleep 3
mkdir -p "$TMP/dst9"
( cd "$TMP/dst9" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite --ip "$LOCAL_IP:9009" ) > "$TMP/9.cli" 2>&1 || true
diff "$TMP/src/a.txt" "$TMP/dst9/a.txt" > /dev/null || fail "LAN only"
wait; pass "LAN only"

# 10. croc v10 peer, both directions (R8): crocmobile reports peerVersion.
# Both sides must reach the same relay room. A v10 CLI defaults to
# croc.schollz.com, which is only one of the pool relays, so outside RELAY mode
# it is pointed at the pool relay the code maps to. LAN is off on both sides:
# the v10 sender's own local relay would answer with the old relay protocol.
v10_relay() { if [ -n "${RELAY:-}" ]; then echo "$RELAY"; else "$CT" relay "$1"; fi; }

SCENARIO=10
C=$(code v1)
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC_V10" --debug --ignore-stdin --relay "$(v10_relay "$C")" send --no-local a.txt ) > "$TMP/10s.cli" 2>&1 &
sleep 3
mkdir -p "$TMP/dst10"
timeout 30 "$CT" receive ${CT_R:+"$CT_R"} -no-local -out "$TMP/dst10" -answer y "$C" > "$TMP/10s.log" 2>&1 || true
wait
grep -q 'EVENT error {"code":"peerVersion"' "$TMP/10s.log" || fail "v10 sender: no peerVersion"
[ ! -e "$TMP/dst10/a.txt" ] || fail "v10 sender: file arrived"
pass "v10 sender: peerVersion"

C=$(code v2)
timeout 30 "$CT" send ${CT_R:+"$CT_R"} -no-local -code "$C" "$TMP/src/a.txt" > "$TMP/10r.log" 2>&1 &
sleep 3
( cd "$TMP/dst10" && CROC_SECRET="$C" timeout 30 "$CROC_V10" --debug --yes --overwrite --relay "$(v10_relay "$C")" ) > "$TMP/10r.cli" 2>&1 || true
wait
grep -q 'EVENT error {"code":"peerVersion"' "$TMP/10r.log" || fail "v10 receiver: no peerVersion"
[ ! -e "$TMP/dst10/a.txt" ] || fail "v10 receiver: file arrived"
pass "v10 receiver: peerVersion"

# 12. receive onto existing files (R24): Keep Both and Replace, answered at the
# prompt and preset with -yes. Keep Both leaves the old file and adds
# "a (1).txt"; Replace leaves one file with the new content. A zipped folder
# received twice into one folder hits croc's per-member unzip prompt, which
# reads the answers crocmobile queues: Keep Both skips the existing member,
# Replace at the prompt overwrites it, and both finish without an error. Under
# -yes the queued answers are always "n", so that a sender's --ask prompt,
# which croc forces even under -yes, is still refused with Replace: the last
# case checks that, and the zipped folder keeps its member.
SCENARIO=12
collide() {                                         # collide NAME POLICY ACCEPT...
  local name=$1 policy=$2 dir="$TMP/dst12-$1" C
  shift 2
  C=$(code "c$name")
  mkdir -p "$dir"
  echo "existing file" > "$dir/a.txt"
  ( cd "$TMP/src" && CROC_SECRET="$C" timeout 60 "$CROC" ${CLI_R:+"$CLI_R"} --ignore-stdin send a.txt ) > "$TMP/12$name.cli" 2>&1 &
  sleep 3
  timeout 60 "$CT" receive ${CT_R:+"$CT_R"} -out "$dir" -policy "$policy" "$@" "$C" > "$TMP/12$name.log" 2>&1 || true
  wait
  grep -q 'EVENT done {"files":1,"success":true' "$TMP/12$name.log" || fail "$policy ($*): receive did not succeed"
  if [ "$policy" = keepBoth ]; then
    [ "$(cat "$dir/a.txt")" = "existing file" ] || fail "keepBoth ($*): existing file changed"
    diff "$TMP/src/a.txt" "$dir/a (1).txt" > /dev/null || fail "keepBoth ($*): no a (1).txt with the new content"
  else
    diff "$TMP/src/a.txt" "$dir/a.txt" > /dev/null || fail "replace ($*): file not replaced"
    [ ! -e "$dir/a (1).txt" ] || fail "replace ($*): renamed copy written"
  fi
  pass "existing file, $policy ($*)"
}
collide kp keepBoth -answer y
collide rp replace -answer y
collide ky keepBoth -yes
collide ry replace -yes

zip_twice() {                                       # zip_twice NAME POLICY ACCEPT...
  local name=$1 policy=$2 dir="$TMP/dst12z-$1" C round
  shift 2
  for round in 1 2; do
    C=$(code "z$name$round")
    ( cd "$TMP/src" && CROC_SECRET="$C" timeout 60 "$CROC" ${CLI_R:+"$CLI_R"} --ignore-stdin send --zip sub ) > "$TMP/12z$name$round.cli" 2>&1 &
    sleep 3
    timeout 60 "$CT" receive ${CT_R:+"$CT_R"} -out "$dir" -policy "$policy" "$@" "$C" > "$TMP/12z$name$round.log" 2>&1 || true
    wait
    grep -q '"success":true' "$TMP/12z$name$round.log" || fail "zipped folder $policy ($*), round $round: receive did not succeed"
    [ ! -e "$dir/sub.zip" ] || fail "zipped folder $policy ($*), round $round: archive left behind"
    [ "$round" = 2 ] || echo "local edit" > "$dir/sub/b.txt"
  done
  if [ "$policy" = keepBoth ] || [ "$1" = -yes ]; then
    [ "$(cat "$dir/sub/b.txt")" = "local edit" ] || fail "zipped folder keepBoth ($*): existing member changed"
  else
    diff "$TMP/src/sub/b.txt" "$dir/sub/b.txt" > /dev/null || fail "zipped folder replace ($*): member not replaced"
  fi
  pass "zipped folder received twice, $policy ($*)"
}
zip_twice kp keepBoth -answer y
zip_twice rp replace -answer y
zip_twice ky keepBoth -yes
zip_twice ry replace -yes

C=$(code ask12)
mkdir -p "$TMP/dst12-ask"
( cd "$TMP/src" && CROC_SECRET="$C" timeout 60 "$CROC" ${CLI_R:+"$CLI_R"} --ignore-stdin --ask send a.txt ) > "$TMP/12ask.cli" 2>&1 &
sleep 3
timeout 60 "$CT" receive ${CT_R:+"$CT_R"} -out "$TMP/dst12-ask" -policy replace -yes "$C" > "$TMP/12ask.log" 2>&1 || true
wait
grep -q 'EVENT error {"code":"refused"' "$TMP/12ask.log" || fail "sender --ask under -yes with replace: not refused"
[ ! -e "$TMP/dst12-ask/a.txt" ] || fail "sender --ask under -yes with replace: file arrived"
pass "sender --ask under -yes with replace: refused"

if [ -n "${RELAY:-}" ]; then
  echo "ALL INTEROP CHECKS PASSED (relay $RELAY; public pool scenario skipped)"
  exit 0
fi

# 11. public relay pool: every pool relay, both directions, with custom codes
# and with wrapper-generated codes forced to each relay, plus one CLI-generated
# code. LAN is off on both sides, so a transfer completes only when both sides
# chose the same relay. The CLI's --debug log names the index it chose.
# A relay admits 30 connections a minute from one address, and a multiplexed
# transfer opens 9 per peer, so the earlier scenarios can exhaust a relay and
# make these fail with "relay admission rate limited". Hence: a wait for their
# admissions to age out, multiplexing off (2 connections per peer), and one pass
# over the pool per kind of transfer, so no relay is used twice in a row.
SCENARIO=11
await_code() {                                      # await_code LOG
  local i c
  for (( i = 0; i < 100; i++ )); do
    c=$(sed -n 's/^EVENT code //p' "$1")
    [ -n "$c" ] && { echo "$c"; return 0; }
    sleep 0.2
  done
  return 1
}
pool_code() {                                       # pool_code PREFIX RELAY
  local k c
  for (( k = 0; k < 64; k++ )); do
    c=$(code "$1$k")
    [ "$("$CT" relay "$c")" = "$2" ] && { echo "$c"; return 0; }
  done
  return 1
}
pool_send_custom() {                                # pool_send_custom INDEX RELAY
  local L="$TMP/11-$1-cs" C
  C=$(pool_code "p$1" "$2") || fail "relay $1: no custom code maps to $2"
  timeout 120 "$CT" send -no-local -no-multi -code "$C" "$TMP/src/a.txt" > "$L.log" 2>&1 &
  sleep 3
  mkdir -p "$L"
  ( cd "$L" && CROC_SECRET="$C" timeout 90 "$CROC" --debug --yes --overwrite ) > "$L.cli" 2>&1 || true
  wait
  diff "$TMP/src/a.txt" "$L/a.txt" > /dev/null || fail "relay $1: wrapper custom-code send"
  grep -q "EVENT relay $2" "$L.log" || fail "relay $1: wrapper send not on $2"
  grep -q "public relay index $1 selected: $2" "$L.cli" || fail "relay $1: CLI receive not on $2"
  pass "relay $1 ($2): wrapper sends, custom code"
}
pool_receive_custom() {                             # pool_receive_custom INDEX RELAY
  local L="$TMP/11-$1-cr" C
  C=$(pool_code "q$1" "$2") || fail "relay $1: no custom code maps to $2"
  ( cd "$TMP/src" && CROC_SECRET="$C" timeout 120 "$CROC" --debug --ignore-stdin --disable-clipboard send --no-local --no-multi a.txt ) > "$L.cli" 2>&1 &
  sleep 3
  timeout 90 "$CT" receive -no-local -out "$L" -answer y "$C" > "$L.log" 2>&1 || true
  wait
  diff "$TMP/src/a.txt" "$L/a.txt" > /dev/null || fail "relay $1: wrapper custom-code receive"
  grep -q "EVENT relay $2" "$L.log" || fail "relay $1: wrapper receive not on $2"
  grep -q "public relay index $1 selected: $2" "$L.cli" || fail "relay $1: CLI send not on $2"
  pass "relay $1 ($2): wrapper receives, custom code"
}
pool_send_generated() {                             # pool_send_generated INDEX RELAY
  local L="$TMP/11-$1-gs" C
  timeout 120 "$CT" send -no-local -no-multi -relay-index "$1" "$TMP/src/a.txt" > "$L.log" 2>&1 &
  C=$(await_code "$L.log") || fail "relay $1: wrapper printed no generated code"
  grep -q "EVENT relay $2" "$L.log" || fail "relay $1: generated code not on $2"
  sleep 3
  mkdir -p "$L"
  ( cd "$L" && CROC_SECRET="$C" timeout 90 "$CROC" --debug --yes --overwrite ) > "$L.cli" 2>&1 || true
  wait
  diff "$TMP/src/a.txt" "$L/a.txt" > /dev/null || fail "relay $1: wrapper generated-code send"
  grep -q "public relay index $1 selected: $2" "$L.cli" || fail "relay $1: CLI receive not on $2"
  pass "relay $1 ($2): wrapper sends, generated code"
}
POOL=$("$CT" relays)
[ -n "$POOL" ] || fail "relay pool: empty"
sleep 60
for leg in pool_send_custom pool_receive_custom pool_send_generated; do
  i=0
  for R in $POOL; do
    "$leg" "$i" "$R"
    i=$((i + 1))
  done
done

# The CLI caches the relay its latency probe picks, so this covers one index.
L="$TMP/11-cli"
( cd "$TMP/src" && timeout 120 "$CROC" --debug --ignore-stdin --disable-clipboard send --no-local --no-multi a.txt ) > "$L.cli" 2>&1 &
for (( k = 0; k < 100; k++ )); do
  C=$(sed -n 's|.*getcroc.com/?code=||p' "$L.cli")
  [ -n "$C" ] && break
  sleep 0.2
done
[ -n "$C" ] || fail "CLI-generated code: CLI printed no code"
R=$(sed -n 's/.*public relay index [0-9]* selected: //p' "$L.cli")
[ -n "$R" ] || fail "CLI-generated code: CLI logged no relay"
timeout 90 "$CT" receive -no-local -out "$L" -answer y "$C" > "$L.log" 2>&1 || true
wait
diff "$TMP/src/a.txt" "$L/a.txt" > /dev/null || fail "CLI-generated code receive"
grep -q "EVENT relay $R" "$L.log" || fail "CLI-generated code: wrapper not on $R"
pass "CLI-generated code ($R)"

echo "ALL INTEROP CHECKS PASSED"
