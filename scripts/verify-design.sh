#!/usr/bin/env bash
# shellcheck disable=SC2016  # awk programs and tables in single quotes: awk expands them, not the shell
# Enforces the three rules design/AGENTS.md leaves to a machine.
#
#   1. Mirror parity. design/tokens.css is canonical; DesignTokens.swift and the
#      asset catalog color sets are hand-written mirrors. Every shared value
#      must be equal in all three, every token must either be mirrored or
#      listed as deliberately not mirrored. The numeric half (spacing, radius,
#      control sizes, durations, curves) compares tokens.css with Swift
#      constants only, so it needs no value tables in the docs.
#   2. Contrast. Every ratio design/principles.md ("Contrast") claims is
#      recomputed from tokens.css (WCAG 2.x relative luminance, alpha
#      composited onto the surface underneath), and the contrast guidance holds
#      as invariants. Edit an olive step and this names the guidance you just
#      broke. The focus ring and the web manifest colors are checked too.
#   3. No raw colors in web code. Web CSS, HTML and scripts write color
#      tokens, not hex, rgb()/hsl() or named colors (design/implementation.md,
#      "Raw colors on web"). Swift is not linted: reviewers keep views on
#      tokens and text styles.
#
#   scripts/verify-design.sh           # findings as path:line: message, exit 1 on any
#   scripts/verify-design.sh --quiet   # findings and FAIL lines only, no OK lines
#
# Pure bash and awk on purpose: no toolchain, so CI runs it on a bare runner.
# Only POSIX awk features are used (BSD awk on macOS, mawk on the Ubuntu
# runner): no interval expressions, no gawk extensions.
# Exit 0 clean, 1 findings, 2 usage or unreadable input.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"

QUIET=0
case "${1-}" in
  --quiet) QUIET=1 ;;
  "") ;;
  *)
    echo "usage: $0 [--quiet]" >&2
    exit 2
    ;;
esac
export LC_ALL=C

