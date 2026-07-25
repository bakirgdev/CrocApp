#!/usr/bin/env bash
# Renders web/landing/og-card.html to web/landing/assets/img/og.jpg at 1200x630.
#
# The social card is the most-viewed brand asset there is — every share on HN,
# Reddit, X, Slack and iMessage renders it before anyone reads a word — so it is
# built from the same tokens as the page rather than drawn by hand. Re-run this
# whenever a colour or type token moves.
#
# Requires: a Chrome/Chromium binary, and sips (macOS, for the JPEG encode).
# No npm, no build step, consistent with PLAN.md §2.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="web/landing/assets/img/og.jpg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# og-card.html reads tokens.css the same way the page does, and it is gitignored
# under web/, so it has to be copied in before rendering.
cp design/tokens.css web/landing/tokens.css

CHROME="${CHROME:-}"
if [ -z "$CHROME" ]; then
  for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "$(command -v chromium || true)" \
    "$(command -v google-chrome || true)"; do
    if [ -x "$candidate" ]; then CHROME="$candidate"; break; fi
  done
fi
[ -n "$CHROME" ] || { echo "error: no Chrome binary found; set CHROME=/path/to/chrome"; exit 1; }

# --force-device-scale-factor=2 renders at 2400x1200 so the downscale to the
# 1200x630 JPEG is sharp rather than a 1:1 screenshot of antialiased text.
"$CHROME" \
  --headless \
  --disable-gpu \
  --hide-scrollbars \
  --force-device-scale-factor=2 \
  --window-size=1200,630 \
  --screenshot="$TMP/og.png" \
  --virtual-time-budget=4000 \
  "file://$PWD/web/landing/og-card.html" >/dev/null 2>&1

[ -s "$TMP/og.png" ] || { echo "error: chrome produced no screenshot"; exit 1; }

sips --resampleHeightWidth 630 1200 "$TMP/og.png" --out "$TMP/og-sized.png" >/dev/null
sips -s format jpeg -s formatOptions 82 "$TMP/og-sized.png" --out "$OUT" >/dev/null

echo "wrote $OUT"
sips -g pixelWidth -g pixelHeight "$OUT" | tail -2
ls -lh "$OUT" | awk '{print $5}'
