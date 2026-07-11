# v2-beta 发布候选与集成实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将已通过 Gate 7 的 `codex/v2-beta-history` 固定为可审计的本地发布候选，并形成不覆盖主 worktree 用户改动的集成路径。

**Architecture:** 生产基线 `v2-alpha` 保持不动；发布候选使用新的本地分支 `codex/v2-beta-rc` 指向已验证提交。由于主 worktree 存在未提交改动，本 Gate 不在主 worktree merge，不清理、不覆盖、不构建镜像；下一生产闸门直接以 RC 分支为构建输入。

**Tech Stack:** Git、Python fixture、TrendRadar Dockerfile 静态检查、Markdown 进度文档。

## Global Constraints

- 生产基线：TrendRadar `v2-alpha` HEAD `33d80973`。
- 发布候选源：`codex/v2-beta-history` HEAD `8f7e385a`。
- 不修改或暂存 `/Users/shankluo/AI/Claude/TrendRadar` 主 worktree 的任何既有改动。
- 不执行 push、tag、rebase、merge、分支删除或 worktree 清理。
- 不构建镜像、不访问 NAS、不改 `.env`、不重启容器、不调用付费 AI、不修改 Cloudflare 或生产环境。
- RC 只允许由已验证 HEAD 建立分支引用；若源分支 HEAD 变化，必须重新执行全部 Gate 7 验证。

---

### Task 1：审计基线与差异范围

**Files:**

- Read: `/Users/shankluo/AI/Claude/TrendRadar/.git`
- Read: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history`

**Interfaces:**

- Consumes: `v2-alpha` 与 `codex/v2-beta-history` 的本地 Git 引用。
- Produces: 可验证的 merge-base、领先提交数和精确文件清单。

- [x] **Step 1: 确认 worktree 与分支状态**

```bash
git -C /Users/shankluo/AI/Claude/TrendRadar worktree list --porcelain
git -C /Users/shankluo/AI/Claude/TrendRadar status --short --branch
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history status --short --branch
```

预期：主 worktree 为 `v2-alpha` 且保留既有改动；隔离 worktree 为 `codex/v2-beta-history`，仅有未跟踪测试产物。

- [x] **Step 2: 确认快进关系**

```bash
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history merge-base v2-alpha HEAD
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history rev-list --left-right --count v2-alpha...HEAD
```

预期：merge-base 为 `33d80973`，左右计数为 `0 12`。

- [x] **Step 3: 确认差异文件**

```bash
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history diff --name-status v2-alpha..HEAD
```

预期：仅 2 个 fixture 与 `formatter.py`、`context.py`、`generator.py`、`html.py`，不包含 config、Docker、数据库或凭据文件。

### Task 2：建立本地发布候选分支

**Files:**

- Create Git ref: `refs/heads/codex/v2-beta-rc`

**Interfaces:**

- Consumes: 已验证提交 `8f7e385a`。
- Produces: 本地发布候选分支 `codex/v2-beta-rc`，必须精确指向同一提交。

- [x] **Step 1: 创建 RC 分支引用**

```bash
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history branch codex/v2-beta-rc 8f7e385a
```

预期：仅新增本地分支引用，不切换 worktree，不修改文件。

- [x] **Step 2: 验证 RC 引用**

```bash
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history rev-parse codex/v2-beta-rc
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history rev-parse codex/v2-beta-history
```

预期：两者均为 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`。

### Task 3：RC 自审与构建路径检查

**Files:**

