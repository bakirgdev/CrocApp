#!/usr/bin/env bash
# Writes every screenshot in assets/screenshots/ from real builds -- no mockups,
# no device frames, no real transfer codes. This file is the manifest: each
# `want <name>` block below is one shot, captured light and dark, at 2x, and
# SHOTS lists them all (`--list` prints them with their output files).
#
# Staging rides on the DEBUG-only harness flags in AutoVerify.swift: --screen
# navigates, --stage preloads the Send list, --seed-history fills the
# (in-memory) history store, --hold parks at the incoming prompt. The macOS
# shots are per-window captures (screencapture -l), so they keep the real
# window shape with no desktop behind them; the iOS shots are whole-device
# captures, which is what a phone screenshot is.
#
# The same run also writes the App Store set to assets/screenshots/store/, light
# only, PNG with no alpha channel, numbered in upload order (01-..., 02-...).
# Apple's current sizes (developer.apple.com/help/app-store-connect/reference/
# app-information/screenshot-specifications):
#   iphone-6.3  1206x2622  iPhone 17 Pro, the same shots as the main set
#   iphone-6.9  1320x2868  iPhone 17 Pro Max, a throwaway simulator
#   ipad-13     2064x2752  iPad Pro 13-inch (M5), a throwaway simulator
#   mac         2880x1800  the window composed on a canvas (see imgtool below)
# Every store file is checked with sips at the end; a wrong size or an alpha
# channel fails the run.
#
# Takes over the display for roughly forty minutes and flips the system
# appearance twice. The original appearance is restored on exit, including on
# failure. Pass a shot name (e.g. `capture-screenshots.sh mac-home`) to
# re-capture just that one in both appearances (and its store file, if it has
# one). `--list` prints the manifest and exits; `--copy-web` copies the main set
# to the two web surfaces and exits. Neither touches the display.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

SIM="${SIM:-iPhone 17 Pro}"
BUNDLE=com.bakirgdev.CrocApp
OUT=assets/screenshots
STORE_DIR="$OUT/store"
DOCS="$HOME/Library/Containers/$BUNDLE/Data/Documents"
# Simulator device types for the two store-only passes. Override if Xcode
# ships neither (see `xcrun simctl list devicetypes`); the pixel size is
# asserted right after boot, so a wrong type fails before any capture.
PHONE_TYPE="${PHONE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max}"
PAD_TYPE="${PAD_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-16GB}"

SHOTS="mac-home mac-send-files mac-send mac-receive mac-transferring mac-done \
mac-history mac-howitworks mac-settings mac-advanced mac-stored mac-conflict \
ios-home ios-onboarding ios-send ios-send-code ios-receive-code \
ios-receive ios-history ios-settings ios-advanced ios-transferring ios-stored \
ios-conflict ios-done"
# The store sets, in upload order. The number in a file name is the position.
STORE_IOS="ios-send ios-send-code ios-transferring ios-receive ios-stored ios-history \
ios-conflict ios-advanced"
STORE_MAC="mac-send-files mac-send mac-transferring mac-done mac-stored mac-history \
mac-conflict mac-advanced"
STORE_CLASSES="iphone-6.3 iphone-6.9 ipad-13 mac"

in_list() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

store_name() {                                      # store_name LIST SHOT -> NN-name
  local i=1 n
  for n in $1; do
    [ "$n" = "$2" ] && { printf '%02d-%s' "$i" "${n#*-}"; return 0; }
    i=$((i + 1))
  done
  return 1
}

store_dims() {                                      # store_dims CLASS -> "WIDTH HEIGHT"
  case "$1" in
    iphone-6.3) echo "1206 2622" ;;
    iphone-6.9) echo "1320 2868" ;;
    ipad-13) echo "2064 2752" ;;
    mac) echo "2880 1800" ;;
    *) return 1 ;;
  esac
}

store_list_for() { [ "$1" = mac ] && echo "$STORE_MAC" || echo "$STORE_IOS"; }

