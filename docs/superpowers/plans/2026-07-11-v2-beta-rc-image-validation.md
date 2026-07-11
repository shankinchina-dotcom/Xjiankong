# v2-beta RC 本地镜像验证实施计划

> 状态：**Gate 9 阻塞于 Docker Desktop 访问 GHCR；未生成镜像，未进入容器验证。**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从已冻结的 `codex/v2-beta-rc` 提交构建本地 Docker 镜像，并在不接入生产配置的临时容器中验证 v2-beta 运行模块和静态报告能力。

**Architecture:** 以 RC HEAD `8f7e385ac1453521a7ffffa9c5de43d725af76b9` 所在隔离 worktree 为唯一构建上下文，使用仓库内 `docker/Dockerfile` 构建带日期的本地镜像。验证容器只运行一次性 Python 检查和临时报告生成，不挂载生产目录、不启动定时任务、不调用 AI。

**Tech Stack:** Docker Desktop、`docker build`、Python 3.12、TrendRadar 本地 fixture、Git、Markdown。

## Global Constraints

- RC 分支 `codex/v2-beta-rc` 与当前 worktree HEAD 必须同时为 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`；不一致立即停止。
- 构建上下文仅使用 `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history`，不得使用存在未提交改动的 `/Users/shankluo/AI/Claude/TrendRadar`。
- 本地镜像标签固定为 `xjiankong-trendradar:v2-beta-rc-20260711`。
- 不挂载或读取生产 `config/`、`output/`、`.env`、数据库或凭据；容器检查使用临时目录和构造数据。
- 不上传镜像、不导出 tar、不访问 NAS、不修改 `.env`、不重建或重启现有容器、不调用付费 AI、不修改 Cloudflare 或生产环境。
- Docker daemon 未运行时只允许启动本机 Docker Desktop；启动失败或构建需要新的系统权限时停止。
- 本 Gate 不修改 TrendRadar 源码；只允许本地镜像状态、临时容器和两份进度文档发生变化。

## 当前阻塞记录（2026-07-11）

- Task 1 已通过：worktree HEAD 与 `codex/v2-beta-rc` 均为 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`；差异仅含四个运行模块和两个 fixture；Docker Client / Server 均为 `29.5.3`。
- 目标标签 `xjiankong-trendradar:v2-beta-rc-20260711` 在构建前不存在。
- 严格执行原构建命令两次，均在 BuildKit 读取 `ghcr.io/astral-sh/uv:latest` metadata 时以 `DeadlineExceeded: context deadline exceeded` 失败，尚未进入 RC 源码层。
- 宿主机 `curl https://ghcr.io/v2/` 可收到 Registry API 响应，但 Docker engine 的 manifest 查询持续不返回；本机没有可复用的 `ghcr.io/astral-sh/uv:latest` 缓存。
- 目标镜像未生成；Task 2 的 image inspect、Task 3 的 `docker run` 和 Task 4 的成功记录均未执行。
- 未修改 Dockerfile、Docker 设置或镜像源；未 push、save、删除镜像；未访问 NAS、`.env`、容器、Cloudflare 或生产环境。
- 依据同一故障重复后的停止条件，Gate 9 保持阻塞。若要调整 Docker Desktop 网络／代理设置，必须另起本地系统配置闸门并由老板确认。

---

### Task 1：构建前基线与 Docker 环境核验

**Files:**

- Read: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/docker/Dockerfile`
- Read: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history`

**Interfaces:**

- Consumes: `codex/v2-beta-rc` 本地 Git 引用和 Docker Desktop。
- Produces: 可复核的 RC commit、构建上下文、Docker server 与目标镜像标签。

- [x] **Step 1: 确认 RC 引用与构建上下文**

```bash
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history rev-parse HEAD codex/v2-beta-rc
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history status --short --branch
git -C /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history diff --name-status v2-alpha..codex/v2-beta-rc
```

