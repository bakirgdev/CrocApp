---
name: sdlc-status
description: Shows where every SDLC task in this project stands (phase, artifact status, approval and run mode) and the command that starts a task's next phase. Use when the user asks for SDLC status, progress, or what to run next.
argument-hint: "[slug]"
allowed-tools:
  - Bash(.claude/sdlc-scripts/status.sh)
  - Bash(.claude/sdlc-scripts/status.sh *)
---

# Status

!`.claude/sdlc-scripts/status.sh $ARGUMENTS`

Report the output above in a few lines. For each task, give its phase and what it is waiting for: a draft to finish, the user's approval, or the gate owner in strict mode. Then show the selected task's next command, unchanged. The output above is complete: do not run other commands or change any file.

If a task runs in autonomous mode, add that `claude agents` lists its background sessions, and that "Needs input" means one is waiting for the user.
