#!/usr/bin/env bash
# Developer ID distribution groundwork (Phase 4):
#   archive -> Developer ID export -> syspolicy_check notarization pre-check.
# Degrades to DEVID-PENDING-CERT when no "Developer ID Application" identity
# is installed (creating one is a human action in PLAN.md).
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE=/tmp/crocapp-devid/CrocApp.xcarchive
EXPORT=/tmp/crocapp-devid/export
rm -rf /tmp/crocapp-devid

( cd app && xcodebuild -scheme CrocApp -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" archive ARCHS=arm64 ) > /tmp/devid-archive.log 2>&1
echo "archive: OK"

if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "No Developer ID Application identity installed."
  echo "Create one at developer.apple.com (Certificates > Developer ID Application),"
  echo "install it in the login keychain, then re-run this script."
  echo DEVID-PENDING-CERT
  exit 0
fi

( cd app && xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist Config/ExportOptions-DevID.plist \
    -exportPath "$EXPORT" ) > /tmp/devid-export.log 2>&1
APP=$(find "$EXPORT" -name "CrocApp.app" -maxdepth 2 | head -1)
codesign --verify --strict --deep "$APP"
echo DEVID-EXPORT-OK

# Notarization dry-run: Apple's pre-submission checker catches signing /
# entitlement / hardened-runtime problems that notarization or Gatekeeper
# would reject. (Real notarytool submission is release engineering, Phase 7.)
syspolicy_check distribution "$APP" && echo DEVID-CHECK-OK
