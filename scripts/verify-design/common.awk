# Shared by every phase of scripts/verify-design.sh: helpers, loaded before the
# phase program. Inputs travel through ENVIRON because a literal newline cannot
# pass through `awk -v`.
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
