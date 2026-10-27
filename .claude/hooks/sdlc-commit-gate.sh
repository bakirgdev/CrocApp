#!/bin/sh
# PreToolUse hook (Bash, if "Bash(git commit*)"). Every repository on a branch
# sdlc/<slug> that has code changes needs an accepted sdlc/<slug>/plan.md and a
# passing check command before any commit goes through. Both kinds are always
# checked, whatever the mode:
#   the project's own repository, with $SDLC_VERIFY;
#   each repository directly inside the project (workspace mode), with its
#   command in .claude/sdlc-workspace.yaml.
# Changes to the task files (the project's sdlc/) pass, and so do changes to
# test files alone, which may hold a deliberately failing test (test-first).
# shellcheck source=../sdlc-scripts/lib.sh
. "$(dirname "$0")/../sdlc-scripts/lib.sh"

input=$(cat)
# git and the check commands only ever run inside this project. Which repository
# a command targets is deliberately not parsed (shell parsing is unreliable):
# any command that mentions a commit is judged against every repository here.
if command -v jq >/dev/null 2>&1; then
  # sdlc-implementer commits in its own worktree; its work is verified after the
  # merge. Claude Code sets agent_type; the model cannot.
  [ "$(printf '%s' "$input" | jq -r '.agent_type // empty')" = sdlc-implementer ] && exit 0
  # The hook's "if" filter also lets through commands it cannot parse.
  printf '%s' "$input" | jq -r '.tool_input.command // empty' | grep -qw commit || exit 0
fi

# Prints the repository's changed paths outside the task files: staged,
# unstaged and untracked, because the command may stage files before committing.
# core.fsmonitor is off so a repository's local config cannot start a program.
changed_paths() {
  {
    git -c core.fsmonitor=false -C "$1" diff --cached --name-only
    git -c core.fsmonitor=false -C "$1" diff --name-only
    git -c core.fsmonitor=false -C "$1" ls-files --others --exclude-standard
  } | sort -u | while IFS= read -r f; do
    case $1/$f in "$SDLC_PROJECT"/sdlc/*) ;; *) printf '%s\n' "$f" ;; esac
  done
}

# Judges one repository; exits 2 with a reason when the commit must wait.
check_repo() {
  repo=$1
  slug=$(sdlc_branch_slug "$repo") || return 0
  outside=$(changed_paths "$repo")
  [ -n "$outside" ] || return 0
  name=${repo#"$SDLC_PROJECT"}
  name=${name#/}
  where=${name:+$name: }
  first=$(printf '%s\n' "$outside" | head -n 1)

  status=$(sdlc_field "$SDLC_PROJECT/sdlc/$slug/plan.md" status)
  if [ "$status" != accepted ]; then
    echo "SDLC commit gate: ${where}code is changed ($first, ...) on branch sdlc/$slug but sdlc/$slug/plan.md is not accepted (status: ${status:-missing}). Finish the plan phase (/sdlc-plan $slug) first." >&2
    exit 2
  fi

  if printf '%s\n' "$outside" | while IFS= read -r f; do sdlc_is_test_path "$f" || exit 1; done; then
    return 0
  fi

  if [ "$repo" != "$root" ]; then
    verify=$(sdlc_field "$SDLC_WORKSPACE_FILE" "$name")
    if [ -z "$verify" ]; then
      echo "SDLC commit gate: no check command for repository $name. Add \"$name: <command>\" to .claude/sdlc-workspace.yaml (/sdlc-setup workspace), or \"$name: true\" to opt out." >&2
      exit 2
    fi
  else
    verify=${SDLC_VERIFY:-}
    if [ -z "$verify" ]; then
      echo "SDLC commit gate: SDLC_VERIFY is empty. Run /sdlc-setup verify, or set \"env\": {\"SDLC_VERIFY\": \"<test command>\"} in .claude/settings.json (\"true\" opts out), then restart the session." >&2
      exit 2
    fi
  fi

  out=$(cd "$repo" && sh -c "$verify" 2>&1)
  rc=$?
  [ "$rc" -eq 0 ] && return 0
  {
    echo "SDLC commit gate: ${where}\`$verify\` failed (exit $rc). Fix the code, not the checks, then commit again. Last 40 lines:"
    printf '%s\n' "$out" | tail -n 40
  } >&2
  exit 2
}

root=$(sdlc_root "$SDLC_PROJECT") || root=
[ -n "$root" ] && check_repo "$root"
repos=$(sdlc_repos)
old_ifs=$IFS
IFS='
'
for name in $repos; do
  IFS=$old_ifs
  check_repo "$SDLC_PROJECT/$name"
done
exit 0
