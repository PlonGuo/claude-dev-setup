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
- **Each loop iteration must start by reading git log + progress.txt** to rebuild context before executing the next task
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
- Each iteration must start by reading `git log --oneline -20` and `progress.txt` to rebuild context
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
Read the current git log and existing progress.txt (if any) to understand the project state.

Based on our Plan Mode conversation and any existing context. **If no prior plan discussion is available in this session**, ask the user: "What feature or set of tasks should I generate requirements for?" before proceeding.

1. **Generate `feature-requirements.md`** with:
   - A numbered task list derived from our plan discussion
   - Each task has explicit completion criteria
   - Each task specifies its verification method (unit tests / lint / type checks / e2e)
   - Format: `- [ ] Task N: [description] — verified by: [test command]`

2. **Initialize or update `progress.txt`** with:
   - Project name
   - Start timestamp
   - Tech stack summary
   - All tasks from feature-requirements.md marked `[ ]`
   - Any already-completed tasks from git history marked `[x]`

3. **Commit both files to git:**
   ```bash
   git add feature-requirements.md progress.txt
   git commit -m "chore: initialize Ralph loop task list"
   ```

4. **Execute the first `[ ]` task:**
   - Write unit tests for the task first (TDD)
   - Implement the feature until tests pass
   - Commit the code with a meaningful message
   - Update `progress.txt` to mark the task `[x]`
   - Commit the updated progress.txt

5. **Do NOT output `<promise>COMPLETE</promise>`** — that signal means "all tasks done" and belongs to the loop iterations, not the initializer. Simply finish after committing task 1.
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

MAX_ITERATIONS=50
ITERATION=0
CONSECUTIVE_FAILURES=0
MAX_FAILURES=3
LOOP_COMPLETE=false  # Track clean completion to suppress false max-iter warning

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
  OUTPUT=$(claude -p "
    First, read git log --oneline -20 to understand recent progress.
    Then read feature-requirements.md and progress.txt.
    Find the next incomplete [ ] task and execute it.
    Write corresponding unit tests and ensure they pass.
    Commit the code and update progress.txt to mark the task [x].
    Output <promise>COMPLETE</promise> when all tasks are done.
  " --dangerously-skip-permissions 2>&1)
  CLAUDE_EXIT=$?  # Capture immediately — $? gets overwritten by any subsequent command

  echo "$OUTPUT"

  # Detect completion signal — match full tag to avoid false positives
  # (e.g. "INCOMPLETE", "not COMPLETE", etc. would trigger naive grep)
  if echo "$OUTPUT" | grep -qF "<promise>COMPLETE</promise>"; then
    echo "✅ Ralph loop complete!"
    LOOP_COMPLETE=true
    break
  fi

  # Detect consecutive failures via claude exit code
  if [ $CLAUDE_EXIT -ne 0 ]; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo "⚠️ Non-zero exit ($CONSECUTIVE_FAILURES/$MAX_FAILURES)"
    if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
      echo "❌ Too many consecutive failures. Review progress.txt and fix manually."
      break
    fi
  else
    CONSECUTIVE_FAILURES=0
  fi

  sleep 2
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
| `/start-ralph` had no fallback if no plan conversation existed | Added: ask user for requirements if no context available |
| `/start-ralph` emitted `COMPLETE` signal (wrong semantics) | Removed: `COMPLETE` is loop-termination signal, not per-task |
