# Global Quality Commands Setup: `/quality-gate` + `/quality-fix`

> **How to use this document:** Paste the contents of this file to your Claude Code. It will automatically create two global commands in `~/.claude/skills/` that work across all your projects, in any language or stack.

---

## What You're Getting

Two on-demand slash commands that enforce engineering quality standards across any project:

| Command | What it does |
|---------|-------------|
| `/quality-gate` | Audits the project — detects stack, checks coverage/linting/security/CI gaps, writes a report to `.claude/quality-gate.md`. **Read-only.** |
| `/quality-fix` | Reads the gap report and implements approved fixes — updates config files, installs deps (with permission), updates CI (with separate permission). |

**Design principles:**
- Works across all languages (Python, Node/TS, Go, Rust, Java, Ruby, PHP, and more)
- Reads `CLAUDE.md` Tech Stack section first; infers from project files if not found
- Audit and implementation are **separate commands** — different blast radii
- Every destructive step (installs, CI changes) requires explicit user confirmation
- Failure stops immediately — never silently continues to the next gap

---

## Instructions for Claude Code

Please create the following two skill files exactly as written below.

---

### File 1: `~/.claude/skills/quality-gate/SKILL.md`

```markdown
---
name: quality-gate
description: Use when assessing a project's engineering quality before a PR or feature branch completion. Detects stack, audits test coverage, linting, type checking, security scanning, and CI/CD gaps. Writes a gap report to .claude/quality-gate.md. Triggers on "quality check", "audit quality", "check coverage", "run quality gate", "engineering standards", "pre-PR checks".
---

# Quality Gate

Audit the current project's engineering quality and write a gap report. Read-only — no files are modified.

## Phase 1 — Stack Detection

Check in this order:

1. **Read `CLAUDE.md`** — look for a `Tech Stack` section. If found, use it directly.
2. **Infer from project files** — scan root and subdirectories:
   - `pyproject.toml` / `requirements.txt` → Python (check `uv.lock` → uv, `poetry.lock` → poetry, else pip)
   - `package.json` → Node/TS (check `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, else npm)
   - `go.mod` → Go
   - `Cargo.toml` → Rust
   - `pom.xml` / `build.gradle` → Java/Kotlin
   - `Gemfile` → Ruby
   - `composer.json` → PHP
3. **Monorepos** — detect multiple stacks per subdirectory, audit each independently.

## Phase 2 — Audit Per Stack

For each check, determine three things:
- **Installed** — is the tool listed in project deps (not just globally installed)?
- **Configured** — is there a config section in the manifest file?
- **In CI** — does `.github/workflows/` (or equivalent) have a step for it?

Canonical toolchain reference:

| Stack | Tests | Coverage | Linting | Type Check | Security |
|-------|-------|----------|---------|------------|----------|
| Python (uv) | pytest | pytest-cov | ruff | mypy | pip-audit |
| Python (pip) | pytest | pytest-cov | ruff/flake8 | mypy | pip-audit/safety |
| Node/TS (pnpm) | vitest/jest | built-in | eslint | tsc | pnpm audit |
| Node/TS (npm) | vitest/jest | built-in | eslint | tsc | npm audit |
| Go | go test | go test -cover | staticcheck | (built-in) | govulncheck |
| Rust | cargo test | cargo tarpaulin | clippy | (built-in) | cargo audit |
| Java | junit | jacoco | checkstyle | (built-in) | OWASP dependency-check |
| Ruby | rspec | simplecov | rubocop | sorbet | bundler-audit |
| PHP | phpunit | xdebug/pcov | phpcs/phpstan | phpstan | local-php-security-checker |

## Phase 3 — Ask Coverage Target

If coverage is a gap, ask before writing the report:
> "What coverage threshold would you like to target? (e.g. 80%, or 'report only' to just measure without failing)"

## Phase 4 — Write Gap Report

**Before writing:** if `.claude/quality-gate.md` already exists, warn:
> "A previous report exists (Generated: X). Overwrite with a fresh audit? This will lose any [x] progress markers from a previous /quality-fix run."

Write `.claude/quality-gate.md`:

