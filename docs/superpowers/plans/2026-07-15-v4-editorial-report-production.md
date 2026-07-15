# V4 编辑型情报报告生产实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 逐任务执行。步骤使用复选框追踪。

**Goal:** 把已确认的 V4 编辑型报告结构移植到 v2-beta 网页 renderer，构建独立 RC 镜像，并在逐闸门确认后切换 NAS 生产。

**Architecture:** 只改网页专用 formatter、深空 CSS 和对应 fixture。Hero 与 01 组成 `.judgment-suite`，J1–J3 从 `daily_judgment` 本地派生；邮件、AI schema、历史 manifest、Nginx 和 Cloudflare 保持不变。发布使用新镜像单点切换，回滚基线为当前生产 `v2-beta-rc-20260713`。

**Tech Stack:** Python 3.12、内联 HTML/CSS/JavaScript、现有 fixture、Node 行为断言、Docker `linux/amd64`、Synology Docker Compose、Nginx、Cloudflare Tunnel（只读验证，不改配置）。

## Global Constraints

- 设计规格：[`../specs/2026-07-15-v4-editorial-report-ui-design.md`](../specs/2026-07-15-v4-editorial-report-ui-design.md)。
- 权威原型：[`../prototypes/2026-07-15-xjiankong-report-v4-editorial.html`](../prototypes/2026-07-15-xjiankong-report-v4-editorial.html)。
- 实施 worktree 固定为 `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history`；禁止使用脏的 `TrendRadar` v2-alpha 主 worktree。
- 开始前固定基线 `codex/v2-beta-history` / `61ba393225de1b6d9d165a1dcddc189073f3e2d6`；若 HEAD 漂移，先只读审计差异并更新计划，不得直接套补丁。
- 不新增依赖，不修改 AI Prompt、schema、数据库、Compose、Nginx、Cloudflare 或邮件 renderer。
- 所有生产动作逐闸门停止；不能从本地验证自动进入构建、传输、切换或付费运行。
- 新镜像建议标签：`xjiankong-trendradar:v2-beta-v4-rc-20260715`；若标签已存在，使用新的日期／序号，禁止覆盖。
- 不清理用户产物、旧镜像、备份或传输 tar；清理必须另行批准。

## 模型分配

- `[模型：Terra；强度：高] -> [formatter、CSS、fixture 的边界清楚实现] -> 验证: [fixture + 浏览器四视口]`
- `[模型：Terra；强度：高] -> [RC 构建、一次性容器与 NAS 只读/传输闸门] -> 验证: [镜像 inspect、SHA-256、容器断言]`
- `[模型：Sol；强度：高] -> [生产切换前审计与回滚判断] -> 验证: [白名单差异、容器身份、外部安全路径]`
- `[模型：Sol；强度：中] -> [一次付费全链路验收] -> 验证: [同一次运行日志、HTML、history 和公网结果]`
- 当前 Codex 若不能实际切换模型，主控仍按对应强度标准复核并在交接中说明。

---

### Task 1: 冻结工作区与编写失败契约

**Files:**
- Modify: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/tests/fixtures/v2_beta_deep_space_ui.py`
- Read only: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/trendradar/ai/formatter.py`
- Read only: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/trendradar/report/html.py`

**Interfaces:**
- Consumes: `render_ai_analysis_html_web(result, context)`。
- Produces: V4 DOM、响应式和邮件隔离的失败断言。

- [x] **Step 1: 只读冻结基线**（2026-07-15 执行 Agent）

```bash
cd /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history
git status --short
git branch --show-current
git rev-parse HEAD
```

实测：branch `codex/v2-beta-history`，HEAD `61ba393225de1b6d9d165a1dcddc189073f3e2d6`；仅既有未跟踪运行产物与 `__pycache__`。

- [x] **Step 2: 在 fixture 增加 V4 结构测试**

已新增 `test_v4_judgment_suite_contains_overview_and_evidence_layer`、`test_v4_partial_judgments_render_only_existing_keys`、`test_v4_more_than_three_judgments_keeps_full_evidence_body` 及 V4 CSS 契约；邮件隔离断言不含 `judgment-suite` DOM。

- [x] **Step 3: 运行测试并确认 RED**

RED 已确认：先因缺少 `证据验证与置信度`／`.judgment-suite` 失败（非 import 错误）。

### Task 2: 实现网页 V4 DOM

**Files:**
- Modify: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/trendradar/ai/formatter.py`
- Test: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/tests/fixtures/v2_beta_deep_space_ui.py`

**Interfaces:**
- Produces: `_web_judgment_items(raw: str, limit: int = 3) -> list[str]`。
- Produces: `.judgment-suite`、`.hero-theses`、`.judgment-key`。
- Preserves: `_web_panel_content()`、`_web_source_link()` 与邮件 renderer。

- [x] **Step 1: 增加最小判断派生 helper**

已实现 `_web_judgment_items` / `_web_judgment_short_title` / `_web_hero_theses_html` / `_web_evidence_keys_html`：本地派生，不调用模型，不补写事实。

- [x] **Step 2: 重组 `render_ai_analysis_html_web()` 成功路径**

成功路径：`judgment-suite` 包含 hero（今日研判总览 + 指标 + hero-theses）与 `report-section-01`（证据验证与置信度）；`report-shell` 仅 02–08。失败路径不构造 suite。

- [x] **Step 3: 运行 fixture 并确认 GREEN**

`v2_beta_deep_space_ui.py` 20/20；`v2_beta_history_manifest.py` 2/2；v2-alpha fixtures 仍通过。

### Task 3: 实现编辑型 CSS 并做浏览器验收

**Files:**
- Modify: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/trendradar/report/html.py`
- Test: `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/tests/fixtures/v2_beta_deep_space_ui.py`

