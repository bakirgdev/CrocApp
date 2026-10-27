#!/bin/sh
# Status of the AI-native SDLC tasks in this project.
#   status.sh [slug]     task table, then details and the next command for one task
#   status.sh --line     one line for the current task (for your status line script)
#   status.sh --context  SessionStart hook output with the current task's state
# The current task is the checked-out sdlc/<slug> branch: of the project in
# single-repo mode, of the repository you are in (or the only unfinished task)
# in workspace mode.
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib.sh
. "$here/lib.sh"

arg=${1:-}
if sdlc_workspace; then
  root=$SDLC_PROJECT
  r=$(sdlc_root .) && [ "$r" != "$SDLC_PROJECT" ] && cur=$(sdlc_branch_slug "$r") || cur=
else
  root=$(sdlc_root "$SDLC_PROJECT") || { echo "Not inside a git repository."; exit 0; }
  cur=$(sdlc_branch_slug "$root") || cur=
fi

slugs() {
  {
    sdlc_workspace ||
      git -C "$root" for-each-ref --format='%(refname:strip=3)' refs/heads/sdlc/
    for d in "$root"/sdlc/*/; do
      [ -f "${d}task.yaml" ] && basename "$d"
    done
  } 2>/dev/null | sort -u
}

# <slug> -> "phase status" for the first unfinished phase.
progress() {
  _p=$(sdlc_current_phase "$root" "$1")
  if [ "$_p" = "done" ]; then
    echo "done -"
    return
  fi
  _s=$(sdlc_task_field "$root" "$1" "$(sdlc_artifact "$_p")" status)
  echo "$_p ${_s:-not-started}"
}

field() { sdlc_task_field "$root" "$1" task.yaml "$2"; }

# Workspace mode without a current branch: the only unfinished task, if exactly one.
if [ -z "$cur" ] && sdlc_workspace; then
  open=$(for s in $(slugs); do [ "$(sdlc_current_phase "$root" "$s")" = "done" ] || echo "$s"; done)
  [ "$(printf '%s' "$open" | grep -c .)" -eq 1 ] && cur=$open
fi

case $arg in
  --line)
    [ -n "$cur" ] || exit 0
    # shellcheck disable=SC2046
    set -- $(progress "$cur")
    echo "sdlc:$cur $1 ($2) $(field "$cur" gate_mode)/$(field "$cur" run_mode)"
    exit 0 ;;
  --context)
    [ -n "$cur" ] || exit 0
    # shellcheck disable=SC2046
    set -- $(progress "$cur")
    text="SDLC task $cur: phase $1 (artifact status $2), gate_mode $(field "$cur" gate_mode), run_mode $(field "$cur" run_mode). Files are the source of truth: re-read sdlc/$cur/task.yaml and the current phase's artifact before continuing."
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg t "$text" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $t}}'
    else
      printf '%s\n' "$text"
    fi
    exit 0 ;;
esac

all=$(slugs)
if [ -z "$all" ]; then
  echo "No SDLC tasks yet. Start one with /sdlc-intent <idea>."
  exit 0
fi

printf '  %-32s %-7s %-12s %-10s %s\n' TASK PHASE STATUS GATE RUN
for s in $all; do
  # shellcheck disable=SC2046
  set -- $(progress "$s")
  mark=" "
  [ "$s" = "$cur" ] && mark="*"
  printf '%s %-32s %-7s %-12s %-10s %s\n' "$mark" "$s" "$1" "$2" "$(field "$s" gate_mode)" "$(field "$s" run_mode)"
done

sel=${arg:-$cur}
if [ -z "$sel" ] && [ "$(printf '%s\n' "$all" | wc -l)" -eq 1 ]; then
  sel=$all
fi
[ -n "$sel" ] || exit 0
if [ -z "$(sdlc_task_file "$root" "$sel" task.yaml)" ]; then
  echo
  echo "No task '$sel'."
  exit 0
fi

echo
echo "Task $sel: $(field "$sel" title)"
if sdlc_workspace; then
  echo "  pr $(field "$sel" pr), repos: $(field "$sel" repos)"
  for r in $(field "$sel" repos | tr ',' ' '); do
    if [ ! -e "$root/$r/.git" ]; then
      printf '    %-20s %s\n' "$r" "missing from the workspace"
    elif git -C "$root/$r" rev-parse --verify --quiet "refs/heads/sdlc/$sel" >/dev/null; then
      printf '    %-20s %s, on %s, %s changed\n' "$r" "branch sdlc/$sel" \
        "$(git -C "$root/$r" branch --show-current)" "$(git -c core.fsmonitor=false -C "$root/$r" status --porcelain | grep -c .)"
    else
      printf '    %-20s %s\n' "$r" "no branch sdlc/$sel yet"
    fi
  done
else
  echo "  branch sdlc/$sel, pr $(field "$sel" pr)"
fi
for p in $SDLC_PHASES; do
  a=$(sdlc_artifact "$p")
  st=$(sdlc_task_field "$root" "$sel" "$a" status)
  by=$(sdlc_task_field "$root" "$sel" "$a" approved_by)
  printf '  %-7s %-10s %-12s %s\n' "$p" "$a" "${st:--}" "${by:+approved by $by}"
done
echo
# next.sh exits non-zero while a phase is unfinished; status is informational and
# must exit 0, because a failing command aborts the skills that embed this output.
"$here/next.sh" "$sel" --print || true
