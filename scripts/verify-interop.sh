#!/usr/bin/env bash
# Interop verification: crocmobile (via croctest) <-> croc CLI v11.
# Covers: file/folder/text both directions, decline, cancel both directions,
# forced relay (LAN disabled), LAN-only, and every public pool relay (custom,
# wrapper-generated and CLI-generated codes). Exits non-zero on first failure.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc}"
require_croc

TMP=$(mktemp -d)
CT="$TMP/croctest"
trap 'kill_jobs; rm -rf "$TMP"' EXIT

( cd crocmobile && go build -o "$CT" ./cmd/croctest )

mkdir -p "$TMP/src/sub" "$TMP/dst"
echo "small file" > "$TMP/src/a.txt"
head -c 5242880 /dev/urandom > "$TMP/src/big.bin"
echo nested > "$TMP/src/sub/b.txt"

# Codes must differ in their first 4 characters: the relay hashes that prefix
# into a room name, so a shared prefix can collide across scenarios.
code() { echo "$1$$-interop"; }

# 1. wrapper sends file -> CLI receives
C=$(code f1)
timeout 90 "$CT" send -code "$C" "$TMP/src/a.txt" > "$TMP/1.log" 2>&1 &
sleep 3
( cd "$TMP/dst" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite ) > /dev/null 2>&1
diff "$TMP/src/a.txt" "$TMP/dst/a.txt" > /dev/null || fail "send file"
wait; pass "send file"

# 2. CLI sends file -> wrapper receives (accept)
# --ignore-stdin: the CLI probes stdin for piped content and a non-tty send can
# misbehave without it. CROC_SECRET (not --code): the CLI's non-classic send
# mode refuses a custom codephrase passed via --code.
C=$(code f2)
( cd "$TMP/src" && CROC_SECRET="$C" timeout 60 "$CROC" --ignore-stdin send a.txt ) > /dev/null 2>&1 &
sleep 3
timeout 60 "$CT" receive -out "$TMP/dst2" -answer y "$C" > "$TMP/2.log" 2>&1
diff "$TMP/src/a.txt" "$TMP/dst2/a.txt" > /dev/null || fail "receive file"
grep -q "EVENT filelist" "$TMP/2.log" || fail "filelist event"
wait; pass "receive file + filelist event"

# 3. folder both directions
C=$(code d1)
timeout 150 "$CT" send -code "$C" "$TMP/src" > /dev/null 2>&1 &
sleep 3
mkdir -p "$TMP/dstdir"
( cd "$TMP/dstdir" && CROC_SECRET="$C" timeout 120 "$CROC" --yes --overwrite ) > /dev/null 2>&1
diff -r "$TMP/src" "$TMP/dstdir/src" > /dev/null || fail "send folder"
wait; pass "send folder"

C=$(code d2)
( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin send src ) > /dev/null 2>&1 &
sleep 3
timeout 120 "$CT" receive -out "$TMP/dstdir2" -answer y "$C" > /dev/null 2>&1
diff -r "$TMP/src" "$TMP/dstdir2/src" > /dev/null || fail "receive folder"
wait; pass "receive folder"

# 4. text both directions
C=$(code t1)
timeout 90 "$CT" send -code "$C" -text "wrapper text" > /dev/null 2>&1 &
sleep 3
OUT=$( cd "$TMP" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite --stdout 2>/dev/null ) || true
[ "$OUT" = "wrapper text" ] || fail "send text (got: $OUT)"
wait; pass "send text"

C=$(code t2)
CROC_SECRET="$C" timeout 60 "$CROC" --ignore-stdin send --text "cli text" > /dev/null 2>&1 &
sleep 3
timeout 60 "$CT" receive -out "$TMP/dst" -answer y "$C" > "$TMP/4.log" 2>&1
grep -q "EVENT text cli text" "$TMP/4.log" || fail "receive text"
wait; pass "receive text"

# 5. decline notifies sender
# The croc v11 CLI sender exits 0 on a peer decline and reports it only in its
# debug log: "read error message" when it decodes the peer's error frame, then
# "peer error: refusing files". The CLI can exit before writing the second line,
# so either one counts.
PEER_ERROR='peer error: refusing files|read error message'