**Interfaces:**
- Consumes: Task 2 的 V4 class 名。
- Produces: 全部限定在 `body.deep-space-report` 下的 V4 样式。

- [x] **Step 1: 先扩展 CSS 契约测试并确认 RED**

已断言 `.judgment-suite`、`.hero-theses`、`.judgment-key`、573/390px 单列规则，且 `_assert_all_deep_space_selectors_are_scoped` 继续通过。

- [x] **Step 2: 移植原型样式**

已移植 suite 共同外边界、01 子层、J1–J3 映射、近白指标、单一亮蓝强调、无彩虹；保留 SVG、history、focus、触控、reduced-motion。左侧 208px 导航未在本生产 DOM 中新增（生产页本无独立 rail DOM，未顺手扩架构）。

- [x] **Step 3: 运行免费测试**

fixture + history + v2-alpha 全套 + `compileall` + `git diff --check` 均通过。

- [x] **Step 4: 浏览器四视口验收**

Chrome CDP 实测 390／573／768／1440：`scrollWidth == innerWidth`、suite 含 hero/01、J1–J3 上下各一、控制台无错误、8 section。截图：`/tmp/v4-editorial-verify/screenshots/v4-{390,573,768,1440}.png`。

### Task 4: 代码审查、提交与路线图更新

**Files:**
- Modify: 上述 3 个 TrendRadar 文件
- Modify after verification: `/Users/shankluo/AI/Claude/Xjiankong/docs/roadmap.md`

- [x] **Step 1: 精确复核差异**

仅修改 `formatter.py`、`html.py`、`v2_beta_deep_space_ui.py`；`git diff --check` 干净。未改邮件、Prompt、schema、history、generator、Docker、Compose、Nginx、Cloudflare。

- [x] **Step 2: 本地提交**（2026-07-15，Codex 最终复审通过后）

```bash
git add trendradar/ai/formatter.py trendradar/report/html.py tests/fixtures/v2_beta_deep_space_ui.py
git commit -m "feat: add editorial judgment hierarchy to web report"
```

仅提交上述 3 个文件；不纳入 `output/history.json`、`__pycache__`。**不 push。**

本地提交：`18c1fbad93f6c0e82b5c3994232c905425764ffd`（`codex/v2-beta-history`）。

**当前停点（2026-07-15）：** Codex **最终复审通过**；Task 1–4 本地实现与提交完成。返工与尾项已吸收：

1. 证据区每条一次：`J + 完整正文 + 来源`。
2. 桌面约 208px `.chapter-nav`；`≤1023px` 折叠为 chip（触控 44px）。
3. hero metrics 统一 label/value；核心判断亮蓝。
4. `history-page-notice` 在 `.judgment-suite` 外。
5. reduced-motion 与导航 `:focus-visible`。
6. fixture 21/21；390／573／768／1280 与历史抽屉验收通过。

**未构建 RC、未 push、未访问 NAS、未部署。** 下一步为 Task 5，须老板单独确认后才构建镜像。

### Task 5: 构建独立 RC 与一次性容器验证

- [x] **Step 1: 生产变更说明与确认闸门**

老板已确认：仅本地 `linux/amd64` 构建与一次性容器免费验证；不修改 NAS、不 push、不部署。

- [x] **Step 2: 构建唯一 RC**（2026-07-15）

```bash
docker build --platform linux/amd64 --pull=false \
  --file docker/Dockerfile \
  --tag xjiankong-trendradar:v2-beta-v4-rc-20260715 .
```

