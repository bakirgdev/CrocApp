#!/usr/bin/env bash
# Builds CrocKit/Croc.xcframework from crocmobile via gomobile.
#
# Requires: Go >= 1.27.3 (go.mod pin; brew install go), Xcode 26+.
# gomobile and gobind come from the `tool` directives in crocmobile/go.mod, so
# there is one x/mobile version in the repo. Dependabot does not bump it (tool
# requirements are `// indirect`): bump by hand with
# `go get tool` in crocmobile/.
#
# macOS slice is arm64-only: golang/go#73119 (multi-arch macos bind broken).
# The framework Info.plist keeps gomobile's MinimumOSVersion = 100.0 (an SPM
# workaround in x/mobile); App Store Connect accepted it on the first upload.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v go >/dev/null || { echo "error: go not installed (brew install go)" >&2; exit 1; }

# Rebuilt every run, never skipped when present: an "install only if missing"
# check is what lets a stale binary outlive its pin, and Go's build cache makes
# the repeat free. Prepended to PATH, not appended, because gomobile shells out
# to gobind by looking it up there.
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
