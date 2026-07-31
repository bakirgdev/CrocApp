#!/usr/bin/env bash
# Writes every screenshot in assets/screenshots/ from real builds -- no mockups,
# no device frames, no real transfer codes. This file is the manifest: each
# `want <name>` block below is one shot, captured light and dark, at 2x.
#
#   macOS  home, send-files, send, receive, transferring, done, history,
#          howitworks, settings
#   iOS    home, onboarding, send, receive-code, receive, history, settings,
#          transferring, done
#
# Staging rides on the DEBUG-only harness flags in AutoVerify.swift: --screen
# navigates, --stage preloads the Send list, --seed-history fills the
# (in-memory) history store, --hold parks at the incoming prompt. The macOS
# shots are per-window captures (screencapture -l), so they keep the real
# window shape with no desktop behind them; the iOS shots are whole-device
# captures, which is what a phone screenshot is.
#
# Takes over the display for roughly fifteen minutes and flips the system
# appearance twice. The original appearance is restored on exit, including on
# failure. Pass a shot name (e.g. `capture-screenshots.sh mac-home`) to
# re-capture just that one in both appearances.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

CROC="${CROC:-$HOME/go/bin/croc}"
require_croc

SIM="${SIM:-iPhone 17 Pro}"
BUNDLE=com.bakirgdev.CrocApp
OUT=assets/screenshots
DOCS="$HOME/Library/Containers/$BUNDLE/Data/Documents"
ONLY="${1:-}"

TMP=$(mktemp -d)
APP_PID=""
JOB_PID=""
ORIG_DARK=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')

cleanup() {
  [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null || true
  [ -n "$JOB_PID" ] && kill "$JOB_PID" 2>/dev/null || true
  kill_jobs
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  xcrun simctl status_bar "$SIM" clear 2>/dev/null || true
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $ORIG_DARK" >/dev/null 2>&1 || true
  rm -rf "$DOCS/shots" "$TMP"
  return 0
}
trap cleanup EXIT

want() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

# The relay hashes a code's first 4 characters into a room name, so those four
# have to be unique -- not just within a run, but against any recent run still
# holding the room. Hardcoded prefixes made a re-capture of the same shot fail
# against its own leftovers. Random base, then one per code; each $(code ...)
# runs in a subshell, so an incrementing counter would not survive between
# calls and every code takes an explicit offset instead.
CODE_BASE=$((RANDOM % 8000 + 1000))
code() {                                            # code OFFSET WORDS
  printf '%d-%s' "$((CODE_BASE + $1))" "$2"
}

# screencapture wants a CGWindowID and nothing in the shell hands one out.
# AppleScript's window ids are AX ids, not CGWindowIDs, so System Events
# cannot supply this even though it sees the same windows.
cat > "$TMP/windowid.swift" <<'SWIFT'
import CoreGraphics
import Foundation

let owner = CommandLine.arguments[1]
guard
    let list = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
else { exit(1) }
for window in list where window[kCGWindowOwnerName as String] as? String == owner {
    let number = window[kCGWindowNumber as String] as? Int ?? 0
    let layer = window[kCGWindowLayer as String] as? Int ?? -1
    let name = window[kCGWindowName as String] as? String ?? ""
    print("\(number)\t\(layer)\t\(name)")
}
SWIFT

activate_croc() {
  # An unfocused window photographs with grey traffic lights and a dimmed
  # title, so every capture has to raise the app first.
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "CrocApp") to true' >/dev/null
  sleep 1
}

shoot_window() {                                    # shoot_window OUTFILE TITLE
  local wid
  wid=$(xcrun swift "$TMP/windowid.swift" CrocApp \
    | awk -F'\t' -v t="$2" '$2 == 0 && $3 == t { print $1; exit }')
  [ -n "$wid" ] || fail "no on-screen CrocApp window titled '$2'"
  screencapture -x -o -l "$wid" "$1"
  [ -s "$1" ] || fail "screencapture wrote nothing to $1"
  echo "  $1"
}

mac_launch() {                                      # mac_launch ARGS...
  # -AppleLocale/-AppleLanguages for the same reason as the iOS launch: byte
  # counts and relative dates otherwise follow the host locale.
  "$BIN" -ApplePersistenceIgnoreState YES \
    -AppleLocale en_US -AppleLanguages '(en)' "$@" > "$TMP/mac.log" 2>&1 &
  APP_PID=$!
  sleep 5
  activate_croc
}

