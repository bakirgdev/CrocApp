#!/usr/bin/env bash
# Recomputes every contrast ratio design/colors.md claims, from design/tokens.css.
#
# The Contrast table and the seven rules under it are the binding part of the
# design system. They were hand-computed once; this makes them checkable. Edit a
# green step, run this, find out immediately which rule you just broke.
#
#   scripts/verify-contrast.sh           # table + pass/fail, exit 1 on drift
#   scripts/verify-contrast.sh --quiet   # exit code only
#
# Values come from design/tokens.css, never from a web copy. Ratios are WCAG 2.x
# relative luminance, alpha composited onto the surface underneath. Pure bash and
# awk on purpose: no toolchain, so CI can run it on a bare runner.
set -euo pipefail
cd "$(dirname "$0")/.."

QUIET=0
case "${1-}" in
  --quiet) QUIET=1 ;;
  "") ;;
  *) echo "usage: $0 [--quiet]" >&2; exit 2 ;;
esac

TOKENS=design/tokens.css
[ -r "$TOKENS" ] || { echo "FAIL: $TOKENS not readable" >&2; exit 2; }

# Two tables, piped to awk on stdin because a literal newline cannot travel
# through `awk -v`. Above the marker: every row design/colors.md asserts, as
# theme|foreground|background stack|expected. The stack composites front to
# back, so a translucent tint names the opaque surface under it — keep it and
# the markdown table in step. Below the marker: rules that must hold whatever
# the values are, as label|theme|foreground|stack|min or max|threshold. Below
# the second marker: alias rules, label|theme|token|target, true when the token
# resolves to the same color as the target in that theme. The focus ring bands
# (rule 7) are parsed from --shadow-focus-ring in the END block.
TABLES='
light|--color-accent|--color-surface-base|3.41
light|--color-accent|--color-surface-grouped|3.06
light|--color-accent|--color-accent-tint>--color-surface-base|2.99
light|--color-accent-text|--color-surface-base|4.94
light|--color-accent-text|--color-surface-grouped|4.42
light|--color-accent-text|--color-accent-tint>--color-surface-base|4.32
light|--color-accent-text|--color-surface-card|4.94
light|--color-accent-text-on-tint|--color-surface-base|7.36
light|--color-accent-text-on-tint|--color-surface-grouped|6.60
light|--color-accent-text-on-tint|--color-accent-tint>--color-surface-base|6.45
light|--label-2|--color-surface-base|3.44
light|--label-2-web|--color-surface-base|5.16
light|--label-2-web|--color-surface-grouped|4.85
light|--color-text-secondary|--color-accent-tint>--color-surface-base|4.78
light|--label-3|--color-surface-base|1.73
light|--color-on-accent|--color-accent|3.41
light|--color-on-status|--color-status-error|3.55
light|--color-status-success|--color-status-success-tint>--color-surface-base|1.98
light|--color-status-warning|--color-status-warning-tint>--color-surface-base|1.96
light|--color-status-error|--color-status-error-tint>--color-surface-base|2.94
light|--color-status-success|--color-surface-base|2.22
light|--color-status-warning|--color-surface-base|2.20
light|--color-status-error|--color-surface-base|3.55
light|--color-status-info|--color-surface-base|4.02
light|--glass-tint-accent|--color-surface-base|1.14
dark|--color-accent|--color-surface-base|9.44
dark|--color-accent|--color-surface-card|7.65
dark|--color-accent|--color-accent-tint>--color-surface-base|7.72
dark|--color-on-accent|--color-accent|7.19
dark|--color-on-status|--color-status-error|3.41
dark|--label-2|--color-surface-base|6.36
dark|--color-status-success|--color-status-success-tint>--color-surface-base|8.05
dark|--color-status-warning|--color-status-warning-tint>--color-surface-base|7.93
dark|--color-status-error|--color-status-error-tint>--color-surface-base|5.25
dark|--color-status-info|--color-status-info-tint>--color-surface-base|4.92
== invariants ==
accent fill clears 3:1 on base|light|--color-accent|--color-surface-base|min|3.0
accent-text clears AA on base|light|--color-accent-text|--color-surface-base|min|4.5
accent-text-on-tint clears AA on grouped|light|--color-accent-text-on-tint|--color-surface-grouped|min|4.5
accent-text-on-tint clears AA on tint|light|--color-accent-text-on-tint|--color-accent-tint>--color-surface-base|min|4.5
web secondary clears AA on grouped|light|--label-2-web|--color-surface-grouped|min|4.5
filled prominent clears 3:1|light|--color-on-accent|--color-accent|min|3.0
filled destructive clears 3:1, light|light|--color-on-status|--color-status-error|min|3.0
filled destructive clears 3:1, dark|dark|--color-on-status|--color-status-error|min|3.0
focus ring outer band clears 3:1 on base|light|--color-accent|--color-surface-base|min|3.0
focus ring inner band clears 3:1 on the accent fill|light|--color-surface-base|--color-accent|min|3.0
tertiary is NOT a usable text color|light|--label-3|--color-surface-base|max|3.0
secondary text clears AA on the accent tint (rule 4)|light|--color-text-secondary|--color-accent-tint>--color-surface-base|min|4.5
accent-text clears AA on a card|light|--color-accent-text|--color-surface-card|min|4.5
the accent tint is NOT a visible focus indicator (rule 7)|light|--glass-tint-accent|--color-surface-base|max|1.5
dark status success clears AA on its own tint|dark|--color-status-success|--color-status-success-tint>--color-surface-base|min|4.5
dark status warning clears AA on its own tint|dark|--color-status-warning|--color-status-warning-tint>--color-surface-base|min|4.5
dark status error clears AA on its own tint|dark|--color-status-error|--color-status-error-tint>--color-surface-base|min|4.5
dark status info clears AA on its own tint|dark|--color-status-info|--color-status-info-tint>--color-surface-base|min|4.5
== aliases ==
rule 4: secondary text is label-2-web, light|light|--color-text-secondary|--label-2-web
rule 4: secondary text is label-2-web, dark|dark|--color-text-secondary|--label-2-web
rule 6: link is accent-text, light|light|--color-text-link|--color-accent-text
rule 6: link is accent-text, dark|dark|--color-text-link|--color-accent-text
dark accent collapses to green-400|dark|--color-accent|--green-400
dark accent-text collapses to green-400|dark|--color-accent-text|--green-400
dark accent-text-on-tint collapses to green-400|dark|--color-accent-text-on-tint|--green-400
'

