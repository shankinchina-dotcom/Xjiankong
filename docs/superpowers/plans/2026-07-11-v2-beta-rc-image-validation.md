# v2-beta RC 本地镜像验证实施计划

> 状态：**Gate 9 已于 2026-07-13 完成。官方 Python base cache、最小 Dockerfile 构建兼容性修复、本地 RC 镜像、`RC_IMPORT_OK`、`RC_CONTAINER_OK` 与无残留容器检查均已通过；RC 镜像已于 2026-07-14 经 Gate 10 部署至生产并完成 10D 验收，详见 `../../roadmap.md`。**

> 2026-07-12 执行记录：执行 Agent 在删除前停止。临时恢复脚本的 Registry 前置查询在约 27 秒后结束却没有产生可审计 stdout/stderr；因此未满足 config 等价性闸门，未删除标签、未下载 layer、未写 rootfs、未 import、未 build、未运行容器。临时脚本与目录均已清理。主控直接 `HEAD /v2/` 获得 Docker Hub 的公开 `401 Bearer` challenge，确认 registry 路由可达；当前阻塞是脚本可观测性而非 registry 路由。下一动作仅限只读逐阶段可观测性预检。

> Gate 9A 第一次预检记录：脚本只输出 `GATE9A_START|exit=0` 与 `GATE9A_STOP|HEAD_V2|exit=10`，没有保存 HTTP 状态或 stderr，故失败不可审计。`HEAD /v2/` 的预期结果是 `401` 加 `WWW-Authenticate: Bearer ...`，不是 2xx；下一次只读预检必须把这一预期 401 作为成功条件，并显式输出 HTTP 状态和 challenge 是否存在。没有删除、下载、rootfs、import、build、run 或项目文件变更。

> Gate 9A-2 预检通过记录：修正规则后，脚本输出 `HEAD /v2/` 为 HTTP `401`、Bearer challenge 存在、token 仅存在于进程变量、manifest 为 HTTP `200` 且解析到 7 个架构描述符；每个阶段 exit 均为 0。日志只含阶段标记、HTTP 状态、token 长度与 manifest 摘要，敏感模式扫描无命中；脚本与日志已清理。该结果只允许重新开始删除前核验，不等于 OCI config/layer/base cache 已通过。

> Gate 9 恢复尝试记录：执行 Agent 重新核验 `python:3.12-slim-bookworm` 为 `sha256:a1d192bc…`、`linux/amd64`、714B 后，按授权只删除该标签并确认不存在。唯一 `linux/amd64` child manifest 与 digest 校验通过；config blob 的 sha256 未匹配 descriptor，且脚本尚未证明其 blob 请求是否正确处理 Registry 重定向，故在 `CONFIG_DIGEST` 阶段停止。没有 layer、rootfs、import、build、run 或项目文件变更；临时脚本、日志和目录均已清理。

> Gate 9B 通过记录：config blob 初始 endpoint 返回 HTTP `307` 且存在 Location；启用安全重定向跟随后为 HTTP `200`，最终原始字节 sha256 与官方 config descriptor 匹配。日志只含状态、布尔值与退出码，敏感模式扫描无命中，临时脚本/日志/目录均已清理。该结果仅解除 config blob 传输疑点；后续 layer、DiffID、rootfs、import config 等价性和 RC 构建仍未执行。

> Docker load archive 恢复与 build 记录：唯一 `linux/amd64` manifest 的 4 个 layers 均完成压缩 digest 与解压 DiffID 校验，原始官方 config 与字段等价校验通过；`docker load` 成功得到 `python:3.12-slim-bookworm`（`linux/amd64`、129,079,727 bytes），`python --version` 通过。随后唯一一次 RC build 失败于 Dockerfile 第 48 行的 `supercronic -version`：本机 ARM Docker 模拟运行 amd64 Go 二进制时崩溃。RC 镜像未生成，未重试，未执行容器断言；临时产物均已清理。该问题不改变 RC 源码基线，需另起最小 Dockerfile 兼容性修复 Gate。

> Gate 9.5 记录：隔离 worktree 提交 `5c02c6ce` 仅将 `supercronic -version` 替换为 `test -x /usr/local/bin/supercronic`；RED/GREEN 临时检查、SHA-1 保留核验和最小 diff 均通过。唯一重新 build 成功，镜像 `xjiankong-trendradar:v2-beta-rc-20260712` 为 `linux/amd64`、ID `sha256:91983de58c07…`、138,047,386 bytes，且无基于该镜像的常驻容器。第一次 `RC_IMPORT_OK` 命令只捕获到跨架构 warning，未取得成功标记；该容器随后自动移除。因此不得把容器验证标为完成，且未运行 `RC_CONTAINER_OK`。

