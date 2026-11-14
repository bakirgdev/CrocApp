#!/usr/bin/env bash
# Checks the web design rules a machine can keep (design/principles.md, "Web").
# The app uses system styles and is not checked here.
#
#   1. No raw colors in the landing page and docs site sources: hex, rgb() or
#      hsl() functions and named colors. Write a token from design/tokens.css.
#   2. The theme-color literals (landing pages, docusaurus.config.ts,
#      site.webmanifest) equal --bg-base in light and dark. Browser chrome
#      cannot read a custom property, so these are the only literals allowed.
#
#   scripts/verify-design.sh   # findings as path:line: message, exit 1 on any
#
# Needs bash and perl only, so CI runs it on a bare runner.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"

TOKENS=design/tokens.css
MANIFEST=web/landing/assets/img/favicon/site.webmanifest
status=0
finding() {
  echo "$*"
  status=1
}

# 1. Comments are blanked first (line numbers survive), and an HTML page is
# checked only on its style= lines, so `href="#bad"` is not a color. The
# character classes around a match keep `white-space` and `#id` selectors out.
NAMED='white|black|gray|grey|silver|red|green|blue|orange|yellow|purple|pink|brown|navy|teal|olive|cyan|magenta|gold|khaki'
raw_colors() { # raw_colors FILE
  perl -0pe 's{/\*.*?\*/}{"\n" x ($& =~ tr/\n//)}gse; s{(^|\s)//[^\n]*}{$1}g' "$1" \
    | { case $1 in *.html) sed '/style=/!s/.*//' ;; *) cat ;; esac } \
    | grep -nE "(^|[^[:alnum:]_&-])#[0-9A-Fa-f]{3,8}([^[:alnum:]_-]|$)|(^|[^[:alnum:]_-])(rgba?|hsla?|hwb|oklch|oklab|lab|lch)\(|(^|[^[:alnum:]_.#-])($NAMED)([^[:alnum:]_(-]|$)" \
    | grep -v 'theme-color' | sed "s|^\([0-9]*\):|$1:\1: raw color, use a token: |" | cut -c1-180 || true
}
while IFS= read -r f; do
  out=$(raw_colors "$f")
  [ -z "$out" ] || finding "$out"
done < <(git ls-files web/landing web/docs/src | grep -E '\.(css|js|ts|tsx|html)$')

# 2. Every literal below must equal --bg-base.
read -r LIGHT DARK < <(sed -nE 's/^ *--bg-base: *light-dark\((#[0-9A-Fa-f]{6}), *(#[0-9A-Fa-f]{6})\);.*/\1 \2/p' "$TOKENS" | tr a-f A-F)
[ -n "${LIGHT-}" ] || fail "--bg-base is not a light-dark() pair of hex colors in $TOKENS"
while IFS= read -r f; do
  for t in light dark; do
    want=$LIGHT
    [ "$t" = dark ] && want=$DARK
    got=$(sed -nE "s/.*name=\"theme-color\" content=\"(#[0-9A-Fa-f]{6})\" media=\"\(prefers-color-scheme: $t\)\".*/\1/p" "$f" | tr a-f A-F)
    [ "$got" = "$want" ] || finding "$f: theme-color for $t is '${got:-missing}', --bg-base is $want"
  done
done < <(grep -rl 'name="theme-color"' web/landing --include='*.html')
got=$(grep -oE "content: '#[0-9A-Fa-f]{6}'" web/docs/docusaurus.config.ts | grep -oE '#[0-9A-Fa-f]{6}' | tr a-f A-F | tr '\n' ' ')
[ "$got" = "$LIGHT $DARK " ] || finding "web/docs/docusaurus.config.ts: theme-color literals are '$got', want light then dark: '$LIGHT $DARK '"
for k in theme_color background_color; do
  got=$(sed -nE "s/.*\"$k\": *\"(#[0-9A-Fa-f]{6})\".*/\1/p" "$MANIFEST" | tr a-f A-F)
  [ "$got" = "$LIGHT" ] || finding "$MANIFEST: $k is '${got:-missing}', --bg-base in light is $LIGHT"
done

if [ "$status" -ne 0 ]; then
  echo "FAIL: fix the code, or change the rule in design/ with it. Never weaken the check." >&2
  exit 1
fi
echo "OK: no raw colors in web code, theme-color literals match --bg-base"