Expected: 两个 SHA 都是 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`；仅有既有未跟踪测试产物；差异不含 config、Docker、数据库和凭据文件。

- [x] **Step 2: 启动并核验本机 Docker daemon**

```bash
docker version --format '{{.Client.Version}}|{{.Server.Version}}'
```

Expected: 客户端和服务端版本均非空。若服务端未运行，启动 Docker Desktop 后重试；不修改 Docker 设置。

- [x] **Step 3: 确认构建文件覆盖运行代码**

```bash
rg -n '^COPY trendradar/ ./trendradar/|^COPY pyproject.toml uv.lock|^ENTRYPOINT' docker/Dockerfile
```

Expected: `COPY trendradar/ ./trendradar/`、依赖锁文件和 entrypoint 均存在。

### Task 2：构建并校验本地 RC 镜像

**Files:**

- Build context: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history`
- Dockerfile: `docker/Dockerfile`

**Interfaces:**

- Consumes: Task 1 已核验的 RC 源码树。
- Produces: 本地镜像 `xjiankong-trendradar:v2-beta-rc-20260711`。

- [ ] **Step 1: 构建本地镜像 — BLOCKED（GHCR metadata 超时）**

```bash
docker build \
  --file docker/Dockerfile \
  --tag xjiankong-trendradar:v2-beta-rc-20260711 \
  .
```

Expected: build exit code 0；不使用 `--push`、不导出 tar。

- [ ] **Step 2: 核验镜像元数据**

```bash
docker image inspect xjiankong-trendradar:v2-beta-rc-20260711 \
  --format '{{.Id}}|{{.Architecture}}|{{.Os}}|{{.Size}}'
```

Expected: image ID 非空、OS 为 `linux`、size 大于 0。

### Task 3：一次性容器级免费验证

**Files:**

- Runtime modules inside image: `/app/trendradar/ai/formatter.py`、`/app/trendradar/context.py`、`/app/trendradar/report/generator.py`、`/app/trendradar/report/html.py`

**Interfaces:**

- Consumes: Task 2 本地 RC 镜像。
- Produces: 模块导入、8 板块、历史 manifest/归档页、RSS 证据流和 Nitter fallback 的容器内验证结果。

- [ ] **Step 1: 验证镜像内源码标记与模块导入**

```bash
docker run --rm \
  --entrypoint python \
  -e LITELLM_LOCAL_MODEL_COST_MAP=True \
  xjiankong-trendradar:v2-beta-rc-20260711 \
  -c "from trendradar.ai.analyzer import SourceRef; from trendradar.ai.formatter import render_ai_analysis_html_web; from trendradar.report.generator import build_history_manifest, write_history_archive_page; from trendradar.report.html import render_html_content; print('RC_IMPORT_OK')"
```

Expected: 输出 `RC_IMPORT_OK`，无 traceback。

- [ ] **Step 2: 在容器临时目录生成并断言报告**

```bash
docker run --rm -i \
  --entrypoint python \
  -e LITELLM_LOCAL_MODEL_COST_MAP=True \
  xjiankong-trendradar:v2-beta-rc-20260711 - <<'PY'
from datetime import datetime
from pathlib import Path
from tempfile import TemporaryDirectory

from trendradar.ai.analyzer import AIAnalysisResult, SourceRef
from trendradar.ai.formatter import render_ai_analysis_html_web
from trendradar.report.generator import (
    build_history_manifest,
    write_history_archive_page,
    write_history_manifest,
)
from trendradar.report.html import render_html_content

nitter_url = "https://nitter.net/elonmusk/status/2074740539874775163"
result = AIAnalysisResult(
    success=True,
    daily_judgment="1. 容器验证 [来源: R001] [来源: R002]",
    research_breakthroughs="研究信号",
    product_tools="产品信号",
    signals="开源信号",
    sentiment_controversy="政策信号",
    rss_insights="X 观点",
    outlook_strategy="风险关注",
    source_map={
        "R001": SourceRef("R001", "rss", "nitter", "Nitter", nitter_url),
        "R002": SourceRef("R002", "rss", "unsafe", "Unsafe", "javascript:alert(1)"),
    },
)
ai_html = render_ai_analysis_html_web(result)
assert ai_html.count('class="report-section"') == 8
assert nitter_url in ai_html
assert "https://x.com/elonmusk/status/2074740539874775163" in ai_html
assert 'href="javascript:' not in ai_html

report_data = {
    "stats": [], "failed_ids": [], "new_titles": [], "total_new_count": 0,
    "hotlist_total": 0, "rss_matched_count": 1, "rss_total_count": 1,
    "rss_source_total": 1, "rss_source_failed": 0,
}
page = render_html_content(
    report_data,
    total_titles=0,
    region_order=["ai_analysis", "rss"],
    get_time_func=lambda: datetime(2026, 7, 11, 12, 0),
    ai_analysis=result,
    snapshot_relative_path="/html/2026-07-11/12-00.html",
    rss_items=[{
        "word": "AI", "count": 1,
        "titles": [{"title": "容器 RSS", "url": "https://example.com", "is_new": True}],
    }],
)
for marker in ("history-drawer", "history-page-notice", "evidence-stream"):
    assert marker in page

with TemporaryDirectory() as temp:
    root = Path(temp)
    snapshot = root / "html" / "2026-07-11" / "12-00.html"
    snapshot.parent.mkdir(parents=True)
    snapshot.write_text(page, encoding="utf-8")
    history_json = write_history_manifest(root)
    assert history_json.is_file()
    manifest = build_history_manifest(root)
    assert set(manifest) == {"schema_version", "latest", "dates"}
    assert manifest["latest"]["path"] == "/html/2026-07-11/12-00.html"
    history_page = write_history_archive_page(root)
    assert history_page.is_file()
    assert "fetch('/history.json')" in history_page.read_text(encoding="utf-8")

print("RC_CONTAINER_OK")
PY
```