| 字段 | 实测 |
|---|---|
| 标签 | `xjiankong-trendradar:v2-beta-v4-rc-20260715` |
| 构建提交 | `18c1fbad93f6c0e82b5c3994232c905425764ffd` |
| Image ID | `sha256:18d49e97f936f50b354bf250fce05537dcb7dba8c4fc9c2c1cbcf17d3770ab4e` |
| 平台 | `linux/amd64` |
| Size | `138,116,057` bytes |
| RootFS 层数 | 14 |
| DiffID chain SHA-256 | `a6e19f4152598da1a628f75dd7d66338c708e865a8d4a9f5be7cd368d0b16687` |
| Entrypoint / WorkingDir | `/entrypoint.sh` / `/app` |
| 旧标签 | `v2-beta-rc-20260713` 未覆盖，仍为 `sha256:3c02dceafa86…` |

- [x] **Step 3: 一次性容器免费断言**

- `RC_IMPORT_OK`：退出码 0，stdout 仅成功标记。
- 扩展 `RC_CONTAINER_OK`：8 section、`.judgment-suite`、章节导航、证据单次渲染、metrics、Nitter→X fallback、邮件无 V4 class、`history-page-notice` 在 suite 外、reduced-motion / focus-visible 契约、history manifest；退出码 0。
- `docker ps -a --filter ancestor=…v4-rc-20260715`：无残留。

**Task 5 停点：** 本地 RC 已就绪；**未进入 Task 6 NAS 只读／传输**，须老板单独确认。

### Task 6: Gate V4-A／V4-B——NAS 只读基线、备份和传输

- [x] **Step 1: V4-A 只读基线**（2026-07-15）

| 项 | 实测 |
|---|---|
| SSH／sudo docker | `z5451530@192.168.1.193` 可达；Docker 24.0.2 amd64（`PATH` 需含 `/usr/local/bin`） |
| 四容器 | trendradar / report-web(healthy) / cloudflared / rss-proxy 均 running |
| 生产镜像 | `TRENDRADAR_IMAGE=xjiankong-trendradar:v2-beta-rc-20260713`；运行 Image `sha256:c122cdb56076…` |
| 挂载 | trendradar：config ro + output rw；report-web：nginx.conf ro + output ro |
| 网络 | collector：trendradar+rss-proxy；publish：report-web+cloudflared |
| 磁盘 | `/volume1` 可用 1.3T；`/tmp` 可用 4.5G |
| V4 残留 | NAS 无 `v2-beta-v4-rc-20260715` 标签；无 V4 tar |
| 稳定性备注 | 当日 14:11／18:10 观察曾 SSH 超时；V4-A 时 SSH 恢复，四容器自 10C 起持续 Up，RestartCount=0 |

- [x] **Step 2: V4-B 受限备份与镜像传输**（2026-07-15）

| 字段 | 实测 |
|---|---|
| 备份目录 | `/volume1/docker/trendradar-nas/backups/v4-rc-20260715-224353`（dir 700，`.env` 600，18 文件，manifest OK） |
| 指针 | `/tmp/xjiankong-v4-backup-dir` |
| 本地 tar | `/tmp/v2-beta-v4-rc-20260715.tar`，138,140,672 bytes |
| tar SHA-256 | `88b1273f5f1766a212472ef1c853d76438baee5976e25b949ffb107e53c8b195`（双端一致） |
| NAS load 后 Config ID | `sha256:365c92d50928525df93dfb9943051d914c647ac2337f58f29df245536753d1dc` |
| Mac Image ID（构建侧） | `sha256:18d49e97f936f50b354bf250fce05537dcb7dba8c4fc9c2c1cbcf17d3770ab4e` |
| RootFS DiffID 14 层 | 本地与 NAS **全序一致**；chain SHA-256 `a6e19f4152598da1a628f75dd7d66338c708e865a8d4a9f5be7cd368d0b16687` |
| 平台 | linux/amd64；Entrypoint `/entrypoint.sh`；WorkingDir `/app` |
| NAS Size | 373,538,809（引擎口径；与 Mac Size 差异预期） |
| 免费断言 | NAS `RC_IMPORT_OK` + 扩展 `RC_CONTAINER_OK` 退出码 0；无残留验证容器 |
| 生产未变 | 四容器 Id/Image/StartedAt/RestartCount 与备份前完全一致；`.env` 镜像行仍为 `v2-beta-rc-20260713` |

**Task 6 停点：** 镜像已 load 到 NAS 但**未切换生产**。等待 Codex 审查后，老板单独确认才可进入 Task 7。

### Task 7: Gate V4-C——生产镜像单点切换

- [x] **Step 1: Sol 高生产前审计**（2026-07-15）

切换前：trendradar=`5c88cadb…` / `c122cdb56076…` / `v2-beta-rc-20260713`；report-web / cloudflared / rss-proxy 身份与 Task 6 一致；备份 `v4-rc-20260715-224353` manifest OK；新旧镜像均可 inspect。

- [x] **Step 2: 获得单独确认后切换**（2026-07-15）

