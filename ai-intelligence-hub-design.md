# AI 行业情报系统设计

> 状态：A1 TrendRadar 已在群晖 NAS 四容器生产运行，通过 Cloudflare Tunnel 公开只读日报。v1.1（2026-07-07）：RSS 采集成功 **41/44**（30/33 Nitter），热榜 **11/11**；AI 分析（deepseek flash）和 AI 翻译已启用并通过端到端验证。v2-alpha「AI 行业每日研判报告」已于 2026-07-09 生产上线，当前镜像为 `xjiankong-trendradar:v2-alpha-20260709`，代码基线为 TrendRadar `v2-alpha` HEAD `33d80973`。下一步为 v2-beta「AI 情报终端与历史版本浏览」：历史与数据实施仍待闸门确认；“深空研判报告”视觉方向已于 2026-07-10 确认，见 [`docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md`](docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md)。
>
> 活动架构最后核对：2026-07-08。
>
> 目标：建设老板个人的 AI 情报收集中心，从多类公开信息源采集 AI 技术、AI 应用、AIGC 创业、模型价格、平台政策和商业化动态，经相关性过滤、中文分析后生成高信噪比 HTML 日报。

## 一、设计结论

项目只保留一条活动管道：**A1 TrendRadar**。TrendRadar 负责采集、SQLite 存储、过滤、翻译、AI 分析和 HTML 报告。

长期产品定位不是单纯的「AI 技术新闻站」，而是老板个人的 **AI 情报收集中心**：

- 追踪 AI 基础技术：模型、论文、Agent、开源项目、开发者生态。
- 追踪 AI 应用落地：内容创作、销售、教育、电商、办公、视频、音乐、小说、漫剧、游戏、工作流自动化。
- 追踪 AI 创业机会：热门应用方向、平台反应、商业化案例、融资与竞争格局。
- 追踪 AI 成本结构：主流模型价格、降价活动、算力和 API 成本变化。
- 追踪 AI 平台环境：平台政策、版权规则、内容审核、分发机制、监管变化。

X Hosted MCP 因 Pay-per-use 成本已退出活动架构。完整接入说明保留在 [`docs/archive/x-hosted-mcp-setup.md`](docs/archive/x-hosted-mcp-setup.md)，仅用于未来重新评估；恢复前必须重新确认费用、OAuth 权限和官方接口。

当前需要验证的不是不同数据通道，而是同一批 A1 原始数据上的两种过滤方法：

- **Variant K**：关键词过滤，可解释、免费、维护成本低。
- **Variant AI**：TrendRadar 内置 AI 过滤，语义能力更强但有模型成本和稳定性风险。

实验采用精确率优先策略。未经同一快照和人工标注验证，不得因单次日报观感切换生产过滤方式。

## 二、活动架构

```text
中文热榜 ──────────────────────┐
X 账号 Nitter RSS（best effort）├─> TrendRadar 采集
GitHub Trending / agents-radar ┤       ↓
HuggingFace Papers             ┤   SQLite 原始数据
GitHub Releases Atom ──────────┘       ↓
                                  相关性过滤
                              Variant K | Variant AI
                                      ↓
                         翻译 + AI 分析（deepseek flash）
                                      ↓
                                  HTML 日报
                                      ↓
                         report-web + Cloudflare Tunnel
                                      ↓
                         https://trend.shankluo.cc
```

### 2.1 数据源职责

| 来源 | 负责内容 | 优势 | 已知边界 |
|---|---|---|---|
| 中文热榜 | 国内新闻、政策、产业和社会热点 | 覆盖广、更新快 | 依赖公共 NewsNow 实例，单个平台可能暂时失败 |
| Nitter RSS | `config/x-accounts.json` 中的 X 账号 | 免费、正文可进入 RSS 摘要 | Nitter 不稳定；无官方互动指标；单账号可能 404 |
| GitHub Trending RSS | 新项目发现 | 免费、更新频繁 | TrendRadar 当前不保存 feed 的自定义 `stars/addStars` 字段 |
| agents-radar | AI 仓库日报 | 已做上游聚合 | 颗粒度受上游日报格式限制 |
| HuggingFace Papers | AI 论文发现 | 有标题、摘要和 upvotes | 当前关键词过滤只检查标题，可能漏掉仅在摘要体现相关性的论文 |
| GitHub Releases Atom | 重点项目版本发布 | 官方 feed、稳定 | 版本标题可能不含 AI 关键词，当前 K 方案可能漏报 |

GitHub 星数、增长速度和 commit 频率尚未形成可靠能力；相关需求继续保留在 [`docs/requirements.md`](docs/requirements.md)，不在本轮架构收敛中补实现。