C=$(code n1)
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC" --debug --ignore-stdin send a.txt > "$TMP/5s.log" 2>&1; echo "rc=$?" >> "$TMP/5s.log" ) &
sleep 3
timeout 30 "$CT" receive -out "$TMP/dst" -answer n "$C" > "$TMP/5r.log" 2>&1 || true
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
C=$(code c1)
mkdir -p "$TMP/dst6"
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC" --debug --ignore-stdin --throttleUpload 200k send big.bin > "$TMP/6s.log" 2>&1; echo "rc=$?" >> "$TMP/6s.log" ) &
sleep 3
timeout 30 "$CT" receive -out "$TMP/dst6" -answer y -cancel-after 6000 "$C" > "$TMP/6r.log" 2>&1 || true
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
C=$(code c2)
mkdir -p "$TMP/dst7"
timeout 60 "$CT" send -code "$C" -throttle 200k -cancel-after 6000 "$TMP/src/big.bin" > "$TMP/7s.log" 2>&1 &
sleep 3
rc=0; ( cd "$TMP/dst7" && CROC_SECRET="$C" timeout 30 "$CROC" --yes --overwrite ) > "$TMP/7r.log" 2>&1 || rc=$?
wait
! diff -q "$TMP/src/big.bin" "$TMP/dst7/big.bin" > /dev/null 2>&1 || fail "sender cancel: transfer completed anyway"
[ "$rc" -ne 0 ] || grep -Eqi "interruption|context canceled|refus" "$TMP/7r.log" || fail "sender cancel: receiver did not error"
pass "sender cancel"

# 8. forced relay (LAN disabled both sides)
C=$(code r1)
timeout 120 "$CT" send -code "$C" -no-local "$TMP/src/a.txt" > /dev/null 2>&1 &
sleep 3
mkdir -p "$TMP/dst8"
( cd "$TMP/dst8" && CROC_SECRET="$C" timeout 90 "$CROC" --yes --overwrite ) > /dev/null 2>&1
diff "$TMP/src/a.txt" "$TMP/dst8/a.txt" > /dev/null || fail "forced relay"
wait; pass "forced relay"

# 9. LAN only (no internet relay)
# croc's sender-side local relay control port is the first configured relay port
# (9009 by default). --ip routes the receiver straight there, bypassing
# multicast discovery, while still never touching the public relay. Failing hard
# on a missing IP beats discovery-only, which finds zero peers on this class of
# network and hangs until timeout.
C=$(code l1)
LOCAL_IP=$(local_ip)
[ -n "$LOCAL_IP" ] || fail "LAN only: no local IP, cannot bypass multicast discovery"
timeout 90 "$CT" send -code "$C" -only-local "$TMP/src/a.txt" > /dev/null 2>&1 &
sleep 3
mkdir -p "$TMP/dst9"
( cd "$TMP/dst9" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite --ip "$LOCAL_IP:9009" ) > /dev/null 2>&1
diff "$TMP/src/a.txt" "$TMP/dst9/a.txt" > /dev/null || fail "LAN only"
wait; pass "LAN only"

# 10. public relay pool: every pool relay, both directions, with custom codes
# and with wrapper-generated codes forced to each relay, plus one CLI-generated
# code. LAN is off on both sides, so a transfer completes only when both sides
# chose the same relay. The CLI's --debug log names the index it chose.
# A relay admits 30 connections a minute from one address, and a multiplexed
# transfer opens 9 per peer, so the earlier scenarios can exhaust a relay and
# make these fail with "relay admission rate limited". Hence: a wait for their
# admissions to age out, multiplexing off (2 connections per peer), and one pass
# over the pool per kind of transfer, so no relay is used twice in a row.
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
  local L="$TMP/10-$1-cs" C
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
  local L="$TMP/10-$1-cr" C
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
  local L="$TMP/10-$1-gs" C
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
L="$TMP/10-cli"
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
