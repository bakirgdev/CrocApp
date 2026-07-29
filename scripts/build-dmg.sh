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

APP=${1:?usage: build-dmg.sh <CrocApp.app> <version> [out-dir]}
VERSION=${2:?usage: build-dmg.sh <CrocApp.app> <version> [out-dir]}
OUT=${3:-dist}

[ -d "$APP" ] || { echo "error: no app bundle at $APP"; exit 1; }
command -v create-dmg >/dev/null || { echo "error: create-dmg not installed (brew install create-dmg)"; exit 1; }

DMG="$OUT/CrocApp-$VERSION-arm64.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$OUT"
rm -f "$DMG"
cp -R "$APP" "$STAGE/CrocApp.app"

# Window and icon geometry come from design/components.md -> DiskImage. Changing
# a number here without changing it there leaves the spec lying.
create-dmg \
  --volname "CrocApp $VERSION" \
  --background assets/dmg-background.png \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon CrocApp.app 165 195 \
  --hide-extension CrocApp.app \
  --app-drop-link 495 195 \
  --no-internet-enable \
  "$DMG" "$STAGE"

echo "dmg: $DMG"
echo DMG-OK