### 2.2 收录边界

收录：

- 模型、AI 产品、Agent、开发工具、论文、开源项目和行业趋势。
- AI 技术在内容、销售、教育、电商、视频、音乐、小说、漫剧、游戏、办公自动化等场景中的应用新闻和创业信号。
- AIGC 创业项目、平台政策、内容生态、商业化案例和用户需求变化。
- 主流模型价格、API 成本、免费额度、限时活动和横向性价比变化。
- 算力、芯片、融资、财报、版权、监管和地缘政治中，能够说明其对 AI 供给、成本、应用落地、平台分发、创业机会或合规影响的内容。

排除：

- 与 AI 无关的政治、生活、娱乐、股票喊单和加密货币内容。
- 只有宽泛词命中、无法证明与 AI 相关的内容。
- 纯转发、重复内容和无新增信息的营销文案。
- 只有概念热度、没有产品、平台动作、数据或商业化证据的创业故事。

## 三、运行基线

### 3.1 配置来源

- 账号源：`config/x-accounts.json`。
- 受控关键词快照：`config/trendradar/frequency_words.txt`。
- 受控 RSS 快照：`config/trendradar/rss-feeds.yaml`。
- 实际运行配置：相邻 TrendRadar fork 的 `config/config.yaml`、`config/frequency_words.txt` 和 `config/timeline.yaml`。

受控快照和实际运行配置并非自动同步。修改任一方后必须显式对比，并运行 `bash quality-check.sh --trendradar`；质量检查通过不等于所有外部 feed 均可用。

### 3.2 Variant K：关键词过滤

Variant K 使用当前生产 `frequency_words.txt`：

- 文件必须按 `[GLOBAL_FILTER]` → `[WORD_GROUPS]` → 各词组排列。
- 短英文词必须使用单词边界正则，例如 `/\bAI\b/i`。
- 硬件、经济和政策词使用 AI 上下文必须词，避免单独收录普通产业新闻。
- `@N` 只限制单个词组显示数量，不代表数据抓取上限。

Variant K 是当前生产基线。实验完成前，生产环境继续使用 `filter.method=keyword`。

### 3.3 Variant AI：AI 过滤

Variant AI 使用 TrendRadar 内置 `filter.method=ai`。正式实验时必须冻结：

- `ai_interests.txt` 的完整内容及 SHA-256。
- 模型提供商、模型名和版本。
- 分类 Prompt 文件及 SHA-256。
- `min_score`、temperature、批大小和重试配置。
- 运行时间、输入快照 ID、token 用量和估算费用。

本轮只定义实验，不创建 AI 配置、不调用模型、不修改生产过滤方式。

### 3.4 群晖 NAS 生产部署

TrendRadar 已在 DS220+ 的 Container Manager 中运行，当前生产基线为：

- `trendradar` 每 4 小时采集一次，首次启动不立即执行。
- `report-web` 只读公开允许访问的 HTML 报告，不发布宿主机端口。
- `cloudflared` 通过独立 Tunnel 将 `trend.shankluo.cc` 转发到内部 `report-web:80`，无需路由器端口映射。
- AI 分析与翻译已启用；后续新增付费验证、切换模型或扩大调用范围仍必须单独获得确认。
- v2-alpha 生产镜像为 `xjiankong-trendradar:v2-alpha-20260709`，由 TrendRadar `v2-alpha` HEAD `33d80973` 构建；镜像已通过 SourceRef/schema/formatter 免费验证和一次 deepseek flash 付费验证。
- 公网首页、敏感路径拒绝和 Tunnel 路由已验证；`/.env`、配置与 SQLite 路径均不可公开访问。

2026-07-06 的线上报告显示 RSS 源成功数为 `11/44`。活动配置中恰有 33 个 Nitter 源和 11 个其他启用源，数量关系与 NAS 无代理出口导致 Nitter 全部失败相符。修复采用独立 Mihomo sidecar，只代理 `nitter.net`，其他 RSS 继续直连；设计见 [`docs/superpowers/specs/2026-07-06-nitter-rss-proxy-design.md`](docs/superpowers/specs/2026-07-06-nitter-rss-proxy-design.md)。仓库本地准备已完成（docker-compose 新增 `rss-proxy` 服务、`proxy/config.example.yaml` 模板、`.gitignore`/构建脚本/测试脚本同步更新，均通过静态检查）；NAS 实施待老板提供 Clash 订阅 URL 并明确确认，订阅 URL 不得进入仓库或部署包。

## 四、K/AI 离线实验

