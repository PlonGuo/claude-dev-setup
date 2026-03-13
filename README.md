# claude-dev-setup

Configuration files and setup instructions for Claude Code using the **Ralph loop** workflow — an autonomous task execution pattern based on Anthropic engineering best practices.

## What's in This Repo

| File | Description |
|------|-------------|
| `claude-code-setup-instruction-en.md` | English setup instructions (give to Claude Code to auto-configure) |
| `claude-code-setup-instruction-CN.md` | Chinese setup instructions (中文配置指令) |
| `global-quality-commands-setup.md` | Global `/quality-gate` + `/quality-fix` commands (paste to Claude Code to install) |

## How to Use

Clone this repo, then paste the content of either instruction file into a new Claude Code session. Claude will configure your global `~/.claude/` environment automatically.

## The Ralph Loop Workflow

```
Plan Mode (chat) → ralph → Review commits
```

1. **Plan Mode**: Discuss requirements with Claude, design architecture, define tasks
2. **`ralph`**: Single command — initializes `feature-requirements.md` + `progress.txt` via `/start-ralph`, then loops autonomously until all tasks are complete (fresh context window per iteration)
3. **Review**: Check git commit history; re-run `ralph` to resume after manual adjustments

**New project:**
```bash
# After a Plan Mode session:
cd /your/project
ralph
```

**Resume after interruption:**
```bash
cd /your/project
ralph   # detects existing progress.txt, resumes from next [ ] task
```

## What Gets Configured

```
~/.claude/
├── CLAUDE.md                        # Global rules (Ralph loop + @-include references)
├── docs/
│   ├── effective-harnesses.md       # Harness design best practices
│   ├── building-c-compiler.md       # Parallel agent coordination patterns
│   └── demystifying-evals.md        # Phased eval strategy
├── commands/
│   └── start-ralph.md               # /start-ralph slash command (init + resume)
├── skills/
│   ├── quality-gate/SKILL.md        # /quality-gate — read-only audit command
│   └── quality-fix/SKILL.md         # /quality-fix — implements approved gaps
└── scripts/
    └── ralph.sh                     # Ralph loop runner (reads start-ralph.md as prompt)
```

## Global Quality Commands

Two on-demand slash commands for enforcing engineering quality standards across any project:

| Command | What it does |
|---------|-------------|
| `/quality-gate` | Detects stack, audits test coverage / linting / type checking / security / CI gaps, writes a report to `.claude/quality-gate.md`. **Read-only.** |
| `/quality-fix` | Reads the existing gap report and implements approved fixes — config files, deps (with permission), CI pipeline (separate confirmation). |

**To install:** paste the contents of `global-quality-commands-setup.md` into a Claude Code session. Claude will create both skill files under `~/.claude/skills/` automatically.

### Typical workflow

**First time setup** — run both commands:

```
# Step 1: Audit your project (detects stack, checks tests/lint/security/CI, writes report)
/quality-gate

# Step 2: Review .claude/quality-gate.md, then implement fixes
/quality-fix
```

`/quality-gate` handles the full discovery phase on first run — it detects your stack, audits all quality dimensions including test infrastructure, and writes the gap report. **You only need to run it once per project.**

**Ongoing use** — just run `/quality-fix` directly:

```
# The gap report persists between sessions — no need to re-audit
/quality-fix
```

`/quality-fix` reads the existing `.claude/quality-gate.md` report and picks up where you left off. Re-run `/quality-gate` only if the project has changed significantly (it will warn you if the report is older than 7 days).

### Key safety features of `/quality-fix`

- **Three gated steps** — config files first, then deps (requires confirmation), then CI changes (separate confirmation)
- **Verification after each fix** — runs the tool immediately; stops on failure rather than silently continuing
- **Stale report warning** — alerts if the report is older than 7 days and suggests re-auditing

Works across all languages: Python, Node/TS, Go, Rust, Java, Ruby, PHP, and more.

## Core Principles

- **Fresh context per iteration** — no context accumulation, consistent performance across 50+ iterations
- **Git as memory** — `progress.txt` + `feature-requirements.md` committed after every change; atomic commits prevent state drift on interruption
- **Tests as completion gate** — tasks only marked `[x]` when unit tests pass
- **Auto git-root navigation** — `ralph` works from any subdirectory in your project
- **Idempotent init** — re-running `ralph` on a project with existing progress resumes from the next `[ ]` task, never resets completed work
- **Failure-safe loop** — per-call timeout (10 min), exponential backoff on errors, hard stop after 3 consecutive failures

## Source Articles

The configuration is derived from three Anthropic engineering articles:

- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Building a C compiler with a team of parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler)
- [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

I would definitely recommend everyone to read these three articles. Believe me, after you read through all three, you will have a deeper understanding of how Claude Code works and the mechanism behind the "automation" that happens while using Claude Code.

## Changelog

### v3 — Sync & Safety Overhaul (2026-03-12)

Core change: `ralph.sh` now reads `start-ralph.md` as its prompt source — single source of truth, no more drift between skill and script.

| Issue | Severity | Fix |
|-------|----------|-----|
| ralph.sh inline prompt diverged from start-ralph skill | Critical | ralph.sh reads `~/.claude/commands/start-ralph.md` directly; loop-specific instructions appended as suffix |
| Re-running `start-ralph` reset `progress.txt`, erasing completed tasks | Critical | Resume mode: detects existing `[x]` tasks → skip re-init |
| No per-call timeout — hung `claude` blocked loop indefinitely | Major | `timeout $CALL_TIMEOUT claude ...` (default 600s) |
| Non-interactive mode: `start-ralph` asked questions nobody could answer | Major | Infer from README/git/source files; only ask if interactive |
| `--dangerously-skip-permissions` applied with no warning | Major | 5s countdown with `Ctrl+C` escape hatch; `RALPH_SAFE=1` opt-out |
| `sleep 2` caused rapid retries on rate-limit failures | Minor | Exponential backoff (`2^n` seconds, capped at 60s) on failures |
| Code committed separately from `progress.txt` — state drift on crash | Minor | Atomic commit: code + `progress.txt` in one `git commit` |
| `git add -A` could commit secrets or build artifacts | Minor | Changed to explicit file adds; warns about `.gitignore` |
| `git log --oneline -20` missed early tasks on large projects | Minor | Increased to `-50` across all files |
| `start-ralph` COMPLETE signal semantics were wrong | Minor | Context-aware: only emit COMPLETE when ralph loop appends override |

## License

MIT
