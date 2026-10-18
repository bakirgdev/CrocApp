#!/usr/bin/env bash
# Single source of truth for the Swift source set swift-format touches. CI, the
# PR template and the docs all call this, so a new target is added here once
# instead of in five places.
#
#   scripts/format-swift.sh            # rewrite in place, then lint
#   scripts/format-swift.sh --lint     # lint only, no writes -- what CI runs
#
# The paths are listed file-by-file rather than as `CrocKit`, because a
# recursive run there would descend into .build/ and Croc.xcframework/.
set -euo pipefail
cd "$(dirname "$0")/.."

PATHS=(app/CrocApp app/CrocAppDirect app/CrocShare app/CrocAppTests CrocKit/Sources CrocKit/Tests CrocKit/Package.swift
  scripts/screenshots)

LINT_ONLY=0
case "${1-}" in
  --lint) LINT_ONLY=1 ;;
  "") ;;
  *) echo "usage: $0 [--lint]" >&2; exit 2 ;;
esac

command -v xcrun >/dev/null || { echo "error: xcrun not found (needs the Xcode toolchain)" >&2; exit 1; }

if [ "$LINT_ONLY" -eq 0 ]; then
  xcrun swift-format format --in-place --recursive --parallel "${PATHS[@]}"
fi

# Always lint after formatting: several enabled rules only flag and never
# rewrite, so a clean format run is not evidence this will pass.
xcrun swift-format lint --recursive --parallel --strict "${PATHS[@]}"
echo "PASS: swift-format lint --strict"