### 4.1 实验目的

只回答一个问题：在相同原始数据上，AI 过滤能否以可接受成本显著提高日报精确率或减少人工复核。

下游翻译、AI 行业分析和日报格式不属于变量，两个变体必须保持一致。

### 4.2 输入快照

1. 连续积累 7 个完整自然日的数据。
2. 每日结束后冻结对应的 `output/news/YYYY-MM-DD.db` 和 `output/rss/YYYY-MM-DD.db`。
3. 实验只读取副本，不修改生产数据库，也不重新采集。
4. 记录每个文件的 SHA-256；任一哈希变化都使该次实验失效。

稳定记录 ID：

- RSS：`rss:<feed_id>:<guid>`；无 GUID 时使用规范化 URL 的 SHA-256。
- 热榜：`hotlist:<source_id>:<normalized_title_sha256>`。

### 4.3 人工基准集

从冻结快照中建立不少于 300 条的人工标注集：

- 按中文热榜、Nitter、GitHub、论文和 Release 分层抽样。
- 补充硬件、政治、生活、股票和加密货币类困难负样本。
- 加入人工维护的“重要事件集合”：模型发布、重大产品、关键硬件和监管事件。
- 标注字段为 `record_id`、来源、正文或标题、`keep/drop`、内容类别、是否重要事件、判定理由。

标注在执行 K/AI 之前完成，标注人员不得先看到任一变体结果。

### 4.4 实验执行

对同一组 `record_id` 分别运行：

1. Variant K：加载冻结版本的 `frequency_words.txt`，记录命中词组和 `keep/drop`。
2. Variant AI：加载冻结的兴趣描述、Prompt 和模型参数，记录相关性分数、类别、理由和 `keep/review/drop`。
3. `review` 计入人工复核量；计算精确率时不视为自动保留。
4. 两组结果写入同一个实验目录，不覆盖原始快照。

未来实验产物目录：

```text
output/experiments/filter-ab/<run_id>/
├── manifest.json       # 日期范围、哈希、配置和模型版本
├── labels.jsonl        # 人工基准集
├── variant-k.jsonl     # 关键词结果和命中规则
├── variant-ai.jsonl    # AI 结果、分数、理由和成本
└── report.md           # 指标、重要事件漏报和结论
```

### 4.5 指标

| 指标 | 定义 |
|---|---|
| 精确率 | 正确保留数 / 自动保留总数 |
| 召回率 | 正确保留数 / 人工标注应保留总数 |
| 噪音率 | 错误保留数 / 自动保留总数 |
| 分类准确率 | 分类正确数 / 正确保留数 |
| 人工复核率 | `review` 数 / 全部输入数 |
| 重要事件漏报 | 重要事件集合中未自动保留的条数 |
| 模型成本 | 输入/输出 token、调用次数和估算费用 |

### 4.6 胜负规则

1. 精确率低于 90% 的方案直接淘汰。
2. 重要事件漏报必须为 0；否则不得成为生产方案。
3. 满足门槛后，选择精确率更高者。
4. 精确率差距小于 3 个百分点时，选择人工复核量和运行成本更低者。
5. Variant AI 只有在精确率至少提升 5 个百分点，或显著减少人工复核时，才替换 Variant K。
6. 不用主观 1–5 分代替以上指标。

## 五、运行与变更边界

当前允许的只读检查：

```bash
docker ps --filter name=trendradar
docker logs trendradar --tail 30
bash quality-check.sh --trendradar
```

以下操作必须单独取得老板确认：

- 修改相邻 TrendRadar fork 的运行配置。
- 重启 `trendradar` 或 `trendradar-mcp` 容器。
- 创建 AI 过滤配置或调用付费模型。
- 恢复 X Hosted MCP、OAuth 或购买 X API credits。
- 配置或发送飞书通知。
- 在群晖或 Cloudflare 上创建、修改或启动本项目部署。

## 六、当前阶段验收