printf '%s\n' "$TABLES" | awk -v quiet="$QUIET" -v tokens="$TOKENS" '
function die(msg) { print "FAIL: " msg > "/dev/stderr"; exit_code = 2; exit 2 }

function trim(s) { sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s }

# Split on top-level commas only, so a nested rgba(...) survives intact.
function split_top(s, out,   i, ch, depth, cur, n) {
  depth = 0; cur = ""; n = 0
  for (i = 1; i <= length(s); i++) {
    ch = substr(s, i, 1)
    if (ch == "(") depth++
    else if (ch == ")") depth--
    if (ch == "," && depth == 0) { out[++n] = trim(cur); cur = "" }
    else cur = cur ch
  }
  out[++n] = trim(cur)
  return n
}

function hex2dec(h,   i, c, d, n) {
  n = 0
  for (i = 1; i <= length(h); i++) {
    c = tolower(substr(h, i, 1))
    d = index("0123456789abcdef", c) - 1
    if (d < 0) die("bad hex digit in " h)
    n = n * 16 + d
  }
  return n
}

# Returns "r g b a".
function parse_color(v, theme, depth,   args, n, inner, hex, parts, cnt, a) {
  v = trim(v)
  if (depth > 16) die("token recursion too deep at " v)

  if (v ~ /^light-dark\(/) {
    inner = substr(v, 12, length(v) - 12)
    n = split_top(inner, args)
    if (n != 2) die("light-dark() needs 2 arguments: " v)
    return parse_color(args[theme == "light" ? 1 : 2], theme, depth + 1)
  }

  if (v ~ /^var\(/) {
    inner = trim(substr(v, 5, length(v) - 5))
    return resolve(inner, theme, depth + 1)
  }

  if (v ~ /^#[0-9a-fA-F]+$/) {
    hex = substr(v, 2)
    if (length(hex) != 6) die("only 6-digit hex is supported: " v)
    return hex2dec(substr(hex, 1, 2)) " " hex2dec(substr(hex, 3, 2)) " " hex2dec(substr(hex, 5, 2)) " 1"
  }

  if (v ~ /^rgba?\(/) {
    inner = v
    sub(/^rgba?\(/, "", inner); sub(/\)$/, "", inner)
    cnt = split_top(inner, parts)
    if (cnt < 3 || cnt > 4) die("rgb()/rgba() needs 3 or 4 arguments: " v)
    a = (cnt == 4) ? parts[4] + 0 : 1
    return (parts[1] + 0) " " (parts[2] + 0) " " (parts[3] + 0) " " a
  }

  die("cannot parse color " v)
}

function resolve(name, theme, depth) {
  if (!(name in VAL)) die(name " is not defined in design/tokens.css")
  return parse_color(VAL[name], theme, depth)
}

# Source-over. bg is opaque by the time this runs.
function composite(fg, bg,   f, b, a, i, out) {
  split(fg, f, " "); split(bg, b, " ")
  a = f[4]
  out = ""
  for (i = 1; i <= 3; i++) out = out (f[i] * a + b[i] * (1 - a)) " "
  return out "1"
}

# Resolve a background stack (front to back, ">"-separated) to one opaque color.
function flatten(stack, theme,   names, n, i, result, layer, c) {
  n = split(stack, names, ">")
  result = resolve(names[n], theme, 0)
  split(result, c, " ")
  if (c[4] + 0 < 1) die("bottom of stack " names[n] " is not opaque")
  for (i = n - 1; i >= 1; i--) {
    layer = resolve(names[i], theme, 0)
    result = composite(layer, result)
  }
  return result
}

function channel(v) {
  v /= 255
  return (v <= 0.03928) ? v / 12.92 : ((v + 0.055) / 1.055) ^ 2.4
}

function luminance(col,   c) {
  split(col, c, " ")
  return 0.2126 * channel(c[1]) + 0.7152 * channel(c[2]) + 0.0722 * channel(c[3])
}

function measure(theme, fg_name, stack,   bg, fg, f, la, lb, hi, lo) {
  bg = flatten(stack, theme)
  fg = resolve(fg_name, theme, 0)
  split(fg, f, " ")
  if (f[4] + 0 < 1) fg = composite(fg, bg)
  la = luminance(fg); lb = luminance(bg)
  hi = (la > lb) ? la : lb
  lo = (la > lb) ? lb : la
  return (hi + 0.05) / (lo + 0.05)
}

# Rule 7: --shadow-focus-ring is two bands, the base surface inside (2px) and
# the accent outside (4px). The contrast rows prove each band reads against the
# other and the accent; this proves the token still is that ring.
function check_ring(   ring, n, bands, k, parts, np, spread, color, want_spread, want_color) {
  if (!("--shadow-focus-ring" in VAL)) { failures[++nfail] = "--shadow-focus-ring is not defined in design/tokens.css"; return }
  ring = VAL["--shadow-focus-ring"]
  n = split_top(ring, bands)
  if (n != 2) { failures[++nfail] = "--shadow-focus-ring must have exactly two bands, has " n; return }
  for (k = 1; k <= 2; k++) {
    want_spread = (k == 1) ? "2px" : "4px"
    want_color = (k == 1) ? "var(--color-surface-base)" : "var(--color-accent)"
    np = split(bands[k], parts, " ")
    spread = parts[4]; color = parts[np]
    if (np != 5 || parts[1] != "0" || parts[2] != "0" || parts[3] != "0" || spread != want_spread || color != want_color)
      failures[++nfail] = "--shadow-focus-ring band " k " is \"" bands[k] "\", rule 7 needs \"0 0 0 " want_spread " " want_color "\""
  }
}

BEGIN {
  TOLERANCE = 0.01
  section = "cases"
  width = 10

  # design/tokens.css -> VAL[--name] = raw value, comments stripped.
  body = ""
  while ((getline line < tokens) > 0) body = body line "\n"
  close(tokens)
  while (match(body, /\/\*/)) {
    head = substr(body, 1, RSTART - 1)
    rest = substr(body, RSTART + 2)
    if (!match(rest, /\*\//)) { body = head; break }
    body = head substr(rest, RSTART + 2)
  }
  # Hand-rolled split: BSD awk also breaks split(s, a, ";") on newlines, which
  # truncates multi-line values such as --shadow-focus-ring.
  n = 0
  while ((p = index(body, ";")) > 0) { decls[++n] = substr(body, 1, p - 1); body = substr(body, p + 1) }
  decls[++n] = body
  for (i = 1; i <= n; i++) {
    d = trim(decls[i])
    if (d !~ /^--[a-z0-9-]+[ \t]*:/) continue
    p = index(d, ":")
    name = trim(substr(d, 1, p - 1))
    if (!(name in VAL)) VAL[name] = trim(substr(d, p + 1))
  }
}

trim($0) == "" { next }
trim($0) == "== invariants ==" { section = "invariants"; next }
trim($0) == "== aliases ==" { section = "aliases"; next }

section == "cases" {
  split($0, f, "|")
  ncase++
  ctheme[ncase] = f[1]; cfg[ncase] = f[2]; cstack[ncase] = f[3]; cwant[ncase] = f[4] + 0
  if (length(f[2]) > width) width = length(f[2])
  next
}

section == "aliases" {
  split($0, f, "|")
  nalias++
  alabel[nalias] = f[1]; atheme[nalias] = f[2]; atoken[nalias] = f[3]; atarget[nalias] = f[4]
  next
}

{
  split($0, f, "|")
  ninvariant++
  ilabel[ninvariant] = f[1]; itheme[ninvariant] = f[2]; ifg[ninvariant] = f[3]
  istack[ninvariant] = f[4]; ikind[ninvariant] = f[5]; ithreshold[ninvariant] = f[6] + 0
}

END {
  if (!quiet) printf "%-6s %-*s %-46s %6s %6s\n", "theme", width, "foreground", "on", "got", "doc"

  for (i = 1; i <= ncase; i++) {
    got = measure(ctheme[i], cfg[i], cstack[i])
    on = cstack[i]; gsub(/>/, " over ", on)
    drift = (got - cwant[i] < -TOLERANCE || got - cwant[i] > TOLERANCE)
    if (drift) failures[++nfail] = ctheme[i] ": " cfg[i] " on " on " is " sprintf("%.2f", got) ", colors.md says " sprintf("%.2f", cwant[i])
    if (!quiet) printf "%-6s %-*s %-46s %6.2f %6.2f%s\n", ctheme[i], width, cfg[i], on, got, cwant[i], drift ? "  <-- drift" : ""
  }

  for (i = 1; i <= ninvariant; i++) {
    got = measure(itheme[i], ifg[i], istack[i])
    ok = (ikind[i] == "min") ? (got >= ithreshold[i]) : (got <= ithreshold[i])
    if (!ok) failures[++nfail] = "invariant broken: " ilabel[i] " (" sprintf("%.2f", got) " is " (ikind[i] == "min" ? "below " : "above ") sprintf("%.2f", ithreshold[i]) ")"
  }

  for (i = 1; i <= nalias; i++) {
    if (resolve(atoken[i], atheme[i], 0) != resolve(atarget[i], atheme[i], 0))
      failures[++nfail] = "alias rule broken: " alabel[i] " (" atoken[i] " no longer resolves to " atarget[i] ")"
  }

  check_ring()

  if (!quiet) printf "\n%d documented ratios, %d invariants, %d alias rules, %d focus-ring bands\n", ncase, ninvariant, nalias, 2

  if (nfail) {
    print "\nFAIL"
    for (i = 1; i <= nfail; i++) print "  " failures[i]
    print "\nUpdate design/colors.md, or revert the token change."
    exit 1
  }

  if (!quiet) print "OK: the " ncase " ratios equal the values recorded here (the colors.md Contrast table), and the " ninvariant " invariants, " nalias " alias rules and focus-ring bands hold for design/tokens.css"
}
'
