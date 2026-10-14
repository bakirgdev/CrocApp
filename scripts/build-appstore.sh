#!/usr/bin/env bash
# App Store builds of the `CrocApp` target for iOS and macOS: archive, then
# export or upload to App Store Connect.
#
#   scripts/build-appstore.sh [--upload] [ios|macos]...
#
# Without --upload, writes the signed .ipa and .pkg to $APPSTORE_WORK/export-*
# and uploads nothing. With --upload, `xcodebuild -exportArchive` sends each
# build to App Store Connect (TestFlight). No platform argument means both.
#
# Signing is automatic and cloud-managed through the Apple ID signed in to
# Xcode (Settings > Accounts), hence -allowProvisioningUpdates: no
# distribution certificate needs to be in the keychain. The build number is
# CURRENT_PROJECT_VERSION in app/Config/Version.xcconfig, never Xcode's
# (manageAppVersionAndBuildNumber is off): App Store Connect refuses a build
# number it has seen for that version, so bump it before each upload.
#
# APPSTORE_WORK sets the scratch directory (archives, DerivedData, logs).
set -euo pipefail
cd "$(dirname "$0")/.."

UPLOAD=0
PLATFORMS=()
for arg in "$@"; do
  case "$arg" in
    --upload) UPLOAD=1 ;;
    ios|macos) PLATFORMS+=("$arg") ;;
    *) echo "usage: $0 [--upload] [ios|macos]..." >&2; exit 2 ;;
  esac
done
[ ${#PLATFORMS[@]} -gt 0 ] || PLATFORMS=(ios macos)

TMPROOT="${TMPDIR:-/tmp}"
WORK="${APPSTORE_WORK:-${TMPROOT%/}/crocapp-appstore}"
rm -rf "$WORK"
mkdir -p "$WORK"

for platform in "${PLATFORMS[@]}"; do
  case "$platform" in
    ios) DEST='generic/platform=iOS'; OPTIONS=app/Config/ExportOptions-iOS.plist ;;
    macos) DEST='generic/platform=macOS'; OPTIONS=app/Config/ExportOptions-MAS.plist ;;
  esac
  ARCHIVE="$WORK/CrocApp-$platform.xcarchive"
  EXPORT="$WORK/export-$platform"

  if ! ( cd app && xcodebuild -scheme CrocApp -configuration Release \
      -destination "$DEST" -derivedDataPath "$WORK/dd" \
      -archivePath "$ARCHIVE" -allowProvisioningUpdates archive ) > "$WORK/archive-$platform.log" 2>&1; then
    tail -n 40 "$WORK/archive-$platform.log" >&2
    echo "error: $platform archive failed, full log: $WORK/archive-$platform.log" >&2
    exit 1
  fi
  echo "$platform archive: OK"

  cp "$OPTIONS" "$WORK/options-$platform.plist"
  [ "$UPLOAD" = 1 ] && plutil -replace destination -string upload "$WORK/options-$platform.plist"

  if ! xcodebuild -exportArchive -archivePath "$ARCHIVE" \
      -exportOptionsPlist "$WORK/options-$platform.plist" \
      -exportPath "$EXPORT" -allowProvisioningUpdates > "$WORK/export-$platform.log" 2>&1; then
    tail -n 40 "$WORK/export-$platform.log" >&2
    echo "error: $platform export failed, full log: $WORK/export-$platform.log" >&2
    exit 1
  fi
  if [ "$UPLOAD" = 1 ]; then
    echo "APPSTORE-UPLOAD-OK $platform"
  else
    ls "$EXPORT"
    echo "APPSTORE-EXPORT-OK $platform"
  fi
done
