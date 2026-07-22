#!/usr/bin/env bash
# Interop verification: crocmobile (via croctest) <-> croc CLI v10.5.0.
# Covers: file/folder/text both directions, decline, cancel both directions,
# forced relay (LAN disabled), LAN-only. Exits non-zero on first failure.
set -euo pipefail
cd "$(dirname "$0")/.."

CROC="${CROC:-$HOME/go/bin/croc}"
TMP="$(mktemp -d)"
CT="$TMP/croctest"
trap 'rm -rf "$TMP"; kill $(jobs -p) 2>/dev/null || true' EXIT

# macOS ships no timeout(1) (no GNU coreutils). Shim the `timeout SECONDS
# cmd...` form used throughout this script; real timeout is used where present
# (e.g. Linux CI).
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

( cd crocmobile && go build -o "$CT" ./cmd/croctest )

mkdir -p "$TMP/src/sub" "$TMP/dst"
echo "small file" > "$TMP/src/a.txt"
head -c 5242880 /dev/urandom > "$TMP/src/big.bin"
echo nested > "$TMP/src/sub/b.txt"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }
code() { echo "phase1-$1-$$"; }

# Best-effort local LAN IP, used by scenario 9 to route around broken/absent
# UDP multicast peer discovery (e.g. AP client isolation) -- see report.
local_ip() {
  if command -v ipconfig >/dev/null 2>&1; then
    for iface in en0 en1; do
      ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
      if [ -n "$ip" ]; then
        echo "$ip"
        return
      fi
    done
  fi
  if command -v hostname >/dev/null 2>&1; then
    hostname -I 2>/dev/null | awk '{print $1}' || true
  fi
  return 0
}

# 1. wrapper sends file -> CLI receives
C=$(code f1)
"$CT" send -code "$C" "$TMP/src/a.txt" > "$TMP/1.log" 2>&1 &
sleep 3
( cd "$TMP/dst" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite ) > /dev/null 2>&1
diff "$TMP/src/a.txt" "$TMP/dst/a.txt" > /dev/null || fail "send file"
wait; pass "send file"

# 2. CLI sends file -> wrapper receives (accept)
C=$(code f2)
# --ignore-stdin: the CLI probes stdin for piped content; without it, a
# backgrounded, non-tty send can misbehave (see task notes).
# CROC_SECRET (not --code): v10.5.0's non-classic send mode refuses a
# custom codephrase passed via --code and tells you to use CROC_SECRET instead.
( cd "$TMP/src" && CROC_SECRET="$C" timeout 60 "$CROC" --ignore-stdin send a.txt ) > /dev/null 2>&1 &
sleep 3
rm -rf "$TMP/dst2"; timeout 60 "$CT" receive -out "$TMP/dst2" -answer y "$C" > "$TMP/2.log" 2>&1
diff "$TMP/src/a.txt" "$TMP/dst2/a.txt" > /dev/null || fail "receive file"
grep -q "EVENT filelist" "$TMP/2.log" || fail "filelist event"
pass "receive file + filelist event"

# 3. folder both directions
C=$(code d1)
"$CT" send -code "$C" "$TMP/src" > /dev/null 2>&1 &
sleep 3
rm -rf "$TMP/dstdir" && mkdir -p "$TMP/dstdir"
( cd "$TMP/dstdir" && CROC_SECRET="$C" timeout 120 "$CROC" --yes --overwrite ) > /dev/null 2>&1
diff -r "$TMP/src" "$TMP/dstdir/src" > /dev/null || fail "send folder"
wait; pass "send folder"

C=$(code d2)
( cd "$TMP" && CROC_SECRET="$C" timeout 120 "$CROC" --ignore-stdin send src ) > /dev/null 2>&1 &
sleep 3
rm -rf "$TMP/dstdir2"; timeout 120 "$CT" receive -out "$TMP/dstdir2" -answer y "$C" > /dev/null 2>&1
diff -r "$TMP/src" "$TMP/dstdir2/src" > /dev/null || fail "receive folder"
pass "receive folder"

# 4. text both directions
C=$(code t1)
"$CT" send -code "$C" -text "wrapper text" > /dev/null 2>&1 &
sleep 3
OUT=$( cd "$TMP" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite --stdout 2>/dev/null )
[ "$OUT" = "wrapper text" ] || fail "send text (got: $OUT)"
wait; pass "send text"

C=$(code t2)
CROC_SECRET="$C" timeout 60 "$CROC" --ignore-stdin send --text "cli text" > /dev/null 2>&1 &
sleep 3
timeout 60 "$CT" receive -out "$TMP/dst" -answer y "$C" > "$TMP/4.log" 2>&1
grep -q "EVENT text cli text" "$TMP/4.log" || fail "receive text"
pass "receive text"

# 5. decline notifies sender
# croc v10.5.0 has a race on the sender side when a peer decline arrives:
# usually surfaced as "peer error: refusing files", occasionally as the
# generic "context canceled" (same event -- receipt of the receiver's
# TypeError message -- two different internal error-return paths). Accept
# either as evidence the sender was notified/interrupted by the decline.
C=$(code n1)
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC" --ignore-stdin send a.txt > "$TMP/5s.log" 2>&1; echo "rc=$?" >> "$TMP/5s.log" ) &
sleep 3
timeout 30 "$CT" receive -out "$TMP/dst" -answer n "$C" > "$TMP/5r.log" 2>&1 || true
wait
grep -q "refused files" "$TMP/5r.log" || fail "decline receiver side"
grep -Eqi "refus|context canceled" "$TMP/5s.log" || fail "decline sender not notified"
pass "decline notifies sender"

