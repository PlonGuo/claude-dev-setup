# claude-dev-setup

Configuration files and setup instructions for Claude Code using the **Ralph loop** workflow — an autonomous task execution pattern based on Anthropic engineering best practices.

## What's in This Repo

| File | Description |
|------|-------------|
| `claude-code-setup-instruction-en.md` | English setup instructions (give to Claude Code to auto-configure) |
| `claude-code-setup-instruction-CN.md` | Chinese setup instructions (中文配置指令) |

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
└── scripts/
    └── ralph.sh                     # Automation loop script
```

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