- Read: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/docker/Dockerfile`
- Test: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/tests/fixtures/v2_beta_deep_space_ui.py`
- Test: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/tests/fixtures/v2_beta_history_manifest.py`

**Interfaces:**

- Consumes: `codex/v2-beta-rc` 指向的代码树。
- Produces: RC 测试结果和 Dockerfile 是否包含全部运行代码的静态结论。

- [x] **Step 1: 运行全部免费回归**

```bash
cd /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history
LITELLM_LOCAL_MODEL_COST_MAP=True PYTHONPATH=. python3 tests/fixtures/v2_beta_deep_space_ui.py
LITELLM_LOCAL_MODEL_COST_MAP=True PYTHONPATH=. python3 tests/fixtures/v2_beta_history_manifest.py
LITELLM_LOCAL_MODEL_COST_MAP=True PYTHONPATH=. python3 tests/fixtures/v2_alpha_fixture.py
LITELLM_LOCAL_MODEL_COST_MAP=True PYTHONPATH=. python3 tests/fixtures/v2_alpha_task3.py
LITELLM_LOCAL_MODEL_COST_MAP=True PYTHONPATH=. python3 tests/fixtures/v2_alpha_task4.py
python3 -m py_compile trendradar/ai/formatter.py trendradar/report/html.py trendradar/report/generator.py trendradar/context.py
git diff --check v2-alpha..codex/v2-beta-rc
```

预期：15/15、2/2、v2-alpha schema、8/8、10/10、编译与差异检查均通过。

- [x] **Step 2: 静态检查 Dockerfile 构建覆盖**

```bash
rg -n '^COPY trendradar/ ./trendradar/|^COPY tests/|^COPY config/' docker/Dockerfile
```

预期：`COPY trendradar/ ./trendradar/` 会包含本轮四个运行模块；测试文件不要求进入生产镜像。

### Task 4：记录 RC 状态并停止于生产闸门前

**Files:**

- Modify: `docs/superpowers/plans/2026-07-11-v2-beta-release-candidate-integration.md`
- Modify: `docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md`

**Interfaces:**

- Consumes: RC 分支、完整回归与 Dockerfile 静态检查结果。
- Produces: 下一生产闸门可直接使用的单一 RC 基线。

- [x] **Step 1: 回写 RC 分支、提交与验证事实**

将本计划 Task 2–4 标记完成，并在设计规格中记录：RC 分支、HEAD、差异文件、测试结果、未执行项。

**完成记录（2026-07-11）：**

- `codex/v2-beta-rc` 已建立，精确指向 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`，与 `codex/v2-beta-history` 完全一致。
- 相对生产基线 `v2-alpha`：0 个基线独有提交、12 个 RC 提交；merge-base 为 `33d80973`，属于严格快进关系。
- 差异仅包含两个 fixture 和四个运行模块：`formatter.py`、`context.py`、`generator.py`、`html.py`；没有 config、Docker、数据库或凭据文件差异。
- RC 免费回归通过：v2-beta UI 15/15、history manifest 2/2、v2-alpha schema、解析 8/8、HTML 10/10、相关模块编译和差异检查。
- 实际构建入口为 `docker/Dockerfile`；第 63 行 `COPY trendradar/ ./trendradar/` 会复制四个运行模块。根目录不存在 `Dockerfile`，计划已按实测路径修正。
- 主 `v2-alpha` worktree 存在用户未提交改动和运行产物，本 Gate 没有 merge、切换、覆盖、清理或暂存其中任何文件。
- 未执行 push、tag、Docker build、NAS、`.env`、容器、Cloudflare、付费 AI 或生产部署。

- [x] **Step 2: 运行项目文档校验**

```bash
cd /Users/shankluo/AI/Claude/Xjiankong
jq empty config/x-accounts.json
bash quality-check.sh
bash quality-check.sh --trendradar
rg -n 'A2.*(实施|运行|待接入)|X Hosted MCP.*(主线|当前)' AGENTS.md CLAUDE.md ai-intelligence-hub-design.md docs --glob '!docs/archive/**'
git diff --check
```

预期：JSON、30/30、37/37 和差异检查通过；A2 仍为归档方案。

- [x] **Step 3: 仅提交两份 Gate 8 文档**

```bash
git add docs/superpowers/plans/2026-07-11-v2-beta-release-candidate-integration.md docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md
git commit -m "docs: freeze v2 beta release candidate"
```

预期：不包含主仓库其他既有改动。

## Gate Contract

**Gate name:** Gate 8 v2-beta 发布候选与集成准备。

**Goal:** 固定本地 RC 基线并形成可审计、不会覆盖主 worktree 的集成路径。

**Allowed actions:** 本地只读 Git 审计、新建本地 RC 分支引用、免费测试、文档更新和本地文档提交。

**Forbidden actions:** merge、push、tag、分支删除、worktree 清理、Docker build、NAS/SSH、`.env`、容器、Cloudflare、付费 AI 和生产部署。

**Validation:** RC 与源分支 commit 完全一致；差异范围无 config/凭据/数据库；全部 fixture 与文档质量检查通过。

**Stop conditions:** RC 指向错误、发现未知差异、测试失败、Dockerfile 不包含运行代码，或下一步需要进入任何生产动作。

**Next Owner after completion:** Codex 提交 Gate 8 审计报告；生产镜像构建另起 Gate 9。
