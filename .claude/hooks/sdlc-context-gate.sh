#!/bin/sh
# UserPromptSubmit and PreToolUse hook. Claude cannot run /compact, so once the
# main session's context is large enough to hurt answers, this asks Claude to
# recommend it and, past a hard limit, pauses work until the user compacts.
#   SDLC_COMPACT_SUGGEST tokens: on the next user prompt, Claude ends its reply
#     with the best next move (/compact <focus>, the handoff, or /clear).
#     Repeats every STEP tokens.
#   SDLC_COMPACT_REQUIRE tokens: on the next tool call, Claude may finish only
#     small work. WRAPUP tokens later, every tool call is denied except what
#     saving the task's state and ending its phase need, so Claude saves the
#     unfinished state and asks for /compact. A reply from the user other than /compact resumes
#     work for SNOOZE more tokens, so the block never becomes a dead end.
# Sizes are total context tokens (what each model call sends). Nothing happens
# while compaction would free less than MINGAIN tokens. 0 turns a stage off.
# Subagents are never blocked. Background sessions (CLAUDE_JOB_DIR) are never
# paused, because no one may be there to compact; next.sh starts them with
# --autocompact instead.
# shellcheck source=../sdlc-scripts/lib.sh
. "$(dirname "$0")/../sdlc-scripts/lib.sh"

STEP=50000 WRAPUP=40000 SNOOZE=100000 MINGAIN=100000

input=$(cat)
# The gate only advises and paces work, so without jq it stays out of the way.
command -v jq >/dev/null 2>&1 || exit 0

j() { printf '%s' "$input" | jq -r "$1 // empty"; }
event=$(j .hook_event_name)
sid=$(j .session_id)
transcript=$(j .transcript_path)
[ -z "$(j .agent_id)" ] || exit 0
case $sid in '' | *[!A-Za-z0-9_-]*) exit 0 ;; esac
[ -f "$transcript" ] || exit 0

suggest=${SDLC_COMPACT_SUGGEST:-200000}
require=${SDLC_COMPACT_REQUIRE:-350000}
for v in "$suggest" "$require"; do
  # Leading zeros would make shell arithmetic read the value as octal.
  case $v in
    '' | *[!0-9]* | 0?*)
      echo "SDLC context gate: SDLC_COMPACT_SUGGEST and SDLC_COMPACT_REQUIRE must be token counts (0 turns a stage off)." >&2
      exit 1 ;;
  esac
done

# Per-user state, never a shared /tmp where others could plant or swap files.
dir=${XDG_STATE_HOME:-$HOME/.local/state}/sdlc-context-gate
state=$dir/$sid
tokens=$(sdlc_context_tokens "$transcript")
low=$suggest
if [ "$require" -ne 0 ] && { [ "$low" -eq 0 ] || [ "$require" -lt "$low" ]; }; then
  low=$require
fi
# Unknown (not written yet): keep the state and wait for the next call.
[ -n "$tokens" ] || exit 0
if [ "$low" -eq 0 ] || [ "$tokens" -lt "$low" ]; then
  # Below every threshold, or just compacted: start over.
  rm -f "$state"
  exit 0
fi
# A large fixed context (many skills, tools, a big CLAUDE.md) is not what
# compaction removes; act only when it can free a meaningful amount.
baseline=$(sdlc_context_baseline "$transcript")
[ $((tokens - ${baseline:-0})) -ge "$MINGAIN" ] || exit 0

# State: last suggested size, size up to which the user allowed work, whether
# work is blocked, whether the wrap-up warning was given.
suggested=0 allowed=0 blocked=0 warned=0
[ -f "$state" ] && read -r suggested allowed blocked warned <"$state"
num() { case $1 in '' | *[!0-9]*) echo 0 ;; *) echo "$1" ;; esac; }
suggested=$(num "$suggested") allowed=$(num "$allowed")
blocked=$(num "$blocked") warned=$(num "$warned")
# Hooks for parallel tool calls run at the same time: replace the file whole.
save() {
  mkdir -p "${dir%/*}" && { [ -d "$dir" ] || mkdir -m 700 "$dir"; } &&
    _tmp=$(mktemp "$state.XXXXXX") &&
    printf '%s %s %s %s\n' "$suggested" "$allowed" "$blocked" "$warned" >"$_tmp" &&
    mv -f "$_tmp" "$state"
}
k() { echo "$(($1 / 1000))K"; }
context() {
  jq -n --arg e "$event" --arg t "$1" '{hookSpecificOutput: {hookEventName: $e, additionalContext: $t}}'
}

limit=$((require + WRAPUP))
[ "$allowed" -gt "$limit" ] && limit=$allowed

