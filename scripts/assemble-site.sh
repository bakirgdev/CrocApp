#!/usr/bin/env bash
# Assembles the GitHub Pages artifact: web/landing/ at the root, design/tokens.css
# beside it (the only copy that ships), the built Docusaurus site under /docs.
#
#   scripts/assemble-site.sh [out-dir]      # default _site
set -euo pipefail
cd "$(dirname "$0")/.."

command -v pnpm >/dev/null || { echo "error: pnpm not installed (corepack enable pnpm)" >&2; exit 1; }

OUT="${1:-_site}"
case "$OUT" in
  ""|/|.|..|*/..) echo "error: refusing to wipe '$OUT'" >&2; exit 1 ;;
esac
rm -rf "$OUT"
mkdir -p "$OUT"

cp -R web/landing/. "$OUT/"
cp design/tokens.css "$OUT/tokens.css"

test -s "$OUT/CNAME" || { echo "error: CNAME missing from $OUT" >&2; exit 1; }

pnpm --dir web/docs install --frozen-lockfile
pnpm --dir web/docs run build
mkdir -p "$OUT/docs"
cp -R web/docs/build/. "$OUT/docs/"

test -s "$OUT/index.html"      || { echo "error: no landing index.html in $OUT" >&2; exit 1; }
test -s "$OUT/docs/index.html" || { echo "error: no docs index.html in $OUT/docs" >&2; exit 1; }

echo "assembled $OUT:"
ls "$OUT"
