#!/usr/bin/env bash
# shellcheck disable=SC2016  # awk programs in single quotes: awk expands them, not the shell
# Keeps the repository's markdown pointing at things that exist (docs/AGENTS.md,
# "Keeping docs true"). Checks every .md file outside web/docs/content/,
# which the Docusaurus build checks itself, .claude/** and sdlc/**, plus new
# ones not yet committed:
#
#   1. Relative links. `[text](path)` and `[text](path#anchor)` resolve to a
#      tracked file or directory, and an anchor matches a heading in its target.
#   2. Repo paths. An inline-code span that names a repo path (`scripts/x.sh`,
#      `docs/knowledge/`, a sibling `tooling.md`) exists. A gitignored build
#      output (`CrocKit/Croc.xcframework/`) counts as existing.
#   3. Stale markers, in docs/ and the AGENTS.md files: dates and the
#      planning IDs (R12, F31, O9, B23, W4), which go stale (docs/AGENTS.md,
#      "Writing rules"), and section-number citations, which rot on every
#      re-order.
#   4. Images. The URL in an HTML `src="..."` or `srcset="..."` attribute
#      resolves like a relative link (http(s) URLs are skipped).
#   5. Unused screenshots. Every PNG in assets/screenshots/ is shown by a
#      markdown image, or is the source of a web WebP copy at the same relative
#      path (web/docs/screenshots/, web/landing/assets/img/screenshots/).
#
#   scripts/verify-docs.sh     # findings as path:line: message, exit 1 on any
#
# Fenced code blocks are skipped. Known limits: reference-style links and link
# titles are not checked, an image attribute whose value spans lines is not
# checked, and anchors follow GitHub's slug rule for ASCII
# headings only, without the `-1` suffix a repeated heading gets. Pure bash and POSIX awk, so CI runs it on a
# bare runner. Exit 0 clean, 1 findings.
set -euo pipefail
cd "$(dirname "$0")/.."
export LC_ALL=C

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Tracked and new docs still on disk (a deletion not yet staged is not a doc).
git ls-files --cached --others --exclude-standard '*.md' ':!:web/docs/content/**' ':!:.claude/**' ':!:sdlc/**' | sort -u | while IFS= read -r f; do
  [ -f "$f" ] && echo "$f"
done > "$TMP/files"
# Every tracked file plus every directory above one: the set a path may name.
# Untracked files count too, so a new doc can be linked before its first commit.
git ls-files --cached --others --exclude-standard |
  awk '{ print; while (sub("/[^/]*$", "")) print $0 "/" }' | sort -u > "$TMP/tracked"

# One line per candidate: file<TAB>line<TAB>kind<TAB>target. Kinds: link, code.
while IFS= read -r f; do
  awk -v file="$f" '
    /^[ \t]*(```|~~~)/ {
      m = $0; sub(/^[ \t]*/, "", m); m = substr(m, 1, 3)
      if (fence == "") fence = m; else if (m == fence) fence = ""
      next
    }
    fence != "" { next }
    {
      line = $0
      # inline code spans
      s = line
      while (match(s, /`[^`]+`/)) {
        print file "\t" FNR "\tcode\t" substr(s, RSTART + 1, RLENGTH - 2)
        s = substr(s, RSTART + RLENGTH)
      }
      # markdown links, outside code spans
      gsub(/`[^`]*`/, "", line)
      s = line
      while (match(line, /\]\([^) ]+\)/)) {
        print file "\t" FNR "\tlink\t" substr(line, RSTART + 2, RLENGTH - 3)
        line = substr(line, RSTART + RLENGTH)
      }
      # HTML image attributes: src="x" and srcset="x 1x, y 2x" (data-src does not match)
      while (match(s, /[ \t](src|srcset)="[^"]*"/)) {
        a = substr(s, RSTART, RLENGTH)
        s = substr(s, RSTART + RLENGTH)
        sub(/^[ \t]+(src|srcset)="/, "", a); sub(/"$/, "", a)
        n = split(a, cand, ",")
        for (i = 1; i <= n; i++) {
          split(cand[i], word, " ")
          if (word[1] != "") print file "\t" FNR "\timage\t" word[1]
        }
      }
    }' "$f"
done < "$TMP/files" > "$TMP/candidates"

# Resolves every candidate in one awk pass over the tracked set. Prints
# file<TAB>line<TAB>message for a failure, or file<TAB>line<TAB>?path for a
# path to retry against .gitignore (build outputs exist only after a build).
awk -F'\t' -v top='^(\\.github|app|assets|CrocKit|crocmobile|design|docs|scripts|web)/' '
  function normalize(p,   n, part, i, k, out, s) {
    n = split(p, part, "/"); k = 0
    for (i = 1; i <= n; i++) {
      if (part[i] == "" || part[i] == ".") continue
      if (part[i] == "..") { if (k > 0) k--; continue }
      out[++k] = part[i]
    }
    s = ""; for (i = 1; i <= k; i++) s = s (i > 1 ? "/" : "") out[i]
    return s
  }
  function have(p) { sub(/\/$/, "", p); return (p in known) }
  function check(p) { if (!have(p)) print file "\t" n "\t?" p }
  FILENAME == ARGV[1] {
    sub(/\/$/, "")
    known[$0] = 1
    b = $0; sub(/.*\//, "", b); base[b] = 1
    next
  }
  {
    file = $1; n = $2; kind = $3; t = $4
    dir = file; if (!sub(/\/[^\/]*$/, "", dir)) dir = "."
    if (kind == "image") {
      if (t ~ /^https?:/) next
      path = t
      if (match(path, /[#?]/)) path = substr(path, 1, RSTART - 1)
      if (path == "") next
      target = normalize(dir "/" path)
      if (!have(target)) print file "\t" n "\tbroken image: " t
      print file "\t" n "\t@" target
      next
    }
    if (kind == "link") {
      if (t ~ /^(https?|mailto):/) next
      path = t; anchor = ""
      if (index(t, "#")) { path = substr(t, 1, index(t, "#") - 1); anchor = substr(t, index(t, "#") + 1) }
      target = path == "" ? file : normalize(dir "/" path)
      if (path != "" && !have(target)) { print file "\t" n "\tbroken link: " t; next }
      if (anchor != "" && target ~ /\.md$/) print file "\t" n "\t#" target "#" anchor "#" t
      next
    }
    # Only spans that are a bare path: no spaces, globs or placeholders.
    if (t !~ /^[A-Za-z0-9._\/:-]+$/ || t ~ /\/\/|^-|\/\./) next
    path = t; sub(/:.*/, "", path)
    if (path ~ top) check(path)
    else if (path ~ /^\.\.?\//) { if (!have(normalize(dir "/" path))) check(normalize(path)) }
    else if (path !~ /\// && path ~ /.\.md$/) { if (!(path in base)) print file "\t" n "\tno such file: `" t "`" }
  }' "$TMP/tracked" "$TMP/candidates" > "$TMP/resolved"

findings=0
finding() { echo "$1:$2: $3"; findings=$((findings + 1)); }

# GitHub's heading anchors for a markdown file, one per line.
anchors() {
  awk '
    /^[ \t]*(```|~~~)/ {
      m = $0; sub(/^[ \t]*/, "", m); m = substr(m, 1, 3)
      if (fence == "") fence = m; else if (m == fence) fence = ""
      next
    }
    fence != "" || !/^#+ / { next }
    {
      h = $0
      sub(/^#+ +/, "", h)
      h = tolower(h)
      gsub(/[^a-z0-9 _-]/, "", h)
      gsub(/ /, "-", h)
      print h
    }' "$1"
}

