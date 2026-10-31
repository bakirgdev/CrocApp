#!/usr/bin/env bash
# Writes every screenshot in assets/screenshots/ from real Debug builds: no
# mockups, no device frames, no real transfer codes, nothing sent over the
# internet. SCREENS below is the manifest; `--list` prints it with every output
# file and its expected size.
#
#   assets/screenshots/mac/SCREEN-{light,dark}.png      per-window capture, 2x, real window shape
#   assets/screenshots/iphone/SCREEN-{light,dark}.png   iPhone 17 Pro Max, 1320x2868, 9:41 status bar
#   assets/screenshots/ipad/SCREEN-{light,dark}.png     iPad Pro 13-inch (M5), 2064x2752, 9:41 status bar
#   assets/screenshots/app-store/CLASS/NN-SCREEN-{light,dark}.png
#       Apple's exact sizes, no alpha, numbered in upload order (STORE_SCREENS),
#       odd numbers light and even numbers dark. iphone-6.9, ipad-13 and mac
#       come from the main captures; iphone-6.3 (iPhone 17 Pro) and
#       iphone-duo-outer (iPhone Duo outer display) get their own simulator.
#
# Staging rides on the DEBUG-only harness in app/CrocApp/Support/AutoVerify.swift.
# Launch flags navigate (--screen), preload (--stage), seed history, hold at
# the incoming prompt, throttle a send and point the app at a relay; the
# harness answers with files in the app's Documents folder (verify-ready.txt,
# verify-phase.txt, verify-code-ready.txt, verify-result.txt), which this script
# polls instead of sleeping. Every transfer goes through a croc relay started
# here on 127.0.0.1 with a random port block and password, so the run is
# repeatable and nothing leaves the machine (the croc CLI peers still make
# their own update check). Codes are random per run.
#
# Takes over the display for a while and flips the system appearance twice; the
# original appearance is restored on exit, also on failure. Needs, for the
# terminal that runs it: Screen Recording, Accessibility, and Automation of
# System Events (the preflight names what is missing).
#
# Usage: capture-screenshots.sh [DEVICE...] [SCREEN...]
#   no arguments    everything, after emptying assets/screenshots/
#   DEVICE          mac, iphone, ipad, iphone63 or duo: only those devices
#   SCREEN          only those screens, both appearances, plus the store file
#   --list          print the manifest and exit
#   --copy-web      rebuild the web WebP copies from assets/screenshots/ and exit (needs cwebp)
# Environment: CROC (default: the Homebrew croc, v11 like crocmobile),
# PHONE_TYPE, PHONE63_TYPE, PAD_TYPE and DUO_TYPE (simulator device type ids),
# DUO_OUTER_DISPLAY (simctl display id of the Duo's outer screen), RUNTIME (simulator
# runtime id, default the newest installed one that supports the device type).
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"
DD_MAC=$(derived_data mac)
DD_SIM=$(derived_data sim)

BUNDLE=com.bakirgdev.CrocApp
OUT=assets/screenshots
TOOLS=scripts/screenshots
PHONE_TYPE="${PHONE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max}"
PHONE63_TYPE="${PHONE63_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
PAD_TYPE="${PAD_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-16GB}"
DUO_TYPE="${DUO_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-Duo}"
# `simctl io DEVICE enumerate` lists the Duo's two panels as screens 1 (outer,
# 1398x2034) and 3 (inner, 2007x2853).
DUO_OUTER_DISPLAY="${DUO_OUTER_DISPLAY:-1}"
SIM_NAME="CrocApp Shots"
MAC_DOCS="$HOME/Library/Containers/$BUNDLE/Data/Documents"

# The first three get the main set; the last two exist for the store set only.
DEVICES="mac iphone ipad iphone63 duo"
MAIN_DEVICES="mac iphone ipad"
SCREENS="onboarding home send-files send-code sending receive-code receive-incoming \
receive-conflict receiving receive-done stored-link history how-it-works settings \
settings-advanced receive-saved-codes settings-relay relay-health"
# Screens a phone or an iPad has no counterpart of: the relay this Mac runs and its
# health check live in the Mac's Relay tab only.
MAC_ONLY_SCREENS="settings-relay relay-health"
# The App Store subset, in upload order. The number in a file name is the position.
STORE_SCREENS="send-files send-code sending receive-incoming receiving receive-done \
stored-link history settings how-it-works"
# Everything a run puts into the app's Documents folder, which is the receive
# folder too: removed before each shot, or leftovers would turn up as
# "already exists" warnings in the incoming preview.
PAYLOAD_NAMES="Quarterly-Report.pdf Ridge-Sunrise.jpg Meeting-Notes.md Design-Assets.zip \
Project-Archive.zip Field-Recordings.zip"

in_list() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac }

# has_screen DEVICE SCREEN: whether the device takes the screen.
has_screen() { [ "$1" = mac ] || ! in_list "$MAC_ONLY_SCREENS" "$2"; }

store_index() { # store_index SCREEN -> its position, from 1
  local i=1 n
  for n in $STORE_SCREENS; do
    [ "$n" = "$1" ] && {
      echo "$i"
      return 0
    }
    i=$((i + 1))
  done
  return 1
}

# Light and dark alternate through the upload order, so each class is half of each.
store_mode() { [ $(($(store_index "$1") % 2)) = 1 ] && echo light || echo dark; }
store_name() { printf '%02d-%s-%s' "$(store_index "$1")" "$1" "$(store_mode "$1")"; }

