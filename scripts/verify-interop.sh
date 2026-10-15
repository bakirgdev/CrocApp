#!/usr/bin/env bash
# Interop verification: crocmobile (via croctest) <-> croc CLI v11.
# Covers: file/folder/text both directions, decline, cancel both directions,
# forced relay (LAN disabled), LAN-only, a croc v10 peer both directions, a
# receive onto existing files with Keep Both and Replace (R24), a 130 MiB send
# in each transport mode (R17), stored transfers against a local store server
# (R18-R20), the Advanced options that change the wire (R25: curve, hash, ports,
# multicast group, proxies, internal DNS), and every public pool relay (custom,
# wrapper-generated and CLI-generated codes).
# Exits non-zero on first failure.
#
# RELAY=host:port runs every transfer through that relay instead of the public
# pool, and skips the transport, proxy, internal DNS and pool scenarios (CI runs
# this against a local `croc relay`).
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
# reads the answers crocmobile queues. They are always "n", so every policy
# keeps the existing member and finishes without an error: a queued "y" would
# also answer the accept prompt croc re-runs after a reconnect, and the one
# croc forces under -yes when the sender ran --ask. The last case checks that
# --ask prompt is refused with Replace.
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
  [ "$(cat "$dir/sub/b.txt")" = "local edit" ] || fail "zipped folder $policy ($*): existing member changed"
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

# 14. stored transfers (R18-R20) against a local croc store server, no relay and
# no internet: crocmobile uploads and the CLI downloads, the CLI uploads and
# crocmobile downloads, and a revoked transfer no longer downloads. Every upload
# lasts an hour, allows the downloads the case needs, and is revoked at the end.
# The CLI's revoke receipts go to a throwaway config dir.
SCENARIO=14
mkdir -p "$TMP/store14" "$TMP/croc-config14"
"$CT" store-server "$TMP/store14" > "$TMP/14srv.log" 2>&1 &
STORE_PID=$!
STORE=""
for _ in $(seq 1 50); do
  STORE=$(sed -n 's/^STORE-URL //p' "$TMP/14srv.log")
  [ -n "$STORE" ] && break
  sleep 0.2
done
[ -n "$STORE" ] || fail "store server did not start"
field() {                                           # field LOGFILE KEY: a string value from the EVENT stored receipt
  sed -n "s/.*\"$2\":\"\\([^\"]*\\)\".*/\\1/p" "$1" | head -1
}
cli_store() { CROC_CONFIG_DIR="$TMP/croc-config14" "$CROC" --disable-clipboard "$@"; }

# 14a. wrapper uploads two files (the 5 MiB one spans two chunks), CLI downloads.
# Two downloads allowed so one is left at revoke time: the last download makes
# the server answer revoke with 410, which counts as revoked, so a broken revoke
# would still pass 14b and 14c.
"$CT" store-send -server "$STORE" -downloads 2 -lifetime 3600 "$TMP/src/a.txt" "$TMP/src/big.bin" > "$TMP/14a.log" 2>&1 || fail "store send (wrapper)"
LINK=$(field "$TMP/14a.log" link); ID=$(field "$TMP/14a.log" id); TOKEN=$(field "$TMP/14a.log" uploadToken)
[ -n "$LINK" ] && [ -n "$ID" ] && [ -n "$TOKEN" ] || fail "store send (wrapper): no receipt"
grep -q 'EVENT done {"files":2,"success":true' "$TMP/14a.log" || fail "store send (wrapper): no success summary"
mkdir -p "$TMP/dst14a"
CROC_STORE_TOKEN="$LINK" timeout 60 "$CROC" --yes --out "$TMP/dst14a" > "$TMP/14a.cli" 2>&1 || true
diff "$TMP/src/a.txt" "$TMP/dst14a/a.txt" > /dev/null || fail "store send (wrapper) -> CLI receive: a.txt"
diff "$TMP/src/big.bin" "$TMP/dst14a/big.bin" > /dev/null || fail "store send (wrapper) -> CLI receive: big.bin"
pass "store: wrapper upload, CLI download"

