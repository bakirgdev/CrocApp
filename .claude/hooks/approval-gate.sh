#!/bin/sh
# PreToolUse hook (Edit|Write|MultiEdit|NotebookEdit|Bash). Human-approval gates:
#   ask:  edits to the REVIEW.md "Always human" paths; release actions (v* tag push,
#         gh release, gh workflow run release).
#   deny: force push, direct push to main, gh pr merge --admin. The reason names the route.
# In permission_mode auto (autonomous SDLC sessions) nobody can answer `ask`, so the
# ask tier defers to Claude's own judgment and /sdlc-deploy review (these paths are
# `high` risk there). The deny tier always applies.
# Keep the path list in step with `## Always human` in REVIEW.md.
# shellcheck source=../sdlc-scripts/lib.sh
. "$(dirname "$0")/../sdlc-scripts/lib.sh"

input=$(cat)
if ! command -v jq >/dev/null 2>&1; then
  echo "Approval gate: jq is required on PATH." >&2
  exit 2
fi

decide() { # $1 allow|ask|deny, $2 reason
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}
ask() {
  [ "$mode" = auto ] && exit 0
  decide ask "$1"
}

mode=$(printf '%s' "$input" | jq -r '.permission_mode // empty')
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')

if [ "$tool" = Bash ]; then
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
  push='git[[:space:]]+([^;&|]*[[:space:]])?push([[:space:]]|$)'
  if printf '%s' "$cmd" | grep -Eq "$push[^;&|]*([[:space:]]-f([[:space:]]|\$)|--force)"; then
    decide deny "Approval gate: force push is blocked. Push a normal commit to your branch and land it through a pull request (.github/AGENTS.md)."
  fi
  if printf '%s' "$cmd" | grep -Eq "$push[^;&|]*([[:space:]:]main([[:space:]]|\$)|[[:space:]]HEAD:main)"; then
    decide deny "Approval gate: direct push to main is blocked. Push a branch, open a pull request and merge it once 'ci pass' is green (.github/AGENTS.md)."
  fi
  if printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge[^;&|]*--admin'; then
    decide deny "Approval gate: gh pr merge --admin bypasses the required checks. Wait for 'ci pass', then merge with gh pr merge --squash."
  fi
  if printf '%s' "$cmd" | grep -Eq "$push[^;&|]*([[:space:]]v[0-9]|refs/tags/|--tags)"; then
    ask "Approval gate: pushing a v* tag starts release.yml (sign, notarize, publish). Approve only if the release is intended."
  fi
  if printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+release([[:space:]]|$)|gh[[:space:]]+workflow[[:space:]]+run[^;&|]*release'; then
    ask "Approval gate: release action (gh release / release.yml). Approve only if the release is intended."
  fi
  exit 0
fi

file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$file" ] || exit 0
file=$(sdlc_resolve_path "$file" "${cwd:-$SDLC_PROJECT}")
rel=${file#"$SDLC_PROJECT"/}
[ "$rel" != "$file" ] || exit 0

case $rel in
  crocmobile/session.go | CrocKit/Sources/* | *.entitlements | \
  app/CrocApp/Models/AppSettings.swift | .github/workflows/* | \
  scripts/build-appstore.sh | scripts/build-devid.sh | scripts/build-dmg.sh | \
  app/Config/CrocApp-Direct-Info.plist | app/Config/ExportOptions-*.plist | \
  SECURITY.md | docs/THREAT-MODEL.md | .claude/*)
    ask "Approval gate: $rel is an 'Always human' path in REVIEW.md (transfer path, signing, release, security docs, CI, SDLC config). Approve only if you want this edit." ;;
esac
exit 0
