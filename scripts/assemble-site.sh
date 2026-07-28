#!/usr/bin/env bash
# Assembles the complete crocapp.dev Pages artifact into _site/.
#
# GitHub Pages serves one site per repository and every deploy replaces the
# whole thing. Both .github/workflows/landing.yml and docs.yml therefore call
# this script: whichever one fires has to publish both surfaces, or it deletes
# the other. Keeping the assembly here means the two workflows cannot drift.
#
#   _site/        web/landing/ verbatim, plus design/tokens.css and CNAME
#   _site/docs/   Docusaurus build output, all locales
#
# Requires: pnpm (corepack enable pnpm). Usage: scripts/assemble-site.sh [outdir]
set -euo pipefail
cd "$(dirname "$0")/.."

command -v pnpm >/dev/null || { echo "error: pnpm not installed (corepack enable pnpm)"; exit 1; }

OUT="${1:-_site}"
rm -rf "$OUT"
mkdir -p "$OUT"

# Landing: no build step, it is hand-written static HTML. tokens.css is not
# committed under web/ (ADR 0015), so it lands here instead.
cp -R web/landing/. "$OUT/"
cp design/tokens.css "$OUT/tokens.css"

# Without CNAME the deploy falls back to bakirgdev.github.io/CrocApp and every
# absolute URL on both surfaces breaks.
test -s "$OUT/CNAME" || { echo "error: CNAME missing from $OUT"; exit 1; }

# Docs: baseUrl is /docs/, so the build output goes one level down verbatim.
pnpm --dir web/docs install --frozen-lockfile
pnpm --dir web/docs run build
mkdir -p "$OUT/docs"
cp -R web/docs/build/. "$OUT/docs/"

test -s "$OUT/index.html"      || { echo "error: no landing index.html in $OUT"; exit 1; }
test -s "$OUT/docs/index.html" || { echo "error: no docs index.html in $OUT/docs"; exit 1; }

echo "assembled $OUT:"
ls "$OUT"