TOKENS=design/tokens.css
SWIFT_TOKENS=app/CrocApp/Support/DesignTokens.swift
COLORSETS=app/CrocApp/Assets.xcassets
PRINCIPLES_MD=design/principles.md
MANIFEST=web/landing/assets/img/favicon/site.webmanifest
[ -r "$TOKENS" ] || {
  echo "FAIL: $TOKENS not readable" >&2
  exit 2
}
[ -r "$SWIFT_TOKENS" ] || {
  echo "FAIL: $SWIFT_TOKENS not readable" >&2
  exit 2
}
[ -r "$PRINCIPLES_MD" ] || {
  echo "FAIL: $PRINCIPLES_MD not readable" >&2
  exit 2
}
[ -r "$MANIFEST" ] || {
  echo "FAIL: $MANIFEST not readable" >&2
  exit 2
}
[ -d "$COLORSETS" ] || {
  echo "FAIL: $COLORSETS not a directory" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Parity table: numeric and curve tokens. token|Swift Enum.constant[|curve]
#
# Values compare after unit normalization: px is dropped, ms becomes seconds,
# cubic-bezier(a, b, c, d) is compared to .timingCurve(a, b, c, d, ...).
# Add a shared token here (or to the not-mirrored block) in the same commit
# that adds it to tokens.css: design/AGENTS.md -> Adding or removing a token.
# ---------------------------------------------------------------------------
NUMERIC_TABLE='
--space-1|Spacing.space1
--space-2|Spacing.space2
--space-3|Spacing.space3
--space-4|Spacing.space4
--space-5|Spacing.space5
--space-6|Spacing.space6
--space-7|Spacing.space7
--space-8|Spacing.space8
--space-9|Spacing.space9
--space-10|Spacing.space10
--space-11|Spacing.space11
--radius-xs|Radius.xs
--radius-sm|Radius.sm
--radius-md|Radius.md
--radius-lg|Radius.lg
--radius-xl|Radius.xl
--radius-2xl|Radius.xxl
--radius-capsule|Radius.capsule
--border-hairline|BorderWidth.hairline
--border-hairline-half|BorderWidth.hairlineHalf
--control-height-lg|ControlHeight.large
--control-height-md|ControlHeight.medium
--control-height-sm|ControlHeight.small
--hit-target-min|ControlHeight.hitTargetMin
--icon-size-sm|IconSize.small
--icon-size-md|IconSize.medium
--icon-size-lg|IconSize.large
--content-max-width|LayoutCap.contentMaxWidth
--opacity-disabled-container|Opacity.disabledContainer
--dur-fast|Motion.durationFast
--dur-base|Motion.durationBase
--dur-slow|Motion.durationSlow
--tracking-code|Tracking.code
--tracking-eyebrow|Tracking.eyebrow
--ease-out|Motion.easeOut|curve
--ease-standard|Motion.easeStandard|curve
'

# ---------------------------------------------------------------------------
# Parity table: color sets. ColorSetName|token. Each is resolved through
# var() and light-dark() for both themes and compared with the set's "any"
# (light) and "dark" appearances: 1/255 per channel, 0.01 alpha. A set with no
# dark appearance must have a token whose two themes are equal.
# ---------------------------------------------------------------------------
COLOR_TABLE='
AccentColor|--color-accent
ColorAccentSolid|--color-accent-solid
ColorAccentPressed|--color-accent-pressed
ColorAccentTint|--color-accent-tint
ColorAccentText|--color-accent-text
ColorAccentTextOnTint|--color-accent-text-on-tint
ColorOnAccent|--color-on-accent
ColorPaper|--paper
ColorTextSecondary|--color-text-secondary
ColorScrim|--color-scrim
ColorStatusSuccessTint|--color-status-success-tint
ColorStatusWarningTint|--color-status-warning-tint
ColorStatusErrorTint|--color-status-error-tint
ColorStatusInfoTint|--color-status-info-tint
'

# ---------------------------------------------------------------------------
# Not mirrored: shared token names (no `web` segment) the app deliberately has
# no Swift form for. One ERE per line, anchored. Source: design/implementation.md,
# "Not mirrored", plus the semantic aliases it routes to system semantics (text, status, surface, separator). A token that matches
# neither this block nor a table above fails the check, so a new shared token
# forces the mirror decision in the same commit.
# ---------------------------------------------------------------------------
NOT_MIRRORED='
^--(olive|khaki)-
^--sys-
^--label-
^--fill-
^--bg-
^--separator
^--glass-
^--blur-
^--color-surface-
^--color-glass-border$
^--shadow-
^--type-
^--weight-
^--font-
^--tracking-
^--icon-stroke
^--color-text-(primary|tertiary|quaternary|link)$
^--color-fill
^--color-separator$
^--color-on-status$
^--color-status-(success|warning|error|info)$
'

# ---------------------------------------------------------------------------
# Contrast table. Above the first marker: every row design/principles.md asserts,
# as theme|foreground|background stack|expected. The stack composites front to
# back, so a translucent tint names the opaque surface under it. Each expected
# ratio must also appear in the Contrast section of design/principles.md: keep
# the two in step. Below the first marker: rules that must hold whatever the values
# are, as label|theme|foreground|stack|min or max|threshold. Below the second
# marker: alias rules, label|theme|token|target, true when the token resolves
# to the same color as the target in that theme. The focus ring bands (rule 7)
# are parsed from --shadow-focus-ring, not listed here.
# ---------------------------------------------------------------------------
CONTRAST_TABLE='
light|--color-accent|--color-surface-base|4.06
light|--color-accent|--color-surface-grouped|3.63
light|--color-accent|--color-accent-tint>--color-surface-base|3.54
light|--color-accent-text|--color-surface-base|5.84
light|--color-accent-text|--color-surface-grouped|5.23
light|--color-accent-text|--color-accent-tint>--color-surface-base|5.09
light|--color-accent-text|--color-surface-card|5.84
light|--color-accent-text|--color-fill-tertiary>--color-surface-base|5.06
light|--color-accent-text-on-tint|--color-fill-tertiary>--color-surface-base|6.54
light|--color-accent-text-on-tint|--color-surface-base|7.54
light|--color-accent-text-on-tint|--color-surface-grouped|6.76
light|--color-accent-text-on-tint|--color-accent-tint>--color-surface-base|6.58
light|--label-2|--color-surface-base|3.44
light|--label-2-text|--color-surface-base|5.63
light|--label-2-text|--color-surface-grouped|5.26
light|--label-2|--color-surface-grouped|3.30
light|--color-text-secondary|--color-accent-tint>--color-surface-base|5.17
light|--color-text-secondary|--color-fill-tertiary>--color-surface-grouped|4.83
light|--color-text-secondary|--color-status-error-tint>--color-surface-grouped|4.70
light|--label-3|--color-surface-base|1.73
light|--color-on-accent|--color-accent-solid|5.84
light|--color-on-accent|--color-accent-pressed|7.54
light|--color-on-status|--color-status-error|3.55
light|--color-status-success|--color-status-success-tint>--color-surface-base|1.98
light|--color-status-warning|--color-status-warning-tint>--color-surface-base|1.96
light|--color-status-error|--color-status-error-tint>--color-surface-base|2.94
light|--color-status-success|--color-surface-base|2.22
light|--color-status-warning|--color-surface-base|2.20
light|--color-status-error|--color-surface-base|3.55
light|--color-status-info|--color-surface-base|4.02
light|--glass-tint-accent|--color-surface-base|1.14
dark|--color-accent|--color-surface-base|9.62
dark|--color-accent|--color-surface-card|7.80
dark|--color-accent|--color-accent-tint>--color-surface-base|7.81
dark|--color-on-accent|--color-accent-solid|5.99
dark|--color-on-accent|--color-accent-pressed|7.13
dark|--color-on-status|--color-status-error|3.41
dark|--label-2|--color-surface-base|6.36
dark|--color-text-secondary|--color-surface-card|5.95
dark|--color-text-secondary|--color-status-success-tint>--color-surface-card|4.74
dark|--color-status-success|--color-status-success-tint>--color-surface-base|8.05
dark|--color-status-warning|--color-status-warning-tint>--color-surface-base|7.93
dark|--color-status-error|--color-status-error-tint>--color-surface-base|5.25
dark|--color-status-info|--color-status-info-tint>--color-surface-base|4.92
== invariants ==
accent fill clears 3:1 on base|light|--color-accent|--color-surface-base|min|3.0
accent-text clears AA on base|light|--color-accent-text|--color-surface-base|min|4.5
accent-text-on-tint clears AA on grouped|light|--color-accent-text-on-tint|--color-surface-grouped|min|4.5
accent-text-on-tint clears AA on tint|light|--color-accent-text-on-tint|--color-accent-tint>--color-surface-base|min|4.5
secondary text clears AA on grouped|light|--label-2-text|--color-surface-grouped|min|4.5
filled prominent clears AA, light|light|--color-on-accent|--color-accent-solid|min|4.5
filled prominent clears AA, dark|dark|--color-on-accent|--color-accent-solid|min|4.5
filled prominent pressed clears AA, light|light|--color-on-accent|--color-accent-pressed|min|4.5
filled prominent pressed clears AA, dark|dark|--color-on-accent|--color-accent-pressed|min|4.5
accent-text-on-tint clears AA on a fill-tertiary wash (link in code or table)|light|--color-accent-text-on-tint|--color-fill-tertiary>--color-surface-base|min|4.5
filled destructive clears 3:1, light|light|--color-on-status|--color-status-error|min|3.0
filled destructive clears 3:1, dark|dark|--color-on-status|--color-status-error|min|3.0
focus ring outer band clears 3:1 on base|light|--color-accent|--color-surface-base|min|3.0
focus ring inner band clears 3:1 on the accent solid fill|light|--color-surface-base|--color-accent-solid|min|3.0
tertiary is NOT a usable text color|light|--label-3|--color-surface-base|max|3.0
secondary text clears AA on the accent tint (rule 4)|light|--color-text-secondary|--color-accent-tint>--color-surface-base|min|4.5
secondary text clears AA on a success tint over grouped (rule 4)|light|--color-text-secondary|--color-status-success-tint>--color-surface-grouped|min|4.5
secondary text clears AA on a warning tint over grouped (rule 4)|light|--color-text-secondary|--color-status-warning-tint>--color-surface-grouped|min|4.5
secondary text clears AA on an error tint over grouped (rule 4)|light|--color-text-secondary|--color-status-error-tint>--color-surface-grouped|min|4.5
secondary text clears AA on an info tint over grouped (rule 4)|light|--color-text-secondary|--color-status-info-tint>--color-surface-grouped|min|4.5
secondary text clears AA on the fill-tertiary wash over grouped (rule 4)|light|--color-text-secondary|--color-fill-tertiary>--color-surface-grouped|min|4.5
secondary text clears AA on a success tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-status-success-tint>--color-surface-card|min|4.5
secondary text clears AA on a warning tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-status-warning-tint>--color-surface-card|min|4.5
secondary text clears AA on an error tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-status-error-tint>--color-surface-card|min|4.5
secondary text clears AA on an info tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-status-info-tint>--color-surface-card|min|4.5
secondary text clears AA on the accent tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-accent-tint>--color-surface-card|min|4.5
the system secondary label clears the 3:1 glyph floor on grouped (rule 4)|light|--label-2|--color-surface-grouped|min|3.0
the system secondary label is NOT text on grouped (rule 4)|light|--label-2|--color-surface-grouped|max|4.5
accent-text clears AA on a card|light|--color-accent-text|--color-surface-card|min|4.5
accent-text clears AA on grouped|light|--color-accent-text|--color-surface-grouped|min|4.5
accent-text clears AA on the accent tint|light|--color-accent-text|--color-accent-tint>--color-surface-base|min|4.5
accent-text clears AA on a fill-tertiary wash|light|--color-accent-text|--color-fill-tertiary>--color-surface-base|min|4.5
the accent tint is NOT a visible focus indicator (rule 7)|light|--glass-tint-accent|--color-surface-base|max|1.5
dark status success clears AA on its own tint|dark|--color-status-success|--color-status-success-tint>--color-surface-base|min|4.5
dark status warning clears AA on its own tint|dark|--color-status-warning|--color-status-warning-tint>--color-surface-base|min|4.5
dark status error clears AA on its own tint|dark|--color-status-error|--color-status-error-tint>--color-surface-base|min|4.5
dark status info clears AA on its own tint|dark|--color-status-info|--color-status-info-tint>--color-surface-base|min|4.5
== aliases ==
rule 4: secondary text is label-2-text, light|light|--color-text-secondary|--label-2-text
rule 4: secondary text is label-2-text, dark|dark|--color-text-secondary|--label-2-text
rule 6: link is accent-text, light|light|--color-text-link|--color-accent-text
rule 6: link is accent-text, dark|dark|--color-text-link|--color-accent-text
dark accent collapses to olive-400|dark|--color-accent|--olive-400
dark accent-solid collapses to olive-400|dark|--color-accent-solid|--olive-400
light accent-solid is olive-700, the step white clears AA on|light|--color-accent-solid|--olive-700
dark accent-text collapses to olive-400|dark|--color-accent-text|--olive-400
dark accent-text-on-tint collapses to olive-400|dark|--color-accent-text-on-tint|--olive-400
'

# ---------------------------------------------------------------------------
# Web raw-color allowlist. path ERE @@ source-line ERE @@ reason. A finding is
# suppressed only when both match, so an allowance cannot silently widen to a
# whole file. Never suppress with a comment in CSS: add a row here.
# ---------------------------------------------------------------------------
ALLOW_WEB='
'

WEB_FILES=$(
  for f in web/landing/styles.css web/docs/src/css/custom.css web/landing/app.js web/landing/theme-init.js web/landing/r/receive.js web/docs/src/prismTheme.ts; do
    [ -r "$f" ] || {
      echo "FAIL: $f not readable" >&2
      exit 2
    }
    echo "$f"
  done
  find web/landing -name '*.html' | sort
)

# ---------------------------------------------------------------------------
# awk shared by every phase. Inputs travel through ENVIRON because a literal
# newline cannot pass through `awk -v`.
# ---------------------------------------------------------------------------
AWK_COMMON='
function trim(s) { sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s }

function blank(s) { gsub(/[^\n]/, " ", s); return s }

function nl_count(s,   t) { t = s; return gsub(/\n/, "", t) }

function read_file(path,   line, buf, rc) {
  buf = ""
  while ((rc = (getline line < path)) > 0) buf = buf line "\n"
  close(path)
  if (rc < 0) return "\001unreadable"
  return buf
}

# Comments become spaces so line numbers survive.
function strip_css_comments(s,   out, p, q) {
  out = ""
  while ((p = index(s, "/*")) > 0) {
    out = out substr(s, 1, p - 1)
    s = substr(s, p + 2)
    q = index(s, "*/")
    if (q == 0) { out = out "  " blank(s); s = ""; break }
    out = out "  " blank(substr(s, 1, q - 1)) "  "
    s = substr(s, q + 2)
  }
  return out s
}

# Swift source, one cleaned line per SL[] entry: comments gone, string and
# multi-line string contents emptied, so a regex never reads prose. Returns
# the line count, or -1 when the file is unreadable.
function swift_clean(path,   n, raw, out, i, j, len, c, c2, c3, d, in_block, in_multi, rc) {
  n = 0; in_block = 0; in_multi = 0
  while ((rc = (getline raw < path)) > 0) {
    n++; out = ""; i = 1; len = length(raw)
    while (i <= len) {
      c = substr(raw, i, 1); c2 = substr(raw, i, 2); c3 = substr(raw, i, 3)
      if (in_block) { if (c2 == "*/") { in_block = 0; i += 2 } else i++; continue }
      if (in_multi) { if (c3 == "\"\"\"") { in_multi = 0; i += 3 } else i++; continue }
      if (c3 == "\"\"\"") { in_multi = 1; i += 3; out = out "\"\""; continue }
      if (c2 == "/*") { in_block = 1; i += 2; continue }
      if (c2 == "//") break
      if (c == "\"") {
        j = i + 1
        while (j <= len) {
          d = substr(raw, j, 1)
          if (d == "\\") j += 2
          else if (d == "\"") break
          else j++
        }
        out = out "\"\""; i = j + 1; continue
      }
      out = out c; i++
    }
    SL[n] = out
  }
  close(path)
  if (rc < 0) return -1
  return n
}

function count_of(line, ch,   t) { t = line; return gsub(ch, "", t) }

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

function die(msg) { print "FAIL: " msg > "/dev/stderr"; exit 2 }

# Returns "r g b a": channels 0-255, alpha 0-1.
function parse_color(v, theme, depth,   args, n, inner, hex, parts, cnt, a) {
  v = trim(v)
  if (depth > 16) die("token recursion too deep at " v)
  if (v ~ /^light-dark\(/) {
    inner = substr(v, 12, length(v) - 12)
    n = split_top(inner, args)
    if (n != 2) die("light-dark() needs 2 arguments: " v)
    return parse_color(args[theme == "light" ? 1 : 2], theme, depth + 1)
  }
  if (v ~ /^var\(/) return resolve(trim(substr(v, 5, length(v) - 5)), theme, depth + 1)
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
  if (!(name in VAL)) die(name " is not defined in " tokens)
  return parse_color(VAL[name], theme, depth)
}

# tokens.css -> VAL[name], VLINE[name], ORDER[1..ntok]
function load_tokens(path,   body, n, pieces, i, d, p, name, cum, lead, k) {
  body = read_file(path)
  if (body ~ /^\001unreadable/) die(path " not readable")
  body = strip_css_comments(body)
  # Hand-rolled split: BSD awk also breaks split(s, a, ";") on newlines.
  n = 0
  while ((p = index(body, ";")) > 0) { pieces[++n] = substr(body, 1, p - 1); body = substr(body, p + 1) }
  pieces[++n] = body
  cum = 0
  for (i = 1; i <= n; i++) {
    d = pieces[i]
    # Drop everything up to the last brace: `:root {` or `}` heads a piece.
    k = 0
    for (p = length(d); p >= 1; p--) if (substr(d, p, 1) == "{" || substr(d, p, 1) == "}") { k = p; break }
    lead = substr(d, 1, k)
    d = substr(d, k + 1)
    if (match(d, /--[a-z0-9-]+[ \t]*:/)) {
      lead = lead substr(d, 1, RSTART - 1)
      d = substr(d, RSTART)
      p = index(d, ":")
      name = trim(substr(d, 1, p - 1))
      if (!(name in VAL)) {
        VAL[name] = trim(substr(d, p + 1))
        VLINE[name] = 1 + cum + nl_count(lead)
        ORDER[++ntok] = name
      }
    }
    cum += nl_count(pieces[i])
  }
}
'

# ---------------------------------------------------------------------------
# Phase 1: mirror parity
# ---------------------------------------------------------------------------
AWK_PARITY='
function finding(path, line, msg) { print path ":" line ": " msg; nfind++ }

# DesignTokens.swift -> SW[Enum.name] (whole statement), SWLINE[...]
function load_swift(path,   n, i, line, depth, sp, c, k, stmt, j, pd, bd, name, pend, key) {
  n = swift_clean(path)
  if (n < 0) die(path " not readable")
  depth = 0; sp = 0; pend = ""
  for (i = 1; i <= n; i++) {
    line = SL[i]
    if (sp > 0 && depth == STKD[sp] && match(line, /static[ \t]+(let|var|func)[ \t]+[A-Za-z0-9_]+/)) {
      name = substr(line, RSTART, RLENGTH); sub(/^static[ \t]+(let|var|func)[ \t]+/, "", name)
      stmt = line; j = i
      pd = count_of(stmt, "\\(") - count_of(stmt, "\\)")
      bd = count_of(stmt, "{") - count_of(stmt, "}")
      while ((pd > 0 || bd > 0) && j < n && j - i < 20) {
        j++; stmt = stmt "\n" SL[j]
        pd += count_of(SL[j], "\\(") - count_of(SL[j], "\\)")
        bd += count_of(SL[j], "{") - count_of(SL[j], "}")
      }
      key = STKN[sp] "." name
      SW[key] = stmt; SWLINE[key] = i
    }
    if (match(line, /(^|[ \t])enum[ \t]+[A-Za-z0-9_]+/)) {
      name = substr(line, RSTART, RLENGTH); sub(/^.*enum[ \t]+/, "", name); pend = name
    }
    for (k = 1; k <= length(line); k++) {
      c = substr(line, k, 1)
      if (c == "{") { depth++; if (pend != "") { sp++; STKN[sp] = pend; STKD[sp] = depth; pend = "" } }
      else if (c == "}") { if (sp > 0 && depth == STKD[sp]) sp--; depth-- }
    }
  }
}

function swift_num(stmt,   v) {
  v = trim(substr(stmt, index(stmt, "=") + 1))
  sub(/[ \t]*\{.*$/, "", v)
  if (v ~ /^-?[0-9]+(\.[0-9]+)?$/) return v + 0
  if (match(v, /^CGFloat\(-?[0-9.]+\)$/)) { sub(/^CGFloat\(/, "", v); sub(/\)$/, "", v); return v + 0 }
  return "?"
}

function token_num(raw) {
  raw = trim(raw)
  if (raw ~ /^-?[0-9.]+ms$/) { sub(/ms$/, "", raw); return (raw + 0) / 1000 }
  if (raw ~ /^-?[0-9.]+px$/) { sub(/px$/, "", raw); return raw + 0 }
  if (raw ~ /^-?[0-9.]+$/) return raw + 0
  return "?"
}

# First `want` numbers inside the call that follows `marker`, space separated.
function call_nums(s, marker, want,   p, rest, out, cnt) {
  p = index(s, marker)
  if (p == 0) return "?"
  rest = substr(s, p + length(marker)); out = ""; cnt = 0
  while (cnt < want && match(rest, /-?[0-9]*\.?[0-9]+/)) {
    out = out ((cnt ? " " : "") (substr(rest, RSTART, RLENGTH) + 0))
    rest = substr(rest, RSTART + RLENGTH); cnt++
  }
  if (cnt < want) return "?"
  return out
}

function near(a, b) { return (a - b < 0.0005 && b - a < 0.0005) }

function check_numeric(   n, i, f, tok, key, tv, sv, tn, sn, a, b, k) {
  n = split(ENVIRON["NUMERIC_TABLE"], rows, "\n")
  for (i = 1; i <= n; i++) {
    if (trim(rows[i]) == "") continue
    split(rows[i], f, "|"); tok = f[1]; key = f[2]
    nparity++; MIRRORED[tok] = 1
    if (!(tok in VAL)) { finding("scripts/verify-design.sh", 1, tok " is in the parity table but not defined in " tokens); continue }
    if (!(key in SW)) { finding(swiftfile, 1, "missing " key ", the Swift mirror of " tok " (" tokens ":" VLINE[tok] ")"); continue }
    if (f[3] == "curve") {
      tv = call_nums(VAL[tok], "cubic-bezier(", 4)
      sv = call_nums(SW[key], "timingCurve(", 4)
      if (sv == "?") { finding(swiftfile, SWLINE[key], key " has no .timingCurve(a, b, c, d, ...) to compare with " tok); continue }
      split(tv, a, " "); split(sv, b, " ")
      for (k = 1; k <= 4; k++) if (!near(a[k], b[k])) break
      if (k <= 4) finding(swiftfile, SWLINE[key], key " curve is (" sv ") but " tok " is (" tv ") in " tokens ":" VLINE[tok])
      continue
    }
    tn = token_num(VAL[tok]); sn = swift_num(SW[key])
    if (tn == "?") { finding(tokens, VLINE[tok], tok " value " VAL[tok] " is not a plain px, ms or unitless number the parity check can read"); continue }
    if (sn == "?") { finding(swiftfile, SWLINE[key], key " is not a plain numeric literal the parity check can read"); continue }
    if (!near(tn, sn)) finding(swiftfile, SWLINE[key], key " is " sn " but " tok " is " tn " (" VAL[tok] ") in " tokens ":" VLINE[tok])
  }
}

# Colorset Contents.json -> CS[set, "any"|"dark"] = "r g b a" (255 scale), CSLINE.
function comp(v, is_alpha) {
  v = trim(v); gsub(/["\t ,]/, "", v)
  if (is_alpha) return v + 0
  if (v ~ /^0[xX][0-9a-fA-F]+$/) return hex2dec(substr(v, 3))
  if (v ~ /\./) return (v + 0) * 255
  return v + 0
}

function load_colorset(set,   path, line, rc, mode, skip, r, g, b, a, rline, have) {
  path = colorsets "/" set ".colorset/Contents.json"
  mode = "any"; skip = 0; have = 0
  while ((rc = (getline line < path)) > 0) {
    if (line ~ /"appearance"[ \t]*:[ \t]*"contrast"/) skip = 1
    else if (line ~ /"value"[ \t]*:[ \t]*"dark"/) mode = "dark"
    else if (line ~ /"red"[ \t]*:/)   { r = comp(substr(line, index(line, ":") + 1), 0); rline = FNR_; have = 1 }
    else if (line ~ /"green"[ \t]*:/) g = comp(substr(line, index(line, ":") + 1), 0)
    else if (line ~ /"blue"[ \t]*:/)  b = comp(substr(line, index(line, ":") + 1), 0)
    else if (line ~ /"alpha"[ \t]*:/) a = comp(substr(line, index(line, ":") + 1), 1)
    if (line ~ /"idiom"/) {
      if (have && !skip) { CS[set, mode] = r " " g " " b " " a; CSLINE[set, mode] = rline }
      mode = "any"; skip = 0; have = 0
    }
    FNR_++
  }
  close(path)
  FNR_ = 1
  return (rc < 0) ? 0 : 1
}

function check_colors(   n, i, f, set, tok, th, want, got, w, g, k, mode, path) {
  n = split(ENVIRON["COLOR_TABLE"], rows, "\n")
  for (i = 1; i <= n; i++) {
    if (trim(rows[i]) == "") continue
    split(rows[i], f, "|"); set = f[1]; tok = f[2]
    ncolor++; MIRRORED[tok] = 1
    path = colorsets "/" set ".colorset/Contents.json"
    if (!(tok in VAL)) { finding("scripts/verify-design.sh", 1, tok " is in the color table but not defined in " tokens); continue }
    FNR_ = 1
    if (!load_colorset(set)) { finding(path, 1, "missing color set " set ", the mirror of " tok " (" tokens ":" VLINE[tok] ")"); continue }
    for (k = 1; k <= 2; k++) {
      th = (k == 1) ? "light" : "dark"
      mode = (k == 1) ? "any" : "dark"
      want = resolve(tok, th, 0)
      if (!((set, mode) in CS)) {
        if (k == 2 && (set, "any") in CS) {
          if (want != resolve(tok, "light", 0)) { finding(path, 1, set " has no dark appearance but " tok " differs in dark (" want ")"); continue }
          got = CS[set, "any"]; mode = "any"
        } else { finding(path, 1, set " has no " mode " appearance to compare with " tok); continue }
      } else got = CS[set, mode]
      split(want, w, " "); split(got, g, " ")
      if (w[1] - g[1] > 1 || g[1] - w[1] > 1 || w[2] - g[2] > 1 || g[2] - w[2] > 1 || w[3] - g[3] > 1 || g[3] - w[3] > 1 || w[4] - g[4] > 0.01 || g[4] - w[4] > 0.01)
        finding(path, CSLINE[set, mode], set " (" th ") is " sprintf("%.0f %.0f %.0f a%.3f", g[1], g[2], g[3], g[4]) " but " tok " is " sprintf("%.0f %.0f %.0f a%.3f", w[1], w[2], w[3], w[4]) " in " tokens ":" VLINE[tok])
    }
  }
}

# Every shared token is mirrored or deliberately not.
function check_complete(   i, name, nn, pats, k, ok) {
  nn = split(ENVIRON["NOT_MIRRORED"], pats, "\n")
  for (i = 1; i <= ntok; i++) {
    name = ORDER[i]
    if (name ~ /(^|-)web(-|$)/) continue
    if (name in MIRRORED) continue
    ok = 0
    for (k = 1; k <= nn; k++) if (trim(pats[k]) != "" && name ~ trim(pats[k])) { ok = 1; break }
    if (!ok) finding(tokens, VLINE[name], name " is shared but neither in the parity tables of scripts/verify-design.sh nor in design/implementation.md -> Not mirrored: decide its mirror")
    ncomplete++
  }
}

BEGIN {
  tokens = ENVIRON["TOKENS"]; swiftfile = ENVIRON["SWIFT_TOKENS"]; colorsets = ENVIRON["COLORSETS"]
  FNR_ = 1
  load_tokens(tokens)
  load_swift(swiftfile)
  check_numeric()
  check_colors()
  check_complete()
  if (nfind) {
    printf "parity: FAIL (%d finding%s)\n", nfind, (nfind == 1 ? "" : "s")
    exit 1
  }
  if (ENVIRON["QUIET"] != "1")
    printf "parity: OK (%d numeric and %d color mirrors, %d other shared tokens deliberately not mirrored)\n", nparity, ncolor, ncomplete
}
'

# ---------------------------------------------------------------------------
# Phase 2: contrast
# ---------------------------------------------------------------------------
AWK_CONTRAST='
function fail(msg) { failures[++nfail] = msg }

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
  if (!("--shadow-focus-ring" in VAL)) { fail("--shadow-focus-ring is not defined in " tokens); return }
  ring = VAL["--shadow-focus-ring"]
  n = split_top(ring, bands)
  if (n != 2) { fail("--shadow-focus-ring must have exactly two bands, has " n); return }
  for (k = 1; k <= 2; k++) {
    want_spread = (k == 1) ? "2px" : "4px"
    want_color = (k == 1) ? "var(--color-surface-base)" : "var(--color-accent)"
    np = split(bands[k], parts, " ")
    spread = parts[4]; color = parts[np]
    if (np != 5 || parts[1] != "0" || parts[2] != "0" || parts[3] != "0" || spread != want_spread || color != want_color)
      fail("--shadow-focus-ring band " k " is \"" bands[k] "\", rule 7 needs \"0 0 0 " want_spread " " want_color "\"")
  }
}

# The web manifest paints the installed app before any CSS loads. It has one
# value per key, so both are --bg-base in light (design/implementation.md -> Raw colors on web).
function check_manifest(path,   text, key, k, rest, hex, want) {
  text = read_file(path)
  if (text ~ /^\001unreadable/) die(path " not readable")
  want = resolve("--bg-base", "light", 0)
  split("theme_color background_color", key, " ")
  for (k = 1; k <= 2; k++) {
    if (!match(text, "\"" key[k] "\"[ \t\n]*:[ \t\n]*\"#[0-9A-Fa-f]+\"")) { fail(path ": no " key[k] " hex color"); continue }
    rest = substr(text, RSTART, RLENGTH); sub(/^.*"#/, "#", rest); hex = substr(rest, 1, length(rest) - 1)
    if (parse_color(hex, "light", 0) != want) fail(path ": " key[k] " is " hex ", design/implementation.md needs --bg-base in light")
  }
}

# The Contrast section of principles.md: from its heading to the next `## ` line.
function contrast_section(path,   lines, n, i, in_sec, out) {
  n = split(read_file(path), lines, "\n")
  if (lines[1] == "\001unreadable") die(path " not readable")
  in_sec = 0; out = ""
  for (i = 1; i <= n; i++) {
    if (lines[i] ~ /^## Contrast/) in_sec = 1
    else if (lines[i] ~ /^## /) in_sec = 0
    if (in_sec) out = out lines[i] "\n"
  }
  return out
}

# True when num appears in text as a whole number: no digit or "." before it
# (so 3.41 is not found in 13.41), no digit after it.
function has_number(text, num,   rest, p, off, before, after) {
  rest = text; off = 0
  while ((p = index(rest, num)) > 0) {
    before = (off + p > 1) ? substr(text, off + p - 1, 1) : ""
    after = substr(text, off + p + length(num), 1)
    if (before !~ /[0-9.]/ && after !~ /[0-9]/) return 1
    off += p
    rest = substr(rest, p + 1)
  }
  return 0
}

BEGIN {
  TOLERANCE = 0.01
  tokens = ENVIRON["TOKENS"]; quiet = (ENVIRON["QUIET"] == "1")
  width = 10

  load_tokens(tokens)

  section = "cases"
  n = split(ENVIRON["CONTRAST_TABLE"], rows, "\n")
  for (i = 1; i <= n; i++) {
    if (trim(rows[i]) == "") continue
    if (trim(rows[i]) == "== invariants ==") { section = "invariants"; continue }
    if (trim(rows[i]) == "== aliases ==") { section = "aliases"; continue }
    split(rows[i], f, "|")
    if (section == "cases") {
      ncase++
      ctheme[ncase] = f[1]; cfg[ncase] = f[2]; cstack[ncase] = f[3]; cwant[ncase] = f[4] + 0
      if (length(f[2]) > width) width = length(f[2])
    } else if (section == "aliases") {
      nalias++
      alabel[nalias] = f[1]; atheme[nalias] = f[2]; atoken[nalias] = f[3]; atarget[nalias] = f[4]
    } else {
      ninvariant++
      ilabel[ninvariant] = f[1]; itheme[ninvariant] = f[2]; ifg[ninvariant] = f[3]
      istack[ninvariant] = f[4]; ikind[ninvariant] = f[5]; ithreshold[ninvariant] = f[6] + 0
    }
  }

  doc = contrast_section(ENVIRON["PRINCIPLES_MD"])
  if (doc == "") fail(ENVIRON["PRINCIPLES_MD"] ": has no Contrast section")

  if (!quiet) printf "%-6s %-*s %-46s %6s %6s\n", "theme", width, "foreground", "on", "got", "doc"

  for (i = 1; i <= ncase; i++) {
    got = measure(ctheme[i], cfg[i], cstack[i])
    on = cstack[i]; gsub(/>/, " over ", on)
    drift = (got - cwant[i] < -TOLERANCE || got - cwant[i] > TOLERANCE)
    if (drift) fail(ctheme[i] ": " cfg[i] " on " on " is " sprintf("%.2f", got) ", principles.md says " sprintf("%.2f", cwant[i]))
    if (!quiet) printf "%-6s %-*s %-46s %6.2f %6.2f%s\n", ctheme[i], width, cfg[i], on, got, cwant[i], drift ? "  <-- drift" : ""
    if (doc != "" && !has_number(doc, sprintf("%.2f", cwant[i])))
      fail(ENVIRON["PRINCIPLES_MD"] ": " sprintf("%.2f", cwant[i]) " (" ctheme[i] " " cfg[i] " on " cstack[i] ") is in the verify-design.sh contrast table but not in the Contrast section: keep the two in step")
  }

  for (i = 1; i <= ninvariant; i++) {
    got = measure(itheme[i], ifg[i], istack[i])
    ok = (ikind[i] == "min") ? (got >= ithreshold[i]) : (got <= ithreshold[i])
    if (!ok) fail("invariant broken: " ilabel[i] " (" sprintf("%.2f", got) " is " (ikind[i] == "min" ? "below " : "above ") sprintf("%.2f", ithreshold[i]) ")")
  }

  for (i = 1; i <= nalias; i++) {
    if (resolve(atoken[i], atheme[i], 0) != resolve(atarget[i], atheme[i], 0))
      fail("alias rule broken: " alabel[i] " (" atoken[i] " no longer resolves to " atarget[i] ")")
  }

  check_ring()
  check_manifest(ENVIRON["MANIFEST"])

  if (nfail) {
    for (i = 1; i <= nfail; i++) print failures[i]
    printf "contrast: FAIL (%d finding%s)\n", nfail, (nfail == 1 ? "" : "s")
    print "Update design/principles.md, or revert the token change."
    exit 1
  }
  if (!quiet)
    printf "contrast: OK (%d documented ratios, %d invariants, %d alias rules, 2 focus-ring bands, manifest colors)\n", ncase, ninvariant, nalias
}
'

# ---------------------------------------------------------------------------
# Phase 3: web raw-color lint
# ---------------------------------------------------------------------------
AWK_WEB='
function allowed(path, text,   n, i, parts, rows) {
  n = split(ENVIRON["ALLOW_WEB"], rows, "\n")
  for (i = 1; i <= n; i++) {
    if (trim(rows[i]) == "") continue
    split(rows[i], parts, " @@ ")
    if (path ~ trim(parts[1]) && text ~ trim(parts[2])) return 1
  }
  return 0
}

function finding(path, line, msg, text) {
  if (allowed(path, text)) return
  print path ":" line ": " msg; nfind++
}

# Selectors and at-rule preludes (including every @media condition) become
# spaces; only declarations remain.
function blank_preludes(s,   i, c, len, seg, out) {
  out = ""; seg = ""; len = length(s)
  for (i = 1; i <= len; i++) {
    c = substr(s, i, 1)
    if (c == "{") { out = out blank(seg) " "; seg = "" }
    else if (c == ";" || c == "}") { out = out seg c; seg = "" }
    else seg = seg c
  }
  return out seg
}

# CM[line, col] = 1 for every character inside a color-mix( ... ) call, across
# lines: the only place `black` is allowed (the pressed state of a filled
# destructive button).
function mark_color_mix(text,   i, c, len, line, col, depth) {
  delete CM
  line = 1; col = 0; depth = 0; len = length(text)
  for (i = 1; i <= len; i++) {
    c = substr(text, i, 1); col++
    if (c == "\n") { line++; col = 0; continue }
    if (depth == 0 && substr(text, i, 10) == "color-mix(" && (i == 1 || substr(text, i - 1, 1) !~ /[A-Za-z0-9_-]/)) depth = 1
    else if (depth > 0) {
      if (c == "(") depth++
      else if (c == ")") depth--
    }
    if (depth > 0) CM[line, col] = 1
  }
}

# CSS named colors. transparent, currentColor, inherit, none are not colors to
# the lint (no entry here).
function is_named_color(w) {
  return index(" " NAMED " ", " " tolower(w) " ") > 0
}

function lint_text(path, text, line0,   n, T, ln, t, rest, tok, prev, nextc, hexlen, col, off, before) {
  if (NAMED == "") NAMED = "aliceblue antiquewhite aqua aquamarine azure beige bisque black blanchedalmond blue blueviolet brown burlywood cadetblue chartreuse chocolate coral cornflowerblue cornsilk crimson cyan darkblue darkcyan darkgoldenrod darkgray darkgreen darkgrey darkkhaki darkmagenta darkolivegreen darkorange darkorchid darkred darksalmon darkseagreen darkslateblue darkslategray darkslategrey darkturquoise darkviolet deeppink deepskyblue dimgray dimgrey dodgerblue firebrick floralwhite forestgreen fuchsia gainsboro ghostwhite gold goldenrod gray green greenyellow grey honeydew hotpink indianred indigo ivory khaki lavender lavenderblush lawngreen lemonchiffon lightblue lightcoral lightcyan lightgoldenrodyellow lightgray lightgreen lightgrey lightpink lightsalmon lightseagreen lightskyblue lightslategray lightslategrey lightsteelblue lightyellow lime limegreen linen magenta maroon mediumaquamarine mediumblue mediumorchid mediumpurple mediumseagreen mediumslateblue mediumspringgreen mediumturquoise mediumvioletred midnightblue mintcream mistyrose moccasin navajowhite navy oldlace olive olivedrab orange orangered orchid palegoldenrod palegreen paleturquoise palevioletred papayawhip peachpuff peru pink plum powderblue purple rebeccapurple red rosybrown royalblue saddlebrown salmon sandybrown seagreen seashell sienna silver skyblue slateblue slategray slategrey snow springgreen steelblue tan teal thistle tomato turquoise violet wheat white whitesmoke yellow yellowgreen"
  mark_color_mix(text)
  n = split(text, T, "\n")
  for (ln = 1; ln <= n; ln++) {
    t = T[ln]
    if (t ~ /(^|[^A-Za-z0-9_-])(rgb|rgba|hsl|hsla)\(/)
      finding(path, line0 + ln - 1, "color function literal: use a color token", t)
    rest = t; off = 0
    while (match(rest, /#[0-9A-Fa-f]+/)) {
      tok = substr(rest, RSTART, RLENGTH)
      prev = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
      nextc = substr(rest, RSTART + RLENGTH, 1)
      before = substr(t, 1, off + RSTART - 1)
      off += RSTART + RLENGTH - 1
      rest = substr(rest, RSTART + RLENGTH)
      hexlen = length(tok) - 1
      if (before ~ /url\([\047"]?$/) continue
      if (index(" \t:,(\047\"", prev) > 0 && nextc !~ /[A-Za-z0-9_-]/ && (hexlen == 3 || hexlen == 4 || hexlen == 6 || hexlen == 8))
        finding(path, line0 + ln - 1, "hex color literal " tok ": use a color token", t)
    }
    # Named colors as values. black is allowed inside color-mix() only (the
    # pressed state of a filled destructive button).
    rest = t; off = 0
    while (match(rest, /[A-Za-z][A-Za-z]*/)) {
      tok = substr(rest, RSTART, RLENGTH)
      prev = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
      nextc = substr(rest, RSTART + RLENGTH, 1)
      col = off + RSTART
      off += RSTART + RLENGTH - 1
      rest = substr(rest, RSTART + RLENGTH)
      if (prev ~ /[A-Za-z0-9_-]/ || nextc ~ /[A-Za-z0-9_(-]/) continue
      if (!is_named_color(tok)) continue
      if (tolower(tok) == "black" && ((ln, col) in CM)) continue
      finding(path, line0 + ln - 1, "named color literal " tok ": use a color token", t)
    }
  }
}

function lint_css(path, text, line0,   s) {
  s = strip_css_comments(text)
  lint_text(path, blank_preludes(s), line0)
}

# JS and TS: comments gone (a // only at line start or after whitespace, so
# URLs in strings survive), then the same color rules as CSS.
function lint_script(path, text,   s, n, T, ln, t) {
  s = strip_css_comments(text)
  n = split(s, T, "\n"); s = ""
  for (ln = 1; ln <= n; ln++) {
    t = T[ln]
    if (match(t, /(^|[ \t])\/\/.*$/)) t = substr(t, 1, RSTART - 1) blank(substr(t, RSTART))
    s = s t (ln < n ? "\n" : "")
  }
  lint_text(path, s, 1)
}

# Every style="..." (q is the quote character) in an HTML file.
function lint_style_attrs(path, text, re, q,   rest, base, pre, m, qi, body, prevc) {
  rest = text; base = 0
  while (match(rest, re)) {
    pre = substr(rest, 1, RSTART - 1)
    prevc = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
    m = substr(rest, RSTART, RLENGTH)
    rest = substr(rest, RSTART + RLENGTH)
    base += nl_count(pre)
    if (prevc !~ /[A-Za-z0-9_-]/) {
      qi = index(m, q)
      body = substr(m, qi + 1, length(m) - qi - 1)
      lint_text(path, body, base + 1 + nl_count(substr(m, 1, qi)))
    }
    base += nl_count(m)
  }
}

# Every <style> element body, linted as CSS.
function lint_style_elements(path, text,   rest, lrest, base, pre, close_at, body, tag) {
  rest = text; base = 0
  while (1) {
    lrest = tolower(rest)
    if (!match(lrest, /<style([ \t\n][^>]*)?>/)) break
    tag = substr(rest, 1, RSTART + RLENGTH - 1)
    base += nl_count(tag)
    rest = substr(rest, RSTART + RLENGTH)
    lrest = tolower(rest)
    close_at = index(lrest, "</style")
    if (close_at == 0) { body = rest; rest = "" } else { body = substr(rest, 1, close_at - 1); rest = substr(rest, close_at) }
    lint_css(path, body, base + 1)
    base += nl_count(body)
  }
}

function lint_html(path, text) {
  lint_style_attrs(path, text, "style[ \t\n]*=[ \t\n]*\"[^\"]*\"", "\"")
  lint_style_attrs(path, text, "style[ \t\n]*=[ \t\n]*[\047][^\047]*[\047]", "\047")
  lint_style_elements(path, text)
}

BEGIN {
  nf = split(ENVIRON["WEB_FILES"], files, "\n")
  for (i = 1; i <= nf; i++) {
    f = files[i]
    if (f == "") continue
    text = read_file(f)
    if (text ~ /^\001unreadable/) die(f " not readable")
    if (f ~ /\.html$/) lint_html(f, text)
    else if (f ~ /\.(js|ts)$/) lint_script(f, text)
    else lint_css(f, text, 1)
    nfile++
  }
  if (nfind) {
    printf "web colors: FAIL (%d finding%s)\n", nfind, (nfind == 1 ? "" : "s")
    exit 1
  }
  if (ENVIRON["QUIET"] != "1") printf "web colors: OK (%d files)\n", nfile
}
'

export TOKENS SWIFT_TOKENS COLORSETS PRINCIPLES_MD MANIFEST NUMERIC_TABLE COLOR_TABLE CONTRAST_TABLE NOT_MIRRORED \
  ALLOW_WEB WEB_FILES
export QUIET

status=0
run_phase() {
  local rc=0
  awk "${AWK_COMMON}${1}" < /dev/null || rc=$?
  if [ "$rc" -ge 2 ]; then exit 2; fi
  if [ "$rc" -ne 0 ]; then status=1; fi
}

run_phase "$AWK_PARITY"
run_phase "$AWK_CONTRAST"
run_phase "$AWK_WEB"

if [ "$status" -ne 0 ]; then
  echo
  echo "FAIL: fix the code, or update design/ and its mirrors together. Never weaken the check."
  exit 1
fi
if [ "$QUIET" -eq 0 ]; then echo "OK: mirrors match design/tokens.css, every contrast ratio holds and no raw colors in web code"; fi
