# claude-dev-setup

A one-time setup instruction for configuring Claude Code with the Ralph loop workflow, based on Anthropic's engineering best practices.

一次性配置 Claude Code 的 Ralph loop 工作流，基于 Anthropic 工程团队的最佳实践。

---

## What is this? / 这是什么？

This repo contains setup instructions that configure Claude Code with:
- **Ralph loop** workflow for autonomous task execution
- **Long-running agent** best practices (progress tracking, fresh context windows)
- **Eval strategy** (phased approach from unit tests to RAGAs)

本 repo 包含配置指令，帮你一键设置：
- **Ralph loop** 自动化任务执行工作流
- **Long-running agent** 最佳实践（进度追踪、fresh context window）
- **分阶段 Eval 策略**（从单元测试到 RAGAs）

---

## Based on / 基于

- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Building a C compiler with a team of parallel Claudes](https://www.anthropic.com/engineering/building-c-compiler)
- [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)

---

## Usage / 使用方法

**First time or new machine / 首次使用或新机器：**

```bash
git clone https://github.com/your-username/claude-dev-setup
```

Then open Claude Code, upload the instruction file, and let it run.

打开 Claude Code，上传 instruction 文件，让它自动执行配置。

- English: `claude-code-setup-instruction-en.md`
- 中文: `claude-code-setup-instruction.md`

**After setup / 配置完成后，每个新项目：**

```
1. Plan Mode  →  discuss requirements with Claude Code
2. /start-ralph  →  auto-generate task files + execute first task
3. bash ralph.sh  →  fully automated loop until all tasks complete
4. Review commit history
```

---

## What gets configured / 配置内容

| File | Location | Purpose |
|------|----------|---------|
| `CLAUDE.md` | `~/.claude/` | Global rules for all projects |
| `effective-harnesses.md` | `~/.claude/docs/` | Harness best practices summary |
| `building-c-compiler.md` | `~/.claude/docs/` | Parallel agent best practices summary |
| `demystifying-evals.md` | `~/.claude/docs/` | Eval best practices summary |
| `start-ralph.md` | `.claude/commands/` | Project-level slash command template |
| `ralph.sh` | project root | Bash loop script template |

---

## License

MIT