mac_quit() {
  [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
  APP_PID=""
  sleep 1
}

ios_launch() {                                      # ios_launch ARGS...
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  # Byte sizes and dates are locale-formatted; pin en_US so the shots read
  # "8.8 MB" and not the host locale's decimal comma.
  xcrun simctl launch "$SIM" "$BUNDLE" -AppleLocale en_US -AppleLanguages '(en)' "$@" > /dev/null
}

ios_shoot() {                                       # ios_shoot OUTFILE
  xcrun simctl io "$SIM" screenshot --type=png "$1" 2>/dev/null
  [ -s "$1" ] || fail "simctl wrote nothing to $1"
  echo "  $1"
}

set_appearance() {                                  # set_appearance light|dark
  local dark=false
  [ "$1" = dark ] && dark=true
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" >/dev/null
  xcrun simctl ui "$SIM" appearance "$1" >/dev/null
  sleep 3
}

# --- macOS ------------------------------------------------------------------

capture_mac() {                                     # capture_mac MODE CODE_A CODE_B CODE_C
  local mode=$1 code_a=$2 code_b=$3 code_c=$4
  # Same reason as the iOS side: leftovers from an earlier run would show up
  # as a conflict warning on the next incoming preview.
  rm -f "$DOCS/Presentation.pdf" "$DOCS/Budget.numbers" "$DOCS/Cover-Art.png" \
    "$DOCS/Field-Recordings.zip" "$DOCS/verify-result.txt"

  if want mac-home || want mac-settings; then
    mac_launch --screen home
    want mac-home && shoot_window "$OUT/mac-home-$mode.png" CrocApp
    if want mac-settings; then
      osascript -e 'tell application "System Events" to keystroke "," using command down'
      sleep 3
      # A freshly opened Settings scene is scrolled to the top. It opens at
      # its .defaultSize (480x780) and is user-resizable, which is
      # why this catches the whole form rather than stopping mid-row.
      shoot_window "$OUT/mac-settings-$mode.png" "CrocApp Settings"
    fi
    mac_quit
  fi

  if want mac-send-files; then
    mac_launch --screen send \
      --stage "$DOCS/shots/Presentation.pdf" \
      --stage "$DOCS/shots/Budget.numbers" \
      --stage "$DOCS/shots/Cover-Art.png"
    shoot_window "$OUT/mac-send-files-$mode.png" Send
    mac_quit
  fi

  if want mac-receive; then
    mac_launch --screen receive
    shoot_window "$OUT/mac-receive-$mode.png" Receive
    mac_quit
  fi

  if want mac-history; then
    mac_launch --screen history --seed-history
    shoot_window "$OUT/mac-history-$mode.png" History
    mac_quit
  fi

  if want mac-howitworks; then
    mac_launch --screen howItWorks
    shoot_window "$OUT/mac-howitworks-$mode.png" "How it works"
    mac_quit
  fi

  if want mac-send; then
    # No receiver ever shows up, so this parks in "Ready to send" -- the only
    # state that displays the code phrase and the QR.
    mac_launch --auto-send "$DOCS/shots/Design-Assets.zip" --code "$code_a" --screen send
    # croc hashes the payload before the relay publishes the code.
    sleep 9
    activate_croc
    shoot_window "$OUT/mac-send-$mode.png" Send
    mac_quit
  fi

  if want mac-transferring; then
    # --relay pins the relay AND sets harnessDisableLocal, which is the whole
    # point: both ends of this transfer are this machine, so croc's local path
    # wins the race and moves 400 MB at ~390 MB/s -- there is no payload big
    # enough to photograph mid-flight. Forced through the relay it runs at
    # internet speed and the progress bar actually sits still long enough.
    # The app is the sender, so croc's --throttleUpload is not available here.
    mac_launch --auto-send "$DOCS/shots/Field-Recordings.zip" --code "$code_b" \
      --relay croc.schollz.com:9009 --screen send
    sleep 10
    # A fresh directory, not $TMP: croc resumes against a same-named file of
    # the same size, and $TMP holds the very file being sent.
    mkdir -p "$TMP/recv-b"
    ( cd "$TMP/recv-b" && CROC_SECRET="$code_b" "$CROC" --ignore-stdin --yes ) \
      > "$TMP/recv-b.log" 2>&1 &
    JOB_PID=$!
    sleep 14
    activate_croc
    shoot_window "$OUT/mac-transferring-$mode.png" Send
    kill "$JOB_PID" 2>/dev/null || true
    wait "$JOB_PID" 2>/dev/null || true
    JOB_PID=""
    mac_quit
  fi

  if want mac-done; then
    # Receiving, not sending: the finished-receive state is the richer one
    # (it offers "Show in Finder").
    rm -f "$DOCS/verify-result.txt"
    ( cd "$TMP/payload" && CROC_SECRET="$code_c" "$CROC" --ignore-stdin send \
        Presentation.pdf Budget.numbers Cover-Art.png ) > "$TMP/send-c.log" 2>&1 &
    JOB_PID=$!
    sleep 5
    mac_launch --auto-receive "$code_c" --screen receive
    for _ in $(seq 1 90); do
      [ -f "$DOCS/verify-result.txt" ] && break
      sleep 1
    done
    [ -f "$DOCS/verify-result.txt" ] || fail "mac-done: transfer never finished"
    sleep 2
    activate_croc
    shoot_window "$OUT/mac-done-$mode.png" Receive
    kill "$JOB_PID" 2>/dev/null || true
    wait "$JOB_PID" 2>/dev/null || true
    JOB_PID=""
    mac_quit
  fi
}

# --- iOS --------------------------------------------------------------------

capture_ios() {                                     # capture_ios MODE CODE_A CODE_B CODE_C
  local mode=$1 code_a=$2 code_b=$3 code_c=$4
  local simdocs
  simdocs=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)/Documents
  # Documents is the iOS receive folder, so files left by an earlier run make
  # the next incoming preview sprout an "already exist and will be replaced"
  # warning. True, but an artifact of re-running rather than anything a reader
  # should see. Named explicitly: shots/ next door holds the staged payloads.
  rm -f "$simdocs/Presentation.pdf" "$simdocs/Budget.numbers" "$simdocs/Cover-Art.png" \
    "$simdocs/Live-Set.wav" "$simdocs/verify-result.txt"

  if want ios-home; then
    ios_launch --screen home
    sleep 4
    ios_shoot "$OUT/ios-home-$mode.png"
  fi

  if want ios-onboarding; then
    ios_launch --screen onboarding
    sleep 5
    ios_shoot "$OUT/ios-onboarding-$mode.png"
  fi

  if want ios-send; then
    ios_launch --screen send \
      --stage "$simdocs/shots/Presentation.pdf" \
      --stage "$simdocs/shots/Budget.numbers" \
      --stage "$simdocs/shots/Cover-Art.png"
    sleep 4
    ios_shoot "$OUT/ios-send-$mode.png"
  fi

  if want ios-receive-code; then
    ios_launch --screen receive
    sleep 4
    ios_shoot "$OUT/ios-receive-code-$mode.png"
  fi

  if want ios-history; then
    ios_launch --screen history --seed-history
    sleep 4
    ios_shoot "$OUT/ios-history-$mode.png"
  fi

  if want ios-settings; then
    ios_launch --screen settings
    sleep 4
    ios_shoot "$OUT/ios-settings-$mode.png"
  fi

  if want ios-receive; then
    ( cd "$TMP/payload" && CROC_SECRET="$code_a" "$CROC" --ignore-stdin send \
        Presentation.pdf Budget.numbers Cover-Art.png ) > "$TMP/ios-a.log" 2>&1 &
    JOB_PID=$!
    # Sender first: starting the receiver into an unregistered code races the
    # PAKE handshake (same ordering constraint as verify-app-sim.sh).
    sleep 5
    ios_launch --auto-receive "$code_a" --screen receive --hold
    # Long enough to cover a slow relay handshake: at 18s this sometimes
    # photographed "Starting..." instead of the file list.
    sleep 30
    ios_shoot "$OUT/ios-receive-$mode.png"
    ios_stop_job
  fi

  if want ios-transferring; then
    # Here the CLI is the sender, so the rate can be pinned instead of guessed:
    # unthrottled, 150 MB finished before the shutter fell. 41 MB at 800k/s
    # cannot finish inside the wait below, and that wait is long enough that
    # the handshake -- which eats most of the first half minute -- is well
    # behind us by the time the progress bar is photographed.
    ( cd "$TMP/big" && CROC_SECRET="$code_b" "$CROC" --throttleUpload 800k \
        --ignore-stdin send Live-Set.wav ) > "$TMP/ios-b.log" 2>&1 &
    JOB_PID=$!
    sleep 5
    ios_launch --auto-receive "$code_b" --screen receive
    sleep 70
    ios_shoot "$OUT/ios-transferring-$mode.png"
    ios_stop_job
  fi

  if want ios-done; then
    # Its own small transfer rather than a tail on the big one, so this waits
    # seconds instead of minutes for a state that looks identical either way.
    rm -f "$simdocs/verify-result.txt"
    ( cd "$TMP/payload" && CROC_SECRET="$code_c" "$CROC" --ignore-stdin send \
        Presentation.pdf Budget.numbers Cover-Art.png ) > "$TMP/ios-c.log" 2>&1 &
    JOB_PID=$!
    sleep 5
    ios_launch --auto-receive "$code_c" --screen receive
    for _ in $(seq 1 120); do
      [ -f "$simdocs/verify-result.txt" ] && break
      sleep 1
    done
    if [ ! -f "$simdocs/verify-result.txt" ]; then
      echo "--- croc sender log ---" >&2
      tail -5 "$TMP/ios-c.log" >&2
      fail "ios-done: transfer never finished"
    fi
    sleep 2
    ios_shoot "$OUT/ios-done-$mode.png"
    rm -f "$simdocs/verify-result.txt"
    ios_stop_job
  fi

  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
}

