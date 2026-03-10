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
- Each loop iteration uses a fresh context window
- Each iteration must start by reading git log and progress.txt to rebuild context
- Task completion criteria: all corresponding unit tests must pass
- progress.txt and feature-requirements.md must be committed to git

## Long-Running Agent Best Practices
@~/.claude/docs/effective-harnesses.md

## Parallel Agent Best Practices
@~/.claude/docs/building-c-compiler.md

## Eval Best Practices
@~/.claude/docs/demystifying-evals.md
```

---

### 2. Article Summaries `~/.claude/docs/`

Fetch each article in full using web_fetch, then distill into concise summaries of **no more than 200 words each** — do not paste raw content. Focus on actionable best practices only.

Create the following files:
- `~/.claude/docs/effective-harnesses.md`
- `~/.claude/docs/building-c-compiler.md`
- `~/.claude/docs/demystifying-evals.md`

---

### 3. Global Slash Command `~/.claude/commands/start-ralph.md`

Place in the **global** `~/.claude/commands/` directory so it is available across all projects.

Requirements:
- Read current git log and existing progress.txt (if any) to understand project state
- Based on our Plan Mode conversation, generate `feature-requirements.md`
  - Clear task list with explicit completion criteria per task
  - Each task specifies its verification method (unit tests / lint / type checks)
- Initialize or update `progress.txt`
  - All tasks marked `[ ]`
  - Include project name, start time, and tech stack
- Commit both `feature-requirements.md` and `progress.txt` to git
- Execute the first `[ ]` task
  - Write unit tests upon completion
  - Commit after tests pass, update `progress.txt` to mark `[x]`
  - Output `<promise>COMPLETE</promise>` to signal readiness for next iteration

---

### 4. Global Ralph Bash Script `~/.claude/scripts/ralph.sh`

Place in the **global** `~/.claude/scripts/` directory so all projects share the same script.

```bash
#!/bin/bash

MAX_ITERATIONS=50
ITERATION=0
CONSECUTIVE_FAILURES=0
MAX_FAILURES=3

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))
  echo "=== Ralph iteration $ITERATION ==="

  # Check if all tasks are complete
  if ! grep -q "\[ \]" progress.txt 2>/dev/null; then
    echo "✅ All tasks complete!"
    break
  fi

  # Run one Claude Code iteration (fresh context)
  # Each iteration reads git log + progress.txt to rebuild context
  OUTPUT=$(claude -p "
    First, read git log --oneline -20 to understand recent progress.
    Then read feature-requirements.md and progress.txt.
    Find the next incomplete [ ] task and execute it.
    Write corresponding unit tests and ensure they pass.
    Commit the code and update progress.txt to mark the task [x].
    Output <promise>COMPLETE</promise> when all tasks are done.
  " --dangerously-skip-permissions 2>&1)

  echo "$OUTPUT"

  # Detect completion signal
  if echo "$OUTPUT" | grep -q "COMPLETE"; then
    echo "✅ Ralph loop complete!"
    break
  fi

  # Detect consecutive failures to prevent infinite loops
  if echo "$OUTPUT" | grep -qiE "error|failed|cannot"; then
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo "⚠️ Failure detected ($CONSECUTIVE_FAILURES/$MAX_FAILURES)"
    if [ $CONSECUTIVE_FAILURES -ge $MAX_FAILURES ]; then
      echo "❌ Too many consecutive failures. Review progress.txt and fix manually."
      break
    fi
  else
    CONSECUTIVE_FAILURES=0
  fi

  sleep 2
done

if [ $ITERATION -eq $MAX_ITERATIONS ]; then
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
- `ralph.sh` lives in global `~/.claude/scripts/`, shared across all projects
- Do not interrupt the Ralph loop while it's running — review commit history after it finishes
- To restore this setup on a new machine: clone the `claude-dev-setup` repo and re-run this instruction with Claude Code
