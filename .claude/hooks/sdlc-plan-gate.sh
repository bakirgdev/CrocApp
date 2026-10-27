#!/bin/sh
# PreToolUse hook (Edit|Write|MultiEdit|NotebookEdit). When the edited file's
# repository is on branch sdlc/<slug>, wherever it lives, blocks the edit until
# sdlc/<slug>/plan.md (in the project folder) is accepted. The task files in the
# project's sdlc/ and files in no repository (for example plan-mode drafts in
# ~/.claude/plans) pass. Works in single-repo and workspace mode alike.
# shellcheck source=../sdlc-scripts/lib.sh
. "$(dirname "$0")/../sdlc-scripts/lib.sh"

input=$(cat)
if ! command -v jq >/dev/null 2>&1; then
  for r in "$SDLC_PROJECT" $(sdlc_repos | sed "s|^|$SDLC_PROJECT/|"); do
    sdlc_branch_slug "$r" >/dev/null || continue
    echo "SDLC plan gate: jq is required on PATH while an sdlc/ branch is checked out." >&2
    exit 2
  done
  exit 0
fi

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$file" ] || exit 0
if sdlc_unnormalized_path "$file"; then
  echo "SDLC plan gate: use a normalized path without ./ or ../ segments ($file)." >&2
  exit 2
fi
file=$(sdlc_resolve_path "$file" "${cwd:-$SDLC_PROJECT}")
case $file in
  "$SDLC_PROJECT"/sdlc/*) exit 0 ;;
esac

# The repository that holds the file (git only reads, nothing runs from it).
d=${file%/*}
while [ -n "$d" ] && [ ! -d "$d" ]; do d=${d%/*}; done
[ -n "$d" ] || exit 0
repo=$(sdlc_root "$d") || exit 0
slug=$(sdlc_branch_slug "$repo") || exit 0

status=$(sdlc_field "$SDLC_PROJECT/sdlc/$slug/plan.md" status)
[ "$status" = accepted ] && exit 0
echo "SDLC plan gate: ${file#"$SDLC_PROJECT"/} is on branch sdlc/$slug and sdlc/$slug/plan.md is not accepted (status: ${status:-missing}). Finish the plan phase (/sdlc-plan $slug) before changing code." >&2
exit 2
