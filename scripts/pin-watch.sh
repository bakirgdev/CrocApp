#!/usr/bin/env bash
# Checks the pins Dependabot does not update (docs/knowledge/tooling.md,
# "Keeping versions current") against the newest stable upstream release and
# prints a markdown report. The weekly pin-watch workflow keeps one issue in
# step with it.
#
#   scripts/pin-watch.sh     # report on stdout; exit 0 when every pin is current, 1 otherwise
#
# Needs curl, jq and an authenticated gh (GH_TOKEN in CI).
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"

stale=0
rows=""
row() { # row NAME FILE PINNED LATEST
  local mark="current"
  [ -n "$4" ] || fail "no upstream version found for $1"
  if [ "$3" != "$4" ]; then
    mark="**differs**"
    stale=1
  fi
  rows+="| $1 | \`$2\` | $3 | $4 | $mark |"$'\n'
}

# Newest file name matching a pattern in a runner-images toolset directory.
toolsets() { gh api "repos/actions/runner-images/contents/images/$1/toolsets" --jq '.[].name'; }

xcode_pin=$(cat .xcode-version)
xcode_major=${xcode_pin%%.*}
# Stable only: the toolset lists betas and release candidates in their file names.
xcode_runner=$(gh api "repos/actions/runner-images/contents/images/macos/toolsets/toolset-xcode-$xcode_major.json" --jq .content \
  | base64 -d | jq -r '.xcode.arm64.versions[] | select(.filename | test("beta|Release_Candidate"; "i") | not) | .link' \
  | sort -V | tail -1)
row "Xcode (newest stable on the \`xcode-$xcode_major\` runner)" .xcode-version "$xcode_pin" "$xcode_runner"

node_pin=$(cat web/docs/.nvmrc)
node_latest=$(curl -fsS https://nodejs.org/dist/index.json \
  | jq -r --arg m "v${node_pin%%.*}." '[.[] | select(.version | startswith($m))][0].version | ltrimstr("v")')
row "Node ${node_pin%%.*}" web/docs/.nvmrc "$node_pin" "$node_latest"

pnpm_pin=$(jq -r '.packageManager | ltrimstr("pnpm@")' web/docs/package.json)
row pnpm web/docs/package.json "$pnpm_pin" "$(curl -fsS https://registry.npmjs.org/pnpm/latest | jq -r .version)"

go_pin=$(awk '$1 == "go" {print $2}' crocmobile/go.mod)
row Go crocmobile/go.mod "$go_pin" "$(curl -fsS 'https://go.dev/dl/?mode=json' | jq -r '.[0].version | ltrimstr("go")')"

v10_pin=$(cat scripts/croc-v10.version)
row "croc v10 test peer" scripts/croc-v10.version "$v10_pin" \
  "$(gh api repos/schollz/croc/tags --paginate --jq '.[].name' | grep -E '^v10\.[0-9]+\.[0-9]+$' | sort -V | tail -1)"

lint_pin=$(awk '/golangci-lint-action/ {f=1} f && $1 == "version:" {print $2; exit}' .github/workflows/reusable-go.yml)
row golangci-lint .github/workflows/reusable-go.yml "$lint_pin" "$(gh api repos/golangci/golangci-lint/releases/latest --jq .tag_name)"

# Tools a workflow downloads by checksum: the *_VERSION env value next to the download.
pinned_env() { awk -v k="$1:" '$1 == k {print $2; exit}' "$2"; }
row shfmt .github/workflows/ci.yml "$(pinned_env SHFMT_VERSION .github/workflows/ci.yml)" \
  "$(gh api repos/mvdan/sh/releases/latest --jq .tag_name)"
row create-dmg .github/workflows/release.yml "$(pinned_env CREATE_DMG_VERSION .github/workflows/release.yml)" \
  "$(gh api repos/create-dmg/create-dmg/releases/latest --jq .tag_name)"

ubuntu_pin=$(grep -ho 'ubuntu-[0-9][0-9]\.[0-9][0-9]' .github/workflows/*.yml | sort -u | tail -1)
ubuntu_latest=$(toolsets ubuntu | sed -nE 's/^toolset-([0-9]{2})([0-9]{2})\.json$/ubuntu-\1.\2/p' | sort -V | tail -1)
row "Ubuntu runner" ".github/workflows/" "$ubuntu_pin" "$ubuntu_latest"

macos_toolsets=$(toolsets macos)
macos_pin=$(grep -ho 'macos-[0-9][0-9]*' .github/workflows/*.yml | sort -u | tail -1)
row "macOS runner" ".github/workflows/" "$macos_pin" \
  "$(echo "$macos_toolsets" | sed -nE 's/^toolset-([0-9]+)\.json$/macos-\1/p' | sort -V | tail -1)"
row "Xcode runner" ".github/workflows/" "$(grep -ho 'xcode-[0-9][0-9]*' .github/workflows/*.yml | sort -u | tail -1)" \
  "$(echo "$macos_toolsets" | sed -nE 's/^toolset-(xcode-[0-9]+)\.json$/\1/p' | sort -V | tail -1)"

cat << EOF
| Pin | File | Pinned | Newest stable | |
|---|---|---|---|---|
$rows
How to bump each one: \`docs/knowledge/tooling.md\`, "Keeping versions current".
EOF
exit "$stale"