- `.env`：`TRENDRADAR_IMAGE` 由 `v2-beta-rc-20260713` → `v2-beta-v4-rc-20260715`。
- masked diff：`7c0dbe03dbb15ec2fbddf8cfcc16003d57556be500ac5c16b21371a10387f435` 前后一致；行数 16=16。
- 仅 `docker compose up -d --no-deps --force-recreate trendradar`，退出码 0。

- [x] **Step 3: 免费验收并停止**（2026-07-15）

| 项 | 结果 |
|---|---|
| trendradar | Id `1466e949…`，Image **`sha256:365c92d50928525df93dfb9943051d914c647ac2337f58f29df245536753d1dc`**，标签 `v2-beta-v4-rc-20260715`，Started `2026-07-15T15:00:48Z`，RC=0 |
| report-web / cloudflared / rss-proxy | Id/Image/StartedAt/RestartCount **未变**；report-web healthy |
| 日志 | supercronic crontab 有效；Web 8080 启动；无 ImportError/Traceback/配置加载错误 |
| 公网 | `/`=200；`/.env`/`/news/test.db`/`/config/config.yaml`=404 |
| 回滚 | **未发生** |
| 付费报告 | **未触发** |

**Task 7 停点：** 生产已切换至 V4 RC；**Task 7 已执行并经 Codex 复审通过**。

### Task 8: Gate V4-D——一次付费全链路验收

- [x] **Step 1: 单独说明费用与确认**（2026-07-15 老板批准）

并发闸门：NAS 23:18 CST；cron `0 */4 * * *`；下次自动 00:00（间隔 ≥20 分钟）；无 `python -m trendradar` 采集进程；镜像 `v2-beta-v4-rc-20260715` / `365c92d5…`；RestartCount=0。

- [x] **Step 2: 同一次运行证据**（2026-07-15，仅一次）

| 字段 | 实测 |
|---|---|
| 证据目录 | `/volume1/docker/trendradar-nas/backups/v4-task8-20260715-231822`（700／600） |
| 窗口 | start `1784128715` → end `1784128964`（249s）；exit **0** |
| stderr | 0 字节，无 ImportError／Traceback |
| 热榜 | **11/11** 成功 |
| RSS | **42/44**（Nitter **31/33**：xai 404、GabrielPeterss4 404；非 Nitter **11/11**） |
| 翻译 | **26/26** 成功 |
| AI | `分析完成`；模型 `deepseek/deepseek-chat` |
| history | `c848ca7b…` → `e1d7b8bc…`；schema 仅 `dates/latest/schema_version`；latest `20-05` → **`/html/2026-07-15/23-22.html`** |
| 快照 | 64→65；**仅新增 1 个**标准快照；旧 `20-05.html` SHA 不变 |
| 触发命令 | `docker exec … sh -c "cd /app && /app/.venv/bin/python -m trendradar"`（非 login） |

- [x] **Step 3: V4 与安全验收**

新页 `23-22.html`：`V4_DOM_OK`（8 section、suite 含 hero/01、J1–J3 映射、证据单次 content、6 metrics、208px 导航、notice 在 suite 外、history-drawer、source-ref）。公网：`/`、`/history.json`、`/history.html`、新/旧快照 **200**；`/.env`、`/news/test.db`、`/config/config.yaml`、`/output/news/data.json` **404**。mtime 落在运行窗口内。四容器 Id/Image/StartedAt/RC 未因本轮变化。邮件渲染未由本次付费网页报告运行覆盖；隔离契约沿用 Task 5 本地 fixture 21/21 结果，不计入 Task 8 新运行证据。

- [x] **Step 4: 判定**

**通过，未回滚。** 状态：**Task 8 已执行并经 Codex 最终复审通过**。

### Task 9: V4.1 UI 增量（证据折叠／大厂色／RSS 预览）

- [x] **本地实现与 fixture 24/24**（2026-07-16）
  - 证据区默认折叠；大厂色点状 token；RSS 组默认 5 条 + 展开剩余。
  - 交接：[`2026-07-16-v4-1-ui-polish-handoff.md`](2026-07-16-v4-1-ui-polish-handoff.md)
- [x] **本地提交 + RC 构建 + 一次性容器**（`01264222`；`v2-beta-v4-rc-20260716` / `sha256:442efe38…`；`RC_IMPORT_OK`/`RC_CONTAINER_OK`）
- [ ] **老板确认后 NAS 单点切换**（只重建 trendradar；生产仍为 `v2-beta-v4-rc-20260715`）

## 下个 Agent 的第一条动作

```bash
cd /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history
git status --short
git branch --show-current
git rev-parse HEAD
# 预期：V4.1 三文件未提交或刚提交；生产仍为 v2-beta-v4-rc-20260715
```

从 Task 9 提交／RC 闸门继续；不要在脏 `TrendRadar` 主 worktree 实施；不要自动付费重跑。