store_class() { # store_class DEVICE -> App Store class dir
  case "$1" in
    mac) echo mac ;;
    iphone) echo iphone-6.9 ;;
    ipad) echo ipad-13 ;;
    iphone63) echo iphone-6.3 ;;
    duo) echo iphone-duo-outer ;;
  esac
}

store_dims() { # store_dims DEVICE -> "WIDTH HEIGHT"
  case "$1" in
    iphone) echo "1320 2868" ;;
    iphone63) echo "1206 2622" ;;
    duo) echo "1398 2034" ;;
    ipad) echo "2064 2752" ;;
    mac) echo "2880 1800" ;;
  esac
}

is_main() { in_list "$MAIN_DEVICES" "$1"; }

# --- arguments --------------------------------------------------------------

PICK_DEVICES=""
PICK_SCREENS=""
case "${1:-}" in
  --list)
    for d in $DEVICES; do
      echo "$d ($(store_dims "$d" | tr ' ' x) in the store set):"
      if is_main "$d"; then
        for s in $SCREENS; do
          [ "$d $s" = "mac onboarding" ] && continue
          has_screen "$d" "$s" || continue
          echo "  $OUT/$d/$s-{light,dark}.png"
        done
      fi
      for s in $STORE_SCREENS; do echo "  $OUT/app-store/$(store_class "$d")/$(store_name "$s").png"; done
    done
    exit 0
    ;;
  --copy-web)
    # Rebuilds the WebP files a web surface already uses from their PNG sources
    # (same relative path under assets/screenshots/), at each file's current
    # pixel size. A new shot goes in by running cwebp on it once, into the web
    # folder, at the size its page needs.
    command -v cwebp > /dev/null || fail "cwebp is missing (brew install webp)"
    for dir in web/docs/screenshots web/landing/assets/img/screenshots; do
      n=0
      while IFS= read -r f; do
        rel=${f#"$dir"/}
        src="$OUT/${rel%.webp}.png"
        [ -f "$src" ] || fail "$f has no source $src"
        w=$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')
        h=$(sips -g pixelHeight "$f" | awk '/pixelHeight/ {print $2}')
        sw=$(sips -g pixelWidth "$src" | awk '/pixelWidth/ {print $2}')
        sh=$(sips -g pixelHeight "$src" | awk '/pixelHeight/ {print $2}')
        # Cross-multiplied, so a one-pixel rounding difference still passes.
        d=$((w * sh - h * sw))
        [ "${d#-}" -le $((sw + sh)) ] \
          || fail "$f is ${w}x${h} but $src is ${sw}x${sh}: the aspect ratio changed, resize the page's image by hand (see docs/knowledge/screenshots.md)"
        if [ "$w" = "$sw" ] && [ "$h" = "$sh" ]; then
          cwebp -quiet -q 85 -m 6 "$src" -o "$f" 2> /dev/null || fail "cwebp failed on $src"
        else
          cwebp -quiet -q 85 -m 6 -resize "$w" "$h" "$src" -o "$f" 2> /dev/null || fail "cwebp failed on $src"
        fi
        n=$((n + 1))
      done < <(find "$dir" -name '*.webp' | sort)
      echo "rebuilt $n files in $dir"
    done
    exit 0
    ;;
esac
for arg in "$@"; do
  if in_list "$DEVICES" "$arg"; then
    PICK_DEVICES="$PICK_DEVICES $arg"
  elif in_list "$SCREENS" "$arg"; then
    PICK_SCREENS="$PICK_SCREENS $arg"
  else
    fail "unknown argument '$arg'. Devices: $DEVICES. Screens: $SCREENS"
  fi
done
RUN_DEVICES="${PICK_DEVICES:-$DEVICES}"
RUN_SCREENS="${PICK_SCREENS:-$SCREENS}"
uses_mac=0
uses_sim=0
if in_list "$RUN_DEVICES" mac; then uses_mac=1; fi
for d in $RUN_DEVICES; do
  if [ "$d" != mac ]; then uses_sim=1; fi
done

# --- state and cleanup ------------------------------------------------------

TMP=$(mktemp -d)
APP_PID=""
PEER_PID=""
RELAY_PID=""
STORE_PID=""
STORE_URL=""
SIM_IDS="" # UDIDs of the simulators this run created
SIM_APP=""
ORIG_DARK=""
DEV=""
DOCS=""
SIM=""
SCREEN=""
MODE=""
CODE_PREFIXES=" "

stop_peer() {
  [ -n "$PEER_PID" ] || return 0
  # A stopped process holds a pending TERM until it is continued.
  kill -CONT "$PEER_PID" 2> /dev/null || true
  kill "$PEER_PID" 2> /dev/null || true
  wait "$PEER_PID" 2> /dev/null || true
  PEER_PID=""
}

cleanup() {
  local udid name
  stop_peer
  [ -n "$APP_PID" ] && kill "$APP_PID" 2> /dev/null || true
  [ -n "$RELAY_PID" ] && kill "$RELAY_PID" 2> /dev/null && wait "$RELAY_PID" 2> /dev/null || true
  [ -n "$STORE_PID" ] && kill "$STORE_PID" 2> /dev/null && wait "$STORE_PID" 2> /dev/null || true
  kill_jobs
  for udid in $SIM_IDS; do
    xcrun simctl shutdown "$udid" 2> /dev/null || true
    xcrun simctl delete "$udid" 2> /dev/null || true
  done
  if [ -n "$ORIG_DARK" ]; then
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $ORIG_DARK" > /dev/null 2>&1 || true
  fi
  if [ "$uses_mac" = 1 ]; then
    rm -rf "$MAC_DOCS/shots"
    rm -f "$MAC_DOCS"/verify-*.txt
    for name in $PAYLOAD_NAMES; do rm -f "$MAC_DOCS/$name"; done
  fi
  rm -rf "$TMP"
  return 0
}
trap cleanup EXIT

# --- preflight --------------------------------------------------------------

for tool in xcodebuild xcrun swiftc sips; do
  command -v "$tool" > /dev/null || fail "$tool not found (needs Xcode and its command line tools)"
done
CROC="${CROC:-${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc}"
require_croc
"$CROC" --version | grep -q 'version v\?11\.' \
  || fail "croc 11 expected (crocmobile pins v11.5.5), '$CROC' says: $("$CROC" --version)"
if in_list "$RUN_SCREENS" stored-link; then
  command -v go > /dev/null || fail "go is needed to build the local store server for stored-link"
fi
for type in "$PHONE_TYPE" "$PHONE63_TYPE" "$PAD_TYPE" "$DUO_TYPE"; do
  xcrun simctl list -j devicetypes | grep -q "\"$type\"" \
    || fail "simulator device type $type is not installed (set PHONE_TYPE, PHONE63_TYPE, PAD_TYPE, DUO_TYPE)"
done

mkdir -p "$TMP/bin"
for tool in window imgtool payload; do
  xcrun swiftc -O "$TOOLS/$tool.swift" -o "$TMP/bin/$tool"
done

if [ "$uses_mac" = 1 ]; then
  missing=$("$TMP/bin/window" preflight 2>&1) || fail "$missing. Grant it to the terminal running this script in System Settings > Privacy & Security, then restart the terminal."
  ORIG_DARK=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>&1) \
    || fail "Automation: allow the terminal running this script to control System Events (System Settings > Privacy & Security > Automation). osascript said: $ORIG_DARK"
