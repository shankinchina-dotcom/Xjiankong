# v2-beta Gate 6：深空报告与历史 UI 本地实施计划

> 状态：Gate 6 本地实现与 Gate 7 免费独立审计已完成。仅限隔离 worktree `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history` 的分支 `codex/v2-beta-history`；当前 HEAD 为 `8f7e385a`。
>
> 本计划落实已批准的 [`2026-07-10-v2-beta-deep-space-report-ui-design.md`](../specs/2026-07-10-v2-beta-deep-space-report-ui-design.md)。不合并到 `v2-alpha`，不构建镜像、不访问 NAS、不改 `.env`、不重启容器、不调用 AI、不改数据库 schema 或 Cloudflare。

## 一、目标与验收

将网页报告改为深空蓝、连续阅读的 8 板块研判报告，并把 Gate 5 已生成的公开 `history.json` 接入报告内历史抽屉与独立 `/history.html`。邮件、飞书、钉钉、Telegram 等既有通知渲染不得变化。

完成后必须满足：

- 网页有紧凑状态栏、唯一深空蓝 Hero、连续 8 章节、低权重证据流与来源索引；不再复用 8 张同质卡片布局。
- 顶栏和 Hero 的时间、热榜/RSS 数量、AI 板块数量、当日版本数均来自实际报告数据或 `history.json`；缺失时显示真实空态。
- 历史入口读取 `history.json`，有右侧抽屉、遮罩、关闭按钮、`ESC` 关闭；历史快照以真实相对路径跳转。
- 旧快照有“当前查看历史版本／查看最新”提示；最新版本不显示误导性历史状态。
- `history.html` 只使用 `history.json`，不暴露目录、配置、数据库、`source_map` 或链接探测结果。
- `SourceRef` 链接只接受 `http/https`；Nitter 状态链接额外提供确定性的 `x.com` 原文 fallback；无 URL 时不生成链接。不得运行时探测外部链接。
- 网页专用渲染与邮件渲染隔离；`render_ai_analysis_html_rich` 及通知调用路径保持原样。

## 二、全局约束

1. 保留 Gate 5 的 `history.json` 格式：顶层仅 `schema_version`、`latest`、`dates`，版本项仅 `time`、`path`、`is_latest`。
2. 不增加第三方依赖、前端框架、图标库或后端服务；图标使用内联 SVG。
3. 不伪造信号强度、趋势、热度、差分、历史指标或 URL 可用性。
4. HTML 必须继续对标题、来源 ID、URL 做转义；链接带 `target="_blank" rel="noopener noreferrer"`。
5. 只改为本计划必需的文件；不修改主 worktree 的既有脏文件，也不提交本地 `output/` 或 `__pycache__/`。
6. 每项功能先写 fixture 并确认其因功能缺失而失败，再写最小实现；每项独立提交。

## 三、任务

### [x] Task 1：网页专用深空研判渲染器

**文件：**

- 修改 `trendradar/ai/formatter.py`
- 修改 `trendradar/report/html.py`
- 新增或扩展 `tests/fixtures/v2_beta_deep_space_ui.py`

**步骤：**

1. 在 fixture 中构造成功与空态的 `AIAnalysisResult`，断言网页输出含 `intel-topbar`、`judgment-hero`、`report-shell`、8 个 `report-section`、内联 SVG 图标、真实空态和来源索引；同时断言旧 `render_ai_analysis_html_rich` 仍保持其原有 v2-alpha 结构。
2. 运行 fixture，确认因网页专用函数与页面结构尚不存在而失败。
3. 在 `formatter.py` 新增网页专用函数（命名为 `render_ai_analysis_html_web`）及仅供其使用的安全来源标记/索引辅助函数；不要修改 `get_ai_analysis_renderer` 或 `render_ai_analysis_html_rich`。
4. 让 `html.py` 网页路径调用新函数，传入仅由报告数据得出的热榜、RSS、生成时间与快照路径上下文。替换网页使用的 AI 视觉 CSS 为已批准的深空 token、连续章节与低权重证据流样式；保留全局非 AI 报告的现有行为。
5. 将原报告 Hero 的“核心判断/引用来源”改为真实派生数量，不显示虚构业务评分。

