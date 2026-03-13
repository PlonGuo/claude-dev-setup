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
Plan Mode (chat) → /start-ralph → bash ~/.claude/scripts/ralph.sh → Review commits
```

1. **Plan Mode**: Discuss requirements with Claude, design architecture, define tasks
2. **`/start-ralph`**: Generates `feature-requirements.md` + `progress.txt`, executes first task
3. **`ralph.sh`**: Fully automated loop — fresh context window per iteration, runs until all tasks complete
4. **Review**: Check git commit history; exit loop for manual adjustments if needed

## What Gets Configured

```
~/.claude/
├── CLAUDE.md                        # Global rules (Ralph loop + @-include references)
├── docs/
│   ├── effective-harnesses.md       # Harness design best practices
│   ├── building-c-compiler.md       # Parallel agent coordination patterns
│   └── demystifying-evals.md        # Phased eval strategy
├── commands/
│   └── start-ralph.md               # /start-ralph slash command
├── skills/
│   ├── quality-gate/SKILL.md        # /quality-gate — read-only audit command
│   └── quality-fix/SKILL.md         # /quality-fix — implements approved gaps
└── scripts/
    └── ralph.sh                     # Automation loop script
```

## Global Quality Commands

Two on-demand slash commands for enforcing engineering quality standards across any project:

| Command | What it does |
|---------|-------------|
| `/quality-gate` | Detects stack, audits test coverage / linting / type checking / security / CI gaps, writes a report to `.claude/quality-gate.md`. **Read-only.** |
| `/quality-fix` | Reads the gap report and implements approved fixes — config files, deps (with permission), CI pipeline (separate confirmation). |

**To install:** paste the contents of `global-quality-commands-setup.md` into a Claude Code session. Claude will create both skill files under `~/.claude/skills/` automatically.

```
# Step 1: Audit your project
/quality-gate

# Step 2: Review .claude/quality-gate.md, then implement fixes
/quality-fix
```

Works across all languages: Python, Node/TS, Go, Rust, Java, Ruby, PHP, and more.

## Core Principles

- **Fresh context per iteration** — no context accumulation, consistent performance across 50+ iterations
- **Git as memory** — `progress.txt` + `feature-requirements.md` committed after every change
- **Tests as completion gate** — tasks only marked `[x]` when unit tests pass
- **Auto git-root navigation** — `ralph.sh` works from any subdirectory in your project

## Source Articles

The configuration is derived from three Anthropic engineering articles:

- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Building a C compiler with a team of parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler)
- [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

I would definitely everyone to read these three articles. Believe me, after you read through all these three files, you would have a deeper understand of how Claude Code works and the mechanism about the "automation" happens while using Claude Code.

## Changelog

### v2 — Bug Fixes (2026-03-12)

Reviewed against Anthropic engineering standards. Fixed 7 issues in the original design:

| Issue | Fix |
|-------|-----|
| `$?` overwritten before failure check | Capture `CLAUDE_EXIT=$?` immediately after `claude` command |
| `grep "COMPLETE"` matched "INCOMPLETE" etc. | Use `grep -qF "<promise>COMPLETE</promise>"` for exact match |
| Missing `progress.txt` silently exits as "all done" | Added guard: explicit error + `exit 1` |
| Max-iter warning fired on clean COMPLETE exit | Added `LOOP_COMPLETE` flag |
| Script required running from project root | Auto `cd` via `git rev-parse --show-toplevel` |
| `/start-ralph` undefined behavior without plan context | Added fallback: ask user for requirements |
| `/start-ralph` emitted COMPLETE signal (wrong semantics) | Removed: COMPLETE is loop-termination only |

## License

MIT
