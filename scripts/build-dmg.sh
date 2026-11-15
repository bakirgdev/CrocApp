#!/usr/bin/env bash
# Wrap a built CrocApp.app in a styled disk image.
#
#   scripts/build-dmg.sh <path/to/CrocApp.app> <version> [out-dir]
#
# Produces <out-dir>/CrocApp-<version>-arm64.dmg. The arch is in the name on
# purpose: the macOS slice of Croc.xcframework is arm64-only (golang/go#73119),
# so an Intel Mac has nothing to run and the filename should say so before the
# download does.
#
# This does not sign, notarize or staple anything -- whatever signature the app
# already carries is what ships. See scripts/build-devid.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"

APP=${1:?usage: build-dmg.sh <CrocApp.app> <version> [out-dir]}
VERSION=${2:?usage: build-dmg.sh <CrocApp.app> <version> [out-dir]}
OUT=${3:-dist}

[ -d "$APP" ] || fail "no app bundle at $APP"
command -v create-dmg > /dev/null || fail "create-dmg not installed (brew install create-dmg)"

DMG="$OUT/CrocApp-$VERSION-arm64.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$OUT"
rm -f "$DMG"
cp -R "$APP" "$STAGE/CrocApp.app"

# Window and icon geometry come from docs/RELEASING.md, "Disk image". Changing
# a number here without changing it there leaves the spec lying.
create-dmg \
  --volname "CrocApp $VERSION" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon CrocApp.app 165 160 \
  --hide-extension CrocApp.app \
  --app-drop-link 495 160 \
  --no-internet-enable \
  "$DMG" "$STAGE"

[ -s "$DMG" ] || fail "create-dmg wrote nothing to $DMG"

# create-dmg lays the window out by driving Finder, which saves the result in
# .DS_Store. A missing one means the layout was not applied.
mkdir "$STAGE/mnt"
hdiutil attach -readonly -nobrowse -quiet -mountpoint "$STAGE/mnt" "$DMG"
trap 'hdiutil detach -quiet "$STAGE/mnt"; rm -rf "$STAGE"' EXIT
[ -s "$STAGE/mnt/.DS_Store" ] || fail "$DMG has no Finder layout (.DS_Store)"
[ ! -e "$STAGE/mnt/.background" ] || fail "$DMG still has a .background folder"
echo "dmg: $DMG"
echo DMG-OK
