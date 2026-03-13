#!/bin/bash

# Auto-navigate to git root so script works from any subdirectory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo "❌ Not in a git repository. Run from within your project directory."
  exit 1
fi
cd "$GIT_ROOT"

# Configuration
MAX_ITERATIONS=${RALPH_MAX:-50}
CALL_TIMEOUT=${RALPH_TIMEOUT:-600}  # Per-call timeout in seconds (default 10 min)
LOG_FILE="${RALPH_LOG:-$GIT_ROOT/.ralph.log}"

# macOS fallback: timeout not available by default (needs `brew install coreutils`)
if ! command -v timeout &>/dev/null; then
  echo "⚠️  'timeout' command not found. Running without per-call timeout protection."
  echo "    Install with: brew install coreutils"
  timeout() { shift; "$@"; }  # no-op: skip timeout arg, run command directly
fi

MAX_FAILURES=3
ITERATION=0
CONSECUTIVE_FAILURES=0
LOOP_COMPLETE=false

# Helper: log to both terminal and file
log() { echo "[ralph] $*" | tee -a "$LOG_FILE"; }

# Safety warning for --dangerously-skip-permissions
if [ "${RALPH_SAFE}" != "1" ]; then
  echo ""
  echo "  [ralph] WARNING: running with --dangerously-skip-permissions (full auto mode)"
  echo "  [ralph] Project: $GIT_ROOT"
  echo "  [ralph] Press Ctrl+C within 5s to abort, or set RALPH_SAFE=1 to skip this warning."
  echo ""
  sleep 5
fi

# Load start-ralph skill as the single source of truth for the prompt
SKILL_PATH="$HOME/.claude/commands/start-ralph.md"
if [ ! -f "$SKILL_PATH" ]; then
  log "❌ start-ralph skill not found at $SKILL_PATH"
  exit 1
fi
SKILL_PROMPT=$(cat "$SKILL_PATH")

# Loop-specific instructions appended to the skill prompt
LOOP_SUFFIX="

---
## Loop Context (appended by ralph.sh)

You are running inside the Ralph loop (non-interactive, fresh context each iteration).
Override the earlier instruction about COMPLETE — in this context:
- After completing a task, check progress.txt for remaining [ ] tasks.
- If ALL tasks are now [x], output <promise>COMPLETE</promise> to signal the loop is finished.
- If there are remaining [ ] tasks, do NOT output COMPLETE. Simply finish after committing.
"

log "======================================================"
log "Ralph Loop started: $(date)"
log "Project:  $GIT_ROOT"
log "Max iter: $MAX_ITERATIONS  |  Timeout: ${CALL_TIMEOUT}s/iter"
log "Log:      $LOG_FILE"
log "======================================================"

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))
  log "=== Iteration $ITERATION / $MAX_ITERATIONS ==="

  # Guard: progress.txt must exist before looping
  if [ ! -f progress.txt ]; then
    log "❌ progress.txt not found. Run /start-ralph first."
    exit 1
  fi

  # Check if all tasks are complete
  if ! grep -q "\[ \]" progress.txt; then
    log "✅ All tasks complete!"
    LOOP_COMPLETE=true
    break
  fi

  # Run one Claude Code iteration (fresh context)
  # Uses start-ralph.md as prompt — any changes to the skill auto-sync here
  # tee streams output to both terminal and log file in real time
  TMPOUT=$(mktemp)
  timeout "$CALL_TIMEOUT" claude -p "${SKILL_PROMPT}${LOOP_SUFFIX}" --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE" "$TMPOUT"
  CLAUDE_EXIT=${PIPESTATUS[0]}

  OUTPUT=$(cat "$TMPOUT")
  rm -f "$TMPOUT"

  # Detect completion signal — match full tag to avoid false positives
  if echo "$OUTPUT" | grep -qF "<promise>COMPLETE</promise>"; then
    log "✅ Ralph loop complete!"
    LOOP_COMPLETE=true
    break
  fi

  # Handle timeout (exit code 124)
  if [ $CLAUDE_EXIT -eq 124 ]; then
    log "⚠️ Iteration timed out after ${CALL_TIMEOUT}s"
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
  elif [ $CLAUDE_EXIT -ne 0 ]; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    log "⚠️ Non-zero exit ($CONSECUTIVE_FAILURES/$MAX_FAILURES)"
  else
    CONSECUTIVE_FAILURES=0
  fi

  # Exponential backoff on failures, fixed delay on success
  if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
    if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
      log "❌ Too many consecutive failures. Review progress.txt and fix manually."
      break
    fi
    BACKOFF=$((2 ** CONSECUTIVE_FAILURES))
    [ $BACKOFF -gt 60 ] && BACKOFF=60
    log "⏳ Backing off ${BACKOFF}s before retry..."
    sleep $BACKOFF
  else
    sleep 2
  fi
done

if [ "$LOOP_COMPLETE" = true ]; then
  log "Ralph Loop finished successfully."
elif [ $ITERATION -ge $MAX_ITERATIONS ]; then
  log "⚠️ Reached max iterations ($MAX_ITERATIONS). Review progress.txt and re-run ralph."
fi
