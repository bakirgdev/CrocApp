#!/bin/sh
# Starts a task's next SDLC phase in a fresh, named session.
#   next.sh <slug> [--phase P] [--model M] [--effort E] [--permission MODE] [--print]
#   next.sh --defaults
# run_mode manual (or --print): prints the command to run in a new terminal.
# run_mode autonomous: launches the phase as a background session (claude --bg).
# Precedence: task.yaml <phase>_model|_effort|_permission (the user's choice for this
# task) > flags (Claude's weighed choice) > the defaults below.
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=lib.sh
. "$here/lib.sh"

# <phase> -> "model effort permission"
defaults() {
  case $1 in
    intent) echo "opus high acceptEdits" ;;
    spec) echo "opus xhigh acceptEdits" ;;
    plan) echo "opus xhigh plan" ;;
    build) echo "sonnet high auto" ;;
    test) echo "sonnet high auto" ;;
    deploy) echo "opus high default" ;;
    maintain) echo "opus high default" ;;
    setup) echo "opus high default" ;;
    *) return 1 ;;
  esac
}

usage="usage: next.sh <slug> [--phase P] [--model M] [--effort E] [--permission MODE] [--print] | next.sh --defaults"

if [ "${1:-}" = --defaults ]; then
  printf '%-9s %-7s %-7s %s\n' phase model effort permission
  for p in $SDLC_PHASES maintain setup; do
    # shellcheck disable=SC2046
    set -- $(defaults "$p")
    printf '%-9s %-7s %-7s %s\n' "$p" "$1" "$2" "$3"
  done
  echo "run_mode autonomous: every phase defaults to permission auto."
  echo "gate_mode auto: plan defaults to permission auto instead of plan mode."
  exit 0
fi

slug=${1:-}
case $slug in '' | -*) echo "$usage" >&2; exit 64 ;; esac
shift
phase='' f_model='' f_effort='' f_perm='' print=0
while [ $# -gt 0 ]; do
  case $1 in
    --phase | --model | --effort | --permission)
      [ $# -ge 2 ] || { echo "$usage" >&2; exit 64; }
      case $1 in
        --phase) phase=$2 ;;
        --model) f_model=$2 ;;
        --effort) f_effort=$2 ;;
        --permission) f_perm=$2 ;;
      esac
      shift 2 ;;
    --print) print=1; shift ;;
    *) echo "$usage" >&2; exit 64 ;;
  esac
done

if sdlc_workspace; then
  root=$SDLC_PROJECT
else
  root=$(sdlc_root "$SDLC_PROJECT") || { echo "next.sh: not inside a git repository." >&2; exit 1; }
fi
if [ -z "$(sdlc_task_file "$root" "$slug" task.yaml)" ]; then
  echo "next.sh: no task '$slug' (sdlc/$slug/task.yaml not found)." >&2
  exit 1
fi
tf() { sdlc_task_field "$root" "$slug" task.yaml "$1"; }

prev_phase() {
  _prev=
  for _p in $SDLC_PHASES; do
    [ "$_p" = "$1" ] && { [ -n "$_prev" ] && echo "$_prev"; return 0; }
    _prev=$_p
  done
}

q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

if [ -z "$phase" ]; then
  phase=$(sdlc_current_phase "$root" "$slug")
  if [ "$phase" = "done" ]; then
    echo "Task $slug is complete: every phase is accepted."
    exit 0
  fi
  art=$(sdlc_artifact "$phase")
  st=$(sdlc_task_field "$root" "$slug" "$art" status)
  if [ -n "$st" ]; then
    echo "sdlc/$slug/$art is '$st', so the $phase phase is not finished; it must be accepted before the next phase starts."
    echo "Reopen that phase's session: claude -r $(q "$slug-$phase")"
    echo "Or start it again in a new session: .claude/sdlc-scripts/next.sh $slug --phase $phase"
    exit 3
  fi
fi

case " $SDLC_PHASES " in
  *" $phase "*) ;;
  *) echo "next.sh: '$phase' is not a task phase ($SDLC_PHASES)." >&2; exit 64 ;;
esac
d=$(defaults "$phase") || { echo "next.sh: unknown phase '$phase'." >&2; exit 64; }
# shellcheck disable=SC2086
set -- $d
d_model=$1 d_effort=$2 d_perm=$3
if [ "$(tf run_mode)" = autonomous ]; then
  d_perm=auto
elif [ "$phase" = plan ] && [ "$(tf gate_mode)" = auto ]; then
  d_perm=auto
fi

model=$(tf "${phase}_model"); model=${model:-${f_model:-$d_model}}
effort=$(tf "${phase}_effort"); effort=${effort:-${f_effort:-$d_effort}}
perm=$(tf "${phase}_permission"); perm=${perm:-${f_perm:-$d_perm}}

for v in "$model" "$effort"; do
  case $v in
    *[!A-Za-z0-9._[\]-]* | '')
      echo "next.sh: invalid model or effort value '$v' (check task.yaml)." >&2
      exit 64 ;;
  esac
done

case $perm in
  bypassPermissions) perm_args="--dangerously-skip-permissions" ;;
  acceptEdits | auto | default | dontAsk | manual | plan) perm_args="--permission-mode $perm" ;;
  *) echo "next.sh: unknown permission mode '$perm'." >&2; exit 64 ;;
esac

name="$slug-$phase"
prompt="/sdlc-$phase $slug"
prev=$(prev_phase "$phase")

# Never start a permission-bypassing session without a person running the command.
if [ "$print" -eq 1 ] || [ "$(tf run_mode)" != autonomous ] || [ "$perm" = bypassPermissions ]; then
  [ "$perm" = bypassPermissions ] && [ "$print" -eq 0 ] &&
    echo "Not starting automatically: this phase is set to bypassPermissions."
  echo "Next phase: $phase (model $model, effort $effort, permission $perm)"
  echo "Start it in a new terminal:"
  echo
  echo "  cd $(q "$root") && claude -n $(q "$name") --model $(q "$model") --effort $effort $perm_args $(q "$prompt")"
  echo
  [ -n "$prev" ] && echo "Optional, reopen the previous phase's session: claude -r $(q "$slug-$prev")"
  exit 0
fi

cd "$root" || exit 1
# No one is there to run /compact, so auto-compact takes over at the size where
# the context gate asks for it in interactive sessions (instead of near 1M).
compact_args=
r=${SDLC_COMPACT_REQUIRE:-350000}
case $r in
  '' | *[!0-9]* | 0?*) ;;
  *) [ "$r" -ge 100000 ] && [ "$r" -le 1000000 ] && compact_args="--autocompact $r" ;;
esac
echo "Starting the $phase phase in the background (model $model, effort $effort, permission $perm)."
# Sessions started from inside Claude Code are hidden from `claude agents` unless
# these markers are cleared.
# shellcheck disable=SC2086
env -u CLAUDE_CODE_CHILD_SESSION -u CLAUDECODE \
  claude --bg -n "$name" --model "$model" --effort "$effort" $perm_args $compact_args "$prompt"
rc=$?
[ "$rc" -eq 0 ] && echo "Follow it with: claude agents (\"Needs input\" means it is waiting for you), or claude attach $(q "$name")"
exit "$rc"
