# Phase 2 of scripts/verify-design.sh: contrast.
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