> Gate 9.7 完成记录：独立 Agent 只读审计后，主控在可保留输出的本地执行会话中，对固定镜像 `xjiankong-trendradar:v2-beta-rc-20260712` 顺序运行原容器断言。`RC_IMPORT_OK` 与 `RC_CONTAINER_OK` 均为退出码 0 且仅输出对应成功标记；最终无基于该镜像的残留容器，镜像仍为 `sha256:91983de58c07a12c9fc0ada28474e1d48de26b5a126c3d8fd7f6971f7a748ee4`、`linux/amd64`、138,047,386 bytes。新的独立验收 Agent 复核后同意 Gate 9 完成；未执行 Gate 10 或生产动作。

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 从已冻结的 `codex/v2-beta-rc` 提交构建本地 Docker 镜像，并在不接入生产配置的临时容器中验证 v2-beta 运行模块和静态报告能力。

**Architecture:** 以功能 RC `8f7e385ac1453521a7ffffa9c5de43d725af76b9` 所在隔离 worktree 为构建上下文；Gate 9.5 仅增加 Docker 构建兼容性提交 `5c02c6ce`，再使用仓库内 `docker/Dockerfile` 构建本地镜像。验证容器只运行一次性 Python 检查和临时报告生成，不挂载生产目录、不启动定时任务、不调用 AI。

**Tech Stack:** Docker Desktop、`docker build`、Python 3.12、TrendRadar 本地 fixture、Git、Markdown。

## Global Constraints