- 活动架构只有 A1 TrendRadar，A2 仅存在于归档。
- 生产继续使用 Variant K，不因文档变更改变运行行为。
- v2-alpha 已生产上线（2026-07-09）：核心为 8 板块「AI 行业每日研判报告」、运行时 SourceRef/source_map 溯源、AI 分析区前置、HTML 视觉统一；生产基线为 TrendRadar `v2-alpha` HEAD `33d80973`，镜像 `xjiankong-trendradar:v2-alpha-20260709`。
- v2-alpha 上线验证结果：热榜 11/11，RSS 38/44，翻译 26/26，AI 分析 deepseek flash 完成，页面含 `ai-section-v2`、8 板块和引用来源索引，公网 `https://trend.shankluo.cc` HTTP 200，`/.env` 与 `/news/test.db` 均 404。
- K/AI 实验使用同一 SQLite 快照、稳定 ID 和人工基准集。
- GitHub 指标能力缺口被明确记录，不把“RSS 已接入”等同于“需求已满足”。
- NAS、Tunnel、DNS 和只读公网发布已完成；AI 分析（deepseek flash）与 AI 翻译已启用并通过端到端验证（2026-07-07）。
- Nitter RSS 代理修复已实施并端到端验证通过（2026-07-07）：RSS 采集成功 **40/44**（30/33 Nitter X 源成功，2 个 404 为账号在 Nitter 不存在，非代理问题），从修复前 11/44 显著提升。热榜直连，RSS 经 `rss-proxy:7890` 按域名分流 Nitter。踩坑记录：NAS 运行配置需手动更新 `advanced.rss.use_proxy` 和 `proxy_url`（仓库快照与实际运行配置不同步）；Synology `sed -i` 不支持 macOS 的空备份后缀语法；误将爬虫代理一并开启会导致热榜全量失败。
- 文档变更本身不修改 TrendRadar、Docker、RSS 源、关键词和账号清单。
- AI 分析（deepseek flash）与翻译已启用，单次采集费用约几分钱。启用付费 AI 前已获老板明确确认。

## 七、下一步：v2-beta AI 情报终端与历史版本浏览

v2-beta 的当前候选方向是将已上线的 v2-alpha 日报升级为「AI 情报终端」：

1. 将系统定位从「AI 行业日报」升级为「AI 情报收集中心」，覆盖 AI 技术、AI 应用、AIGC 创业、模型价格、平台政策和商业化机会。
2. 保持 v2-alpha 8 板块「AI 行业每日研判报告」为核心，不替代分析框架。
3. 增加历史版本浏览能力，让用户按日期和时间查看今天、昨天、前天及每天多版报告。
4. 基于现有 `output/html/YYYY-MM-DD/HH-MM.html` 历史快照生成受控的 `history.json` / `history.html`，不启用 Nginx 目录列表。
5. 页面视觉统一为深色情报终端 + 淡饱和蓝色渐变，RSS/热榜作为证据层，不再喧宾夺主。
6. 预留「主流模型官方价格动态」内容板块，用于后续跟踪 Claude、OpenAI GPT、Gemini、Grok、智谱 GLM/GLM 5.2、DeepSeek、通义千问、GPT Image 2、字节 Seedream 等模型的官方价格变化、降价幅度和价格优势；价格事实必须来自官方价格页、公告或开发者文档。
7. 预留「AI 创业方向与 AIGC 应用风向」内容板块，用于后续分析漫剧、AI 小说、AI 音乐和新的 AI 创业方向，重点记录热门新闻、平台反应、商业化机会和可核验数据。
8. 修复原始消息链接 404 问题，保证报告中的消息、RSS 和引用来源能追踪到可用的原始页面或明确 fallback；该问题直接影响溯源可信度，应优先于生产同步。
9. 不新增数据源，不改数据库 schema，不持久化 `source_map`，不改 NAS/Cloudflare。

当前状态：历史与数据策划见 [`docs/superpowers/specs/2026-07-09-v2-beta-intelligence-history-ui-design.md`](docs/superpowers/specs/2026-07-09-v2-beta-intelligence-history-ui-design.md)；深空研判报告视觉已确认并写入 [`docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md`](docs/superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md)，效果图见 [`docs/superpowers/specs/v2-beta-deep-space-report-reference.png`](docs/superpowers/specs/v2-beta-deep-space-report-reference.png)（示意数据，仅作风格参考）。Gate 3／4 已完成：链接问题是源站外链与 Nitter 单点风险，页面数据映射可行但缺少 `history.json`、来源状态和动态板块摘要；下一闸门为本地 Gate 5 受控 `history.json` 生成，不涉及生产同步。

## 八、参考资料

- [TrendRadar 官方仓库](https://github.com/sansan0/TrendRadar)
- [GitHub AI 追踪需求](docs/requirements.md)
- [GitHub AI RSS 接入记录](docs/github-ai-tracking-plan.md)
- [群晖 NAS 部署手册](deploy/nas/README.md)
- [群晖 NAS 部署设计](docs/superpowers/specs/2026-07-03-nas-deployment-design.md)
- [群晖 NAS 实施计划](docs/superpowers/plans/2026-07-04-nas-deployment.md)
- [X Hosted MCP 历史方案](docs/archive/x-hosted-mcp-setup.md)
