# Claude Code Setup Instruction

## Background

Please carefully read the following three Anthropic engineering articles before proceeding:

1. Effective harnesses for long-running agents
   https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

2. Building a C compiler with a team of parallel Claudes
   https://www.anthropic.com/engineering/building-c-compiler

3. Demystifying evals for AI agents
   https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents

After reading, configure my development environment according to the requirements below.

---

## My Workflow

I use the **Ralph loop** development pattern:

1. **Plan Mode** (conversation with you): Discuss requirements, design architecture, define tasks
2. **`/start-ralph`** (slash command): Auto-generate required files and execute the first task
3. **`bash ~/.claude/scripts/ralph.sh`**: Fully automated loop through remaining tasks until all complete
4. **Review**: I check the commit history, exit the loop for manual adjustments if needed

---

## Core Principles

- **Each Ralph loop iteration uses a fresh context window** — do NOT use the official Ralph plugin (it causes context accumulation and degrades performance)
- **Each task = one independently testable unit of functionality**
- **Task granularity**: not too large (can't finish in one context), not too small (too fragmented)
- **Unit tests are the only completion criteria** — a task is not marked `[x]` until its tests pass; retry until passing or max iterations reached
- **Each loop iteration must start by reading `git log --oneline -50` + progress.txt** to rebuild context before executing the next task
- **progress.txt and feature-requirements.md must be committed to git** — they are the core memory that persists across context windows

---

## Files to Configure

### 1. Global Rules `~/.claude/CLAUDE.md`

Write the following content:

```markdown
# Global Rules

## Ralph Loop Workflow
- All projects use the Ralph loop pattern by default
- Each loop iteration uses a fresh context window (do NOT use the official Ralph plugin)
- Each iteration must start by reading `git log --oneline -50` and `progress.txt` to rebuild context
- Task completion criteria: all corresponding unit tests must pass before marking `[x]`
- `progress.txt` and `feature-requirements.md` must be committed to git after every change

## Long-Running Agent Best Practices
@~/.claude/docs/effective-harnesses.md

## Parallel Agent Best Practices
@~/.claude/docs/building-c-compiler.md

## Eval Best Practices
@~/.claude/docs/demystifying-evals.md
```

---

### 2. Article Summaries `~/.claude/docs/`

First create the required directory:

```bash
mkdir -p ~/.claude/docs
```

Fetch each article in full using web_fetch, then distill into concise summaries of **no more than 200 words each** — do not paste raw content. Focus on actionable best practices only.

Create the following files:

**`~/.claude/docs/effective-harnesses.md`**

```markdown
# Effective Harnesses for Long-Running Agents

Source: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

## Core Pattern: Two-Phase Agent

- **Initializer agent** (one-time): environment setup, write `init.sh`, scaffold state files
- **Coding agent** (iterative): reads progress + recent commits, implements ONE feature, commits, updates progress

## State Persistence

- Use explicit state files (`progress.txt`, `feature-requirements.md`) — never rely on agent memory
- Detailed git commits are implicit documentation; enable safe rollback
- Both files MUST be committed to git — they are cross-context memory

## Failure Prevention

- Granular feature lists (many small items) prevent premature "I'm done" hallucination
- Pre-write `init.sh` for environment setup — eliminate runtime discovery overhead
- Session-end checklist: commit progress + update docs before context closes

## Completion Criteria

- Require end-to-end tests (browser automation if applicable) before marking tasks `[x]`
- Session startup: read progress → identify next task → run smoke test → implement single feature → commit

## Completion Signal

- Output `<promise>COMPLETE</promise>` to signal all work is finished — the outer harness (ralph.sh) breaks the loop on this signal. Only emit when there are no remaining tasks.
```

**`~/.claude/docs/building-c-compiler.md`**

```markdown
# Building a C Compiler with Parallel Claudes

Source: https://www.anthropic.com/engineering/building-c-compiler

## Git-Based Coordination

- Use lock files (`current_tasks/`) for parallel agent synchronization
- Git merge conflicts automatically prevent duplicate effort — git IS the coordination layer
- Multiple agents multiply throughput beyond single-agent limits

## Task Decomposition

- **Vertical**: Specialize agents by domain (parser, codegen, optimizer) or meta-task (docs, perf review)
- **Horizontal**: Break large tasks using external tools as comparison oracles (e.g., reference implementations)

## Environment Design

- Log comprehensively to files; print ONLY essential summaries to Claude context (avoid context flooding)
- Add `--fast` mode (1-10% random samples) for quick regression detection
- Update README + progress files frequently so fresh agents understand project state instantly

## Agent State Management

- Externalize all state: progress docs, failure logs, lock files = agent working memory
- Specialize agents when single-agent scope becomes unreliable
- Fresh agents need: recent git log + progress file to rebuild context efficiently
```

**`~/.claude/docs/demystifying-evals.md`**

```markdown
# Demystifying Evals for AI Agents

Source: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents

## Grader Types

- **Code-based**: Fast, objective, brittle — use for deterministic outputs
- **Model-based**: Flexible, non-deterministic, expensive — use for subjective quality
- **Human**: Gold standard, slow — use for calibration and edge cases

## Test Case Design

- Start with 20-50 tasks from REAL failures, not hypothetical scenarios
- Convert user-reported bugs into repeatable eval tasks
- Validate every task is passable by a competent agent (verify with reference solution)
- Test both positive (should occur) AND negative (shouldn't occur) cases

## Key Metrics

- **pass@k**: ≥1 correct solution across k attempts — measures success likelihood
- **pass^k**: ALL k attempts succeed — measures consistency/reliability
- Divergence (pass@k high, pass^k low) = reliability problem, not capability problem

## Phased Rollout (Ralph Loop aligned)

1. **Phase 1 (during dev)**: Unit tests as completion criteria — no eval infra needed
2. **Phase 2 (pre-launch)**: Add RAGAs if RAG involved; regression evals for core features
3. **Phase 3 (at scale)**: Capability evals from user feedback; model-based graders for quality

## Integration

Combine automated evals + production monitoring + A/B testing + human review. No single layer is sufficient.
```

---

### 3. Global Slash Command `~/.claude/commands/start-ralph.md`

Place in the **global** `~/.claude/commands/` directory so it is available across all projects.

```markdown
Read `git log --oneline -50` and `progress.txt` (if it exists) to understand the project state.

## Mode Detection (check this first)

**Resume mode** — if `progress.txt` already exists AND contains at least one `[x]` task:
- Do NOT regenerate `feature-requirements.md` or reset `progress.txt`
- Skip directly to Step 4: find the next `[ ]` task and execute it

**Fresh init mode** — if `progress.txt` does not exist or has no `[x]` tasks: proceed with Steps 1–4.

---

## Fresh Init

**Step 1 — Generate `feature-requirements.md`**

Source requirements from (in priority order):
1. Current session's Plan Mode discussion
2. README, existing docs, `.claude/` files
3. Git log and existing source structure

- If running **non-interactively** (called via `ralph` script with no plan discussion in session): infer requirements from project files — do NOT ask questions, make your best inference and proceed.
- If running **interactively** and you cannot infer enough: ask the user _"What feature or set of tasks should I generate requirements for?"_

Format: `- [ ] Task N: [description] — verified by: [test command]`

**Step 2 — Initialize `progress.txt`** with project name, start timestamp, tech stack summary, all tasks marked `[ ]`, and any already-completed tasks from git history marked `[x]`.

**Step 3 — Commit both files:**
```bash
git add feature-requirements.md progress.txt
git commit -m "chore: initialize Ralph loop task list"
```

**Step 4 — Execute the next `[ ]` task:**
1. Write unit tests first (TDD)
2. Implement until tests pass
3. Mark the task `[x]` in `progress.txt`
4. Commit code AND `progress.txt` together in one atomic commit — prevents state drift if the loop is interrupted:
   ```bash
   git add <changed source files> progress.txt
   git commit -m "feat: <task description>"
   ```
   **Important:** Do NOT use `git add -A` — explicitly add only the files you changed to avoid committing secrets or build artifacts. Ensure `.gitignore` is adequate before committing.

**Do NOT output `<promise>COMPLETE</promise>`** unless you are running inside the Ralph loop (the loop will tell you if you are). In interactive mode, simply finish after committing the task.
```

---

### 4. Global Ralph Bash Script `~/.claude/scripts/ralph.sh`

First create the required directory:

```bash
mkdir -p ~/.claude/scripts
```

Place in the **global** `~/.claude/scripts/` directory so all projects share the same script.

```bash
#!/bin/bash

# Auto-navigate to git root so script works from any subdirectory
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo "❌ Not in a git repository. Run from within your project directory."
  exit 1
fi
cd "$GIT_ROOT"

# Configuration
MAX_ITERATIONS=50
CALL_TIMEOUT=${CALL_TIMEOUT:-600}  # Per-call timeout in seconds (default 10 min)

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

# Safety warning for --dangerously-skip-permissions
if [ "${RALPH_SAFE}" != "1" ]; then
  echo "⚠️  Running with --dangerously-skip-permissions (full auto mode)"
  echo "    Set RALPH_SAFE=1 to skip this warning."
  echo "    Press Ctrl+C within 5s to abort..."
  sleep 5
fi

# Load start-ralph skill as the single source of truth for the prompt
SKILL_PATH="$HOME/.claude/commands/start-ralph.md"
if [ ! -f "$SKILL_PATH" ]; then
  echo "❌ start-ralph skill not found at $SKILL_PATH"
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

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))
  echo "=== Ralph iteration $ITERATION ==="

  # Guard: progress.txt must exist before looping
  if [ ! -f progress.txt ]; then
    echo "❌ progress.txt not found. Run /start-ralph first."
    exit 1
  fi

  # Check if all tasks are complete
  if ! grep -q "\[ \]" progress.txt; then
    echo "✅ All tasks complete!"
    LOOP_COMPLETE=true
    break
  fi

  # Run one Claude Code iteration (fresh context)
  # Uses start-ralph.md as prompt — any changes to the skill auto-sync here
  OUTPUT=$(timeout "$CALL_TIMEOUT" claude -p "${SKILL_PROMPT}${LOOP_SUFFIX}" --dangerously-skip-permissions 2>&1)
  CLAUDE_EXIT=$?  # Capture immediately — $? gets overwritten by any subsequent command

  echo "$OUTPUT"

  # Detect completion signal — match full tag to avoid false positives
  if echo "$OUTPUT" | grep -qF "<promise>COMPLETE</promise>"; then
    echo "✅ Ralph loop complete!"
    LOOP_COMPLETE=true
    break
  fi

  # Handle timeout (exit code 124)
  if [ $CLAUDE_EXIT -eq 124 ]; then
    echo "⚠️ Iteration timed out after ${CALL_TIMEOUT}s"
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
  elif [ $CLAUDE_EXIT -ne 0 ]; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo "⚠️ Non-zero exit ($CONSECUTIVE_FAILURES/$MAX_FAILURES)"
  else
    CONSECUTIVE_FAILURES=0
  fi

  # Exponential backoff on failures, fixed delay on success
  if [ $CONSECUTIVE_FAILURES -gt 0 ]; then
    if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
      echo "❌ Too many consecutive failures. Review progress.txt and fix manually."
      break
    fi
    BACKOFF=$((2 ** CONSECUTIVE_FAILURES))
    [ $BACKOFF -gt 60 ] && BACKOFF=60
    echo "⏳ Backing off ${BACKOFF}s before retry..."
    sleep $BACKOFF
  else
    sleep 2
  fi
done

if [ "$LOOP_COMPLETE" = false ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
  echo "⚠️ Reached max iterations ($MAX_ITERATIONS). Review progress.txt."
fi
```

After creating the file, run:
```bash
chmod +x ~/.claude/scripts/ralph.sh
```

---

## Eval Strategy (Phased)

### Phase 1: During Development (inside Ralph loop)
- **Unit tests only** as task completion criteria
- Tests must pass before marking a task `[x]`
- No complex eval infrastructure needed

### Phase 2: After Core Features Complete (before open-sourcing)
- Add RAGAs eval if the project involves RAG
- Write representative test cases to verify retrieval quality and answer accuracy
- Use as a regression eval to prevent future regressions

### Phase 3: After Reaching User Scale
- Add capability evals based on user feedback
- Consider model-based graders for subjective quality assessment
- No need to think about this now

---

## Notes

- `progress.txt` and `feature-requirements.md` **must be committed to git** — do NOT add them to `.gitignore`
- `/start-ralph` is a global command, available in all projects without any per-project setup
- `ralph.sh` lives in global `~/.claude/scripts/`, shared across all projects; run it from anywhere inside your project — it auto-navigates to the git root
- Do not interrupt the Ralph loop while it's running — review commit history after it finishes
- To restore this setup on a new machine: clone the `claude-dev-setup` repo and re-run this instruction with Claude Code

## Bug Fixes vs Original Design

The following improvements were made over the original specification during review:

| Issue | Fix |
|-------|-----|
| `$?` overwritten by `echo "$OUTPUT"` before failure check | Capture `CLAUDE_EXIT=$?` immediately after `claude` command |
| `grep -q "COMPLETE"` matches "INCOMPLETE", "not COMPLETE", etc. | Use `grep -qF "<promise>COMPLETE</promise>"` for exact match |
| `progress.txt` missing → script silently exits as "all done" | Added guard: explicit error + `exit 1` if file not found |
| Max-iter warning fires even on clean COMPLETE exit | Added `LOOP_COMPLETE` flag; warning only fires on true timeout |
| Script requires running from project root | Auto `cd` to git root via `git rev-parse --show-toplevel` |
| `/start-ralph` had no fallback if no plan conversation existed | Added: infer from project files (non-interactive) or ask user (interactive) |
| `/start-ralph` emitted `COMPLETE` signal (wrong semantics) | Context-aware: only emit when ralph loop tells it to |
| ralph.sh inline prompt diverged from start-ralph skill | ralph.sh now reads `start-ralph.md` as prompt — single source of truth |
| No per-call timeout — hung `claude` blocked loop indefinitely | `timeout $CALL_TIMEOUT claude ...` (default 600s) |
| `sleep 2` caused rapid retries on rate-limit failures | Exponential backoff (`2^n` seconds, capped at 60s) on failures |
| `--dangerously-skip-permissions` applied with no warning | 5s countdown with `Ctrl+C` escape hatch; `RALPH_SAFE=1` opt-out |
| `git add -A` in start-ralph could commit secrets/artifacts | Changed to explicit file adds; warns about `.gitignore` |
| `git log --oneline -20` missed early tasks on large projects | Increased to `-50` across all files |
| Re-running start-ralph reset `progress.txt`, erasing completed tasks | Resume mode: detects existing `[x]` tasks, skips re-init |
| Code committed separately from `progress.txt` — state drift | Atomic commit: code + `progress.txt` in one `git commit` |