- 功能 RC 基线固定为 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`；最终构建 worktree HEAD 固定为仅追加 Dockerfile 兼容性修复的 `5c02c6ce`。出现其他源码差异立即停止。
- 构建上下文仅使用 `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history`，不得使用存在未提交改动的 `/Users/shankluo/AI/Claude/TrendRadar`。
- 最终本地镜像标签固定为 `xjiankong-trendradar:v2-beta-rc-20260712`；旧标签 `20260711` 只保留在历史命令记录中。
- 镜像平台固定为 `linux/amd64`：已上线的 `xjiankong-trendradar:v2-alpha-20260709` 是 `linux/amd64`，而本机 Docker host 为 `linux/arm64`；不得默认构建 host 架构镜像。
- 不挂载或读取生产 `config/`、`output/`、`.env`、数据库或凭据；容器检查使用临时目录和构造数据。
- 不上传镜像、不导出 tar、不访问 NAS、不修改 `.env`、不重建或重启现有容器、不调用付费 AI、不修改 Cloudflare 或生产环境。
- Docker daemon 未运行时只允许启动本机 Docker Desktop；启动失败或构建需要新的系统权限时停止。
- 本 Gate 不修改 TrendRadar Python 源码；唯一代码差异为已审计的 Dockerfile 构建兼容性提交 `5c02c6ce`。其余只允许本地镜像状态、临时容器、系统临时目录中的 OCI 恢复产物和 Gate 9 收口文档发生变化；不得因此删除任何额外镜像或容器。

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

**官方 OCI config 等价性闸门（2026-07-12 专项审计补充，必须先于恢复执行）：**

- 使用 Docker Hub Registry V2 API 读取 `python:3.12-slim-bookworm` 的 index/manifest；若返回 index，只接受唯一的 `linux/amd64` child manifest。必须校验 child manifest、config blob、每个压缩 layer blob 的 sha256，并逐项校验解压 tar 的 DiffID 与 config `rootfs.diff_ids`；任何数量、顺序、media type 或 digest 不匹配立即停止。
- rootfs 必须按 manifest layer 顺序应用；正确处理普通 whiteout、opaque whiteout、文件类型替换、路径逃逸、hardlink/symlink 与所有权/权限保真。不得使用裸 `tar -xf` 直接覆盖 rootfs。
- `docker import` 只导入文件系统层，不能自然保留官方 OCI config。执行 Agent 必须先从官方 config 提取并白名单核验 `Env`、`Cmd`、`Entrypoint`、`User`、`WorkingDir`、`Volumes`、`ExposedPorts`、`Healthcheck`、`StopSignal`、`Labels`、`OnBuild`；只有全部非空字段都能由 `docker import --change` 无歧义重建，才允许 import。
- import 后必须以 `docker image inspect` 逐项比对上述白名单字段，并确认平台为 `linux/amd64`；随后用一次性容器验证 `python --version`。任一字段不等价、任一字段无法由 `--change` 表达、平台不符或 Python 运行失败，立即停止，不重试构建，也不删除本次 import 的残留标签。
- registry token 仅可存在于执行进程的短生命周期内；不得写入命令历史、文件、日志、进度文档或 Agent 报告。阶段记录只写是否解析 manifest、layer 数、是否逐层校验、import 退出码和验证结果。

**脚本可观测性预检（新增；只读，且必须先于删除）：**

- 新的执行 Agent 只能在系统临时目录创建最小预检脚本；脚本必须对每一个无凭据边界输出固定阶段标记和退出码：启动、`HEAD /v2/`、解析 `WWW-Authenticate` 的 realm/service、向 token 端点发起请求、收到 token 的长度（不得输出 token）、请求 manifest、写入 manifest 的非敏感摘要。
- `HEAD /v2/` 的预期成功条件固定为 HTTP `401` 且存在 `WWW-Authenticate: Bearer` challenge；该步骤不得使用会把 HTTP 401 直接转为失败的 `curl --fail`／等价模式。日志必须写入 `http_status=401` 与 `bearer_challenge=true|false`，不得写完整 header 值。
- 预检日志只能位于系统临时目录，执行结束前必须审查其不含 token、Authorization header、signed redirect URL 或 layer 内容；审查后删除脚本和日志。预检不得下载 layer、创建 rootfs、import、tag、删除镜像、build 或 run 容器。
- 任一阶段没有可审计标记、退出码非零、需要持久化凭据或日志无法安全审查时，立即停止 Gate 9。只有预检完整通过，主控才能另派执行 Agent 从删除前核验重新开始恢复；不得复用本次预检的 token。

**Gate 9B：config blob 传输保真审计（新增；只读，且必须先于重新恢复）：**

- 仅验证已选官方 child manifest 的 config descriptor。新的短生命周期 token 不得复用；预检脚本必须分别记录初始 response 的 HTTP 状态、是否存在重定向、是否存在 `Location`、最终 response 的 HTTP 状态、是否跟随重定向、最终原始字节的 sha256 是否匹配 descriptor；不得记录任何 header 值、URL、token、blob 内容或完整 digest。
- 只有明确证明初始 Registry blob endpoint 的重定向已被安全跟随、最终 body 是原始压缩 blob、且 sha256 与 descriptor 完全匹配，才可重新进入 config/layer 恢复。若初始不重定向而仍不匹配、最终响应非 200、重定向无法安全跟随或日志含敏感内容，停止 Gate 9。
- Gate 9B 不得下载任何 layer、写 rootfs、import、tag、删除镜像、build、run 容器或修改项目文件；脚本与日志必须审查并清理。

**Docker load archive 恢复路径（2026-07-12 修订；替代手工 rootfs 与 `docker import`）：**

- 适用原因：本机没有 `skopeo`、`crane`、`regctl`、`oras` 等专用镜像工具；手工 rootfs 路径两次止于脚本可观测性，且 `docker import` 无法天然保留官方 OCI config。此修订不增加依赖、不改 Dockerfile/设置/镜像源，也不改变“只重试一次 RC build”的约束。
- 使用新的短生命周期 token 下载唯一 `linux/amd64` child manifest 的官方 config 与每个 layer blob；每个 blob 必须安全跟随重定向、校验压缩原始字节 sha256 与 descriptor、解压为 layer tar 并校验未压缩 DiffID 与 config `rootfs.diff_ids`。层数、顺序、media type 或任一 digest 不符立即停止。
- 临时 archive 必须包含**原始官方 config blob**、按 manifest 顺序保存的未压缩 `layer.tar` 和 Docker `manifest.json`；其唯一 RepoTag 为 `python:3.12-slim-bookworm`。不得修改 config 内容、不得手工应用 rootfs/whiteout、不得使用 `docker import`。在系统临时目录用 `docker load` 导入后，以 `docker image inspect` 验证 ID、平台和官方 config 的白名单字段等价，并用一次性容器运行 `python --version`。
- 若 `docker load`、inspect、config 等价性或 Python 验证失败，立即停止；不得删除新加载镜像、不得重试、不得进入 RC build。成功后才可以按 Task 2 的唯一构建命令继续。临时 archive、压缩 blob、未压缩 layer、脚本与日志必须经敏感扫描后清理。

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
- Produces: 本地镜像 `xjiankong-trendradar:v2-beta-rc-20260712`。

- [x] **Step 1: 构建本地镜像 — 通过受控 base cache 与最小跨架构兼容性修复完成**

```bash
docker build \
  --platform linux/amd64 \
  --pull=false \
  --file docker/Dockerfile \
  --tag xjiankong-trendradar:v2-beta-rc-20260712 \
  .
```

Expected: build exit code 0；不使用 `--push`、不导出 tar。

- [x] **Step 2: 核验镜像元数据**

```bash
docker image inspect xjiankong-trendradar:v2-beta-rc-20260712 \
  --format '{{.Id}}|{{.Architecture}}|{{.Os}}|{{.Size}}'
