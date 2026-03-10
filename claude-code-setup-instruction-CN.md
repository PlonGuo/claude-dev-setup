# Claude Code Setup Instruction

## 背景

我已经阅读了以下三篇 Anthropic 文章，请你也认真阅读并理解其中的核心实践：

1. Effective harnesses for long-running agents
   https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

2. Building a C compiler with a team of parallel Claudes
   https://www.anthropic.com/engineering/building-c-compiler

3. Demystifying evals for AI agents
   https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents

读完后，按照下面的要求帮我配置我的开发环境。

---

## 我的工作流

我采用 **Ralph loop** 工作模式：

1. **Plan Mode**（我和你对话）：讨论需求、设计架构、明确 task
2. **`/start-ralph`**（slash command）：自动生成所需文件并执行第一个 task
3. **`bash ~/.claude/scripts/ralph.sh`**：全自动循环执行剩余 task，直到全部完成
4. **Review**：我检查 commit history，不满意则退出 loop 手动修改

---

## 核心原则

- **每次 Ralph loop 使用 fresh context window**，不使用官方 Ralph 插件（会导致 context 堆积降低质量）
- **每个 task = 一个可独立测试的功能点**，完成后必须有对应测试通过才标记 `[x]`
- **task 粒度适中**：不能太大（一个 context 跑不完），不能太小（碎片化）
- **单元测试是 task 完成的唯一标准**，测试不通过不标 `[x]`，重试直到通过或超过最大次数
- **每次 loop 开始时读取 git log + progress.txt**，重建上下文后再执行下一个 task
- **progress.txt 和 feature-requirements.md 必须提交到 git**，这是 loop 跨 context 的核心记忆

---

## 需要配置的文件

### 1. 全局规则 `~/.claude/CLAUDE.md`

写入以下内容：

```markdown
# Global Rules

## Ralph Loop Workflow
- 所有项目默认采用 Ralph loop 工作模式
- 每次 loop 使用 fresh context window
- 每次 loop 开始时必须先读取 git log 和 progress.txt 重建上下文
- task 完成标准：对应单元测试全部通过
- progress.txt 和 feature-requirements.md 必须提交到 git

## Long-Running Agent Best Practices
@~/.claude/docs/effective-harnesses.md

## Parallel Agent Best Practices
@~/.claude/docs/building-c-compiler.md

## Eval Best Practices
@~/.claude/docs/demystifying-evals.md
```

---

### 2. 文章摘要文件 `~/.claude/docs/`

使用 web_fetch 完整获取每篇文章，提炼成 **200 字以内的核心实践要点**，不要粘贴原文，只保留可操作的最佳实践。

创建以下三个文件：
- `~/.claude/docs/effective-harnesses.md`
- `~/.claude/docs/building-c-compiler.md`
- `~/.claude/docs/demystifying-evals.md`

---

### 3. 全局 Slash Command `~/.claude/commands/start-ralph.md`

放在**全局** `~/.claude/commands/` 目录下，所有项目都可以直接使用。

内容要求：
- 读取当前 git log 和已有的 progress.txt（如果存在）了解项目状态
- 根据 Plan Mode 的对话内容，生成 `feature-requirements.md`
  - 清晰的 task list，每个 task 有明确的完成标准
  - 每个 task 注明对应的测试验证方式（单元测试/lint/类型检查）
- 初始化或更新 `progress.txt`
  - 所有 task 标记为 `[ ]`
  - 记录项目名称、开始时间、技术栈
- 提交 `feature-requirements.md` 和 `progress.txt` 到 git
- 执行第一个 `[ ]` task
  - 完成后写单元测试
  - 测试通过后 commit，更新 `progress.txt` 标记 `[x]`
  - 输出 `<promise>COMPLETE</promise>` 等待下一次循环

---

### 4. 全局 Ralph bash 脚本 `~/.claude/scripts/ralph.sh`

放在**全局** `~/.claude/scripts/` 目录下，所有项目共用同一个脚本。

```bash
#!/bin/bash

MAX_ITERATIONS=50
ITERATION=0
CONSECUTIVE_FAILURES=0
MAX_FAILURES=3

while [ $ITERATION -lt $MAX_ITERATIONS ]; do
  ITERATION=$((ITERATION + 1))
  echo "=== Ralph iteration $ITERATION ==="

  # 检查是否所有 task 完成
  if ! grep -q "\[ \]" progress.txt 2>/dev/null; then
    echo "✅ All tasks complete!"
    break
  fi

  # 执行一次 Claude Code（fresh context）
  # 每次都读取 git log + progress.txt 重建上下文
  OUTPUT=$(claude -p "
    First, read git log --oneline -20 to understand recent progress.
    Then read feature-requirements.md and progress.txt.
    Find the next incomplete [ ] task and execute it.
    Write corresponding unit tests and ensure they pass.
    Commit the code and update progress.txt to mark the task [x].
    Output <promise>COMPLETE</promise> when all tasks are done.
  " --dangerously-skip-permissions 2>&1)

  echo "$OUTPUT"

  # 检测完成信号
  if echo "$OUTPUT" | grep -q "COMPLETE"; then
    echo "✅ Ralph loop complete!"
    break
  fi

  # 检测连续失败，防止无限卡死
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

创建完成后运行：
```bash
chmod +x ~/.claude/scripts/ralph.sh
```

---

## Eval 策略（分阶段）

### 阶段一：开发阶段（Ralph loop 中）
- **只用单元测试作为 task 完成标准**
- 每个 task 完成后自动跑测试，通过才标 `[x]`
- 不需要复杂 eval 体系

### 阶段二：核心功能完成后（开源前）
- 针对产品功能加 RAGAs eval（如果项目是 RAG 相关）
- 写几个典型测试用例验证检索质量和回答准确度
- 作为 regression eval，保证后续修改不回退

### 阶段三：有用户规模后
- 根据用户反馈补充 capability eval
- 考虑 model-based grader 评估主观质量
- 目前不需要考虑

---

## 注意事项

- `progress.txt` 和 `feature-requirements.md` **必须提交到 git**，不要加入 `.gitignore`
- `/start-ralph` 是全局 command，所有项目直接可用，不需要每个项目单独创建
- `ralph.sh` 放在全局 `~/.claude/scripts/`，所有项目共用
- Ralph loop 跑的时候不要手动干预，跑完再 review commit history
- 新机器恢复：clone `claude-dev-setup` repo，把此文件丢给 Claude Code 重新执行即可