**验证：**

```bash
cd /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history
PYTHONPATH=. python3 tests/fixtures/v2_beta_deep_space_ui.py
PYTHONPATH=. python3 tests/fixtures/v2_alpha_fixture.py
PYTHONPATH=. python3 tests/fixtures/v2_alpha_task3.py
git diff --check
```

### [x] Task 2：历史抽屉与独立历史归档页

**文件：**

- 修改 `trendradar/report/html.py`
- 修改 `trendradar/report/generator.py`
- 修改 `trendradar/context.py`（仅为向网页传递快照上下文）
- 扩展 `tests/fixtures/v2_beta_deep_space_ui.py`

**步骤：**

1. 扩展 fixture：用临时输出目录生成合法快照与 Gate 5 manifest，断言网页包含历史按钮、drawer、遮罩、关闭/ESC 逻辑、历史快照提示和相对 `history.json` 读取；断言 `history.html` 生成并且未内嵌任意版本 URL、`source_map`、`.env`、`config` 或数据库字样。
2. 运行 fixture，确认因历史 UI/归档页尚不存在而失败。
3. 为 HTML 渲染增加可选且向后兼容的快照上下文；生成器在成功写入 manifest 后生成 `output/history.html`，其内容为静态壳和浏览器端 manifest 读取逻辑，不复制报告正文。
4. 网页脚本从 `history.json` 填充抽屉：当天版本倒序、按日期折叠的归档链接、当前版本高亮。路径仅来自 manifest，使用同源相对路径。
5. 使用嵌入的 `data-snapshot-path` 判别历史快照；若 manifest 缺失/读取失败，显示“历史归档准备中”，不使用硬编码时间线。

**验证：**

```bash
cd /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history
PYTHONPATH=. python3 tests/fixtures/v2_beta_deep_space_ui.py
PYTHONPATH=. python3 tests/fixtures/v2_beta_history_manifest.py
git diff --check
```

### [x] Task 3：来源链接状态与网页回归收口

**文件：**

- 修改 `trendradar/ai/formatter.py`
- 扩展 `tests/fixtures/v2_beta_deep_space_ui.py`

**步骤：**

1. 写 fixture 覆盖三种网页来源呈现：安全 canonical URL、Nitter 状态 URL 的 X 原文 fallback、缺失或非 `http/https` URL 的非链接文本。
2. 运行 fixture，确认 fallback 与无链接状态因功能缺失而失败。
3. 在网页专用来源渲染中实现确定性 URL 规则：仅匹配 Nitter 状态路径时增加 `x.com/<handle>/status/<id>`；不发送请求、不猜测可用性、不改变邮件来源 HTML。
4. 确保 `[Rxxx]`、来源索引和证据流的链接均通过同一网页安全规则生成，补齐键盘 focus、窄屏抽屉和长标题截断 CSS。

**验证：**

```bash
cd /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history
PYTHONPATH=. python3 tests/fixtures/v2_beta_deep_space_ui.py
PYTHONPATH=. python3 tests/fixtures/v2_beta_history_manifest.py
PYTHONPATH=. python3 tests/fixtures/v2_alpha_fixture.py
PYTHONPATH=. python3 tests/fixtures/v2_alpha_task3.py
PYTHONPATH=. python3 tests/fixtures/v2_alpha_task4.py
git diff --check
```

### [x] Task 4：本地生成验证与文档回写

**文件：**

- 修改 `docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md`
- 修改本计划中的任务状态

**步骤：**

1. 用已有 fixture 构造报告，生成本地 `output/index.html`、历史快照、`history.json` 与 `history.html`；产物仅用于检查，不提交。
2. 检查 HTML 中 8 板块、静态历史入口、来源安全规则、空态与历史页的必要标记；用浏览器或等价静态检查验证窄屏关键 CSS/脚本入口。
3. 更新设计规格与本计划：记录本地实现和验证事实（当时仍处于未合并/未构建镜像/未部署；后已于 2026-07-14 经 Gate 10 部署至生产，见 `../../roadmap.md`）。
4. 在 Xjiankong 文档仓库运行项目规定文档校验，仅提交这两个文档文件。