fi

# --- helpers ----------------------------------------------------------------

# Polls CMD... every 0.2 s for up to SECONDS seconds.
poll() { # poll SECONDS CMD...
  local deadline=$((SECONDS + $1))
  shift
  until "$@"; do
    [ "$SECONDS" -lt "$deadline" ] || return 1
    sleep 0.2
  done
}

# What a failed wait leaves behind is the only clue, so show it.
die() {
  echo "--- peer log ---" >&2
  tail -n 8 "$TMP/peer.log" 2> /dev/null >&2 || true
  echo "--- app log ---" >&2
  tail -n 8 "$TMP/app.log" 2> /dev/null >&2 || true
  echo "--- relay log ---" >&2
  tail -n 8 "$TMP/relay.log" 2> /dev/null >&2 || true
  fail "$DEV $SCREEN $MODE: $*"
}

rand_int() { od -An -N4 -tu4 /dev/urandom | tr -d ' '; }
rand_hex() { od -An -N12 -tx1 /dev/urandom | tr -d ' \n'; }

WORDS=(amber willow signal copper lantern summit quiet meadow anchor violet harbor drift
  golden cedar morrow silver thicket crimson pillar indigo marsh russet canyon bridge falcon
  garden hollow island jasper kernel lagoon mosaic nectar orchard pebble quartz ribbon sparrow
  timber umber velvet walnut yonder zephyr acorn basil clover dune ember fjord glacier heron
  ivory juniper kettle lilac maple nutmeg olive prairie quill river saffron tundra uplands
  vista wren xenon yarrow zenith)

