#!/usr/bin/env bash
# Builds CrocKit/Croc.xcframework from crocmobile via gomobile.
#
# Requires: Go >= 1.25 (brew install go), Xcode 26+.
# gomobile/gobind are auto-installed to $(go env GOPATH)/bin if missing.
#
# macOS slice is arm64-only: golang/go#73119 (multi-arch macos bind broken).
# iOS device slice layout issue golang/go#66500 affects App Store archives,
# not simulator/dev builds — revisit at release engineering (Phase 7).
set -euo pipefail
cd "$(dirname "$0")/.."

command -v go >/dev/null || { echo "error: go not installed (brew install go)"; exit 1; }
GOBIN="$(go env GOPATH)/bin"
export PATH="$PATH:$GOBIN"
command -v gomobile >/dev/null || go install golang.org/x/mobile/cmd/gomobile@latest
command -v gobind  >/dev/null || go install golang.org/x/mobile/cmd/gobind@latest

OUT="CrocKit/Croc.xcframework"
rm -rf "$OUT"
cd crocmobile
go mod download
gomobile bind \
  -target ios,iossimulator,macos/arm64 \
  -iosversion 26.0 -macosversion 26.0 \
  -o "../$OUT" \
  .
cd ..
echo "built $OUT:"
ls "$OUT"