# 6. receiver cancels mid-transfer -> sender errors out
# Throttle the sender to 200 KB/s so the 5 MB file takes ~25s: at unthrottled
# loopback speed (~250 MB/s) the whole file sends before any cancel-after
# value fires, so "cancel" only ever interrupted the receiver's *post*-transfer
# hash-verification step, not the wire transfer itself, and a fully-received
# (if not-yet-hash-confirmed) file could satisfy a loose assertion. With the
# throttle, cancel-after 6000 lands at ~20% sent (confirmed repeatedly via
# sender-side progress) -- genuinely mid-wire. Dedicated dst dir: scenario 7
# reuses "big.bin" and must not see this scenario's (mismatched) leftover.
C=$(code c1)
rm -rf "$TMP/dst6"; mkdir -p "$TMP/dst6"
( cd "$TMP/src" && CROC_SECRET="$C" timeout 30 "$CROC" --ignore-stdin --throttleUpload 200k send big.bin > "$TMP/6s.log" 2>&1; echo "rc=$?" >> "$TMP/6s.log" ) &
sleep 3
timeout 30 "$CT" receive -out "$TMP/dst6" -answer y -cancel-after 6000 "$C" > "$TMP/6r.log" 2>&1 || true
wait
! diff -q "$TMP/src/big.bin" "$TMP/dst6/big.bin" > /dev/null 2>&1 || fail "receiver cancel: transfer completed anyway"
grep -q "cancelled\|error" "$TMP/6r.log" || fail "receiver cancel: receiver side"
grep -q "rc=0" "$TMP/6s.log" && fail "receiver cancel: sender exited 0 (transfer completed anyway)" || true
grep -Eqi "context canceled|peer error|refus" "$TMP/6s.log" || fail "receiver cancel: sender did not report a real error"
pass "receiver cancel"

# 7. sender cancels mid-transfer -> receiver errors out
# Same throttle reasoning as scenario 6, mirrored: cancel-after 6000 on the
# (throttled) sender lands at ~20% sent. Assert the destination file does NOT
# byte-match the source (or is absent) -- at full loopback speed the transfer
# completed before cancel fired, and a benign reconnect-warning log line
# ("error setting read deadline") could satisfy a bare err/refus grep even on
# a fully successful transfer; the file-content check can't be fooled that way.
C=$(code c2)
rm -rf "$TMP/dst7"; mkdir -p "$TMP/dst7"
"$CT" send -code "$C" -throttle 200k -cancel-after 6000 "$TMP/src/big.bin" > "$TMP/7s.log" 2>&1 &
sleep 3
rc=0; ( cd "$TMP/dst7" && CROC_SECRET="$C" timeout 30 "$CROC" --yes --overwrite ) > "$TMP/7r.log" 2>&1 || rc=$?
wait
! diff -q "$TMP/src/big.bin" "$TMP/dst7/big.bin" > /dev/null 2>&1 || fail "sender cancel: transfer completed anyway"
[ "$rc" -ne 0 ] || grep -Eqi "interruption|context canceled|refus" "$TMP/7r.log" || fail "sender cancel: receiver did not error"
pass "sender cancel"

# 8. forced relay (LAN disabled both sides)
C=$(code r1)
"$CT" send -code "$C" -no-local "$TMP/src/a.txt" > /dev/null 2>&1 &
sleep 3
rm -rf "$TMP/dst3"; mkdir -p "$TMP/dst3"
( cd "$TMP/dst3" && CROC_SECRET="$C" timeout 90 "$CROC" --yes --overwrite ) > /dev/null 2>&1
diff "$TMP/src/a.txt" "$TMP/dst3/a.txt" > /dev/null || fail "forced relay"
wait; pass "forced relay"

# 9. LAN only (no internet relay)
# croc's sender-side local relay control port is always the first configured
# relay port (9009 by default). --ip routes the receiver straight there,
# bypassing UDP multicast peer discovery -- which some networks (AP/client
# isolation) never deliver -- while still never touching the public relay.
C=$(code l1)
LOCAL_IP=$(local_ip)
# Don't silently fall back to discovery-only: on this class of network it
# reliably finds zero peers and the receiver would just hang until timeout,
# masking a real "no usable local IP" environment problem as a slow pass/fail.
[ -n "$LOCAL_IP" ] || fail "LAN only: could not determine local IP (no ipconfig/hostname -I) -- cannot use --ip fallback for broken multicast discovery"
ip_args=(--ip "$LOCAL_IP:9009")
"$CT" send -code "$C" -only-local "$TMP/src/a.txt" > /dev/null 2>&1 &
sleep 3
rm -rf "$TMP/dst4"; mkdir -p "$TMP/dst4"
( cd "$TMP/dst4" && CROC_SECRET="$C" timeout 60 "$CROC" --yes --overwrite "${ip_args[@]}" ) > /dev/null 2>&1
diff "$TMP/src/a.txt" "$TMP/dst4/a.txt" > /dev/null || fail "LAN only"
wait; pass "LAN only"

echo "ALL INTEROP CHECKS PASSED"