```

Expected: image ID 非空、OS 为 `linux`、size 大于 0。

### Task 3：一次性容器级免费验证

**Files:**

- Runtime modules inside image: `/app/trendradar/ai/formatter.py`、`/app/trendradar/context.py`、`/app/trendradar/report/generator.py`、`/app/trendradar/report/html.py`

**Interfaces:**

- Consumes: Task 2 本地 RC 镜像。
- Produces: 模块导入、8 板块、历史 manifest/归档页、RSS 证据流和 Nitter fallback 的容器内验证结果。

- [x] **Step 1: 验证镜像内源码标记与模块导入**

```bash
docker run --rm \
  --entrypoint python \
  -e LITELLM_LOCAL_MODEL_COST_MAP=True \
  xjiankong-trendradar:v2-beta-rc-20260712 \
  -c "from trendradar.ai.analyzer import SourceRef; from trendradar.ai.formatter import render_ai_analysis_html_web; from trendradar.report.generator import build_history_manifest, write_history_archive_page; from trendradar.report.html import render_html_content; print('RC_IMPORT_OK')"
```

Expected: 输出 `RC_IMPORT_OK`，无 traceback。

- [x] **Step 2: 在容器临时目录生成并断言报告**

```bash
docker run --rm -i \
  --entrypoint python \
  -e LITELLM_LOCAL_MODEL_COST_MAP=True \
  xjiankong-trendradar:v2-beta-rc-20260712 - <<'PY'
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

- [x] **Step 3: 确认没有新增常驻容器**

```bash
docker ps -a --filter ancestor=xjiankong-trendradar:v2-beta-rc-20260712 --format '{{.ID}} {{.Status}}'
```

Expected: 无输出。

### Task 4：记录 Gate 9 结果并停止

**Files:**

- Modify: `docs/superpowers/plans/2026-07-11-v2-beta-rc-image-validation.md`
- Modify: `docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md`

**Interfaces:**

- Consumes: 镜像 ID、架构、大小、容器级验证结果。
- Produces: 可供后续生产同步计划引用的本地镜像验证记录。

- [x] **Step 1: 回写构建与验证事实**

记录镜像标签、image ID、architecture、size、构建结果、容器级断言、未执行项和已知限制。只有实际命令通过的项目才能标为完成。

- [x] **Step 2: 运行项目文档校验**

```bash
cd /Users/shankluo/AI/Claude/Xjiankong
jq empty config/x-accounts.json
bash quality-check.sh
bash quality-check.sh --trendradar
rg -n 'A2.*(实施|运行|待接入)|X Hosted MCP.*(主线|当前)' AGENTS.md CLAUDE.md ai-intelligence-hub-design.md docs --glob '!docs/archive/**'
git diff --check
```

Expected: JSON、30/30、37/37 和差异检查通过；A2 仍为归档方案。

- [x] **Step 3: 仅提交 Gate 9 收口文档**

```bash
git add docs/roadmap.md docs/superpowers/plans/2026-07-11-v2-beta-rc-image-validation.md docs/superpowers/plans/2026-07-13-v2-beta-container-observability.md docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md
git commit -m "docs: record v2 beta RC image validation"
```

Expected: 不包含 Xjiankong 既有未提交文件；TrendRadar 分支不新增源码提交。

> 实际执行：commit `476e097`（`docs: close v2 beta Gate 9 validation`），含 4 个文件，与计划一致。

## Gate Contract

**Gate name:** Gate 9 v2-beta RC 本地镜像构建与容器级免费验证。

**Goal:** 证明冻结的 RC 可以由现有 Dockerfile 构建，并在一次性容器中正确提供 v2-beta 网页、历史与来源能力。

**Allowed actions:** 启动本机 Docker Desktop、本地 `docker build`、本地 image inspect、一次性 `docker run --rm`、免费本地测试、Gate 9 进度与详细文档更新和本地文档提交。

**Forbidden actions:** `docker push`、镜像 tar 导出、NAS/SSH、修改 `.env`、挂载生产配置或数据、重建/重启现有容器、付费 AI、Cloudflare、生产部署、除 `5c02c6ce` 外的 TrendRadar 代码改动。

**Validation:** RC SHA 完全一致；镜像构建成功；容器内导入和报告断言成功；无新增常驻容器；文档质量检查通过。

**Stop conditions:** RC SHA 漂移、未知源文件差异、Docker daemon/构建失败、容器断言失败、出现凭据/生产挂载需求或需要改变生产环境。

**Next Owner after completion:** Codex 审核 Gate 9；镜像上传和 NAS 同步另起 Gate 10 并由老板单独批准。
