# v2-beta RC 本地镜像验证实施计划

> 状态：**Gate 9 停在受控本地恢复点：Docker Engine/BuildKit 对 GHCR 与 Docker Hub metadata/pull 均卡住；`uv` stage cache 已验证，Python base cache 首次导入失败并留下 714B 无效标签。目标 RC 镜像未生成，未进入容器验证。**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从已冻结的 `codex/v2-beta-rc` 提交构建本地 Docker 镜像，并在不接入生产配置的临时容器中验证 v2-beta 运行模块和静态报告能力。

**Architecture:** 以 RC HEAD `8f7e385ac1453521a7ffffa9c5de43d725af76b9` 所在隔离 worktree 为唯一构建上下文，使用仓库内 `docker/Dockerfile` 构建带日期的本地镜像。验证容器只运行一次性 Python 检查和临时报告生成，不挂载生产目录、不启动定时任务、不调用 AI。

**Tech Stack:** Docker Desktop、`docker build`、Python 3.12、TrendRadar 本地 fixture、Git、Markdown。

## Global Constraints

- RC 分支 `codex/v2-beta-rc` 与当前 worktree HEAD 必须同时为 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`；不一致立即停止。
- 构建上下文仅使用 `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history`，不得使用存在未提交改动的 `/Users/shankluo/AI/Claude/TrendRadar`。
- 本地镜像标签固定为 `xjiankong-trendradar:v2-beta-rc-20260711`。
- 镜像平台固定为 `linux/amd64`：已上线的 `xjiankong-trendradar:v2-alpha-20260709` 是 `linux/amd64`，而本机 Docker host 为 `linux/arm64`；不得默认构建 host 架构镜像。
- 不挂载或读取生产 `config/`、`output/`、`.env`、数据库或凭据；容器检查使用临时目录和构造数据。
- 不上传镜像、不导出 tar、不访问 NAS、不修改 `.env`、不重建或重启现有容器、不调用付费 AI、不修改 Cloudflare 或生产环境。
- Docker daemon 未运行时只允许启动本机 Docker Desktop；启动失败或构建需要新的系统权限时停止。
- 本 Gate 不修改 TrendRadar 源码；只允许本地镜像状态、临时容器和两份进度文档发生变化。

## 当前阻塞记录（2026-07-11）

- Task 1 已通过：worktree HEAD 与 `codex/v2-beta-rc` 均为 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`；差异仅含四个运行模块和两个 fixture；Docker Client / Server 均为 `29.5.3`。
- 目标标签 `xjiankong-trendradar:v2-beta-rc-20260711` 在构建前不存在。
- 严格执行原构建命令两次，均在 BuildKit 读取 `ghcr.io/astral-sh/uv:latest` metadata 时以 `DeadlineExceeded: context deadline exceeded` 失败，尚未进入 RC 源码层。
- 宿主机与临时容器均可访问 GHCR、Docker Hub 的公开 registry API；Docker Engine 的 manifest/pull 通道持续不返回，表明问题局限于 Docker Engine/BuildKit 的 registry 客户端路径。
- 目标镜像未生成；Task 2 的 image inspect、Task 3 的 `docker run` 和 Task 4 的成功记录均未执行。
- 未修改 Dockerfile、Docker 设置或镜像源；未 push、save、删除镜像；未访问 NAS、`.env`、容器、Cloudflare 或生产环境。
- `uv` 本地 stage cache 已生成并验证：`ghcr.io/astral-sh/uv:latest` 为 `linux/amd64`、24,935,106 bytes，`/uv` 与 `/uvx` 均为 `0.11.22`。使用该 cache 的一次构建已越过 GHCR stage，但在官方 Python base metadata 处同样超时。
- Python base cache 的首次官方 OCI 导入失败，留下 `python:3.12-slim-bookworm` / `sha256:a1d192bc…`（`linux/amd64`、714 bytes）；`python --version` 不存在。该标签是本 Gate 生成的无效临时产物，禁止用于构建。
- 依据同一故障重复后的停止条件，Gate 9 保持阻塞；下一恢复动作仅限清理上述无效标签并以可观测的官方 OCI rootfs 流程重建 Python base cache。若仍失败，停止，不调整 Docker Desktop 网络／代理设置。

**受控恢复路径（Gate 9A 已证实 Docker pull／BuildKit 客户端卡死后）：**

- `xjiankong-trendradar:v2-alpha-20260709` 是同一 Dockerfile 的已验证 `linux/amd64` 本地镜像，已核验含 `/bin/uv` 与 `/bin/uvx`，二者版本均为 `0.11.22`。
- 可以只从这两个本地二进制生成临时、同名的 `ghcr.io/astral-sh/uv:latest` 本地 stage cache；该 cache 只满足 Dockerfile 的 `COPY --from=... /uv /uvx /bin/`，不包含 TrendRadar 代码，不上传、保存或用于生产。
- cache 必须经 `linux/amd64` inspect 和 `/uv --version` 验证后，才可以用原 Dockerfile 执行一次 `--platform linux/amd64 --pull=false` 本地构建。
- 若 cache 或该构建失败，立即停止；不得修改 Dockerfile 或把临时 cache 当作发布产物。

**Python base 同类恢复路径：**

- 在 uv cache 命中后，BuildKit 又在 `docker.io/library/python:3.12-slim-bookworm` metadata 阶段超时；不得将带旧 TrendRadar 应用层的 v2-alpha 镜像直接伪装为 Python base。
- 可通过 Docker Hub 公开 registry API 获取 `python:3.12-slim-bookworm` 的 `linux/amd64` manifest 和 layers，在临时 rootfs 中按 OCI whiteout 规则应用 layers，再以 `docker import --platform linux/amd64` 导入同名本地 base cache。
- 导入后必须只核验 Python 版本和 `linux/amd64` 平台；临时 rootfs 与下载层必须清理；该 base cache 不上传、不导出、不作为发布产物。
- 仅当官方 Python rootfs cache 成功时，允许再次使用原 Dockerfile、`--platform linux/amd64 --pull=false` 重试一次。
- 开始该恢复前，必须只删除 `python:3.12-slim-bookworm` 的已记录 714B 无效标签，并立即验证该标签不存在；不得删除其他镜像或容器。恢复过程必须保留非敏感阶段指标（平台 manifest 是否解析、layer 数、每层是否成功应用、import 退出码），不记录 token、代理值、签名 URL 或 layer 内容。

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
  --platform linux/amd64 \
  --pull=false \
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