# 14b. revoke from the wrapper, then the transfer is gone for the CLI
"$CT" store-revoke "$STORE" "$ID" "$TOKEN" > "$TMP/14b.log" 2>&1 || fail "store revoke (wrapper)"
grep -q 'EVENT revoked' "$TMP/14b.log" || fail "store revoke (wrapper): no revoked event"
"$CT" store-revoke "$STORE" "$ID" "$TOKEN" > "$TMP/14b2.log" 2>&1 || fail "store revoke twice: a missing transfer must count as revoked"
mkdir -p "$TMP/dst14b"
CROC_STORE_TOKEN="$LINK" timeout 60 "$CROC" --yes --out "$TMP/dst14b" > "$TMP/14b.cli" 2>&1 && fail "revoked transfer still downloads (CLI)"
[ -z "$(ls -A "$TMP/dst14b")" ] || fail "revoked transfer wrote files (CLI)"
pass "store: revoke, then CLI download fails"

# 14c. CLI uploads, wrapper downloads, then the CLI revokes and the wrapper's
# download fails with storeExpired
cli_store --ignore-stdin store --url "$STORE" --downloads 2 --expiration 1h "$TMP/src/a.txt" "$TMP/src/big.bin" > "$TMP/14c.cli" 2>&1 || fail "store send (CLI)"
LINK=$(grep -o 'http://127.0.0.1:[0-9]*/s/[A-Za-z0-9_-]*#v1\.[A-Za-z0-9_-]*' "$TMP/14c.cli" | head -1)
ID=${LINK#*/s/}; ID=${ID%%#*}
[ -n "$LINK" ] && [ -n "$ID" ] || fail "store send (CLI): no link in its output"
timeout 60 "$CT" store-receive -out "$TMP/dst14c" -answer y "$LINK" > "$TMP/14c.log" 2>&1 || true
grep -q 'EVENT filelist' "$TMP/14c.log" || fail "store receive: no filelist event"
diff "$TMP/src/a.txt" "$TMP/dst14c/a.txt" > /dev/null || fail "store send (CLI) -> wrapper receive: a.txt"
diff "$TMP/src/big.bin" "$TMP/dst14c/big.bin" > /dev/null || fail "store send (CLI) -> wrapper receive: big.bin"
cli_store --revoke "$ID" > "$TMP/14c.revoke" 2>&1 || fail "store revoke (CLI)"
timeout 60 "$CT" store-receive -out "$TMP/dst14c2" -answer y "$LINK" > "$TMP/14c2.log" 2>&1 && fail "revoked transfer still downloads (wrapper)"
grep -q 'EVENT error {"code":"storeExpired"' "$TMP/14c2.log" || fail "revoked transfer: not storeExpired"
pass "store: CLI upload, wrapper download, revoke, then wrapper download fails"

# 14d. a receive onto an existing name: Keep Both adds "a (1).txt", Replace
# overwrites, and a declined preview leaves the transfer downloadable
"$CT" store-send -server "$STORE" -downloads 3 -lifetime 3600 "$TMP/src/a.txt" > "$TMP/14d.log" 2>&1 || fail "store send for collision"
LINK=$(field "$TMP/14d.log" link); ID=$(field "$TMP/14d.log" id); TOKEN=$(field "$TMP/14d.log" uploadToken)
mkdir -p "$TMP/dst14d"
echo "existing file" > "$TMP/dst14d/a.txt"
timeout 60 "$CT" store-receive -out "$TMP/dst14d" -answer n "$LINK" > "$TMP/14d0.log" 2>&1 && fail "declined store receive exited 0"
grep -q 'EVENT error {"code":"refused"' "$TMP/14d0.log" || fail "declined store receive: not refused"
[ "$(cat "$TMP/dst14d/a.txt")" = "existing file" ] || fail "declined store receive changed the existing file"
[ "$(find "$TMP/dst14d" -type f | wc -l | tr -d ' ')" = 1 ] || fail "declined store receive wrote files"
timeout 60 "$CT" store-receive -out "$TMP/dst14d" -answer y -policy keepBoth "$LINK" > "$TMP/14d1.log" 2>&1 || fail "store receive, keepBoth"
[ "$(cat "$TMP/dst14d/a.txt")" = "existing file" ] || fail "store keepBoth: existing file changed"
diff "$TMP/src/a.txt" "$TMP/dst14d/a (1).txt" > /dev/null || fail "store keepBoth: no a (1).txt with the new content"
timeout 60 "$CT" store-receive -out "$TMP/dst14d" -answer y -policy replace "$LINK" > "$TMP/14d2.log" 2>&1 || fail "store receive, replace"
diff "$TMP/src/a.txt" "$TMP/dst14d/a.txt" > /dev/null || fail "store replace: file not replaced"
"$CT" store-revoke "$STORE" "$ID" "$TOKEN" > "$TMP/14d3.log" 2>&1 || fail "store revoke after collision cases"
pass "store: existing file with Keep Both and Replace, decline keeps the transfer"
# Later scenarios end in a bare `wait`, which would wait on the server forever.
kill "$STORE_PID"
wait "$STORE_PID" 2>/dev/null || true

# 15. Advanced options that change the wire (R25), against the croc v11 CLI with
# the matching flag. What each case pins down was observed with croc v11.5.4:
#  - curve: the receiver chooses it and the sender adopts it ("using curve" in
#    the CLI sender's --debug log); the sender's own curve is never used, so a
#    mismatch is not an error in either direction.
#  - hash: the sender chooses it and the receiver adopts it ("using hash
#    algorithm" in the CLI receiver's --debug log); -hash imohash is sent as
#    imohash-v2.
#  - base port and transfers: the sender's local relay listens on the base port
#    and the next `transfers` ports, so a receiver given the sender IP reaches
#    it there, and the banner it reads lists those data ports.
#  - multicast: croc's peer discovery drops packets from the host's own
#    addresses, so two peers on one host never find each other. A listener on
#    the group sees what each side announces instead.
# The CLI runs with a throwaway config dir, because it remembers its flags.
SCENARIO=15
CFG15="$TMP/croc-config15"
mkdir -p "$CFG15"
# A pool relay admits 30 connections a minute from one address, and scenario 12
# spends most of that; see scenario 11.
[ -n "${RELAY:-}" ] || sleep 60

free_port() {                                       # a base port with 3 free loopback ports from it
  local p k i busy
  for (( k = 0; k < 50; k++ )); do
    p=$(( 20000 + RANDOM % 9000 ))
    busy=0
    for i in 0 1 2; do
      ( exec 3<>"/dev/tcp/127.0.0.1/$((p + i))" ) 2>/dev/null && busy=1
    done
    [ "$busy" = 0 ] && { echo "$p"; return 0; }
  done
  return 1
}

adv_ws() {                                          # adv_ws NAME FILE CLI_FLAGS CT_FLAGS: wrapper sends, CLI receives
  local name=$1 file=$2 cli_flags=$3 ct_flags=$4 dir="$TMP/15$1" C
  C=$(code "$name")
  mkdir -p "$dir"
  # shellcheck disable=SC2086  # a flag string, split on purpose
  timeout 90 "$CT" send ${CT_R:+"$CT_R"} -no-multi $ct_flags -code "$C" "$TMP/src/$file" > "$TMP/15$name.log" 2>&1 &
  sleep 3
  # shellcheck disable=SC2086
  ( cd "$dir" && CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 60 "$CROC" ${CLI_R:+"$CLI_R"} --debug --yes --overwrite $cli_flags ) > "$TMP/15$name.cli" 2>&1 || true
  wait
  cmp -s "$TMP/src/$file" "$dir/$file" || fail "$name: wrapper send, CLI receive: bytes differ"
}

adv_sw() {                                          # adv_sw NAME FILE CLI_GLOBAL CLI_SEND CT_FLAGS: CLI sends, wrapper receives
  local name=$1 file=$2 cli_global=$3 cli_send=$4 ct_flags=$5 dir="$TMP/15$1" C
  C=$(code "$name")
  mkdir -p "$dir"
  # shellcheck disable=SC2086
  ( cd "$TMP/src" && CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 90 "$CROC" ${CLI_R:+"$CLI_R"} --debug --disable-clipboard --ignore-stdin $cli_global send --no-multi $cli_send "$file" ) > "$TMP/15$name.cli" 2>&1 &
  sleep 3
  # shellcheck disable=SC2086
  timeout 60 "$CT" receive ${CT_R:+"$CT_R"} -out "$dir" -answer y $ct_flags "$C" > "$TMP/15$name.log" 2>&1 || true
  wait
  cmp -s "$TMP/src/$file" "$dir/$file" || fail "$name: CLI send, wrapper receive: bytes differ"
}

# 15 curve. Sender and receiver agree: the transfer succeeds. They disagree: it
# still succeeds, in both directions, and the receiver's curve is the one used.
adv_ws cv1 a.txt "--curve siec" "-curve siec"
pass "curve: wrapper sends -curve siec, CLI receives --curve siec"
adv_sw cv2 a.txt "--curve siec" "" "-curve siec"
grep -q "using curve siec" "$TMP/15cv2.cli" || fail "curve: CLI sender did not use the wrapper receiver's siec"
pass "curve: CLI sends --curve siec, wrapper receives -curve siec"
adv_ws cv3 a.txt "--curve p384" "-curve siec"
pass "curve mismatch: wrapper sends -curve siec, CLI receives --curve p384, still succeeds"
adv_sw cv4 a.txt "--curve siec" "" "-curve p384"
grep -q "using curve p384" "$TMP/15cv4.cli" || fail "curve mismatch: the receiver's curve was not the one used"
pass "curve mismatch: CLI sends --curve siec, wrapper receives -curve p384, succeeds on the receiver's curve"

# 15 hash. The receiver takes the sender's algorithm whatever it is set to.
adv_ws hs1 big.bin "" "-hash imohash"
grep -q "using hash algorithm: imohash-v2" "$TMP/15hs1.cli" || fail "hash: CLI receiver did not adopt the wrapper's imohash"
pass "hash: wrapper sends -hash imohash, CLI receives it as imohash-v2"
adv_ws hs2 big.bin "" "-hash md5"
grep -q "using hash algorithm: md5" "$TMP/15hs2.cli" || fail "hash: CLI receiver did not adopt the wrapper's md5"
pass "hash: wrapper sends -hash md5, CLI receives md5"
adv_sw hs3 big.bin "" "--hash md5" ""
pass "hash: CLI sends --hash md5, wrapper receives"
adv_sw hs4 big.bin "" "--hash md5" "-hash highway"
pass "hash mismatch: CLI sends --hash md5, wrapper receives with -hash highway, still succeeds"

# 15 base port and transfers, with the sender IP. -only-local keeps the relay
# out of it: the receiver can reach the sender only at the base port it was given.
P=$(free_port) || fail "ports: no free port range"
C=$(code pt1)
mkdir -p "$TMP/dst15pt1"
timeout 90 "$CT" send -only-local -port "$P" -transfers 2 -code "$C" "$TMP/src/big.bin" > "$TMP/15pt1.log" 2>&1 &
sleep 3
( cd "$TMP/dst15pt1" && CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 60 "$CROC" --debug --yes --overwrite --ip "127.0.0.1:$P" ) > "$TMP/15pt1.cli" 2>&1 || true
wait
cmp -s "$TMP/src/big.bin" "$TMP/dst15pt1/big.bin" || fail "ports: wrapper send -port $P, CLI receive --ip: bytes differ"
grep -q "banner: $((P + 1)),$((P + 2))$" "$TMP/15pt1.cli" || fail "ports: banner is not the two data ports after $P"
pass "ports: wrapper sends -port $P -transfers 2, CLI receives --ip 127.0.0.1:$P over those ports"

P=$(free_port) || fail "ports: no free port range"
C=$(code pt2)
mkdir -p "$TMP/dst15pt2"
( cd "$TMP/src" && CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 90 "$CROC" --debug --disable-clipboard --ignore-stdin --local send --port "$P" --transfers 2 big.bin ) > "$TMP/15pt2.cli" 2>&1 &
sleep 3
timeout 60 "$CT" receive -ip "127.0.0.1:$P" -out "$TMP/dst15pt2" -answer y "$C" > "$TMP/15pt2.log" 2>&1 || true
wait
cmp -s "$TMP/src/big.bin" "$TMP/dst15pt2/big.bin" || fail "ports: CLI send --port $P, wrapper receive -ip: bytes differ"
pass "ports: CLI sends --port $P --transfers 2, wrapper receives -ip 127.0.0.1:$P"

# A sender IP with nothing listening fails at once, instead of falling back to a relay.
P=$(free_port) || fail "ports: no free port range"
timeout 30 "$CT" receive -ip "127.0.0.1:$P" -out "$TMP/dst15pt3" -answer y "$(code pt3)" > "$TMP/15pt3.log" 2>&1 && fail "ports: receive from a dead sender IP exited 0"
grep -q 'EVENT error {"code":"relayUnreachable"' "$TMP/15pt3.log" || fail "ports: dead sender IP: not relayUnreachable"
pass "ports: a sender IP with nothing listening fails with relayUnreachable"

# 15 multicast. Each side announces on the group it was given: a sender
# "croc<base port>", a receiver "ok". The CLI cases show the listener sees what
# real croc sends, and the last case that another group stays unheard.
MC_GROUP=239.255.42.99
MC_OTHER=239.255.42.98
mc_listen() {                                       # mc_listen GROUP LOG: join for 6 s in the background
  "$CT" multicast-listen "$1" 6 > "$2" 2>&1 &
  MC_PID=$!
  sleep 1
}
mc_heard() {                                        # mc_heard LOG PAYLOAD LABEL
  wait "$MC_PID" || fail "multicast: listener failed ($3)"
  grep -qx "MULTICAST-PAYLOAD $2" "$1" || fail "multicast: $3: group did not carry '$2'"
}
if "$CT" multicast-listen "$MC_GROUP" 1 > "$TMP/15mcprobe.log" 2>&1; then
  P=$(free_port) || fail "multicast: no free port range"
  C=$(code mc1)
  mc_listen "$MC_GROUP" "$TMP/15mc1.listen"
  timeout 4 "$CT" send -only-local -port "$P" -multicast "$MC_GROUP" -code "$C" "$TMP/src/a.txt" > "$TMP/15mc1.log" 2>&1 || true
  mc_heard "$TMP/15mc1.listen" "croc$P" "wrapper sender"
  pass "multicast: wrapper -multicast $MC_GROUP announces croc$P on that group"

  C=$(code mc2)
  mc_listen "$MC_GROUP" "$TMP/15mc2.listen"
  timeout 4 "$CT" receive -only-local -multicast "$MC_GROUP" -out "$TMP/dst15mc" -answer y "$C" > "$TMP/15mc2.log" 2>&1 || true
  mc_heard "$TMP/15mc2.listen" "ok" "wrapper receiver"
  pass "multicast: wrapper receive -multicast $MC_GROUP looks for senders on that group"

  C=$(code mc3)
  mc_listen "$MC_GROUP" "$TMP/15mc3.listen"
  ( cd "$TMP/src" && CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 4 "$CROC" --disable-clipboard --ignore-stdin --local --multicast "$MC_GROUP" send --port "$P" a.txt ) > "$TMP/15mc3.cli" 2>&1 || true
  mc_heard "$TMP/15mc3.listen" "croc$P" "CLI sender"
  C=$(code mc4)
  mc_listen "$MC_GROUP" "$TMP/15mc4.listen"
  CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 4 "$CROC" --disable-clipboard --local --multicast "$MC_GROUP" --yes --out "$TMP/dst15mc" > "$TMP/15mc4.cli" 2>&1 || true
  mc_heard "$TMP/15mc4.listen" "ok" "CLI receiver"
  pass "multicast: the CLI announces the same payloads on the same group"

  C=$(code mc5)
  mc_listen "$MC_GROUP" "$TMP/15mc5.listen"
  timeout 4 "$CT" send -only-local -multicast "$MC_OTHER" -code "$C" "$TMP/src/a.txt" > "$TMP/15mc5.log" 2>&1 || true
  wait "$MC_PID" || fail "multicast: listener failed (mismatch)"
  ! grep -q '^MULTICAST-PAYLOAD' "$TMP/15mc5.listen" || fail "multicast mismatch: a sender on $MC_OTHER was heard on $MC_GROUP"
  pass "multicast mismatch: a sender on $MC_OTHER is not heard on $MC_GROUP"
else
  echo "SKIP: multicast cases (15): this host has no multicast interface to join"
fi

if [ -n "${RELAY:-}" ]; then
  echo "SKIP: proxy and internal DNS cases (15): the relay at $RELAY is a local address, which croc's dialer reaches without the proxy"
  echo "ALL INTEROP CHECKS PASSED (relay $RELAY; transport, proxy, internal DNS and public pool scenarios skipped)"
  exit 0
fi

# 13. transport (R17): a send over croc's 128 MiB Tailcat threshold in each
# mode, both directions. Under auto the sender offers Tailcat and races it
# against the relay; either may carry the data. Under relay no Tailcat offer is
# made. The --debug CLI logs show the offer ("tailcat-offer") on either side.
# Public infrastructure only (Tailcat bootstraps from tailcat.dev), so not in
# RELAY mode.
SCENARIO=13
head -c 136314880 /dev/urandom > "$TMP/huge.bin"
transport_send() {                                  # transport_send MODE
  local L="$TMP/13s-$1" C
  C=$(code "ts$1")
  mkdir -p "$L"
  timeout 300 "$CT" send -transport "$1" -code "$C" "$TMP/huge.bin" > "$L.log" 2>&1 &
  sleep 3
  ( cd "$L" && CROC_SECRET="$C" timeout 280 "$CROC" --debug --yes --overwrite ) > "$L.cli" 2>&1 || true
  wait
  cmp -s "$TMP/huge.bin" "$L/huge.bin" || fail "transport $1: wrapper send of 130 MiB"
}
transport_receive() {                               # transport_receive MODE
  local L="$TMP/13r-$1" C
  C=$(code "tr$1")
  ( cd "$TMP" && CROC_SECRET="$C" timeout 300 "$CROC" --debug --ignore-stdin send --transport "$1" huge.bin ) > "$L.cli" 2>&1 &
  sleep 3
  timeout 280 "$CT" receive -out "$L" -answer y "$C" > "$L.log" 2>&1 || true
  wait
  cmp -s "$TMP/huge.bin" "$L/huge.bin" || fail "transport $1: wrapper receive of 130 MiB"
}
transport_send auto
grep -q "tailcat-offer" "$TMP/13s-auto.cli" || fail "transport auto: wrapper sent no Tailcat offer"
pass "transport auto: wrapper sends 130 MiB, Tailcat offered"
transport_send relay
! grep -q "tailcat-offer" "$TMP/13s-relay.cli" || fail "transport relay: wrapper offered Tailcat"
pass "transport relay: wrapper sends 130 MiB, no Tailcat offer"
transport_receive auto
grep -q "selected=derp" "$TMP/13r-auto.cli" || fail "transport auto: CLI did not choose Tailcat for 130 MiB"
pass "transport auto: wrapper receives 130 MiB, Tailcat offered"
transport_receive relay
! grep -q "tailcat-offer" "$TMP/13r-relay.cli" || fail "transport relay: CLI offered Tailcat"
pass "transport relay: wrapper receives 130 MiB, no Tailcat offer"
rm -f "$TMP/huge.bin" "$TMP"/13[sr]-*/huge.bin

# 15 proxies and internal DNS (R25). croc's dialer bypasses proxies for local
# addresses, so these need the public pool: the transfer goes through a croctest
# proxy that counts the connections it tunnels. -no-local keeps the data off the
# LAN. Skipped under RELAY, whose address is local.
SCENARIO=15
start_proxy() {                                     # start_proxy KIND: sets PROXY_PID and PROXY_ADDR
  "$CT" "$1-proxy" > "$TMP/15px-$1.log" 2>&1 &
  PROXY_PID=$!
  PROXY_ADDR=""
  for _ in $(seq 1 50); do
    PROXY_ADDR=$(sed -n 's/^PROXY-ADDR //p' "$TMP/15px-$1.log")
    [ -n "$PROXY_ADDR" ] && break
    sleep 0.2
  done
  [ -n "$PROXY_ADDR" ] || fail "$1 proxy did not start"
}
tunnels() { grep -c '^PROXY-TUNNEL' "$TMP/15px-$1.log" || true; }

proxy_send() {                                      # proxy_send KIND FLAG: wrapper sends through the proxy, CLI receives
  local kind=$1 flag=$2 L="$TMP/15px-$1-send" C job
  C=$(code "px$kind")
  mkdir -p "$L"
  start_proxy "$kind"
  timeout 100 "$CT" send -no-local -no-multi "$flag" "$PROXY_ADDR" -code "$C" "$TMP/src/a.txt" > "$L.log" 2>&1 &
  job=$!
  sleep 4
  ( cd "$L" && CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 80 "$CROC" --debug --yes --overwrite ) > "$L.cli" 2>&1 || true
  wait "$job" || true
  kill "$PROXY_PID"
  wait "$PROXY_PID" 2>/dev/null || true
  cmp -s "$TMP/src/a.txt" "$L/a.txt" || fail "$kind proxy: wrapper send: bytes differ"
  [ "$(tunnels "$kind")" -ge 1 ] || fail "$kind proxy: wrapper send tunnelled no connection"
  pass "$kind proxy: wrapper $flag sends through $(tunnels "$kind") tunnelled connections"
}
proxy_receive() {                                   # proxy_receive KIND FLAG: CLI sends, wrapper receives through the proxy
  local kind=$1 flag=$2 L="$TMP/15px-$1-recv" C job
  C=$(code "py$kind")
  mkdir -p "$L"
  start_proxy "$kind"
  ( cd "$TMP/src" && CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 100 "$CROC" --debug --disable-clipboard --ignore-stdin send --no-local --no-multi a.txt ) > "$L.cli" 2>&1 &
  job=$!
  sleep 4
  timeout 80 "$CT" receive -no-local "$flag" "$PROXY_ADDR" -out "$L" -answer y "$C" > "$L.log" 2>&1 || true
  wait "$job" || true
  kill "$PROXY_PID"
  wait "$PROXY_PID" 2>/dev/null || true
  cmp -s "$TMP/src/a.txt" "$L/a.txt" || fail "$kind proxy: wrapper receive: bytes differ"
  [ "$(tunnels "$kind")" -ge 1 ] || fail "$kind proxy: wrapper receive tunnelled no connection"
  pass "$kind proxy: wrapper $flag receives through $(tunnels "$kind") tunnelled connections"
}
proxy_send socks5 -socks5
proxy_receive socks5 -socks5
proxy_send http -connect
proxy_receive http -connect

# Internal DNS only swaps the resolver for the relay's name; the transfer
# working is all the harness can see of it.
C=$(code dns1)
mkdir -p "$TMP/15dns"
timeout 100 "$CT" send -no-local -no-multi -internal-dns -code "$C" "$TMP/src/a.txt" > "$TMP/15dns.log" 2>&1 &
job=$!
sleep 4
( cd "$TMP/15dns" && CROC_CONFIG_DIR="$CFG15" CROC_SECRET="$C" timeout 80 "$CROC" --debug --yes --overwrite ) > "$TMP/15dns.cli" 2>&1 || true
wait "$job" || true
cmp -s "$TMP/src/a.txt" "$TMP/15dns/a.txt" || fail "internal DNS: wrapper send over the public pool: bytes differ"
pass "internal DNS: wrapper -internal-dns sends over the public pool"

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
