#!/usr/bin/env bash
# Enforces the two rules design/AGENTS.md leaves to a machine.
#
#   1. Mirror parity. design/tokens.css is canonical; DesignTokens.swift and the
#      asset catalog color sets are hand-written mirrors. Every shared value
#      must be equal in all three, every token must either be mirrored or
#      listed as deliberately not mirrored.
#   2. No literals. Web CSS and the app write tokens, not hex, px, ms, raw
#      system colors or spring presets (design/web.md -> The only literals web
#      may write, design/swiftui.md -> Allowed literals).
#
#   scripts/verify-design.sh           # findings as path:line: message, exit 1 on any
#   scripts/verify-design.sh --quiet   # findings and FAIL lines only, no OK lines
#
# Pure bash and awk on purpose, like verify-contrast.sh: no toolchain, so CI
# runs it on a bare runner. Only POSIX awk features are used (BSD awk on macOS,
# mawk on the Ubuntu runner): no interval expressions, no gawk extensions.
# Exit 0 clean, 1 findings, 2 usage or unreadable input.
set -euo pipefail
cd "$(dirname "$0")/.."

QUIET=0
case "${1-}" in
  --quiet) QUIET=1 ;;
  "") ;;
  *) echo "usage: $0 [--quiet]" >&2; exit 2 ;;
esac
export LC_ALL=C

TOKENS=design/tokens.css
SWIFT_TOKENS=app/CrocApp/Support/DesignTokens.swift
COLORSETS=app/CrocApp/Assets.xcassets
[ -r "$TOKENS" ] || { echo "FAIL: $TOKENS not readable" >&2; exit 2; }
[ -r "$SWIFT_TOKENS" ] || { echo "FAIL: $SWIFT_TOKENS not readable" >&2; exit 2; }
[ -d "$COLORSETS" ] || { echo "FAIL: $COLORSETS not a directory" >&2; exit 2; }

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
ColorAccentPressed|--color-accent-pressed
ColorAccentTint|--color-accent-tint
ColorAccentText|--color-accent-text
ColorAccentTextOnTint|--color-accent-text-on-tint
ColorOnAccent|--color-on-accent
ColorPaper|--paper
ColorScrim|--color-scrim
ColorStatusSuccessTint|--color-status-success-tint
ColorStatusWarningTint|--color-status-warning-tint
ColorStatusErrorTint|--color-status-error-tint
ColorStatusInfoTint|--color-status-info-tint
'

# ---------------------------------------------------------------------------
# Not mirrored: shared token names (no `web` segment) the app deliberately has
# no Swift form for. One ERE per line, anchored. Source: design/swiftui.md ->
# Not mirrored, plus the semantic aliases swiftui.md -> Colors routes to
# system semantics (text, status, surface, separator). A token that matches
# neither this block nor a table above fails the check, so a new shared token
# forces the mirror decision in the same commit.
# ---------------------------------------------------------------------------
NOT_MIRRORED='
^--green-
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
^--color-text-
^--color-fill
^--color-separator$
^--color-on-status$
^--color-status-(success|warning|error|info)$
'

# ---------------------------------------------------------------------------
# No-literals allowlists. path ERE @@ source-line ERE @@ reason. A finding is
# suppressed only when both match, so an allowance cannot silently widen to a
# whole file. Never suppress with a comment in Swift or CSS: add a row here.
# ---------------------------------------------------------------------------
ALLOW_WEB='
'

