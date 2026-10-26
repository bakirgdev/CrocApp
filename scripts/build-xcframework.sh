#!/usr/bin/env bash
# Builds CrocKit/Croc.xcframework from crocmobile via gomobile.
#
# Requires: Go >= 1.27.3 (go.mod pin; brew install go), Xcode 27 (.xcode-version).
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
# -trimpath and "-s -w" (no Go symbol table or DWARF) halve the static archive
# and shrink an unsigned `xcodebuild build`. Xcode strips an archive anyway, so
# a shipped app barely changes (docs/BUILDING.md, "What build-xcframework.sh does").
# -tags croc_no_tailcat builds croc without Tailcat (its peer-to-peer data path,
# which pulls in Tailscale and gVisor): the shipped executable halves, and `auto`
# transport means the relay and the LAN. Every other Go build of crocmobile (the
# harnesses' croctest, CI, golangci-lint) carries the same tag, so what is tested
# is what ships.
gomobile bind \
  -target ios,iossimulator,macos/arm64 \
  -iosversion 26.0 -macosversion 26.0 \
  -trimpath -ldflags "-s -w" -tags croc_no_tailcat \
  -o "../$OUT" \
  .
cd ..
echo "built $OUT:"
ls "$OUT"