# Sets the variable named by $1 to a fresh code, word-word-word, the shape the
# app generates. The relay hashes a three-word code's first word into a room
# name, so that word must not repeat among recent codes (CODE_PREFIXES, cleared
# once most of WORDS is used); a fresh relay per run covers the runs before this one.
new_code() { # new_code VAR
  local first words="" i w
  [ "$(wc -w <<< "$CODE_PREFIXES")" -lt $((${#WORDS[@]} - 8)) ] || CODE_PREFIXES=""
  while :; do
    first=${WORDS[$(($(rand_int) % ${#WORDS[@]}))]}
    in_list "$CODE_PREFIXES" "$first" || break
  done
  CODE_PREFIXES="$CODE_PREFIXES$first "
  words=$first
  for i in 1 2; do
    while :; do
      w=${WORDS[$(($(rand_int) % ${#WORDS[@]}))]}
      case "-$words-" in *"-$w-"*) ;; *) break ;; esac
    done
    words="$words-$w"
  done
  printf -v "$1" '%s' "$words"
}

port_up() { nc -z 127.0.0.1 "$1" > /dev/null 2>&1; }
port_free() { ! port_up "$1"; }

# croc takes a base port plus transfer ports, five in all.
start_relay() {
  local base i p ok
  for _ in $(seq 1 20); do
    base=$((20000 + $(rand_int) % 20000))
    ok=1
    for i in 0 1 2 3 4; do port_free $((base + i)) || ok=0; done
    [ "$ok" = 1 ] && break
  done
  [ "$ok" = 1 ] || fail "no free block of five ports found"
  RELAY_ADDR="127.0.0.1:$base"
  RELAY_PASS=$(rand_hex)
  p="$base,$((base + 1)),$((base + 2)),$((base + 3)),$((base + 4))"
  # --debug is what makes the relay log "room has first peer", the signal that
  # a sender is registered and a receiver may join. The join limits default to
  # 30 a minute per address, and every peer here is 127.0.0.1.
  CROC_PASS="$RELAY_PASS" "$CROC" --debug relay --host 127.0.0.1 --ports "$p" \
    --source-join-limit 1000 --room-join-limit 1000 > "$TMP/relay.log" 2>&1 &
  RELAY_PID=$!
  poll 10 port_up "$base" || die "the relay did not start"
  kill -0 "$RELAY_PID" 2> /dev/null || die "the relay exited at startup"
}

# A croc CLI peer against the local relay. exec, so $! is croc itself and a
# signal reaches it.
croc_peer() { # croc_peer DIR CODE CROC_ARGS...
  local dir=$1 code=$2
  shift 2
  (cd "$dir" && CROC_SECRET="$code" CROC_PASS="$RELAY_PASS" exec "$CROC" --disable-clipboard \
    --relay "$RELAY_ADDR" --ignore-stdin "$@") > "$TMP/peer.log" 2>&1 &
  PEER_PID=$!
}

# The app's receive must start after the sender is in the relay's room: a
# receiver that arrives first corrupts the PAKE handshake.
start_sender() { # start_sender CODE DIR THROTTLE FILE...
  local code=$1 dir=$2 throttle=$3 before
  shift 3
  before=$(grep -c 'room has first peer' "$TMP/relay.log" || true)
  if [ -n "$throttle" ]; then
    croc_peer "$dir" "$code" --throttleUpload "$throttle" send --no-local "$@"
  else
    croc_peer "$dir" "$code" send --no-local "$@"
  fi
  sender_registered() { [ "$(grep -c 'room has first peer' "$TMP/relay.log" || true)" -gt "$before" ]; }
  poll 30 sender_registered || die "the croc sender never reached the relay"
}

# A fresh directory every time: croc skips a file the receiver already holds in
# full, and the transfer would end before it could be photographed.
start_receiver() { # start_receiver CODE
  rm -rf "$TMP/recv"
  mkdir -p "$TMP/recv"
  croc_peer "$TMP/recv" "$1" --yes --overwrite
}

RELAY_ARGS=()    # set once the relay runs
DISABLE_LOCAL="" # 1 once RELAY_ARGS is set: --relay alone leaves the LAN route on, so launch() ends with --disable-local

phase_is() { grep -Eq "$1" "$DOCS/verify-phase.txt" 2> /dev/null; }
await_phase() { # await_phase REGEX SECONDS
  poll "$2" phase_is "$1" || die "the app never reported a phase matching '$1' (last: $(cat "$DOCS/verify-phase.txt" 2> /dev/null || echo none))"
}

percent_reached() {
  local p
  p=$(sed -n 's/^transferring percent=//p' "$DOCS/verify-phase.txt" 2> /dev/null || true)
  [ -n "$p" ] && [ "$p" -ge "$1" ]
}

file_exists() { [ -e "$DOCS/$1" ]; }
await_docs_file() { # await_docs_file NAME SECONDS
  poll "$2" file_exists "$1" || die "the app never wrote $1"
}

# Freezes a transfer part-way. Both ends stand still, so the progress bar and
# the rate stay exactly as they are for as long as the shot takes. The throttle
# makes the climb slow enough to catch: unthrottled, localhost moves 150 MB in
# under a second.
freeze_transfer() {
  poll 90 percent_reached 40 || die "the transfer never reached 40% (phase: $(cat "$DOCS/verify-phase.txt" 2> /dev/null || echo none))"
  kill -STOP "$PEER_PID"
  # The progress callback may still be in flight; one render pass.
  settle
}

# No signal exists for "the last frame has been drawn", so this is the one
# fixed wait: a view takes a frame or two to show a state it was just given.
settle() { sleep 1; }

# --- devices ----------------------------------------------------------------

set_system_appearance() { # set_system_appearance light|dark
  local dark=false
  [ "$1" = dark ] && dark=true
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" > /dev/null
  dark_is() { [ "$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')" = "$dark" ]; }
  poll 10 dark_is || fail "the system appearance did not switch to $1"
}

# simctl takes the time as an ISO instant in UTC with fractional seconds (the
# plain "9:41" form is not accepted by every runtime), shown in the host's zone.
clock_941() {
  date -u -j -f '%Y-%m-%dT%H:%M:%S%z' "$(date +%Y-%m-%d)T09:41:00$(date +%z)" +%Y-%m-%dT%H:%M:%S.000Z
}

# Sets the variable named by $1 to the new simulator's UDID. A name left over
# from an aborted run is deleted first. No $(...) around the call: SIM_IDS has
# to reach the shell that runs cleanup. The newest runtime that supports the
# device type wins: a newer runtime can lack older device types, and without a
# runtime argument simctl picks the oldest.
#
# Prepared so the shots do not depend on the host: a simulator inherits the
# host's global preferences, and a host with a 24-hour time format
# (AppleICUTimeFormatStrings "HH:mm:ss") shows the status bar clock as
# "09:41:00" whatever --time says. The preferences are written to a booted
# device and only take effect after a reboot. An iPad also opens in
# windowed multitasking, which adds an app-name label to the status bar and a
# resize glyph in the corner; the two SpringBoard keys switch that off.
# Restarting SpringBoard with launchctl instead of rebooting leaves the status
# bar blank.
create_sim() { # create_sim VAR NAME TYPE
  local udid="" runtime
  xcrun simctl delete "$2" 2> /dev/null || true
  for runtime in ${RUNTIME:-$(xcrun simctl list runtimes available | awk '/^iOS / { print $NF }' | sort -r)}; do
    udid=$(xcrun simctl create "$2" "$3" "$runtime" 2> /dev/null) && break
    udid=""
  done
  [ -n "$udid" ] || fail "no installed iOS runtime supports $3"
  SIM_IDS="$SIM_IDS $udid"
  xcrun simctl bootstatus "$udid" -b > /dev/null
  xcrun simctl spawn "$udid" defaults write -g AppleICUTimeFormatStrings -dict 1 "h:mm"
  xcrun simctl spawn "$udid" defaults write -g AppleLocale en_US
  xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array en
  case "$3" in
    *iPad*)
      xcrun simctl spawn "$udid" defaults write com.apple.springboard SBMedusaMultitaskingEnabled -bool NO
      xcrun simctl spawn "$udid" defaults write com.apple.springboard SBChamoisWindowingEnabled -bool NO
      ;;
  esac
  xcrun simctl shutdown "$udid"
  xcrun simctl bootstatus "$udid" -b > /dev/null
  xcrun simctl status_bar "$udid" override --time "$(clock_941)" --dataNetwork wifi \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100
  printf -v "$1" '%s' "$udid"
}

# Puts the payloads where the device's app can read them: both macOS and the
# simulator sandbox the app, so $TMP is out of reach from inside.
stage_payloads() { # stage_payloads DOCS
  mkdir -p "$1/shots"
  cp "$TMP/payload"/* "$TMP/big/Project-Archive.zip" "$1/shots/"
}

sim_type() { # sim_type DEVICE
  case "$1" in
    iphone) echo "$PHONE_TYPE" ;;
    iphone63) echo "$PHONE63_TYPE" ;;
    ipad) echo "$PAD_TYPE" ;;
    duo) echo "$DUO_TYPE" ;;
  esac
}

# A prepared simulator with the app and the payloads on it. Its UDID and
# Documents folder go to ID_DEVICE and DOCS_DEVICE.
bring_up() { # bring_up DEVICE
  local id
  create_sim id "$SIM_NAME $1" "$(sim_type "$1")"
  xcrun simctl install "$id" "$SIM_APP"
  printf -v "ID_$1" '%s' "$id"
  printf -v "DOCS_$1" '%s' "$(xcrun simctl get_app_container "$id" "$BUNDLE" data)/Documents"
  stage_payloads "$(xcrun simctl get_app_container "$id" "$BUNDLE" data)/Documents"
}

# Not just shutdown: a deleted simulator frees its disk right away.
drop_sim() { # drop_sim DEVICE
  local var="ID_$1"
  xcrun simctl shutdown "${!var}" 2> /dev/null || true
  xcrun simctl delete "${!var}"
}

use_device() { # use_device DEVICE
  local id="ID_$1" docs="DOCS_$1"
  DEV=$1
  if [ "$1" = mac ]; then DOCS=$MAC_DOCS; else
    SIM=${!id}
    DOCS=${!docs}
  fi
}

clean_docs() {
  local name
  for name in $PAYLOAD_NAMES; do rm -f "$DOCS/$name"; done
  rm -f "$DOCS"/verify-*.txt
}

# --- launching and photographing --------------------------------------------

# -AppleLocale and -AppleLanguages because byte counts and relative dates
# otherwise follow the host locale ("8,8 MB").
# On macOS every launch argument has to come in pairs: AppKit reads "--flag
# value" as a defaults pair and any bare token left over as a file to open,
# which suppresses the window. A flag with no value (--hold, --seed-history)
# therefore goes last.
LOCALE_ARGS=(-AppleLocale en_US -AppleLanguages '(en)')

mac_windows() { "$TMP/bin/window" list CrocApp; }

# The first on-screen window (layer 0) whose title is one of TITLES, a
# |-separated list (titles contain spaces).
mac_window_id() { # mac_window_id TITLES
  mac_windows | awk -F'\t' -v t="$1" '
    BEGIN { n = split(t, want, "|") }
    $2 == 0 { for (i = 1; i <= n; i++) if ($3 == want[i]) { print $1; exit } }'
}

mac_window_shown() { [ -n "$(mac_window_id "$1")" ]; }
mac_has_window() { mac_windows | awk -F'\t' '$2 == 0 { found = 1 } END { exit !found }'; }

# An unfocused window photographs with grey traffic lights and a dimmed title.
# By pid, because the process name races the launch. The pause is a title bar
# repaint, which has no signal.
activate_app() {
  activated() {
    osascript -e "tell application \"System Events\" to set frontmost of (first process whose unix id is $APP_PID) to true" > /dev/null 2>&1
  }
  poll 15 activated || die "System Events never found the app (pid $APP_PID)"
  sleep 1
}

mac_titles() { # the window title(s) a screen shows
  case "$SCREEN" in
    home | onboarding) echo "CrocApp" ;;
    send-files | send-code | sending | stored-link) echo "Send" ;;
    receive-code | receive-incoming | receive-conflict | receiving | receive-done) echo "Receive" ;;
    history) echo "History" ;;
    how-it-works) echo "How It Works" ;;
    settings) echo "CrocApp Settings|General|Settings" ;;
    settings-advanced) echo "Advanced" ;;
    settings-relay | relay-health) echo "Relay" ;;
    receive-saved-codes) echo "Receive" ;;
  esac
}

launch() { # launch ARGS...
  rm -f "$DOCS"/verify-*.txt
  if [ "$DEV" = mac ]; then
    "$BIN" -ApplePersistenceIgnoreState YES "${LOCALE_ARGS[@]}" "$@" ${DISABLE_LOCAL:+--disable-local} > "$TMP/app.log" 2>&1 &
    APP_PID=$!
    poll 30 mac_has_window || die "the app opened no window"
    activate_app
  else
    xcrun simctl terminate "$SIM" "$BUNDLE" 2> /dev/null || true
    xcrun simctl launch "$SIM" "$BUNDLE" "${LOCALE_ARGS[@]}" "$@" ${DISABLE_LOCAL:+--disable-local} > /dev/null
  fi
}

quit_app() {
  if [ "$DEV" = mac ]; then
    [ -n "$APP_PID" ] && kill "$APP_PID" 2> /dev/null || true
    wait "$APP_PID" 2> /dev/null || true
    APP_PID=""
  else
    xcrun simctl terminate "$SIM" "$BUNDLE" 2> /dev/null || true
  fi
  stop_peer
}

await_ready() { await_docs_file verify-ready.txt 30; }

store_file() { # store_file RAW
  local out dir
  dir="$OUT/app-store/$(store_class "$DEV")"
  out="$dir/$(store_name "$SCREEN").png"
  mkdir -p "$dir"
  if [ "$DEV" = mac ]; then
    "$TMP/bin/imgtool" compose "$out" 2880 1800 "$MODE" "$1"
  else
    "$TMP/bin/imgtool" flatten "$1" "$out"
  fi
  echo "  $out"
}

# Photographs the current state. A main device keeps it as SCREEN-MODE; the
# store file is written when the screen's slot in the upload order has this
# appearance. A store-only device keeps nothing else.
snap() {
  local out wid
  if is_main "$DEV"; then
    mkdir -p "$OUT/$DEV"
    out="$OUT/$DEV/$SCREEN-$MODE.png"
  else
    out="$TMP/raw.png"
  fi
  if [ "$DEV" = mac ]; then
    wid=$(mac_window_id "$(mac_titles)")
    [ -n "$wid" ] || die "no on-screen CrocApp window titled '$(mac_titles)'"
    screencapture -x -o -l "$wid" "$out"
  elif [ "$DEV" = duo ]; then
    xcrun simctl io "$SIM" screenshot --type=png --display="$DUO_OUTER_DISPLAY" "$out" 2> /dev/null
  else
    xcrun simctl io "$SIM" screenshot --type=png "$out" 2> /dev/null
  fi
  [ -s "$out" ] || die "nothing was captured to $out"
  is_main "$DEV" && echo "  $out"
  if in_list "$STORE_SCREENS" "$SCREEN" && [ "$(store_mode "$SCREEN")" = "$MODE" ]; then store_file "$out"; fi
}

# A screen that needs no transfer: park on it, wait for the harness, photograph.
still() { # still ARGS...
  launch "$@"
  await_ready
  snap
  quit_app
}

# macOS Settings is a separate window opened with Cmd-comma; the keystroke goes
# to whatever is frontmost, so the app is raised first. TAB is General or Advanced.
mac_settings() { # mac_settings TAB [LAUNCH_ARG...]
  local i tab=$1
  shift
  launch --screen home "$@"
  for i in 1 2 3; do
    activate_app
    osascript -e 'tell application "System Events" to keystroke "," using command down'
    poll 5 mac_window_shown "General|Advanced|Settings|CrocApp Settings" && break
    [ "$i" -lt 3 ] || die "the Settings window did not open"
  done
  osascript -e "tell application \"System Events\" to tell (first process whose unix id is $APP_PID) to click button \"$tab\" of toolbar 1 of window 1" > /dev/null
  poll 5 mac_window_shown "$(mac_titles)" || die "the Settings window never showed the $tab tab"
  # The General form is taller than the window and cannot be stretched, so
  # scroll it to its end: the bottom then closes on a whole caption, and the
  # top slides under the toolbar like any scrolled form.
  [ "$tab" != General ] || "$TMP/bin/window" scroll CrocApp
  if [ "$SCREEN" = relay-health ]; then
    # The sheet runs its check on open; the relay is the local one, so it answers at once.
    osascript -e "tell application \"System Events\" to tell (first process whose unix id is $APP_PID) to click (first button of (entire contents of window 1) whose name is \"Check Relay…\")" > /dev/null
    sleep 3
  fi
  settle
  snap
  quit_app
}

capture_screen() {
  local code
  clean_docs
  case "$SCREEN" in
    onboarding) still --screen onboarding ;;
    home) still --screen home ;;
    send-files)
      still --screen send --stage "$DOCS/shots/Quarterly-Report.pdf" \
        --stage "$DOCS/shots/Ridge-Sunrise.jpg" --stage "$DOCS/shots/Meeting-Notes.md"
      ;;
    receive-code) still --screen receive ;;
    receive-saved-codes) still --screen receive --seed-saved-codes ;;
    history) still --screen history --seed-history ;;
    how-it-works) still --screen howItWorks ;;
    settings)
      if [ "$DEV" = mac ]; then mac_settings General; else still --screen settings; fi
      ;;
    settings-advanced)
      if [ "$DEV" = mac ]; then mac_settings Advanced; else still --screen advanced; fi
      ;;
    settings-relay) mac_settings Relay ;;
    relay-health) mac_settings Relay "${RELAY_ARGS[@]}" ;;
    send-code)
      # Parks on "Ready to send", the one state that shows the code and the QR.
      new_code code
      launch --auto-send "$DOCS/shots/Design-Assets.zip" --code "$code" "${RELAY_ARGS[@]}" --screen send
      await_docs_file verify-code-ready.txt 60
      settle
      snap
      quit_app
      ;;
    sending)
      new_code code
      launch --auto-send "$DOCS/shots/Project-Archive.zip" --code "$code" "${RELAY_ARGS[@]}" \
        --throttle 6m --screen send
      await_docs_file verify-code-ready.txt 60
      start_receiver "$code"
      freeze_transfer
      snap
      quit_app
      rm -rf "$TMP/recv"
      ;;
    receive-incoming | receive-conflict)
      new_code code
      local conflicts=0
      if [ "$SCREEN" = receive-conflict ]; then
        # Files already in the receive folder are what make the preview offer
        # Keep Both / Replace.
        cp "$TMP/payload/Quarterly-Report.pdf" "$TMP/payload/Ridge-Sunrise.jpg" "$DOCS/"
        conflicts=2
      fi
      start_sender "$code" "$TMP/payload" "" Quarterly-Report.pdf Ridge-Sunrise.jpg Meeting-Notes.md
      launch --auto-receive "$code" "${RELAY_ARGS[@]}" --screen receive --hold
      await_phase "^incoming conflicts=$conflicts\$" 60
      settle
      snap
      quit_app
      clean_docs
      ;;
    receiving)
      new_code code
      start_sender "$code" "$TMP/big" 6m Field-Recordings.zip
      launch --auto-receive "$code" "${RELAY_ARGS[@]}" --screen receive
      freeze_transfer
      snap
      quit_app
      clean_docs
      ;;
    receive-done)
      new_code code
      start_sender "$code" "$TMP/payload" "" Quarterly-Report.pdf Ridge-Sunrise.jpg Meeting-Notes.md
      launch --auto-receive "$code" "${RELAY_ARGS[@]}" --screen receive
      await_docs_file verify-result.txt 60
      [ "$(cat "$DOCS/verify-result.txt")" = "ok success=true" ] \
        || die "the receive ended with: $(cat "$DOCS/verify-result.txt")"
      settle
      snap
      quit_app
      clean_docs
      ;;
    stored-link)
      start_store_server
      launch --auto-store-send "$DOCS/shots/Quarterly-Report.pdf" --store-server "$STORE_URL" \
        --shown-link-origin https://getcroc.com --store-downloads 3 --screen send
      await_docs_file verify-store-link.txt 60
      settle
      snap
      quit_app
      ;;
  esac
}

# A local croc store server, as in verify-app-mac.sh, so "Send as link" never
# uploads to a real server. The link on screen is rewritten to the default link server, getcroc.com.
start_store_server() {
  [ -z "$STORE_URL" ] || return 0
  (cd crocmobile && go build -tags croc_no_tailcat -o "$TMP/bin/croctest" ./cmd/croctest)
  mkdir -p "$TMP/store"
  "$TMP/bin/croctest" store-server "$TMP/store" > "$TMP/store-srv.log" 2>&1 &
  STORE_PID=$!
  store_up() {
    STORE_URL=$(sed -n 's/^STORE-URL //p' "$TMP/store-srv.log")
    [ -n "$STORE_URL" ]
  }
  poll 10 store_up || die "the store server did not start (see $TMP/store-srv.log)"
}

# --- payloads ---------------------------------------------------------------

make_payloads() {
  mkdir -p "$TMP/payload" "$TMP/big" "$TMP/assets"
  "$TMP/bin/payload" pdf "$TMP/payload/Quarterly-Report.pdf"
  "$TMP/bin/payload" jpg "$TMP/payload/Ridge-Sunrise.jpg"
  cat > "$TMP/payload/Meeting-Notes.md" << 'EOF'
# Planning sync

- Ship the iPad layout before the next release.
- Move the history view to a shared list.
- Review the relay setup guide for new users.

## Actions

1. Draft the release notes.
2. Update the screenshots.
3. Book the review for Thursday.
EOF
  cp "$TMP/payload/Ridge-Sunrise.jpg" "$TMP/payload/Meeting-Notes.md" "$TMP/assets/"
  ditto -c -k --sequesterRsrc "$TMP/assets" "$TMP/payload/Design-Assets.zip"
  # Large enough that a throttled transfer outlasts the shot. Random bytes:
  # only the name is ever shown.
  head -c 150000000 /dev/urandom > "$TMP/big/Project-Archive.zip"
  head -c 150000000 /dev/urandom > "$TMP/big/Field-Recordings.zip"
}

# --- verification -----------------------------------------------------------

check_png() { # check_png FILE WIDTH HEIGHT
  local info w h a
  info=$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$1")
  w=$(awk '/pixelWidth/ { print $2 }' <<< "$info")
  h=$(awk '/pixelHeight/ { print $2 }' <<< "$info")
  a=$(awk '/hasAlpha/ { print $2 }' <<< "$info")
  [ "$w" = "$2" ] && [ "$h" = "$3" ] && [ "$a" = no ] \
    || fail "$1 is ${w}x${h} hasAlpha=$a, App Store Connect wants $2x$3 with no alpha"
}

# Every store file has Apple's size and no alpha, a class holds exactly its
# slots (at most ten), and a run of a whole device has written every file.
verify_outputs() {
  local d s width height file n
  for d in $RUN_DEVICES; do
    read -r width height <<< "$(store_dims "$d")"
    for s in $RUN_SCREENS; do
      in_list "$STORE_SCREENS" "$s" || continue
      file="$OUT/app-store/$(store_class "$d")/$(store_name "$s").png"
      [ -e "$file" ] || fail "missing store file $file"
      check_png "$file" "$width" "$height"
    done
    n=$(find "$OUT/app-store/$(store_class "$d")" -name '*.png' | wc -l)
    [ "$n" -le 10 ] || fail "$n store files for $d, Apple allows ten"
    is_main "$d" || continue
    for s in $RUN_SCREENS; do
      [ "$d $s" = "mac onboarding" ] && continue
      has_screen "$d" "$s" || continue
      for MODE in light dark; do
        [ -s "$OUT/$d/$s-$MODE.png" ] || fail "missing $OUT/$d/$s-$MODE.png"
      done
    done
  done
  echo "outputs OK (every file present, store files sized and without alpha)"
}

# --- run --------------------------------------------------------------------

make_payloads

echo "building..."
BIN=""
if [ "$uses_mac" = 1 ]; then
  logged "$TMPROOT/shots-mac-build.log" xcodebuild -project app/CrocApp.xcodeproj -scheme CrocApp \
    -destination 'platform=macOS' -derivedDataPath "$DD_MAC" -allowProvisioningUpdates build
  BIN=$(find "$DD_MAC/Build/Products" -maxdepth 3 -name CrocApp.app | head -1)/Contents/MacOS/CrocApp
  [ -x "$BIN" ] || fail "no CrocApp.app in $DD_MAC (see $TMPROOT/shots-mac-build.log)"
  stage_payloads "$MAC_DOCS"
fi

if [ "$uses_sim" = 1 ]; then
  logged "$TMPROOT/shots-sim-build.log" xcodebuild -project app/CrocApp.xcodeproj -scheme CrocApp \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD_SIM" build
  SIM_APP=$(find "$DD_SIM/Build/Products" -maxdepth 3 -name CrocApp.app | head -1)
  [ -n "$SIM_APP" ] || fail "no CrocApp.app in $DD_SIM (see $TMPROOT/shots-sim-build.log)"
fi

start_relay
RELAY_ARGS=(--relay "$RELAY_ADDR" --relay-password "$RELAY_PASS" --shown-relay default)
DISABLE_LOCAL=1

# A full run rebuilds the set from nothing, so a renamed shot cannot leave its
# old file behind. Late, so a failed build or preflight wipes nothing.
if [ -z "$PICK_SCREENS" ]; then
  if [ -z "$PICK_DEVICES" ]; then
    find "$OUT" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  else
    for d in $RUN_DEVICES; do
      rm -rf "${OUT:?}/app-store/$(store_class "$d")"
      is_main "$d" && rm -rf "${OUT:?}/$d"
    done
  fi
fi

# One pass per appearance over the devices that have a main set.
shoot_devices() { # shoot_devices DEVICE...
  local d
  for d in "$@"; do
    use_device "$d"
    for SCREEN in $RUN_SCREENS; do
      # On macOS the first-run welcome is a sheet over a window that then
      # photographs with grey traffic lights.
      [ "$DEV $SCREEN" = "mac onboarding" ] && continue
      has_screen "$DEV" "$SCREEN" || continue
      # A store-only device takes just the screens that are in the store set,
      # in the one appearance their slot calls for.
      if ! is_main "$DEV"; then
        in_list "$STORE_SCREENS" "$SCREEN" && [ "$(store_mode "$SCREEN")" = "$MODE" ] || continue
      fi
      echo "$DEV $SCREEN"
      capture_screen
    done
  done
}

main_run=""
store_run=""
for d in $RUN_DEVICES; do
  if is_main "$d"; then main_run="$main_run $d"; else store_run="$store_run $d"; fi
  if is_main "$d" && [ "$d" != mac ]; then bring_up "$d"; fi
done

for MODE in light dark; do
  echo "$MODE..."
  [ "$uses_mac" = 0 ] || set_system_appearance "$MODE"
  for d in $main_run; do
    [ "$d" = mac ] || {
      id="ID_$d"
      xcrun simctl ui "${!id}" appearance "$MODE" > /dev/null
    }
  done
  # shellcheck disable=SC2086  # deliberate split: one word per device
  [ -z "$main_run" ] || shoot_devices $main_run
done
for d in $main_run; do [ "$d" = mac ] || drop_sim "$d"; done

# The store-only simulators come up one at a time, after the main ones are gone.
for d in $store_run; do
  bring_up "$d"
  for MODE in light dark; do
    id="ID_$d"
    xcrun simctl ui "${!id}" appearance "$MODE" > /dev/null
    echo "$d $MODE..."
    shoot_devices "$d"
  done
  drop_sim "$d"
done

verify_outputs
echo SHOTS-OK