while IFS=$'\t' read -r f n msg; do
  case $msg in
    \?*)
      # A missing path cannot match a directory-only pattern (`dir/`) unless it
      # ends in a slash, so try both: a fresh clone has no build outputs.
      p=${msg#\?}
      p=${p%/}
      git check-ignore -q -- "$p" 2>/dev/null || git check-ignore -q -- "$p/" 2>/dev/null ||
        finding "$f" "$n" "no such path: \`$p\`"
      ;;
    \#*)
      rest=${msg#\#}
      target=${rest%%#*}
      rest=${rest#*#}
      anchor=${rest%%#*}
      anchors "$target" > "$TMP/anchors"
      grep -qxF -- "$anchor" "$TMP/anchors" || finding "$f" "$n" "no heading for anchor: ${rest#*#}"
      ;;
    @*) echo "${msg#@}" >> "$TMP/shown" ;;
    *) finding "$f" "$n" "$msg" ;;
  esac
done < "$TMP/resolved"

# Screenshots: a tracked or new PNG in assets/screenshots/ must be shown by a
# markdown image or be the source of a web WebP copy at the same relative path.
: >> "$TMP/shown"
while IFS= read -r w; do
  case $w in
    web/docs/screenshots/*) rel=${w#web/docs/screenshots/} ;;
    *) rel=${w#web/landing/assets/img/screenshots/} ;;
  esac
  echo "assets/screenshots/${rel%.webp}.png" >> "$TMP/shown"
done < <(git ls-files --cached --others --exclude-standard 'web/docs/screenshots/*.webp' 'web/landing/assets/img/screenshots/*.webp')
sort -u "$TMP/shown" -o "$TMP/shown"
while IFS= read -r png; do
  [ -f "$png" ] || continue
  if ! grep -qxF -- "$png" "$TMP/shown"; then
    echo "$png: unused screenshot: no markdown image or web WebP copy shows it. Publish it or git rm it (docs/knowledge/screenshots.md, \"Where they are used\")"
    findings=$((findings + 1))
  fi
done < <(git ls-files --cached --others --exclude-standard 'assets/screenshots/*.png')

# Stale markers: only where docs/AGENTS.md applies. CHANGELOG.md keeps its
# dated release headings, which release.yml parses.
{ grep -E '^docs/|(^|/)AGENTS\.md$' "$TMP/files" || true; } > "$TMP/strict"
while IFS= read -r f; do
  awk -v file="$f" '
    /^[ \t]*(```|~~~)/ {
      m = $0; sub(/^[ \t]*/, "", m); m = substr(m, 1, 3)
      if (fence == "") fence = m; else if (m == fence) fence = ""
      next
    }
    fence != "" { next }
    {
      s = " " $0 " "
      if (match(s, /[^0-9]20[0-9][0-9]-[01][0-9]-[0-3][0-9][^0-9]/))
        print file ":" FNR ": date: " substr(s, RSTART + 1, 10)
      if (match(s, /[^A-Za-z0-9_][BFORW][0-9][0-9]?[a-z]?[^A-Za-z0-9_]/))
        print file ":" FNR ": planning ID: " substr(s, RSTART + 1, RLENGTH - 2)
      if (match(tolower(s), /(section|§) ?[0-9]/))
        print file ":" FNR ": section-number citation, cite the heading text"
    }' "$f"
done < "$TMP/strict" > "$TMP/markers"
while IFS= read -r m; do
  echo "$m"
  findings=$((findings + 1))
done < "$TMP/markers"

if [ "$findings" -gt 0 ]; then
  echo "FAIL: $findings finding(s). Fix the doc, or the path it names; never the check."
  exit 1
fi
echo "PASS: links, images, repo paths, stale markers and screenshot use in $(wc -l < "$TMP/files" | tr -d ' ') markdown files"
