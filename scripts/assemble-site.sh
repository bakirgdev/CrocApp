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
test -s "$OUT/404.html"        || { echo "error: no landing 404.html in $OUT" >&2; exit 1; }
# A dot-path, so it only survives to production while github-pages.yml keeps
# include-hidden-files: true. SECURITY.md hands this address out.
test -s "$OUT/.well-known/security.txt" || { echo "error: no security.txt in $OUT" >&2; exit 1; }
# Same dot-path rule. Universal links need both app IDs served from here.
test -s "$OUT/.well-known/apple-app-site-association" || { echo "error: no apple-app-site-association in $OUT" >&2; exit 1; }
for id in HBSU359M33.com.bakirgdev.CrocApp HBSU359M33.com.bakirgdev.CrocApp.direct; do
  grep -q "\"$id\"" "$OUT/.well-known/apple-app-site-association" || { echo "error: AASA lacks $id" >&2; exit 1; }
done
# The code stays in the fragment, so the page must not leak it by referrer
# or load anything remote.
test -s "$OUT/r/index.html" || { echo "error: no /r/ page in $OUT" >&2; exit 1; }
grep -q '<meta name="referrer" content="no-referrer"' "$OUT/r/index.html" || { echo "error: /r/ lacks the no-referrer policy" >&2; exit 1; }
if tr '\n' ' ' < "$OUT/r/index.html" | grep -Eiq "<(script|link|img|iframe)[^>]*(src|href)=[\"']?(https?:)?//"; then
  echo "error: /r/ loads a remote resource" >&2; exit 1
fi
test -s "$OUT/docs/index.html" || { echo "error: no docs index.html in $OUT/docs" >&2; exit 1; }

echo "assembled $OUT:"
ls "$OUT"
