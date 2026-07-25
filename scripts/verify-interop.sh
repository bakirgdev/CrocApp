#!/usr/bin/env bash
# Interop verification: crocmobile (via croctest) <-> croc CLI v10.5.0.
# Covers: file/folder/text both directions, decline, cancel both directions,
# forced relay (LAN disabled), LAN-only. Exits non-zero on first failure.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-$HOME/go/bin/croc}"
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
C=$(code f2)
# --ignore-stdin: the CLI probes stdin for piped content; without it, a
# non-tty send can misbehave.
# CROC_SECRET (not --code): v10.5.0's non-classic send mode refuses a custom
# codephrase passed via --code and tells you to use CROC_SECRET instead.
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
OUT=$( cd "$TMP" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite --stdout 2>/dev/null )
[ "$OUT" = "wrapper text" ] || fail "send text (got: $OUT)"
wait; pass "send text"

C=$(code t2)
CROC_SECRET="$C" timeout 60 "$CROC" --ignore-stdin send --text "cli text" > /dev/null 2>&1 &
sleep 3
timeout 60 "$CT" receive -out "$TMP/dst" -answer y "$C" > "$TMP/4.log" 2>&1
grep -q "EVENT text cli text" "$TMP/4.log" || fail "receive text"
wait; pass "receive text"

# 5. decline notifies sender
# croc v10.5.0 races on the sender side when a peer decline arrives: usually
# "peer error: refusing files", occasionally the generic "context canceled"
# (same event, two internal error-return paths). Accept either as evidence the
# sender was notified.
C=$(code n1)
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC" --ignore-stdin send a.txt > "$TMP/5s.log" 2>&1; echo "rc=$?" >> "$TMP/5s.log" ) &
sleep 3
timeout 30 "$CT" receive -out "$TMP/dst" -answer n "$C" > "$TMP/5r.log" 2>&1 || true
wait
grep -q "refused files" "$TMP/5r.log" || fail "decline receiver side"
grep -Eqi "refus|context canceled" "$TMP/5s.log" || fail "decline sender not notified"
pass "decline notifies sender"

# 6. receiver cancels mid-transfer -> sender errors out
# Throttle to 200 KB/s so the 5 MB file takes ~25s. Unthrottled loopback
# (~250 MB/s) sends the whole file before any cancel fires, which reduces this
# to a test of the receiver's post-transfer hash step. At 200 KB/s the cancel
# lands at ~20% sent. Dedicated dst dir: scenario 7 reuses big.bin and must
# not see this scenario's partial copy.
C=$(code c1)
mkdir -p "$TMP/dst6"
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC" --ignore-stdin --throttleUpload 200k send big.bin > "$TMP/6s.log" 2>&1; echo "rc=$?" >> "$TMP/6s.log" ) &
sleep 3
timeout 30 "$CT" receive -out "$TMP/dst6" -answer y -cancel-after 6000 "$C" > "$TMP/6r.log" 2>&1 || true
wait
! diff -q "$TMP/src/big.bin" "$TMP/dst6/big.bin" > /dev/null 2>&1 || fail "receiver cancel: transfer completed anyway"
grep -q "cancelled\|error" "$TMP/6r.log" || fail "receiver cancel: receiver side"
! grep -q "rc=0" "$TMP/6s.log" || fail "receiver cancel: sender exited 0"
grep -Eqi "context canceled|peer error|refus" "$TMP/6s.log" || fail "receiver cancel: sender did not report a real error"
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
# croc's sender-side local relay control port is the first configured relay
# port (9009 by default). --ip routes the receiver straight there, bypassing
# multicast discovery, while still never touching the public relay. Failing
# hard on a missing IP beats falling back to discovery-only, which on this
# class of network finds zero peers and hangs until timeout.
C=$(code l1)
LOCAL_IP=$(local_ip)
[ -n "$LOCAL_IP" ] || fail "LAN only: no local IP, cannot bypass multicast discovery"
timeout 90 "$CT" send -code "$C" -only-local "$TMP/src/a.txt" > /dev/null 2>&1 &
sleep 3
mkdir -p "$TMP/dst9"
( cd "$TMP/dst9" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite --ip "$LOCAL_IP:9009" ) > /dev/null 2>&1
diff "$TMP/src/a.txt" "$TMP/dst9/a.txt" > /dev/null || fail "LAN only"
wait; pass "LAN only"

echo "ALL INTEROP CHECKS PASSED"
