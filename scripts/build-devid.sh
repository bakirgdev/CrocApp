#!/usr/bin/env bash
# Developer ID distribution of the `CrocApp Direct` target: archive, export,
# disk image, notarize, staple. release.yml runs this same script, so a local
# run is the CI path minus the temporary keychain.
#
#   scripts/build-devid.sh [out-dir]
#
# Writes <out-dir>/CrocApp-<version>-arm64.dmg (default out-dir: dist), signed,
# notarized and stapled. The version is MARKETING_VERSION in
# app/Config/Version.xcconfig.
#
# Needs, in the keychain search list:
#   - a "Developer ID Application" identity for team HBSU359M33
#   - the "CrocApp Direct Developer ID" provisioning profile, installed in
#     ~/Library/Developer/Xcode/UserData/Provisioning Profiles/
#
# Notary credentials, one of:
#   - NOTARY_KEY (path to the App Store Connect .p8), NOTARY_KEY_ID and
#     NOTARY_ISSUER (CI)
#   - NOTARY_KEYCHAIN_PROFILE, a `notarytool store-credentials` profile,
#     default crocapp-notary (local)
#
# DEVID_WORK sets the scratch directory (archive, DerivedData, logs). Sparkle's
# generate_appcast ends up under $DEVID_WORK/dd/SourcePackages/artifacts.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"

OUT=${1:-dist}
WORK="${DEVID_WORK:-$TMPROOT/crocapp-devid}"
ARCHIVE="$WORK/CrocApp.xcarchive"
EXPORT="$WORK/export"
IDENTITY="Developer ID Application"
PROFILE="CrocApp Direct Developer ID"
TEAM=HBSU359M33

if [ -n "${NOTARY_KEY:-}" ]; then
  NOTARY_AUTH=(--key "$NOTARY_KEY" --key-id "${NOTARY_KEY_ID:?NOTARY_KEY_ID must be set with NOTARY_KEY}" --issuer "${NOTARY_ISSUER:?NOTARY_ISSUER must be set with NOTARY_KEY}")
else
  NOTARY_AUTH=(--keychain-profile "${NOTARY_KEYCHAIN_PROFILE:-crocapp-notary}")
fi

# By SHA-1, so a second Developer ID identity in the search list cannot be
# picked instead.
SIGNER=$(security find-identity -v -p codesigning \
  | awk -v id="\"$IDENTITY: " -v team="($TEAM)\"" 'index($0, id) && index($0, team) { print $2; exit }')
[ -n "$SIGNER" ] || fail "no \"$IDENTITY\" identity for team $TEAM in the keychain search list. Create one at developer.apple.com (Certificates > Developer ID Application) and install it."

VERSION=$(sed -nE 's/^MARKETING_VERSION = ([^ ]+)$/\1/p' app/Config/Version.xcconfig)
[ -n "$VERSION" ] || fail "no MARKETING_VERSION in app/Config/Version.xcconfig"

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"

# The profile is set on the CrocApp Direct target in the project, not here: a
# command-line setting would also reach CrocShare Direct, which has a different
# bundle ID and needs no profile (its team-prefixed App Group is not restricted).
# The export re-signs everything nested.
logged "$WORK/archive.log" xcodebuild -project app/CrocApp.xcodeproj -scheme 'CrocApp Direct' \
  -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$WORK/dd" \
  -archivePath "$ARCHIVE" archive ARCHS=arm64 \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$SIGNER" DEVELOPMENT_TEAM="$TEAM"
echo "archive: OK"

logged "$WORK/export.log" xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist app/Config/ExportOptions-DevID.plist -exportPath "$EXPORT"
APP="$EXPORT/CrocApp.app"
[ -d "$APP" ] || fail "no CrocApp.app in $EXPORT (see $WORK/export.log)"
codesign --verify --strict --deep "$APP"
echo DEVID-EXPORT-OK

# No `syspolicy_check notary-submission` here: on macOS 27 it fails every
# not-yet-notarized app ("Gatekeeper rejected this file", spctl source
# "Unnotarized Developer ID"). The notary log names any real problem.
notarize() {
  local file=$1 json status id
  json="$WORK/notary-$(basename "$file").json"
  # Status is checked from the JSON, not the exit code alone, and a failed
  # submit still reaches the log fetch below.
  xcrun notarytool submit "$file" "${NOTARY_AUTH[@]}" --wait --output-format json > "$json" || true
  cat "$json"
  echo
  status=$(plutil -extract status raw "$json" 2> /dev/null || echo "no status")
  if [ "$status" != "Accepted" ]; then
    if id=$(plutil -extract id raw "$json" 2> /dev/null); then
      xcrun notarytool log "$id" "${NOTARY_AUTH[@]}" >&2 || echo "warning: could not fetch the notary log for $id" >&2
    fi
    fail "notarization of $file: status '$status'"
  fi
}

# The app and the disk image are notarized separately, so each carries its own
# stapled ticket: an app copied out of the image opens offline on first launch,
# and `syspolicy_check distribution` only passes on a stapled app.
ditto -c -k --keepParent --sequesterRsrc "$APP" "$WORK/CrocApp.zip"
notarize "$WORK/CrocApp.zip"
xcrun stapler staple "$APP"
syspolicy_check distribution "$APP"
echo DEVID-APP-NOTARIZED-OK

scripts/build-dmg.sh "$APP" "$VERSION" "$OUT"
DMG="$OUT/CrocApp-$VERSION-arm64.dmg"
codesign --sign "$SIGNER" --timestamp "$DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl -a -vv -t open --context context:primary-signature "$DMG"
echo "dmg: $DMG"
echo DEVID-NOTARIZED-OK