if [ "$event" = UserPromptSubmit ]; then
  # Task reports and messages from other sessions arrive as prompts in angle
  # brackets; only a person's reply lifts a block.
  case $(j .prompt) in
    '<'*) person=0 ;;
    *) person=1 ;;
  esac
  if [ "$blocked" = 1 ] && [ "$person" = 1 ]; then
    blocked=0 allowed=$((tokens + SNOOZE))
    save
    context "SDLC context gate: the context is about $(k "$tokens") tokens and the user answered without compacting, so tools work again until about $(k "$allowed"). Do what the user asked. Keep the task's artifact current, because the next pause asks for /compact again."
    exit 0
  fi
  [ "$blocked" = 0 ] && [ "$suggest" -ne 0 ] && [ "$tokens" -ge "$suggest" ] &&
    [ "$tokens" -ge $((suggested + STEP)) ] || exit 0
  suggested=$tokens
  save
  context "SDLC context gate: this session's context is about $(k "$tokens") tokens, and answers get less reliable as it grows. Handle this message first. Then end your reply with one line that recommends the best next move, and stop there:
- the work in this session continues: \`/compact <focus>\`, with a focus you draft (the task and phase, the next step, decisions and open questions not yet written down). On an SDLC task, first record the unfinished state in the current artifact so the summary can lose nothing;
- the phase's artifact is accepted: the handoff command from next.sh, because the next phase starts in a new session;
- the next request is unrelated: \`/clear\` or a new session.
Skip the line when one of these is already the obvious next step you are taking."
  exit 0
fi

[ "$event" = PreToolUse ] && [ "$require" -ne 0 ] && [ "$tokens" -ge "$require" ] || exit 0

if [ -n "${CLAUDE_JOB_DIR:-}" ]; then
  [ "$warned" = 1 ] && exit 0
  warned=1
  save
  context "SDLC context gate: this background session's context is about $(k "$tokens") tokens. Auto-compact will summarize it soon. Write the unfinished state (what is done, the next step, open questions, failing checks) to the current artifact now, so the summary loses nothing."
  exit 0
fi

if [ "$tokens" -lt "$limit" ]; then
  [ "$warned" = 1 ] && exit 0
  warned=1
  save
  context "SDLC context gate: this session's context is about $(k "$tokens") tokens. At about $(k "$limit") tools pause until the user runs /compact. Keep going only if the remaining work is small, such as finishing the artifact, the gatekeeper run and the handoff. Otherwise save the unfinished state to the current artifact now and ask the user to run \`/compact <focus>\` at the next natural break, with a focus you draft."
  exit 0
fi

# Past the limit: saving the task's state and ending its phase stay possible
# (task files, the gatekeeper, committing, the handoff).
case $(j .tool_name) in
  Agent)
    [ "$(j .tool_input.subagent_type)" = sdlc-gatekeeper ] && exit 0 ;;
  Bash)
    cmd=$(j .tool_input.command)
    case $cmd in
      *[\;\&\|\`\$\<\>]* | *"
"*) ;;
      .claude/sdlc-scripts/next.sh\ * | .claude/sdlc-scripts/status.sh | .claude/sdlc-scripts/status.sh\ * | \
        git\ add\ sdlc/* | git\ commit\ *) exit 0 ;;
    esac ;;
  Read | Edit | Write | MultiEdit | NotebookEdit)
    file=$(j '.tool_input.file_path // .tool_input.notebook_path')
    if [ -n "$file" ] && ! sdlc_unnormalized_path "$file"; then
      cwd=$(j .cwd)
      case $(sdlc_resolve_path "$file" "${cwd:-$SDLC_PROJECT}") in
        "$SDLC_PROJECT"/sdlc/*) exit 0 ;;
      esac
    fi ;;
esac

blocked=1
save
jq -n --arg r "SDLC context gate: this session's context is about $(k "$tokens") tokens, past the $(k "$limit") limit, so tools are paused until the user compacts. Still allowed: reading and writing files under sdlc/, the sdlc-gatekeeper agent, \`git add sdlc/...\`, \`git commit\`, next.sh and status.sh, so a phase that is nearly done can still end. Otherwise:
1. On an SDLC task, write the unfinished state to the current artifact: what is done, the next step, open questions with recommended answers, failing checks.
2. Stop and ask the user to run \`/compact <focus>\`, with the focus drafted: the task and phase, the next step, and anything not yet in files. If the work is finished or the next request is unrelated, recommend \`/clear\` or a new session instead.
3. Tell the user that any other reply lets you continue for about $(k "$SNOOZE") more tokens without compacting." \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