ios_stop_job() {
  [ -n "$JOB_PID" ] && kill "$JOB_PID" 2>/dev/null || true
  wait "$JOB_PID" 2>/dev/null || true
  JOB_PID=""
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
}

# --- payloads ---------------------------------------------------------------

mkdir -p "$OUT" "$DOCS/shots" "$TMP/payload" "$TMP/big"
# Placeholder payloads. The names show up in the staged and incoming file
# lists, the byte counts show up as their sizes; nothing here is a real
# document. Design-Assets.zip is the send payload nobody ever receives;
# Field-Recordings.zip is large on purpose so a transfer stays photographable.
head -c 8800000 /dev/urandom > "$TMP/payload/Presentation.pdf"
head -c 627000 /dev/urandom > "$TMP/payload/Budget.numbers"
head -c 2200000 /dev/urandom > "$TMP/payload/Cover-Art.png"
head -c 41000000 /dev/urandom > "$TMP/big/Live-Set.wav"
head -c 4194304 /dev/urandom > "$DOCS/shots/Design-Assets.zip"
head -c 200000000 /dev/urandom > "$TMP/Field-Recordings.zip"
# The macOS app is sandboxed, so anything it sends has to live inside its
# container -- $TMP is not readable from in there.
cp "$TMP/payload"/* "$TMP/Field-Recordings.zip" "$DOCS/shots/"

echo "building macOS..."
( cd app && xcodebuild -scheme CrocApp -destination 'platform=macOS' \
    -derivedDataPath /tmp/dd-mac build ) > /tmp/shots-mac-build.log 2>&1
BIN=$(find /tmp/dd-mac/Build/Products -maxdepth 3 -name CrocApp.app | head -1)/Contents/MacOS/CrocApp
[ -x "$BIN" ] || fail "no CrocApp.app in /tmp/dd-mac (see /tmp/shots-mac-build.log)"

echo "building iOS..."
xcrun simctl boot "$SIM" 2>/dev/null || true
( cd app && xcodebuild -scheme CrocApp -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath /tmp/dd-sim build ) > /tmp/shots-sim-build.log 2>&1
SIM_APP=$(find /tmp/dd-sim/Build/Products -maxdepth 3 -name CrocApp.app | head -1)
[ -n "$SIM_APP" ] || fail "no CrocApp.app in /tmp/dd-sim (see /tmp/shots-sim-build.log)"
xcrun simctl install "$SIM" "$SIM_APP"
SIM_DOCS=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)/Documents
mkdir -p "$SIM_DOCS/shots"
cp "$TMP/payload"/* "$SIM_DOCS/shots/"
xcrun simctl status_bar "$SIM" override --time "9:41" \
  --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3

echo "light..."
set_appearance light
capture_mac light "$(code 1 amber-willow-signal)" "$(code 2 copper-lantern-summit)" \
  "$(code 3 quiet-meadow-anchor)"
capture_ios light "$(code 4 violet-harbor-drift)" "$(code 5 golden-cedar-morrow)" \
  "$(code 6 silver-thicket-bay)"

echo "dark..."
set_appearance dark
capture_mac dark "$(code 7 crimson-pillar-notch)" "$(code 8 indigo-marsh-relay)" \
  "$(code 9 russet-canyon-vale)"
capture_ios dark "$(code 10 slate-orchard-vista)" "$(code 11 teal-basin-crest)" \
  "$(code 12 olive-ridge-hollow)"

echo SHOTS-OK
