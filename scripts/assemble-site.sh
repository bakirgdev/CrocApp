#!/usr/bin/env bash
# Assembles the GitHub Pages artifact: web/landing/ at the root, design/tokens.css
# beside it (the only copy that ships), the built Docusaurus site under /docs.
#
#   scripts/assemble-site.sh [out-dir]      # default _site
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"

command -v pnpm > /dev/null || fail "pnpm not installed (corepack enable pnpm)"

OUT="${1:-_site}"
case "$OUT" in
  "" | / | . | .. | */..)
    fail "refusing to wipe '$OUT'"
    ;;
esac
rm -rf "$OUT"
mkdir -p "$OUT"

cp -R web/landing/. "$OUT/"
cp design/tokens.css "$OUT/tokens.css"

test -s "$OUT/CNAME" || fail "CNAME missing from $OUT"

pnpm --dir web/docs install --frozen-lockfile
pnpm --dir web/docs run build
mkdir -p "$OUT/docs"
cp -R web/docs/build/. "$OUT/docs/"

test -s "$OUT/index.html" || fail "no landing index.html in $OUT"
test -s "$OUT/404.html" || fail "no landing 404.html in $OUT"
# A dot-path, so it only survives to production while github-pages.yml keeps
# include-hidden-files: true. SECURITY.md hands this address out.
test -s "$OUT/.well-known/security.txt" || fail "no security.txt in $OUT"
# Same dot-path rule. Universal links need both app IDs served from here.
test -s "$OUT/.well-known/apple-app-site-association" || fail "no apple-app-site-association in $OUT"
for id in HBSU359M33.com.bakirgdev.CrocApp HBSU359M33.com.bakirgdev.CrocApp.direct; do
  grep -q "\"$id\"" "$OUT/.well-known/apple-app-site-association" || {
    fail "AASA lacks $id"
  }
done
# The code stays in the fragment, so the page must not leak it by referrer
# or load anything remote.
test -s "$OUT/r/index.html" || fail "no /r/ page in $OUT"
grep -q '<meta name="referrer" content="no-referrer"' "$OUT/r/index.html" || fail "/r/ lacks the no-referrer policy"
if tr '\n' ' ' < "$OUT/r/index.html" | grep -Eiq "<(script|link|img|iframe)[^>]*(src|href)=[\"']?(https?:)?//"; then
  fail "/r/ loads a remote resource"
fi
test -s "$OUT/docs/index.html" || fail "no docs index.html in $OUT/docs"

echo "assembled $OUT:"
ls "$OUT"