​```
# Quality Gate Report
Generated: <date>
Stack(s): <detected>

## <Stack Name> (<package manager>)

| Check         | Installed | Configured | In CI | Notes                    |
|---------------|-----------|------------|-------|--------------------------|
| Tests         | ✅ / ❌   | ✅ / ❌   | ✅/❌ | <details>                |
| Coverage      | ✅ / ❌   | ✅ / ❌   | ✅/❌ | Target: X% / report-only |
| Linting       | ✅ / ❌   | ✅ / ❌   | ✅/❌ | <details>                |
| Type Check    | ✅ / ❌   | ✅ / ❌   | ✅/❌ | <details>                |
| Security Scan | ✅ / ❌   | ✅ / ❌   | ✅/❌ | <details>                |

## Gaps Summary
- [ ] Gap 1: <description>
- [ ] Gap 2: <description>

## Next Step
Run `/quality-fix` to implement selected gaps.
​```

**Do NOT modify `.gitignore` or any other file** — this command is read-only. All writes are deferred to `/quality-fix`.

**Monorepo rule:** if multiple manifest files of the same type exist, treat each subdirectory's manifest independently and label each section clearly in the report.
```

---

### File 2: `~/.claude/skills/quality-fix/SKILL.md`

```markdown
---
name: quality-fix
description: Use after running /quality-gate to implement the gaps identified in .claude/quality-gate.md. Adds missing test infrastructure, linting config, security scanning, and CI/CD steps. Requires the gap report to exist first. Triggers on "fix quality gaps", "implement quality fixes", "run quality fix".
---

# Quality Fix

Implement the gaps identified by `/quality-gate`. Requires `.claude/quality-gate.md` to exist.

## Phase 1 — Read Gap Report

Read `.claude/quality-gate.md`.

- **If not found:** stop and tell the user: "No gap report found. Run `/quality-gate` first to audit the project."
- **Check `Generated:` date:** if older than 7 days, warn: "This report is X days old. The project may have changed. Run `/quality-gate` again for a fresh audit, or proceed with the existing report?"
- **Check `.gitignore`:** if `.claude/quality-gate.md` is not already ignored, add it now (first and only low-risk write before user confirmation).

## Phase 2 — Confirm Scope

Show the unchecked gaps (`- [ ]`) from the report and ask:
> "Which gaps would you like me to implement? (all / list numbers / none)"

Do not proceed until the user responds.

## Phase 3 — Implement (Three-Step, Each Gated)

### Step 1 — Update config files

For each approved gap:
- Dynamically locate the correct manifest file by scanning the project (no hardcoded paths)
- For monorepos: update the manifest closest to the detected test root for that stack
- Add missing tool config sections following the project's existing formatting conventions
- Do **not** touch CI files yet

Show a summary of all config changes made before moving to Step 2.

### Step 2 — Ask before installing

List all install commands needed, then ask:
> "Config files updated. Ready to run these install commands? [list exact commands] Proceed?"

**Important:** if install fails partway through, config files are already updated but deps are not installed — advise the user to run `git diff` to review what changed and revert manually if needed.

### Step 3 — Ask before CI changes

After installs complete, ask separately:
> "Dependencies installed. Ready to update the CI pipeline (.github/workflows/)? This modifies shared infrastructure — a broken YAML can silently disable CI for the whole team."

Only proceed with CI edits after explicit confirmation.

## Phase 4 — Post-Implementation Verification

After fixing each gap, immediately run the newly configured tool to confirm it works:

| Gap fixed | Verification command |
|-----------|---------------------|
| Python linting (ruff) | `ruff check .` |
| Python coverage | `pytest --cov` |
| Python security | `pip-audit` |
| Node linting | `eslint .` (or `pnpm lint`) |
| Node coverage | `vitest run --coverage` |
| Node security | `pnpm audit` / `npm audit` |
| Go coverage | `go test ./... -cover` |
| Rust linting | `cargo clippy` |
| Rust security | `cargo audit` |

**On failure — stop immediately, do not continue to the next gap:**
> "Verification failed for [tool]: [error output]. Fix this before proceeding, or skip this gap?"

Never silently move to the next gap. A half-configured project is worse than an unconfigured one.

## Phase 5 — Update Gap Report

Mark each successfully fixed gap as `[x]` in `.claude/quality-gate.md`.

---

## What This Command Does NOT Do

- Does NOT scaffold test files without explicit user approval
- Does NOT enforce a fixed coverage threshold — respects what was set in `/quality-gate`
- Does NOT touch production code
- Does NOT hardcode project-specific paths
- Does NOT modify CI pipelines without a separate explicit confirmation
```

---

## Usage

```
# Step 1: Audit your project
/quality-gate

# Step 2: Review .claude/quality-gate.md, then implement fixes
/quality-fix
```

The gap report at `.claude/quality-gate.md` persists between sessions — you can audit on Monday and fix on Tuesday.
