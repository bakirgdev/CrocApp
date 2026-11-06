#!/usr/bin/env bash
# Runs the Swift unit suites: CrocKit (`swift test`) and the app (`xcodebuild
# test`, scheme CrocApp, on this Mac). Run it before pushing a Swift change;
# CI runs the same suites in the macOS leg of `build`.
#
#   scripts/verify-swift.sh     # exit 0 when both suites pass
#
# Both suites link CrocKit/Croc.xcframework. It is rebuilt (all slices) when it
# is missing, has no macOS slice, or is older than anything in crocmobile/ or
# scripts/build-xcframework.sh; otherwise the existing one is reused, which
# keeps a warm run to seconds. No network, no transfers: a green run is not a
# working transfer (docs/BUILDING.md, "Verification harnesses").
#
# Requires: Xcode 27 (.xcode-version), Go (only when the xcframework is rebuilt).
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh

help_flag "$@"
[ $# -eq 0 ] || fail "unknown argument '$1' (try --help)"

LOGS="$TMPROOT/verify-swift"
mkdir -p "$LOGS"

ensure_xcframework "$LOGS/xcframework.log"

logged "$LOGS/crockit.log" swift test --package-path CrocKit -Xswiftc -warnings-as-errors
pass "CrocKit tests ($(grep -Eo 'Test run with [0-9]+ tests' "$LOGS/crockit.log" | tail -n 1))"

# Own DerivedData, so the flags here never invalidate Xcode's own build.
logged "$LOGS/app.log" xcodebuild test -project app/CrocApp.xcodeproj -scheme CrocApp \
  -destination platform=macOS -derivedDataPath "$(derived_data verify-swift)" \
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES
pass "CrocApp tests"
