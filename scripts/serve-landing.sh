#!/usr/bin/env bash
# Serves web/landing/ locally on :8000, exactly as the Pages workflow assembles it.
#
# design/tokens.css is copied in rather than committed under web/ (ADR 0015):
# web/landing/tokens.css is gitignored, and .github/workflows/pages.yml does
# the same copy at deploy time. Re-run this script after editing tokens.
#
# PORT overrides the default port.
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-8000}"

cp design/tokens.css web/landing/tokens.css
echo "copied design/tokens.css -> web/landing/tokens.css"
echo "serving web/landing on http://localhost:$PORT"
exec python3 -m http.server "$PORT" --directory web/landing
