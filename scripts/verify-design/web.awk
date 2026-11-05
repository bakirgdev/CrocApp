# Phase 3 of scripts/verify-design.sh: web raw-color lint.
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