**完成记录（2026-07-10 至 2026-07-11）：**

- 隔离分支完成提交：`c82cc6bb`、`e3e08f48`、`37bed9d6`、`4d0bc1c4`、`8f274cce`、`ad0be46a`、`8b68e580`、`0986303f`、`a8d64784`、`8f7e385a`。
- 本地临时目录生成并检查 `output/index.html`、历史快照、`history.json`、`history.html` 和 `html/latest/daily.html`；产物未保留在主仓库或提交。
- 五组 fixture 均通过：v2-beta 深空网页 15/15、history manifest 2/2、v2-alpha schema、解析 8/8、HTML 渲染 10/10；相关模块 `py_compile` 与 `git diff --check` 通过。
- Codex 于 2026-07-11 使用本地 HTTP 预览完成浏览器验收：最新状态与当日版数由 manifest 正确写入；旧版提示在最新页不可见；旧白色搜索框被隐藏；RSS 使用低饱和深蓝证据流。预览仅访问 `127.0.0.1`，没有访问生产站点。
- Task 3 的 Nitter → X fallback 仅按状态 URL 规则确定性生成；不做运行时外部可用性探测，也不改变邮件渠道的来源 HTML。
- 未合并到 `v2-alpha`，未构建镜像、未上传、未访问 NAS、未修改 `.env`、未重启容器、未调用付费 AI、未修改 Cloudflare 或生产环境。

**Gate 7 审计结论（2026-07-11）：**

- 通过：网页/邮件渲染隔离、8 板块连续报告、历史 manifest/抽屉/独立页、精确快照路径、旧回调兼容、XSS 与非 `http/https` 拒绝、Nitter → X fallback、AI 失败/跳过态历史上下文、RSS 深空证据流。
- 外部 canonical URL 仍可能因源站删除、登录或地区限制失效；本轮按设计不运行时探测，不承诺所有外部页面永久可用。
- 下一步不是直接生产同步，而是单独决定如何把 `codex/v2-beta-history` 集成到 `v2-alpha`；合并、镜像、NAS 和公网验证仍需新的生产闸门。

**验证：**

```bash
cd /Users/shankluo/AI/Claude/TrendRadar-v2-beta-history
PYTHONPATH=. python3 tests/fixtures/v2_beta_deep_space_ui.py
PYTHONPATH=. python3 tests/fixtures/v2_beta_history_manifest.py
PYTHONPATH=. python3 tests/fixtures/v2_alpha_fixture.py
PYTHONPATH=. python3 tests/fixtures/v2_alpha_task3.py
PYTHONPATH=. python3 tests/fixtures/v2_alpha_task4.py
git diff --check

cd /Users/shankluo/AI/Claude/Xjiankong
jq empty config/x-accounts.json
bash quality-check.sh
bash quality-check.sh --trendradar
rg -n 'A2.*(实施|运行|待接入)|X Hosted MCP.*(主线|当前)' AGENTS.md CLAUDE.md ai-intelligence-hub-design.md docs --glob '!docs/archive/**'
git diff --check
```

## 四、闸门合同

**Gate name：** Gate 6 深空报告与历史 UI 本地实现。

**Goal：** 在隔离分支得到可测试、可回滚的 v2-beta 网页 UI 与历史浏览实现。

**Allowed actions：** 修改隔离 worktree 的 Python/fixture；修改本仓库的计划与规格文档；运行本地免费测试、生成本地产物、创建本地提交。

**Forbidden actions：** 合并到 `v2-alpha`、构建镜像、上传、NAS/SSH、容器、`.env`、数据库、Cloudflare、付费 AI、生产 URL 写操作。

**Stop conditions：** 任何测试回归、需改变 manifest schema、需改变邮件渠道、或需进入生产环境时立即停止并由 Codex 审计。

**Expected report format：** 提交哈希、精确文件清单、RED/GREEN 测试证据、未执行操作、已知限制与下一闸门建议。

**Next Owner after completion：** Codex 审核和本地 Gate 7 验证；生产同步必须另起闸门。
