# Claude Code 配置指令

## 背景

在开始之前，请仔细阅读以下三篇 Anthropic 工程博客文章：

1. 长时运行 Agent 的有效 Harness 设计
   https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

2. 用并行 Claude 团队构建 C 编译器
   https://www.anthropic.com/engineering/building-c-compiler

3. 揭秘 AI Agent 的评估方法
   https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents

阅读完毕后，按照以下要求配置我的开发环境。

---

## 我的工作流

我使用 **Ralph 循环** 开发模式：

1. **Plan Mode**（与你对话）：讨论需求、设计架构、定义任务
2. **`/start-ralph`**（slash 命令）：自动生成所需文件并执行第一个任务
3. **`bash ~/.claude/scripts/ralph.sh`**：全自动循环执行剩余任务直到全部完成
4. **Review**：我检查 commit 历史，如需手动调整则退出循环

---

## 核心原则

- **每次 Ralph 循环迭代都使用全新的 context window** — 不要使用官方 Ralph 插件（会导致 context 累积，性能下降）
- **每个任务 = 一个可独立测试的功能单元**
- **任务粒度**：不能太大（一个 context 内无法完成），也不能太小（过于碎片化）
- **单元测试是唯一的完成标准** — 任务的测试通过后才能标记为 `[x]`；否则继续重试，直到通过或达到最大迭代次数
- **每次迭代必须先读取 git log + progress.txt** 以重建上下文，再执行下一个任务
- **progress.txt 和 feature-requirements.md 必须提交到 git** — 它们是跨 context 持久化的核心记忆

---

## 需要配置的文件

### 1. 全局规则 `~/.claude/CLAUDE.md`

写入以下内容：

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

### 2. 文章摘要 `~/.claude/docs/`

首先创建所需目录：

```bash
mkdir -p ~/.claude/docs
```

使用 web_fetch 抓取每篇文章的完整内容，然后提炼为**不超过 200 字**的简洁摘要 — 不要粘贴原文。只关注可操作的最佳实践。

创建以下文件：

**`~/.claude/docs/effective-harnesses.md`**

```markdown
# Effective Harnesses for Long-Running Agents

Source: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

## Core Pattern: Two-Phase Agent

- **Initializer agent**（一次性）：环境初始化、编写 `init.sh`、创建状态文件
- **Coding agent**（迭代式）：读取进度 + 最近 commit，实现一个功能，提交，更新进度

## State Persistence

- 使用显式状态文件（`progress.txt`、`feature-requirements.md`）— 绝不依赖 agent 记忆
- 详细的 git commit 是隐式文档；支持安全回滚
- 两个文件都必须提交到 git — 它们是跨 context 的记忆

## Failure Prevention

- 粒度细的功能列表（很多小项目）可防止 agent 过早宣布"完成"
- 预先编写 `init.sh` 进行环境初始化 — 消除运行时发现的开销
- 会话结束清单：在 context 关闭前提交进度 + 更新文档

## Completion Criteria

- 标记 `[x]` 前必须通过端到端测试（如适用，需浏览器自动化）
- 会话启动顺序：读取进度 → 识别下一个任务 → 运行冒烟测试 → 实现单个功能 → 提交

## Completion Signal

- 输出 `<promise>COMPLETE</promise>` 表示所有工作已完成 — 外层 harness（ralph.sh）在收到此信号时终止循环。只有在没有剩余任务时才输出。
```

**`~/.claude/docs/building-c-compiler.md`**

```markdown
# Building a C Compiler with Parallel Claudes

Source: https://www.anthropic.com/engineering/building-c-compiler

## Git-Based Coordination

- 使用锁文件（`current_tasks/`）进行并行 agent 同步
- git 的合并冲突自动防止重复工作 — git 就是协调层
- 多个 agent 的吞吐量超越单一 agent 的上限

## Task Decomposition

- **垂直分解**：按领域（解析、代码生成、优化）或元任务（文档、性能评审）专化 agent
- **水平分解**：使用外部工具作为对比基准来拆解大任务（如以参考实现作为 oracle）

## Environment Design

- 详细记录到文件；只将关键摘要打印到 Claude context（避免 context 被无用输出淹没）
- 添加 `--fast` 模式（随机抽取 1-10%）用于快速回归检测
- 频繁更新 README + 进度文件，让新启动的 agent 能立即理解项目状态

## Agent State Management

- 将所有状态外部化：进度文档、失败日志、锁文件 = agent 的工作记忆
- 当单 agent 范围变得不可靠时，专化 agent
- 新启动的 agent 需要：最近的 git log + 进度文件来高效重建上下文
```

**`~/.claude/docs/demystifying-evals.md`**

```markdown
# Demystifying Evals for AI Agents

Source: https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents

## Grader Types

- **基于代码**：快速、客观、脆弱 — 用于确定性输出
- **基于模型**：灵活、不确定、昂贵 — 用于主观质量评估
- **人工**：黄金标准、慢 — 用于校准和边缘案例

## Test Case Design

- 从真实失败案例中收集 20-50 个任务，而非假设性场景
- 将用户反馈的 bug 转化为可重复的 eval 任务
- 验证每个任务对于合格 agent 是可通过的（用参考解验证）
- 同时测试正向案例（应该发生的）和负向案例（不应该发生的）

## Key Metrics

- **pass@k**：k 次尝试中至少 1 次成功的概率 — 衡量成功可能性
- **pass^k**：k 次尝试全部成功的概率 — 衡量一致性/可靠性
- 偏差（pass@k 高，pass^k 低）= 可靠性问题，而非能力问题

## Phased Rollout（与 Ralph Loop 对齐）

1. **Phase 1（开发中）**：单元测试作为完成标准 — 无需复杂 eval 基础设施
2. **Phase 2（发布前）**：如涉及 RAG 则添加 RAGAs；核心功能的回归 eval
3. **Phase 3（规模化后）**：基于用户反馈的能力 eval；主观质量的模型评判

## Integration

结合自动化 eval + 生产监控 + A/B 测试 + 人工评审。没有单一层是充分的。
```

