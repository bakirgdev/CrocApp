# Shared helpers for the AI-native SDLC scripts and hooks. POSIX sh; needs git.
# Source it: . "<this dir>/lib.sh"

SDLC_PHASES="intent spec plan build test deploy"

# The project is the folder that holds .claude/. Every caller lives two levels
# below it (.claude/hooks/ or .claude/sdlc-scripts/). Task files always live in
# $SDLC_PROJECT/sdlc/<slug>/.
SDLC_PROJECT=$(cd "$(dirname "$0")/../.." && pwd -P)
SDLC_WORKSPACE_FILE="$SDLC_PROJECT/.claude/sdlc-workspace.yaml"

# True in workspace mode: the project folder holds several git repositories.
sdlc_workspace() {
  [ -f "$SDLC_WORKSPACE_FILE" ]
}

# Workspace repositories: folders directly inside the project that contain .git.
sdlc_repos() {
  for _d in "$SDLC_PROJECT"/*/; do
    [ -e "${_d}.git" ] && basename "$_d"
  done
}

# Repository root of a directory (default: current directory).
sdlc_root() {
  git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null
}

# Prints the task slug when HEAD is on branch sdlc/<slug>; fails otherwise.
sdlc_branch_slug() {
  _b=$(git -C "${1:-.}" symbolic-ref --quiet --short HEAD 2>/dev/null) || return 1
  case $_b in
    sdlc/?*) printf '%s\n' "${_b#sdlc/}" ;;
    *) return 1 ;;
  esac
}

# Artifact file name for a phase.
sdlc_artifact() {
  case $1 in
    intent) echo intent.md ;;
    spec) echo spec.md ;;
    plan) echo plan.md ;;
    build) echo build.md ;;
    test) echo test.md ;;
    deploy) echo deploy.md ;;
    *) return 1 ;;
  esac
}

# True when a path has ./ or ../ segments, which the hooks refuse.
sdlc_unnormalized_path() {
  case $1 in
    . | .. | ./* | ../* | */. | */.. | */./* | */../*) return 0 ;;
  esac
  return 1
}

# Prints the path made absolute (relative to <base>) with its existing directory
# part resolved through symlinks, the way git reports the repository root.
# Usage: sdlc_resolve_path <path> <base>
sdlc_resolve_path() {
  _f=$1
  case $_f in /*) ;; *) _f="$2/$_f" ;; esac
  _d=${_f%/*}
  while [ -n "$_d" ] && [ ! -d "$_d" ]; do _d=${_d%/*}; done
  if [ -n "$_d" ]; then
    printf '%s%s\n' "$(cd "$_d" && pwd -P)" "${_f#"$_d"}"
  else
    printf '%s\n' "$_f"
  fi
}

# True when a path looks like a test file, by the directory and file names
# common test frameworks use.
sdlc_is_test_path() {
  case /${1%/*}/ in
    */test/* | */tests/* | */__tests__/* | */spec/* | */specs/* | */e2e/* | */testdata/* | */fixtures/*) return 0 ;;
  esac
  case ${1##*/} in
    *.test.* | *.spec.* | *_test.* | *_spec.* | test_* | *Test.* | *Tests.*) return 0 ;;
  esac
  return 1
}

# Reads text on stdin and prints the value of the first top-level "key: value"
# line. With is_markdown=1 only YAML frontmatter is searched.
# Usage: sdlc_field_in <key> <is_markdown>
sdlc_field_in() {
  awk -v k="$1" -v md="$2" '
    NR == 1 && $0 == "---" { fm = 1; next }
    NR == 1 && md == 1 { exit }
    fm && $0 == "---" { exit }
    index($0, k ":") == 1 {
      v = substr($0, length(k) + 2)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      if (v ~ /^".*"$/ || v ~ /^\047.*\047$/) v = substr(v, 2, length(v) - 2)
      print v; exit
    }
  '
}

# Value of a key in a task file (task.yaml, or an artifact's frontmatter).
sdlc_field() {
  [ -f "$1" ] || return 1
  case $1 in *.md) _md=1 ;; *) _md=0 ;; esac
  sdlc_field_in "$2" "$_md" < "$1"
}

# Prints sdlc/<slug>/<file>. In workspace mode the files are read from the
# project folder. In single-repo mode, tasks other than the checked-out one are
# read from their branch, because their files exist only there until merged.
# Usage: sdlc_task_file <root> <slug> <file>
sdlc_task_file() {
  if sdlc_workspace; then
    cat "$SDLC_PROJECT/sdlc/$2/$3" 2>/dev/null
  elif [ "$(sdlc_branch_slug "$1")" != "$2" ] &&
    git -C "$1" rev-parse --verify --quiet "refs/heads/sdlc/$2" >/dev/null; then
    git -C "$1" show "sdlc/$2:sdlc/$2/$3" 2>/dev/null
  else
    cat "$1/sdlc/$2/$3" 2>/dev/null
  fi
}

# Usage: sdlc_task_field <root> <slug> <file> <key>
sdlc_task_field() {
  case $3 in *.md) _md=1 ;; *) _md=0 ;; esac
  sdlc_task_file "$1" "$2" "$3" | sdlc_field_in "$4" "$_md"
}

# Prints the main session's context size in tokens: the input, cache read and
# cache write tokens of its last model call, which the next call sends again.
# Prints 0 after a compaction until the next call, and nothing when unknown.
# The transcript is written asynchronously, so the newest call may be missing.
# Its format is undocumented; this reads what Claude Code 2.1 writes.
# Needs jq. Usage: sdlc_context_tokens <transcript_path>
sdlc_context_tokens() {
  tail -n 300 "$1" 2>/dev/null |
    grep -E '"type":"assistant"|"subtype":"compact_boundary"' |
    jq -R -r 'fromjson? | select(.isSidechain != true) |
      if .type == "system" and .subtype == "compact_boundary" then 0
      elif .type == "assistant" and .message.usage then .message.usage |
        (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0) |
        select(. > 0)
      else empty end' |
    tail -n 1
}

# Prints the context size of the session's first model call: system prompt,
# tools, CLAUDE.md and the first prompt, which no compaction can remove.
# Usage: sdlc_context_baseline <transcript_path>
sdlc_context_baseline() {
  grep -m 5 '"type":"assistant"' "$1" 2>/dev/null |
    jq -R -r 'fromjson? | select(.type == "assistant" and .isSidechain != true and .message.usage) |
      .message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' |
    head -n 1
}

# First phase whose artifact is not accepted, or "done".
# Usage: sdlc_current_phase <root> <slug>
sdlc_current_phase() {
  for _p in $SDLC_PHASES; do
    if [ "$(sdlc_task_field "$1" "$2" "$(sdlc_artifact "$_p")" status)" != accepted ]; then
      echo "$_p"
      return 0
    fi
  done
  echo "done"
}
