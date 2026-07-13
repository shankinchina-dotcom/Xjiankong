# v2-beta 生产镜像单点升级设计

> 状态：已获老板确认采用“方案 1：镜像单点升级”；本文只定义 Gate 10 的生产同步与回滚边界，不代表任何 NAS 写入已经执行。

## 一、目标

把 Gate 9 已验证的本地镜像 `xjiankong-trendradar:v2-beta-rc-20260712` 同步到群晖 NAS，并仅切换生产 `trendradar` 容器使用的镜像。现有 Compose、运行配置、代理配置、输出数据、`report-web`、`cloudflared`、`rss-proxy` 和 Cloudflare 路由全部保持不变。

成功标准不是“新容器能启动”，而是以下证据同时成立：

1. NAS 导入后的镜像身份与 Gate 9 完全一致。
2. 生产切换只改变 `.env` 的 `TRENDRADAR_IMAGE` 一行，只重建 `trendradar`。
3. 旧日报、旧快照和 SQLite 数据不被覆盖或迁移。
4. 一次经批准的生产采集完成热榜、RSS、翻译、AI 分析和 v2-beta 历史功能验证。
5. 公网敏感路径继续为 404，且没有新增宿主机端口。
6. 任一关键验收失败时，可以把镜像行恢复到部署前记录值并只重建 `trendradar`。

## 二、冻结输入

| 项目 | 固定值 |
|---|---|
| 功能 RC 基线 | `8f7e385ac1453521a7ffffa9c5de43d725af76b9` |
| Docker 构建兼容性提交 | `5c02c6ce` |
| 本地镜像标签 | `xjiankong-trendradar:v2-beta-rc-20260712` |
| 本地镜像 ID | `sha256:91983de58c07a12c9fc0ada28474e1d48de26b5a126c3d8fd7f6971f7a748ee4` |
| 平台 | `linux/amd64` |
| 大小 | `138047386` bytes |
| Gate 9 断言 | `RC_IMPORT_OK`、`RC_CONTAINER_OK`，退出码均为 0 |
| 已知生产版本 | `xjiankong-trendradar:v2-alpha-20260709`；NAS 实际镜像 ID 须在 Gate 10A 重新读取 |

镜像传输必须使用 `docker save` / `docker load`，不得使用会丢失镜像配置的 `docker export` / `docker import`。传输归档必须记录 SHA-256 和大小，NAS 加载后重新检查镜像 ID、平台和大小。

## 三、变更范围

### 3.1 唯一生产变更

1. NAS 导入固定 RC 镜像。
2. 在受限备份完成后，把 NAS `.env` 的 `TRENDRADAR_IMAGE` 从部署前记录值改为 `xjiankong-trendradar:v2-beta-rc-20260712`。
3. 执行等价于 `docker compose up -d trendradar` 的单服务重建。

### 3.2 明确不变

- 不上传或覆盖 `docker-compose.yml`。
- 不同步仓库 `config/`，不改 NAS 实际 `config/` 和 prompt。
- 不读取、输出或改写 `.env` 的密钥、Token、AI 模型、调度和开关。
- 不触碰 NAS `proxy/config.yaml`、代理运行数据或订阅 URL。
- 不覆盖、迁移、删除 `output/`、SQLite 或历史快照。
- 不重建 `report-web`、`cloudflared`、`rss-proxy`。
- 不修改 Cloudflare Tunnel、DNS、WAF、Access 或域名路由。
- 不删除旧镜像、RC 归档、备份或失败现场。

本地 `deploy/nas/` 当前存在未提交的四容器/Nitter 模板变更和真实代理配置。它们不属于 Gate 10 发布集合，不得提交、打包、上传或作为 NAS 当前状态的替代证据；部署模板清理另起任务。

## 四、分闸门执行

### Gate 10A：NAS 只读基线与回滚可用性核验

**允许：** 只读取得容器状态、镜像身份、Compose 渲染摘要、磁盘空间、挂载/网络、`.env` 非敏感键存在性与 `TRENDRADAR_IMAGE` 当前值、输出目录统计、旧镜像可引用性和既有备份可读性。

**禁止：** 创建备份、上传、加载镜像、修改文件、重建容器、付费采集。

**通过条件：** 能证明旧镜像、现有 Compose、受限 `.env`、运行配置和原地 `output/` 共同构成可恢复基线；磁盘空间足以同时保留旧镜像、RC tar、RC 镜像和新备份。

### Gate 10B：受限备份与镜像传输

**允许：** 经老板确认后创建新的时间戳备份；本地 `docker save`；计算归档 SHA-256；上传 NAS 临时目录；复核 SHA-256；`docker load`；对导入镜像运行不挂载生产数据的一次性免费断言。

**禁止：** 修改 `.env`、切换生产容器、付费采集、清理旧文件。

**通过条件：** 新备份完整且权限受限；NAS 归档校验与本地一致；导入镜像身份与冻结输入完全一致；免费断言通过且无残留容器。

### Gate 10C：镜像切换与免费生产验收

**允许：** 经老板确认后只修改 `.env` 的 `TRENDRADAR_IMAGE` 一行，并只重建 `trendradar`。

**禁止：** 修改其他 `.env` 行、Compose、配置、代理、输出、其他容器或 Cloudflare；不得人工触发采集。

**通过条件：** 四容器保持运行，`report-web` healthy；`trendradar` 使用固定 RC 镜像且无持续重启；挂载、网络和非敏感环境摘要未漂移；旧 `index.html` 和旧快照仍可访问；敏感路径仍为 404。

