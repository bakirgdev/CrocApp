#!/usr/bin/env bash
# Builds CrocKit/Croc.xcframework from crocmobile via gomobile.
#
# Requires: Go >= 1.26.5 (go.mod pin; brew install go), Xcode 26+.
# gomobile and gobind come from the `tool` directives in crocmobile/go.mod, so
# there is one x/mobile version in the repo and dependabot can see it.
#
# macOS slice is arm64-only: golang/go#73119 (multi-arch macos bind broken).
# iOS device slice layout issue golang/go#66500 affects App Store archives,
# not simulator/dev builds — revisit before the first store submission.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v go >/dev/null || { echo "error: go not installed (brew install go)"; exit 1; }

# Rebuilt every run rather than skipped when already present: the old "install
# only if missing" check is what let a stale binary outlive its pin. Go's build
# cache makes the repeat cost nothing. First on PATH, not appended, because
# gomobile shells out to gobind by looking it up there.
TOOLS="$PWD/.tools"
(cd crocmobile && go build -o "$TOOLS/" golang.org/x/mobile/cmd/gomobile golang.org/x/mobile/cmd/gobind)
export PATH="$TOOLS:$PATH"

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