---

### 3. 全局 Slash 命令 `~/.claude/commands/start-ralph.md`

放置在**全局** `~/.claude/commands/` 目录下，使其在所有项目中都可用。

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

### 4. 全局 Ralph Bash 脚本 `~/.claude/scripts/ralph.sh`

首先创建所需目录：

```bash
mkdir -p ~/.claude/scripts
```

放置在**全局** `~/.claude/scripts/` 目录下，所有项目共享同一个脚本。

```bash
#!/bin/bash

# 自动跳转到 git 根目录，支持从项目任意子目录运行
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
LOOP_COMPLETE=false  # 跟踪正常完成状态，防止误触发 max-iter 警告

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))
  echo "=== Ralph iteration $ITERATION ==="

  # 防护：循环前确认 progress.txt 存在
  if [ ! -f progress.txt ]; then
    echo "❌ progress.txt not found. Run /start-ralph first."
    exit 1
  fi

  # 检查所有任务是否已完成
  if ! grep -q "\[ \]" progress.txt; then
    echo "✅ All tasks complete!"
    LOOP_COMPLETE=true
    break
  fi

  # 运行一次 Claude Code 迭代（全新 context）
  OUTPUT=$(claude -p "
    First, read git log --oneline -20 to understand recent progress.
    Then read feature-requirements.md and progress.txt.
    Find the next incomplete [ ] task and execute it.
    Write corresponding unit tests and ensure they pass.
    Commit the code and update progress.txt to mark the task [x].
    Output <promise>COMPLETE</promise> when all tasks are done.
  " --dangerously-skip-permissions 2>&1)
  CLAUDE_EXIT=$?  # 立即捕获 — $? 会被后续任何命令覆盖

  echo "$OUTPUT"

  # 检测完成信号 — 精确匹配完整 tag，避免误匹配
  # （如 "INCOMPLETE"、"not COMPLETE" 等会触发宽泛 grep）
  if echo "$OUTPUT" | grep -qF "<promise>COMPLETE</promise>"; then
    echo "✅ Ralph loop complete!"
    LOOP_COMPLETE=true
    break
  fi

  # 通过 claude 退出码检测连续失败
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

创建文件后运行：
```bash
chmod +x ~/.claude/scripts/ralph.sh
```

---

## Eval 策略（分阶段）

### Phase 1：开发中（Ralph 循环内）
- **仅使用单元测试**作为任务完成标准
- 测试必须通过后才能将任务标记为 `[x]`
- 无需复杂的 eval 基础设施

### Phase 2：核心功能完成后（开源前）
- 如果项目涉及 RAG，添加 RAGAs eval
- 编写代表性测试用例，验证检索质量和回答准确性
- 作为回归 eval，防止未来出现退步

### Phase 3：达到用户规模后
- 根据用户反馈添加能力 eval
- 考虑使用基于模型的评判器进行主观质量评估
- 现在不需要考虑这个

---

## 注意事项

- `progress.txt` 和 `feature-requirements.md` **必须提交到 git** — 不要将它们加入 `.gitignore`
- `/start-ralph` 是全局命令，无需任何项目级配置即可在所有项目中使用
- `ralph.sh` 位于全局 `~/.claude/scripts/`，所有项目共享；可从项目任意位置运行 — 脚本会自动跳转到 git 根目录
- 循环运行期间不要中断 — 等循环结束后检查 commit 历史
- 在新机器上恢复此配置：克隆 `claude-dev-setup` 仓库，用 Claude Code 重新执行本指令

## 相对原始设计的 Bug 修复

以下改进是在 review 过程中发现并修复的：

| 问题 | 修复方案 |
|------|----------|
| `echo "$OUTPUT"` 覆盖了 `$?`，导致失败检测失效 | 在 `claude` 命令后立即捕获 `CLAUDE_EXIT=$?` |
| `grep -q "COMPLETE"` 会误匹配 "INCOMPLETE"、"not COMPLETE" 等 | 改用 `grep -qF "<promise>COMPLETE</promise>"` 精确匹配 |
| `progress.txt` 不存在时，脚本静默退出并误报"全部完成" | 添加防护：文件不存在时输出明确错误信息 + `exit 1` |
| 正常 COMPLETE 退出时仍会触发 max-iter 警告 | 添加 `LOOP_COMPLETE` 标志；只在真正超时时才显示警告 |
| 脚本要求必须在项目根目录运行 | 通过 `git rev-parse --show-toplevel` 自动跳转到 git 根目录 |
| `/start-ralph` 在没有 plan 对话上下文时行为未定义 | 添加 fallback：若无上下文则先询问用户需求 |
| `/start-ralph` 错误地输出 `COMPLETE` 信号（语义错误） | 移除：`COMPLETE` 是循环终止信号，不是每次任务完成的信号 |