case "${1:-}" in
  --list)
    echo "main set, light and dark ($OUT/NAME-light.png, NAME-dark.png):"
    for n in $SHOTS; do echo "  $n"; done
    echo "store set, light only ($STORE_DIR/CLASS/NN-name.png):"
    for c in $STORE_CLASSES; do
      echo "  $c ($(store_dims "$c" | tr ' ' x)):"
      for n in $(store_list_for "$c"); do echo "    $c/$(store_name "$(store_list_for "$c")" "$n").png  <- $n"; done
    done
    exit 0
    ;;
  --copy-web)
    # Refreshes the copies a web surface already uses; a new shot goes in by
    # adding its file to the folder first. The store set stays in
    # assets/screenshots/store/.
    for dir in web/docs/static/img/screenshots web/landing/assets/img/screenshots; do
      n=0
      for f in "$dir"/*.png; do
        [ -e "$f" ] || continue
        cp "$OUT/$(basename "$f")" "$f"
        n=$((n + 1))
      done
      echo "refreshed $n files in $dir"
    done
    exit 0
    ;;
esac

CROC="${CROC:-${HOMEBREW_PREFIX:-/opt/homebrew}/bin/croc}"
require_croc

ONLY="${1:-}"
if [ -n "$ONLY" ]; then
  case " $SHOTS " in
    *" $ONLY "*) ;;
    *) fail "unknown shot '$ONLY'. One of: $SHOTS" ;;
  esac
fi

# The store-only simulator passes run for a full run, or for a single shot
# that belongs to the iOS store set.
if [ -z "$ONLY" ] || in_list "$STORE_IOS" "$ONLY"; then
  RUN_STORE_SIMS=1
  for type in "$PHONE_TYPE" "$PAD_TYPE"; do
    xcrun simctl list -j devicetypes | grep -q "\"$type\"" \
      || fail "simulator device type $type is not installed (set PHONE_TYPE/PAD_TYPE)"
  done
else
  RUN_STORE_SIMS=0
fi

TMP=$(mktemp -d)
APP_PID=""
JOB_PID=""
STORE_PID=""
STORE_URL=""
PRIMARY_SIM="$SIM"
EXTRA_SIM=""
STORE_PASS=""
MODE=""
ORIG_DARK=$(osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode')

cleanup() {
  [ -n "$APP_PID" ] && kill "$APP_PID" 2>/dev/null || true
  [ -n "$JOB_PID" ] && kill "$JOB_PID" 2>/dev/null || true
  [ -n "$STORE_PID" ] && kill "$STORE_PID" 2>/dev/null || true
  kill_jobs
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  xcrun simctl status_bar "$PRIMARY_SIM" clear 2>/dev/null || true
  if [ -n "$EXTRA_SIM" ]; then
    xcrun simctl shutdown "$EXTRA_SIM" 2>/dev/null || true
    xcrun simctl delete "$EXTRA_SIM" 2>/dev/null || true
  fi
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $ORIG_DARK" >/dev/null 2>&1 || true
  rm -rf "$DOCS/shots" "$TMP"
  return 0
}
trap cleanup EXIT

# Inside a store-only simulator pass a shot is wanted only if the store set
# includes it.
want() {
  [ -z "$ONLY" ] || [ "$ONLY" = "$1" ] || return 1
  [ -z "$STORE_PASS" ] || in_list "$STORE_IOS" "$1"
}

# The relay hashes a code's first 4 characters into a room name, so those four
# have to be unique -- not just within a run, but against any recent run still
# holding the room. Hardcoded prefixes made a re-capture of the same shot fail
# against its own leftovers. Random base, then one per code; each $(code ...)
# runs in a subshell, so an incrementing counter would not survive between
# calls and every code takes an explicit offset instead. Each capture pass
# gets its own block of offsets.
CODE_BASE=$((RANDOM % 8000 + 1000))
code() {                                            # code OFFSET WORDS
  printf '%d-%s' "$((CODE_BASE + $1))" "$2"
}

# screencapture wants a CGWindowID and nothing in the shell hands one out.
# AppleScript's window ids are AX ids, not CGWindowIDs, so System Events
# cannot supply this even though it sees the same windows. Width and height
# are there so a caller can tell windows of one app apart.
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
    let bounds = window[kCGWindowBounds as String] as? [String: Any]
    let width = (bounds?["Width"] as? NSNumber)?.intValue ?? 0
    let height = (bounds?["Height"] as? NSNumber)?.intValue ?? 0
    print("\(number)\t\(layer)\t\(name)\t\(width)\t\(height)")
}
SWIFT
xcrun swiftc -O "$TMP/windowid.swift" -o "$TMP/windowid"

# The store files need pixel work the shell has no tool for (no ImageMagick
# here): `flatten` redraws a simulator screenshot into a context with no alpha
# channel; `compose` centres window captures, 1x and side by side if several,
# on a flat gradient canvas, which is how the Mac store size (16:10) is reached
# without stretching a 560x700 window. Both write PNGs without alpha, because
# App Store Connect rejects an alpha channel and flattening over a colour alone
# would keep one.
cat > "$TMP/imgtool.swift" <<'SWIFT'
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func load(_ path: String) -> CGImage {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(src, 0, nil)
    else {
        FileHandle.standardError.write(Data("cannot read \(path)\n".utf8))
        exit(1)
    }
    return image
}

func save(_ context: CGContext, _ path: String) {
    guard let image = context.makeImage(),
        let dest = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { exit(1) }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { exit(1) }
}

// noneSkipLast is what leaves the PNG with no alpha channel.
func opaqueContext(_ width: Int, _ height: Int, _ space: CGColorSpace) -> CGContext {
    guard
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { exit(1) }
    context.interpolationQuality = .none
    return context
}

let args = CommandLine.arguments
switch args.count > 1 ? args[1] : "" {
case "flatten":                                     // flatten IN OUT
    let image = load(args[2])
    let context = opaqueContext(
        image.width, image.height, image.colorSpace ?? CGColorSpaceCreateDeviceRGB())
    let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fill(rect)
    context.draw(image, in: rect)
    save(context, args[3])
case "compose":                                     // compose OUT WIDTH HEIGHT IMG...
    let width = Int(args[3])!, height = Int(args[4])!
    let images = args[5...].map(load)
    let gap = 120
    let total = images.reduce(0) { $0 + $1.width } + gap * (images.count - 1)
    guard total <= width, images.allSatisfy({ $0.height <= height }) else {
        FileHandle.standardError.write(
            Data("images do not fit a \(width)x\(height) canvas\n".utf8))
        exit(1)
    }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = opaqueContext(width, height, space)
    let gradient = CGGradient(
        colorsSpace: space,
        colors: [
            CGColor(red: 0.89, green: 0.92, blue: 0.97, alpha: 1),
            CGColor(red: 0.74, green: 0.80, blue: 0.91, alpha: 1),
        ] as CFArray,
        locations: [0, 1])!
    context.drawLinearGradient(
        gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
    var x = (width - total) / 2
    for image in images {
        let rect = CGRect(
            x: x, y: (height - image.height) / 2, width: image.width, height: image.height)
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -24), blur: 70,
            color: CGColor(gray: 0, alpha: 0.35))
        context.draw(image, in: rect)
        context.restoreGState()
        x += image.width + gap
    }
    save(context, args[2])
default:
    FileHandle.standardError.write(
        Data("usage: imgtool flatten IN OUT | compose OUT WIDTH HEIGHT IMG...\n".utf8))
    exit(2)
}
SWIFT
xcrun swiftc -O "$TMP/imgtool.swift" -o "$TMP/imgtool"

check_png() {                                       # check_png FILE WIDTH HEIGHT
  local info w h a
  info=$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$1")
  w=$(awk '/pixelWidth/ { print $2 }' <<< "$info")
  h=$(awk '/pixelHeight/ { print $2 }' <<< "$info")
  a=$(awk '/hasAlpha/ { print $2 }' <<< "$info")
  [ "$w" = "$2" ] && [ "$h" = "$3" ] && [ "$a" = no ] \
    || fail "$1 is ${w}x${h} hasAlpha=$a, App Store Connect wants $2x$3 with no alpha"
}

activate_croc() {
  # An unfocused window photographs with grey traffic lights and a dimmed
  # title, so every capture has to raise the app first.
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "CrocApp") to true' >/dev/null
  sleep 1
}

# The keystroke goes to whatever app is frontmost, and a terminal that holds
# focus swallows it, so raise CrocApp and retry until the window shows up.
open_settings() {
  local i
  for i in 1 2 3; do
    activate_croc
    osascript -e 'tell application "System Events" to keystroke "," using command down'
    sleep 3
    "$TMP/windowid" CrocApp | awk -F'\t' '$3 == "General" || $3 == "Advanced" || $3 == "Settings" || $3 == "CrocApp Settings" { f = 1 } END { exit !f }' && return 0
  done
  fail "the Settings window did not open"
}

shoot_window() {                                    # shoot_window OUTFILE TITLE...
  local out=$1 wid titles
  shift
  titles=$(IFS='|'; echo "$*")
  wid=$("$TMP/windowid" CrocApp | awk -F'\t' -v t="$titles" '
    BEGIN { n = split(t, want, "|") }
    $2 == 0 { for (i = 1; i <= n; i++) if ($3 == want[i]) { print $1; exit } }')
  [ -n "$wid" ] || fail "no on-screen CrocApp window titled '$titles'"
  screencapture -x -o -l "$wid" "$out"
  [ -s "$out" ] || fail "screencapture wrote nothing to $out"
  echo "  $out"
}

store_mac() {                                       # store_mac SHOT FILE...
  local shot=$1 out
  shift
  [ "$MODE" = light ] || return 0
  in_list "$STORE_MAC" "$shot" || return 0
  mkdir -p "$STORE_DIR/mac"
  out="$STORE_DIR/mac/$(store_name "$STORE_MAC" "$shot").png"
  "$TMP/imgtool" compose "$out" 2880 1800 "$@"
  echo "  $out"
}

shoot_mac() {                                       # shoot_mac SHOT TITLE...
  local shot=$1
  shift
  shoot_window "$OUT/$shot-$MODE.png" "$@"
  store_mac "$shot" "$OUT/$shot-$MODE.png"
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

store_flat() {                                      # store_flat CLASS SHOT RAWFILE
  local out
  in_list "$STORE_IOS" "$2" || return 0
  mkdir -p "$STORE_DIR/$1"
  out="$STORE_DIR/$1/$(store_name "$STORE_IOS" "$2").png"
  "$TMP/imgtool" flatten "$3" "$out"
  echo "  $out"
}

# The primary simulator already produces the 6.3-inch size, so its light shots
# double as that store set. A store-only pass writes nothing to the main set.
ios_shoot() {                                       # ios_shoot SHOT
  local raw="$OUT/$1-$MODE.png"
  [ -z "$STORE_PASS" ] || raw="$TMP/store-raw.png"
  xcrun simctl io "$SIM" screenshot --type=png "$raw" 2>/dev/null
  [ -s "$raw" ] || fail "simctl wrote nothing to $raw"
  echo "  $raw"
  if [ -n "$STORE_PASS" ]; then
    store_flat "$STORE_PASS" "$1" "$raw"
  elif [ "$MODE" = light ]; then
    store_flat iphone-6.3 "$1" "$raw"
  fi
}

set_appearance() {                                  # set_appearance light|dark
  local dark=false
  [ "$1" = dark ] && dark=true
  osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $dark" >/dev/null
  xcrun simctl ui "$SIM" appearance "$1" >/dev/null
  sleep 3
}

# Boots and fills one simulator the way the primary one is prepared: the app,
# the staged payloads, a 9:41 status bar. Waits for the boot, because a
# freshly created device takes a while.
prepare_sim() {                                     # prepare_sim DEVICE
  local docs
  xcrun simctl bootstatus "$1" -b > /dev/null
  xcrun simctl install "$1" "$SIM_APP"
  docs=$(xcrun simctl get_app_container "$1" "$BUNDLE" data)/Documents
  mkdir -p "$docs/shots"
  cp "$TMP/payload"/* "$docs/shots/"
  xcrun simctl status_bar "$1" override --time "9:41" \
    --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3
}

# A local croc store server, as in verify-app-mac.sh, so "Send as link" never
# uploads to a real server. The link on screen therefore names 127.0.0.1.
start_store_server() {
  [ -z "$STORE_URL" ] || return 0
  command -v go > /dev/null || fail "go is needed to build the local store server"
  ( cd crocmobile && go build -o "$TMP/croctest" ./cmd/croctest )
  mkdir -p "$TMP/store"
  "$TMP/croctest" store-server "$TMP/store" > "$TMP/store-srv.log" 2>&1 &
  STORE_PID=$!
  local _
  for _ in $(seq 1 50); do
    STORE_URL=$(sed -n 's/^STORE-URL //p' "$TMP/store-srv.log")
    [ -z "$STORE_URL" ] || return 0
    sleep 0.2
  done
  fail "store server did not start (see $TMP/store-srv.log)"
}

stop_job() {
  [ -n "$JOB_PID" ] && kill "$JOB_PID" 2>/dev/null || true
  wait "$JOB_PID" 2>/dev/null || true
  JOB_PID=""
}

# --- macOS ------------------------------------------------------------------

capture_mac() {                                     # capture_mac MODE CODE_OFFSET
  MODE=$1
  local code_a code_b code_c code_d
  code_a=$(code "$2" amber-willow-signal)
  code_b=$(code "$(($2 + 1))" copper-lantern-summit)
  code_c=$(code "$(($2 + 2))" quiet-meadow-anchor)
  code_d=$(code "$(($2 + 3))" violet-harbor-drift)
  # Same reason as the iOS side: leftovers from an earlier run would show up
  # as a conflict warning on the next incoming preview.
  rm -f "$DOCS/Presentation.pdf" "$DOCS/Budget.numbers" "$DOCS/Cover-Art.png" \
    "$DOCS/Field-Recordings.zip" "$DOCS/verify-result.txt" "$DOCS/verify-store-link.txt"

  if want mac-home || want mac-settings || want mac-advanced; then
    mac_launch --screen home
    if want mac-home; then shoot_mac mac-home CrocApp; fi
    if want mac-settings || want mac-advanced; then
      open_settings
      # The selected tab survives a relaunch, so a run after mac-advanced
      # would open on Advanced.
      osascript -e 'tell application "System Events" to tell process "CrocApp" to click button "General" of toolbar 1 of window 1'
      sleep 2
      # A freshly opened Settings scene is scrolled to the top. It opens at
      # its .defaultSize (480x780) and is user-resizable, which is
      # why this catches the whole form rather than stopping mid-row. With
      # the General/Advanced tabs the window title follows the selected tab.
      if want mac-settings; then shoot_mac mac-settings "CrocApp Settings" General Settings; fi
      if want mac-advanced; then
        osascript -e 'tell application "System Events" to tell process "CrocApp" to click button "Advanced" of toolbar 1 of window 1'
        sleep 2
        shoot_mac mac-advanced Advanced
      fi
    fi
    mac_quit
  fi

  if want mac-send-files; then
    mac_launch --screen send \
      --stage "$DOCS/shots/Presentation.pdf" \
      --stage "$DOCS/shots/Budget.numbers" \
      --stage "$DOCS/shots/Cover-Art.png"
    shoot_mac mac-send-files Send
    mac_quit
  fi

  if want mac-receive; then
    mac_launch --screen receive
    shoot_mac mac-receive Receive
    mac_quit
  fi

  if want mac-conflict; then
    # The files are already in the receive folder, which is what makes the
    # incoming preview offer Keep Both / Replace.
    cp "$TMP/payload/Presentation.pdf" "$TMP/payload/Cover-Art.png" "$DOCS/"
    ( cd "$TMP/payload" && CROC_SECRET="$code_d" "$CROC" --ignore-stdin send \
        Presentation.pdf Budget.numbers Cover-Art.png ) > "$TMP/send-d.log" 2>&1 &
    JOB_PID=$!
    sleep 5
    mac_launch --auto-receive "$code_d" --screen receive --hold
    sleep 20
    activate_croc
    shoot_mac mac-conflict Receive
    stop_job
    mac_quit
    rm -f "$DOCS/Presentation.pdf" "$DOCS/Cover-Art.png"
  fi

  if want mac-history; then
    mac_launch --screen history --seed-history
    shoot_mac mac-history History
    mac_quit
  fi

  if want mac-howitworks; then
    mac_launch --screen howItWorks
    shoot_mac mac-howitworks "How it works"
    mac_quit
  fi

  if want mac-stored; then
    start_store_server
    mac_launch --auto-store-send "$DOCS/shots/Presentation.pdf" \
      --store-server "$STORE_URL" --store-downloads 3 --screen send
    await_file "$DOCS/verify-store-link.txt" 60 || fail "mac-stored: the upload never produced a link"
    sleep 3
    activate_croc
    shoot_mac mac-stored Send
    rm -f "$DOCS/verify-store-link.txt"
    mac_quit
  fi

  if want mac-send; then
    # No receiver ever shows up, so this parks in "Ready to send" -- the only
    # state that displays the code phrase and the QR.
    mac_launch --auto-send "$DOCS/shots/Design-Assets.zip" --code "$code_a" --screen send
    # croc hashes the payload before the relay publishes the code.
    sleep 9
    activate_croc
    shoot_mac mac-send Send
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
    shoot_mac mac-transferring Send
    stop_job
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
    await_file "$DOCS/verify-result.txt" 90 || fail "mac-done: transfer never finished"
    sleep 2
    activate_croc
    shoot_mac mac-done Receive
    stop_job
    mac_quit
  fi
}

# --- iOS --------------------------------------------------------------------

capture_ios() {                                     # capture_ios MODE CODE_OFFSET
  MODE=$1
  local code_a code_b code_c code_d code_e
  code_a=$(code "$2" golden-cedar-morrow)
  code_b=$(code "$(($2 + 1))" silver-thicket-bay)
  code_c=$(code "$(($2 + 2))" crimson-pillar-notch)
  code_d=$(code "$(($2 + 3))" indigo-marsh-relay)
  code_e=$(code "$(($2 + 4))" russet-canyon-vale)
  local simdocs
  simdocs=$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)/Documents
  # Documents is the iOS receive folder, so files left by an earlier run make
  # the next incoming preview sprout an "already exist and will be replaced"
  # warning. True, but an artifact of re-running rather than anything a reader
  # should see. Named explicitly: shots/ next door holds the staged payloads.
  rm -f "$simdocs/Presentation.pdf" "$simdocs/Budget.numbers" "$simdocs/Cover-Art.png" \
    "$simdocs/Live-Set.wav" "$simdocs/verify-result.txt" "$simdocs/verify-store-link.txt"

  if want ios-home; then
    ios_launch --screen home
    sleep 4
    ios_shoot ios-home
  fi

  if want ios-onboarding; then
    ios_launch --screen onboarding
    sleep 5
    ios_shoot ios-onboarding
  fi

  if want ios-send; then
    ios_launch --screen send \
      --stage "$simdocs/shots/Presentation.pdf" \
      --stage "$simdocs/shots/Budget.numbers" \
      --stage "$simdocs/shots/Cover-Art.png"
    sleep 4
    ios_shoot ios-send
  fi

  if want ios-send-code; then
    # Same parked "Ready to send" state as mac-send.
    ios_launch --auto-send "$simdocs/shots/Design-Assets.zip" --code "$code_d" --screen send
    sleep 12
    ios_shoot ios-send-code
  fi

  if want ios-receive-code; then
    ios_launch --screen receive
    sleep 4
    ios_shoot ios-receive-code
  fi

  if want ios-history; then
    ios_launch --screen history --seed-history
    sleep 4
    ios_shoot ios-history
  fi

  if want ios-settings; then
    ios_launch --screen settings
    sleep 4
    ios_shoot ios-settings
  fi

  if want ios-advanced; then
    ios_launch --screen advanced
    sleep 4
    ios_shoot ios-advanced
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
    ios_shoot ios-receive
    ios_stop_job
  fi

  if want ios-conflict; then
    # As ios-receive, with two of the three files already in Documents: the
    # preview then offers Keep Both / Replace.
    cp "$TMP/payload/Presentation.pdf" "$TMP/payload/Cover-Art.png" "$simdocs/"
    ( cd "$TMP/payload" && CROC_SECRET="$code_e" "$CROC" --ignore-stdin send \
        Presentation.pdf Budget.numbers Cover-Art.png ) > "$TMP/ios-e.log" 2>&1 &
    JOB_PID=$!
    sleep 5
    ios_launch --auto-receive "$code_e" --screen receive --hold
    sleep 12
    ios_shoot ios-conflict
    ios_stop_job
    rm -f "$simdocs/Presentation.pdf" "$simdocs/Cover-Art.png"
  fi

  if want ios-stored; then
    start_store_server
    ios_launch --auto-store-send "$simdocs/shots/Presentation.pdf" \
      --store-server "$STORE_URL" --store-downloads 3 --screen send
    await_file "$simdocs/verify-store-link.txt" 60 || fail "ios-stored: the upload never produced a link"
    sleep 3
    ios_shoot ios-stored
    rm -f "$simdocs/verify-store-link.txt"
  fi

  if want ios-transferring; then
    # Here the CLI is the sender, so the rate can be pinned instead of guessed:
    # unthrottled, 150 MB finished before the shutter fell. 41 MB at 400k/s
    # cannot finish inside the wait below, and that wait is long enough that
    # the handshake -- which eats most of the first half minute -- is well
    # behind us by the time the progress bar is photographed.
    ( cd "$TMP/big" && CROC_SECRET="$code_b" "$CROC" --throttleUpload 400k \
        --ignore-stdin send Live-Set.wav ) > "$TMP/ios-b.log" 2>&1 &
    JOB_PID=$!
    sleep 5
    ios_launch --auto-receive "$code_b" --screen receive
    sleep 70
    ios_shoot ios-transferring
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
    if ! await_file "$simdocs/verify-result.txt" 120; then
      echo "--- croc sender log ---" >&2
      tail -5 "$TMP/ios-c.log" >&2
      fail "ios-done: transfer never finished"
    fi
    sleep 2
    ios_shoot ios-done
    rm -f "$simdocs/verify-result.txt"
    ios_stop_job
  fi

  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
}

ios_stop_job() {
  stop_job
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
}

# One store-only pass on a throwaway simulator of the given device type, light
# only. The size is asserted before any capture, so a device type that does not
# produce Apple's pixels fails in a minute, not at the end of the run.
store_sim_pass() {                                  # store_sim_pass CLASS TYPE CODE_OFFSET
  local class=$1 name="CrocApp Shots $1" width height
  read -r width height <<< "$(store_dims "$class")"
  xcrun simctl delete "$name" 2>/dev/null || true
  EXTRA_SIM=$(xcrun simctl create "$name" "$2")
  prepare_sim "$EXTRA_SIM"
  xcrun simctl ui "$EXTRA_SIM" appearance light > /dev/null
  sleep 3
  xcrun simctl io "$EXTRA_SIM" screenshot --type=png "$TMP/size.png" 2>/dev/null
  "$TMP/imgtool" flatten "$TMP/size.png" "$TMP/size-flat.png"
  check_png "$TMP/size-flat.png" "$width" "$height"
  echo "$class: $name is ${width}x${height}"
  SIM=$EXTRA_SIM
  STORE_PASS=$class
  capture_ios light "$3"
  SIM=$PRIMARY_SIM
  STORE_PASS=""
  xcrun simctl shutdown "$EXTRA_SIM" 2>/dev/null || true
  xcrun simctl delete "$EXTRA_SIM"
  EXTRA_SIM=""
}

# Every file under store/ has Apple's size and no alpha; after a full run,
# every file in the lists is there too.
verify_store() {
  local class width height shot file listed
  for class in $STORE_CLASSES; do
    read -r width height <<< "$(store_dims "$class")"
    listed=$(store_list_for "$class")
    for shot in $listed; do
      file="$STORE_DIR/$class/$(store_name "$listed" "$shot").png"
      if [ -e "$file" ]; then
        check_png "$file" "$width" "$height"
      elif [ -z "$ONLY" ]; then
        fail "missing store file $file"
      fi
    done
  done
  echo "store files OK (sizes and no alpha)"
}

# --- payloads ---------------------------------------------------------------

mkdir -p "$OUT" "$DOCS/shots" "$TMP/payload" "$TMP/big"
# A full run rebuilds the store set from nothing, so a renumbered shot cannot
# leave its old file behind.
[ -n "$ONLY" ] || rm -rf "$STORE_DIR"
# Placeholder payloads. The names show up in the staged and incoming file
# lists, the byte counts show up as their sizes; nothing here is a real
# document. Design-Assets.zip is the send payload nobody ever receives;
# Field-Recordings.zip is large on purpose so a transfer stays photographable.
head -c 8800000 /dev/urandom > "$TMP/payload/Presentation.pdf"
head -c 627000 /dev/urandom > "$TMP/payload/Budget.numbers"
head -c 2200000 /dev/urandom > "$TMP/payload/Cover-Art.png"
head -c 4194304 /dev/urandom > "$TMP/payload/Design-Assets.zip"
head -c 41000000 /dev/urandom > "$TMP/big/Live-Set.wav"
head -c 200000000 /dev/urandom > "$TMP/Field-Recordings.zip"
# The macOS app is sandboxed, so anything it sends has to live inside its
# container -- $TMP is not readable from in there.
cp "$TMP/payload"/* "$TMP/Field-Recordings.zip" "$DOCS/shots/"

echo "building macOS..."
( cd app && xcodebuild -scheme CrocApp -destination 'platform=macOS' \
    -derivedDataPath "$TMPROOT/dd-mac" -allowProvisioningUpdates build ) > "$TMPROOT/shots-mac-build.log" 2>&1
BIN=$(find "$TMPROOT/dd-mac/Build/Products" -maxdepth 3 -name CrocApp.app | head -1)/Contents/MacOS/CrocApp
[ -x "$BIN" ] || fail "no CrocApp.app in $TMPROOT/dd-mac (see $TMPROOT/shots-mac-build.log)"

echo "building iOS..."
xcrun simctl boot "$SIM" 2>/dev/null || true
( cd app && xcodebuild -scheme CrocApp -destination "platform=iOS Simulator,name=$SIM" \
    -derivedDataPath "$TMPROOT/dd-sim" build ) > "$TMPROOT/shots-sim-build.log" 2>&1
SIM_APP=$(find "$TMPROOT/dd-sim/Build/Products" -maxdepth 3 -name CrocApp.app | head -1)
[ -n "$SIM_APP" ] || fail "no CrocApp.app in $TMPROOT/dd-sim (see $TMPROOT/shots-sim-build.log)"
prepare_sim "$SIM"

echo "light..."
set_appearance light
capture_mac light 0
capture_ios light 5
if [ "$RUN_STORE_SIMS" = 1 ]; then
  echo "store: iPhone 6.9-inch..."
  store_sim_pass iphone-6.9 "$PHONE_TYPE" 10
  echo "store: iPad 13-inch..."
  store_sim_pass ipad-13 "$PAD_TYPE" 15
fi

echo "dark..."
set_appearance dark
capture_mac dark 20
capture_ios dark 25

verify_store
echo SHOTS-OK
