#!/usr/bin/env bash
# Checks, before `git tag vX.Y.Z`, everything the tag run of release.yml checks
# but a workflow_dispatch rehearsal skips. The v* tag ruleset forbids deleting
# or moving a tag, so a tag run that fails on one of these burns the version.
# Run it on an up-to-date main, at the commit you are about to tag
# (docs/RELEASING.md, "Each release").
#
#   scripts/release-check.sh X.Y.Z    # exit 0 when the tag can be pushed
#
# Needs an authenticated gh.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"

v=${1:-}
case "$v" in
  *[!0-9.]* | "" | *..* | .* | *.) fail "usage: scripts/release-check.sh X.Y.Z (a plain dotted version)" ;;
esac

declared=$(sed -nE 's/^MARKETING_VERSION = ([^ ]+)$/\1/p' app/Config/Version.xcconfig)
[ "$declared" = "$v" ] || fail "Version.xcconfig says MARKETING_VERSION $declared, not $v"
pass "MARKETING_VERSION is $v"

grep -qE "^## \[$v\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$" CHANGELOG.md \
  || fail "CHANGELOG.md has no '## [$v] - YYYY-MM-DD' heading"
grep -qE "^\[$v\]: " CHANGELOG.md || fail "CHANGELOG.md has no '[$v]:' link reference"

# The same extraction as release.yml: it stops at the next version heading or
# at the first link reference, so a link reference inside the section would
# cut the release notes short without an error there.
notes=$(awk -v h="## [$v]" '
  index($0, h) == 1 { found = 1; next }
  found && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  found
' CHANGELOG.md)
[ -n "$(tr -d '[:space:]' <<< "$notes")" ] || fail "the '## [$v]' section in CHANGELOG.md is empty"
# The whole section up to the next version heading, with the link-reference
# block that ends the file and the blank lines around it dropped.
whole=$(awk -v h="## [$v]" '
  index($0, h) == 1 { found = 1; next }
  found && /^## \[/ { exit }
  found { line[++n] = $0 }
  END {
    while (n > 0 && (line[n] ~ /^\[[^]]+\]: / || line[n] ~ /^[[:space:]]*$/)) n--
    for (i = 1; i <= n; i++) print line[i]
  }
' CHANGELOG.md)
[ "$notes" = "$whole" ] \
  || fail "a '[label]: url' line inside the '## [$v]' section would end the release notes there"
pass "CHANGELOG.md section for $v"

build=$(sed -nE 's/^CURRENT_PROJECT_VERSION = ([0-9]+)$/\1/p' app/Config/Version.xcconfig)
[ -n "$build" ] || fail "Version.xcconfig declares no numeric CURRENT_PROJECT_VERSION"
newest=0
if [ -n "$(gh release list --limit 1 --exclude-drafts --exclude-pre-releases --json tagName --jq '.[].tagName')" ]; then
  feed=$(mktemp -d)
  trap 'rm -rf "$feed"' EXIT
  if gh release download --pattern appcast.xml --dir "$feed" 2> /dev/null; then
    newest=$(grep -oE 'sparkle:version(>|=")[0-9]+' "$feed/appcast.xml" | grep -oE '[0-9]+$' | sort -n | tail -n 1 || true)
  fi
fi
[ "$build" -gt "${newest:-0}" ] \
  || fail "CURRENT_PROJECT_VERSION $build is not above $newest, the newest build in the published appcast"
pass "build $build is above the published appcast's newest (${newest:-0})"

if gh release view "v$v" > /dev/null 2>&1; then fail "release v$v already exists"; fi
[ -z "$(git ls-remote --tags origin "refs/tags/v$v")" ] || fail "tag v$v already exists on origin"
pass "no release or tag v$v yet"
