# Phase 1 of scripts/verify-design.sh: mirror parity.
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