ALLOW_SWIFT='
^app/CrocApp/CrocAppApp\.swift$ @@ \.frame\( @@ scene window minimums from platforms.md (swiftui.md -> Allowed literals: window sizes in the scene declarations)
^app/CrocApp/Views/AppCommands\.swift$ @@ NSColor\.labelColor @@ About-panel credits are an NSAttributedString, which has no SwiftUI color: the system semantic label color is the text color (swiftui.md -> Colors routes text to system semantics)
^app/CrocApp/Views/SettingsView\.swift$ @@ \.frame\(minWidth @@ the macOS Settings window minimum from platforms.md (swiftui.md -> Allowed literals)
'

# Swift files the no-literals lint covers: DesignTokens.swift is where the
# literals live, tests may use any value.
SWIFT_FILES=$(find app -name '*.swift' ! -path "$SWIFT_TOKENS" ! -path 'app/CrocAppTests/*' | sort)
[ -n "$SWIFT_FILES" ] || { echo "FAIL: no Swift files under app/" >&2; exit 2; }

WEB_FILES=$(
  for f in web/landing/styles.css web/docs/src/css/custom.css; do
    [ -r "$f" ] || { echo "FAIL: $f not readable" >&2; exit 2; }
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

# rgba of a token or literal: "r g b a", channels 0-255, alpha 0-1.
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

function die(msg) { print "FAIL: " msg > "/dev/stderr"; internal = 1; exit 2 }
'

# ---------------------------------------------------------------------------
# Phase 1: mirror parity
# ---------------------------------------------------------------------------
AWK_PARITY='
function finding(path, line, msg) { print path ":" line ": " msg; nfind++ }

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

# DesignTokens.swift -> SW[Enum.name] (whole statement), SWLINE[...]
function load_swift(path,   n, i, line, depth, sp, STK, c, k, stmt, j, pd, bd, name, pend, key) {
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

function load_colorset(set,   path, line, rc, mode, skip, r, g, b, a, rline, val, have) {
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
    if (!ok) finding(tokens, VLINE[name], name " is shared but neither in the parity tables of scripts/verify-design.sh nor in design/swiftui.md -> Not mirrored: decide its mirror")
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
# Phase 2a: web no-literals lint
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

# Lines of every rule block that carries a clip or clip-path declaration: the
# visually-hidden pattern, where 1px is geometry (web.md).
function mark_clip(s,   i, c, len, line, open_pos, open_line, blk, l) {
  line = 1; open_pos = 0; len = length(s)
  for (i = 1; i <= len; i++) {
    c = substr(s, i, 1)
    if (c == "\n") line++
    else if (c == "{") { open_pos = i; open_line = line }
    else if (c == "}") {
      if (open_pos > 0) {
        blk = ";" substr(s, open_pos + 1, i - open_pos - 1)
        if (blk ~ /[^A-Za-z-]clip(-path)?[ \t]*:/) for (l = open_line; l <= line; l++) EX[l] = 1
      }
      open_pos = 0
    }
  }
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
# lines: the only place web.md lets a percentage and `black` appear (components.md
# -> Button specs).
function mark_color_mix(text,   i, c, len, line, col, depth, want_open, k) {
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

function lint_text(path, text, line0, use_ex,   n, T, ln, t, rest, tok, prev, nextc, v, hexlen, pos, col, W, nw, k, off, before) {
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
      if (before ~ /url\($/) continue
      if (index(" \t:,(", prev) > 0 && nextc !~ /[A-Za-z0-9_-]/ && (hexlen == 3 || hexlen == 4 || hexlen == 6 || hexlen == 8))
        finding(path, line0 + ln - 1, "hex color literal " tok ": use a color token", t)
    }
    rest = t
    while (match(rest, /-?[0-9]*\.?[0-9]+(rem|em|px|ms|s|vw|vh)/)) {
      tok = substr(rest, RSTART, RLENGTH)
      prev = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
      nextc = substr(rest, RSTART + RLENGTH, 1)
      rest = substr(rest, RSTART + RLENGTH)
      if (prev ~ /[A-Za-z0-9_]/ || nextc ~ /[A-Za-z0-9_]/) continue
      v = tok; sub(/(rem|em|px|ms|s|vw|vh)$/, "", v)
      if (v + 0 == 0) continue
      if (use_ex && EX[ln] && (tok == "1px" || tok == "-1px")) continue
      finding(path, line0 + ln - 1, "dimension literal " tok ": use a spacing, size or duration token", t)
    }
    # Percentages: 0 and 100% are geometry; 50% only in a visually-hidden
    # block (clip-path: inset(50%)); 12%, 22% and 82% only inside color-mix().
    rest = t; off = 0
    while (match(rest, /-?[0-9]*\.?[0-9]+%/)) {
      tok = substr(rest, RSTART, RLENGTH)
      prev = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
      col = off + RSTART
      off += RSTART + RLENGTH - 1
      rest = substr(rest, RSTART + RLENGTH)
      if (prev ~ /[A-Za-z0-9_.]/) continue
      v = tok; sub(/%$/, "", v)
      if (v + 0 == 0 || v + 0 == 100) continue
      if (use_ex && EX[ln] && v + 0 == 50) continue
      if (((ln, col) in CM) && (v + 0 == 12 || v + 0 == 22 || v + 0 == 82)) continue
      finding(path, line0 + ln - 1, "percentage literal " tok ": use a token (only 100%, and color-mix() as components.md specs, are allowed)", t)
    }
    # Named colors as values. black is spec-allowed inside color-mix() only.
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
  delete EX
  s = strip_css_comments(text)
  mark_clip(s)
  lint_text(path, blank_preludes(s), line0, 1)
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
      lint_text(path, body, base + 1 + nl_count(substr(m, 1, qi)), 0)
    }
    base += nl_count(m)
  }
}

# Every <style> element body, linted as CSS.
function lint_style_elements(path, text,   low, rest, lrest, base, pre, tagend, close_at, body, tag) {
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
    if (f ~ /\.html$/) lint_html(f, text); else lint_css(f, text, 1)
    nfile++
  }
  if (nfind) {
    printf "web literals: FAIL (%d finding%s)\n", nfind, (nfind == 1 ? "" : "s")
    exit 1
  }
  if (ENVIRON["QUIET"] != "1") printf "web literals: OK (%d files)\n", nfile
}
'

# ---------------------------------------------------------------------------
# Phase 2b: Swift no-literals lint
# ---------------------------------------------------------------------------
AWK_SWIFT='
function allowed(path, text,   n, i, parts, rows) {
  n = split(ENVIRON["ALLOW_SWIFT"], rows, "\n")
  for (i = 1; i <= n; i++) {
    if (trim(rows[i]) == "") continue
    split(rows[i], parts, " @@ ")
    if (path ~ trim(parts[1]) && text ~ trim(parts[2])) return 1
  }
  return 0
}

function finding(path, line, msg) {
  if (allowed(path, SL[line])) return
  print path ":" line ": " msg; nfind++
}

# Text inside the parentheses opened at s[p], to the match or the end.
function args_at(s, p,   d, i, c, len) {
  d = 0; len = length(s)
  for (i = p; i <= len; i++) {
    c = substr(s, i, 1)
    if (c == "(") d++
    else if (c == ")") { d--; if (d == 0) return substr(s, p + 1, i - p - 1) }
  }
  return substr(s, p + 1)
}

# First standalone numeric literal in a, or "". mode "nz" skips 0, "op" skips 0 and 1.
function bare_num(a, mode,   rest, tok, prev, nextc) {
  rest = a
  while (match(rest, /[0-9]+(\.[0-9]+)?/)) {
    tok = substr(rest, RSTART, RLENGTH)
    prev = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : " "
    nextc = substr(rest, RSTART + RLENGTH, 1)
    rest = substr(rest, RSTART + RLENGTH)
    if (prev ~ /[A-Za-z0-9_.]/ || nextc ~ /[A-Za-z_]/) continue
    if (tok + 0 == 0) continue
    if (mode == "op" && tok + 0 == 1) continue
    return tok
  }
  return ""
}

# First `name: <number>` argument (non-zero) in a, or "".
function param_num(a, names,   rest, m, tok) {
  rest = a
  while (match(rest, "(^|[^A-Za-z0-9_])(" names "):[ \t\n]*-?[0-9]+(\\.[0-9]+)?")) {
    m = substr(rest, RSTART, RLENGTH)
    rest = substr(rest, RSTART + RLENGTH)
    tok = m; sub(/^.*:[ \t\n]*-?/, "", tok)
    if (tok + 0 != 0) return tok
  }
  return ""
}

# Every `re` match in s (re ends with an open paren); kind picks the test on its arguments.
function each_call(f, s, start, re, kind, label,   rest, off, rs, rl, a, tok, ln) {
  rest = s; off = 0
  while (match(rest, re)) {
    rs = RSTART; rl = RLENGTH
    a = args_at(s, off + rs + rl - 1)
    ln = start + nl_count(substr(s, 1, off + rs))
    rest = substr(rest, rs + rl); off += rs + rl - 1
    tok = ""
    if (kind == "bare")        tok = bare_num(a, "nz")
    else if (kind == "opacity") tok = bare_num(a, "op")
    else if (kind == "frame")  tok = param_num(a, "width|height|minWidth|idealWidth|maxWidth|minHeight|idealHeight|maxHeight")
    else if (kind == "radius") tok = param_num(a, "radius")
    else if (kind == "size")   tok = param_num(a, "size")
    else if (kind == "rgb")    { if (a ~ /^[ \t\n]*red:/) tok = "literal" }
    else if (kind == "rawcolor") tok = raw_color(a)
    if (tok != "") finding(f, ln, label " " tok)
  }
}

# First SwiftUI named color in a (.red, Color.red, .white.opacity(...)), or "".
# Token accessors (Color.accentFill) never match: the name must end the word.
function raw_color(a,   re, t) {
  re = "(^|[^A-Za-z0-9_])(Color)?\\.(white|black|gray|yellow|purple|pink|mint|teal|cyan|indigo|brown|green|red|orange|blue)([^A-Za-z0-9_]|$)"
  if (!match(a, re)) return ""
  t = substr(a, RSTART, RLENGTH)
  sub(/^[^A-Za-z.]/, "", t); sub(/[^A-Za-z0-9_]$/, "", t)
  return t
}

# Plain regex hits, optionally requiring a non-zero number after the colon.
function each_match(f, s, start, re, nz, label,   rest, off, rs, rl, m, tok, ln) {
  rest = s; off = 0
  while (match(rest, re)) {
    rs = RSTART; rl = RLENGTH
    m = substr(rest, rs, rl)
    ln = start + nl_count(substr(s, 1, off + rs))
    rest = substr(rest, rs + rl); off += rs + rl - 1
    if (nz) { tok = m; sub(/^.*:[ \t\n]*-?/, "", tok); if (tok + 0 == 0) continue }
    finding(f, ln, label)
  }
}

function analyze(f, s, start) {
  each_match(f, s, start, "#colorLiteral", 0, "#colorLiteral: use a color token or color set")
  each_call(f, s, start, "(^|[^A-Za-z0-9_])Color\\(", "rgb", "Color(red:, green:, blue:) literal: use a color set or token")
  each_call(f, s, start, "\\.system\\(", "size", "literal font size, use a text style, size:")
  each_call(f, s, start, "\\.padding\\(", "bare", "literal padding, use Spacing.*:")
  each_match(f, s, start, "(^|[^A-Za-z0-9_])spacing:[ \t\n]*-?[0-9]+(\\.[0-9]+)?", 1, "literal spacing: use Spacing.*")
  each_match(f, s, start, "cornerRadius:[ \t\n]*-?[0-9]+(\\.[0-9]+)?", 1, "literal cornerRadius: use Radius.*")
  each_call(f, s, start, "\\.opacity\\(", "opacity", "literal opacity, use an Opacity.* token:")
  each_match(f, s, start, "lineWidth:[ \t\n]*-?[0-9]+(\\.[0-9]+)?", 1, "literal lineWidth: use BorderWidth.*")
  each_call(f, s, start, "\\.frame\\(", "frame", "literal frame size, use ControlHeight, IconSize, LayoutCap or a component constant:")
  each_call(f, s, start, "\\.shadow\\(", "radius", "literal shadow radius, use shadowMd() or Shadow.*:")
  each_match(f, s, start, "\\.(spring|interpolatingSpring|bouncy|snappy)([^A-Za-z0-9_]|$)", 0, "spring animation preset: motion.md rules out springs, use the Motion.* curves")
  each_call(f, s, start, "\\.(foregroundStyle|foregroundColor|tint|fill|stroke|strokeBorder|background|border|shadow)\\(", "rawcolor", "raw system color, use a Color.* token:")
  each_match(f, s, start, "Color\\((uiColor:|nsColor:|cgColor:)?[ \t\n]*\\.(system[A-Z][A-Za-z]*|[a-z]*[lL]abel|separator|opaqueSeparator|link|placeholderText|[a-z][A-Za-z]*Background|[a-z][A-Za-z]*Color)", 0, "UIKit/AppKit system color: use a color set or Color.* token")
  each_match(f, s, start, "(UIColor|NSColor)\\.[a-z]", 0, "UIKit/AppKit color: use a color set or Color.* token")
  each_match(f, s, start, "(^|[^A-Za-z0-9_])duration:[ \t\n]*-?[0-9]+(\\.[0-9]+)?", 1, "literal animation duration: use Motion.duration*")
  each_match(f, s, start, "(^|[^A-Za-z0-9_])\\.(easeIn|easeOut|easeInOut)([^A-Za-z0-9_]|$)", 0, "Animation preset in a view: use Motion.easeOut or Motion.easeStandard")
  each_match(f, s, start, "(^|[^A-Za-z0-9_])Animation\\.(easeIn|easeOut|easeInOut|linear)([^A-Za-z0-9_]|$)", 0, "Animation preset in a view: use Motion.easeOut or Motion.easeStandard")
  each_match(f, s, start, "(^|[^A-Za-z0-9_])\\.linear\\(|(animation|withAnimation)\\([ \t\n]*\\.linear", 0, "Animation preset in a view: use Motion.easeOut or Motion.easeStandard")
}

function count_parens(line) { return count_of(line, "\\(") - count_of(line, "\\)") }

function lint_swift(f,   n, i, buf, bstart, depth) {
  n = swift_clean(f)
  if (n < 0) die(f " not readable")
  buf = ""; depth = 0; bstart = 0
  for (i = 1; i <= n; i++) {
    if (buf == "") {
      if (trim(SL[i]) == "") continue
      bstart = i; buf = SL[i]
    } else buf = buf "\n" SL[i]
    depth += count_parens(SL[i])
    if (depth <= 0) { analyze(f, buf, bstart); buf = ""; depth = 0 }
  }
  if (buf != "") analyze(f, buf, bstart)
}

BEGIN {
  nf = split(ENVIRON["SWIFT_FILES"], files, "\n")
  for (i = 1; i <= nf; i++) {
    if (files[i] == "") continue
    lint_swift(files[i]); nfile++
  }
  if (nfind) {
    printf "swift literals: FAIL (%d finding%s)\n", nfind, (nfind == 1 ? "" : "s")
    exit 1
  }
  if (ENVIRON["QUIET"] != "1") printf "swift literals: OK (%d files)\n", nfile
}
'

export TOKENS SWIFT_TOKENS COLORSETS NUMERIC_TABLE COLOR_TABLE NOT_MIRRORED \
  ALLOW_WEB ALLOW_SWIFT SWIFT_FILES WEB_FILES
export QUIET

status=0
run_phase() {
  local rc=0
  awk "${AWK_COMMON}${1}" </dev/null || rc=$?
  if [ "$rc" -ge 2 ]; then exit 2; fi
  if [ "$rc" -ne 0 ]; then status=1; fi
}

run_phase "$AWK_PARITY"
run_phase "$AWK_WEB"
run_phase "$AWK_SWIFT"

if [ "$status" -ne 0 ]; then
  echo
  echo "FAIL: fix the code, or update design/ and its mirrors together. Never weaken the check."
  exit 1
fi
if [ "$QUIET" -eq 0 ]; then echo "OK: mirrors match design/tokens.css and no literals found"; fi