Expected: 容器 exit code 0；容器退出后自动删除，不产生宿主机输出文件。

- [ ] **Step 3: 确认没有新增常驻容器**

```bash
docker ps -a --filter ancestor=xjiankong-trendradar:v2-beta-rc-20260711 --format '{{.ID}} {{.Status}}'
```

Expected: 无输出。

### Task 4：记录 Gate 9 结果并停止

**Files:**

- Modify: `docs/superpowers/plans/2026-07-11-v2-beta-rc-image-validation.md`
- Modify: `docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md`

**Interfaces:**

- Consumes: 镜像 ID、架构、大小、容器级验证结果。
- Produces: 可供后续生产同步计划引用的本地镜像验证记录。

- [ ] **Step 1: 回写构建与验证事实**

记录镜像标签、image ID、architecture、size、构建结果、容器级断言、未执行项和已知限制。只有实际命令通过的项目才能标为完成。

- [ ] **Step 2: 运行项目文档校验**

```bash
cd /Users/shankluo/AI/Claude/Xjiankong
jq empty config/x-accounts.json
bash quality-check.sh
bash quality-check.sh --trendradar
rg -n 'A2.*(实施|运行|待接入)|X Hosted MCP.*(主线|当前)' AGENTS.md CLAUDE.md ai-intelligence-hub-design.md docs --glob '!docs/archive/**'
git diff --check
```

Expected: JSON、30/30、37/37 和差异检查通过；A2 仍为归档方案。

- [ ] **Step 3: 仅提交 Gate 9 两份文档**

```bash
git add docs/superpowers/plans/2026-07-11-v2-beta-rc-image-validation.md docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md
git commit -m "docs: record v2 beta RC image validation"
```

Expected: 不包含 Xjiankong 既有未提交文件；TrendRadar 分支不新增源码提交。

## Gate Contract

**Gate name:** Gate 9 v2-beta RC 本地镜像构建与容器级免费验证。

**Goal:** 证明冻结的 RC 可以由现有 Dockerfile 构建，并在一次性容器中正确提供 v2-beta 网页、历史与来源能力。

**Allowed actions:** 启动本机 Docker Desktop、本地 `docker build`、本地 image inspect、一次性 `docker run --rm`、免费本地测试、两份文档更新和本地文档提交。

**Forbidden actions:** `docker push`、镜像 tar 导出、NAS/SSH、修改 `.env`、挂载生产配置或数据、重建/重启现有容器、付费 AI、Cloudflare、生产部署、TrendRadar 源码改动。

**Validation:** RC SHA 完全一致；镜像构建成功；容器内导入和报告断言成功；无新增常驻容器；文档质量检查通过。

**Stop conditions:** RC SHA 漂移、未知源文件差异、Docker daemon/构建失败、容器断言失败、出现凭据/生产挂载需求或需要改变生产环境。

**Next Owner after completion:** Codex 审核 Gate 9；镜像上传和 NAS 同步另起 Gate 10 并由老板单独批准。