首次新报告生成前，`/history.json` 和 `/history.html` 仍可能是 404，不作为 Gate 10C 失败条件。

### Gate 10D：一次付费全链路验收

**允许：** 经老板再次确认后，只人工触发一次现有生产采集；完整审查同一次运行结果。

**禁止：** 因结果不理想连续重跑、改模型、改代理、改 Cloudflare 或扩大配置范围。

**通过条件：**

- 热榜目标为 11/11；若有波动，必须按来源解释。
- RSS 分开记录 Nitter 与非 Nitter；健康参考为总计 38—41/44、Nitter 约 30/33。单个 404 不触发整体回滚。
- 翻译以本次实际待翻译数为分母，全部成功。
- AI 分析使用现有生产模型并成功完成，页面包含连续 8 板块、来源索引、安全链接和 Nitter → X fallback。
- 新快照生成，旧快照保留；`/history.json` 为合法受控结构且 latest 指向新快照；`/history.html`、历史抽屉和旧版提示可用。
- `/`、`/index.html`、新快照、`/history.json`、`/history.html` 可访问；`/.env`、`/news/`、`/rss/`、`/config/` 和数据库扩展路径保持 404。

## 五、备份与回滚单位

新的 Gate 10 备份点必须包含或记录：

1. 部署前 `trendradar` 容器实际镜像 ID、标签、平台和大小。
2. 当前 `docker-compose.yml`。
3. `.env` 的受限完整备份；报告只允许出现 `TRENDRADAR_IMAGE` 的旧值和非敏感键存在性，不输出其他内容。
4. `config/config.yaml`、`config/ai_analysis_prompt.txt`、`config/frequency_words.txt`、`config/timeline.yaml` 的受限备份或校验摘要。
5. `proxy/config.yaml` 只保留 NAS 原文件或 NAS 端受限备份，不传回本地、不输出内容。
6. `output/news/`、`output/rss/`、`output/html/` 的存在性、文件数、最新时间和容量；`output/index.html` 的 mtime 与 SHA-256。
7. 旧镜像仍可被 Docker 精确引用的证据。

回滚时只恢复 `.env` 中部署前的 `TRENDRADAR_IMAGE`，以旧 Compose 和配置为准，只重建 `trendradar`。保留 `output/`、SQLite、新快照、RC 镜像、传输归档和备份，不修改其他三个容器或 Cloudflare，不再次触发付费采集。

## 六、回滚触发条件

立即停止并回滚：

- 镜像归档校验、NAS 镜像 ID、平台或大小与冻结值不一致。
- NAS 免费容器断言失败或留下未知容器。
- `trendradar` crash loop、持续重启，或出现 import、权限、配置加载错误。
- `.env` 除镜像行外、Compose、配置、代理、挂载、网络或输出出现未知漂移。
- 旧 `index.html`、旧快照或 SQLite 被覆盖、丢失或不可读。
- 任一敏感路径不再返回 404。
- 新报告无法生成，或 `history.json` 非法、泄露内部路径/敏感字段。
- 8 板块、来源安全、历史抽屉/归档等核心功能回归。

进入回滚评估：热榜大面积失败；RSS 退化到约 11/44 且 Nitter 集体失败；非 Nitter 大面积回归；翻译或 AI 分析整批失败。单个 Nitter 404、既有 38—41/44 波动或 Cloudflare 单独短时异常不自动触发镜像回滚。

## 七、模型与复核分配

| 子任务 | 推荐模型 | 选择依据 | 验证方式 |
|---|---|---|---|
| Gate 10A 只读基线采集 | Terra 高 | 命令边界清楚，但需理解 Docker/NAS 状态 | 固定字段输出、敏感扫描、主控逐项比对 |
| Gate 10B 备份、归档与加载 | Terra 高 | 机械执行为主，涉及可回滚生产文件 | SHA-256、镜像 inspect、备份清单、免费断言 |
| Gate 10C 生产镜像切换 | Sol 高 | 生产写入与回滚关键节点 | 修改前后单行差异、容器/挂载/网络/安全路径独立验收 |
| Gate 10D 全链路验收 | Sol 中 | 需要综合热榜、RSS、AI 与历史证据 | 同一次运行日志、报告结构、HTTP 与 JSON 检查 |
| Gate 10 最终结论 | Sol 高 | 跨 Agent 最终验收和生产风险判断 | 对照冻结输入、白名单差异、回滚证据完整性 |

当前 Codex 界面不能保证逐 Agent 实际切换模型；执行时仍须在每个闸门指令中保留推荐强度，并由主控按对应标准复核。

## 八、Gate Contract

**Gate name：** Gate 10 v2-beta 生产镜像单点升级。

**Goal：** 在不改变现有生产架构和数据边界的前提下，把 `trendradar` 切换到已验证的 v2-beta RC，并证明可回滚。

**Allowed actions：** 仅限当前被老板明确批准的单个子闸门。

**Forbidden actions：** 自动连续执行 10A—10D、同步整个部署目录、读取/传播凭据、覆盖配置或输出、修改其他容器或 Cloudflare、删除任何文件/镜像/备份。

**Validation：** 每个子闸门完成后由执行 Agent 报告，Codex 主控独立复核并停止；下一子闸门需老板批准。

**Stop conditions：** 出现未知差异、敏感信息风险、回滚证据不足、校验失败、生产状态与文档不一致或需要扩大变更范围。

**Next Owner after design：** 老板审阅本文；确认后由 Codex 编写逐命令实施计划，不直接进入 NAS 执行。
