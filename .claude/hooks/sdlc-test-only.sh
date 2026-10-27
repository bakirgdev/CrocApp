#!/bin/sh
# PreToolUse hook used only by the sdlc-test-writer agent (agent frontmatter):
# edits are allowed to test files inside the project's repositories only.
# shellcheck source=../sdlc-scripts/lib.sh
. "$(dirname "$0")/../sdlc-scripts/lib.sh"

input=$(cat)
if ! command -v jq >/dev/null 2>&1; then
  echo "sdlc-test-writer guard: jq is required on PATH." >&2
  exit 2
fi
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
[ -n "$file" ] || exit 0
if sdlc_unnormalized_path "$file"; then
  echo "sdlc-test-writer guard: use a normalized path without ./ or ../ segments ($file)." >&2
  exit 2
fi
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
file=$(sdlc_resolve_path "$file" "${cwd:-$SDLC_PROJECT}")
# Match test patterns on the path inside its repository, after symlinks are resolved.
case $file in
  "$SDLC_PROJECT"/?*)
    d=${file%/*}
    while [ -n "$d" ] && [ ! -d "$d" ]; do d=${d%/*}; done
    if repo=$(sdlc_root "$d"); then
      case $file in
        "$repo"/?*) sdlc_is_test_path "${file#"$repo"/}" && exit 0 ;;
      esac
    fi ;;
esac
echo "sdlc-test-writer may edit test files only, and $file is not one (test/, tests/, __tests__/, spec/, e2e/, fixtures/, *.test.*, *.spec.*, *_test.*, test_*, *Test.*). Report the non-test change that is needed instead." >&2
exit 2
