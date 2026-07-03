# AI 行业情报系统设计

> 状态：A1 已部署运行（Docker 本地），A2（X Hosted MCP）因付费已放弃。  
> 外部依赖最后核验：2026-07-03。  
> 目标：用 TrendRadar 做广覆盖采集 + Nitter RSS 补充 X 内容，输出有结论的中文日报。

## 一、设计结论

系统需要区分两个概念：

- **数据通道**决定从哪里获取数据：A1 为 TrendRadar，A2 为 X Hosted MCP。
- **处理方案**决定如何过滤和分析数据：Version A 使用通道原生规则，Version B 使用统一规则。

不能把 A1/A2 当成 Version A/B。A1 与 A2 数据源不同，适合比较覆盖能力；Version A 与 B 必须处理同一份原始数据，才适合比较过滤和分析质量。

```text
TrendRadar（A1） ─┐
                  ├─> 标准化记录 ─> 过滤/分类 ─> 中文分析 ─> 日报
X Hosted MCP（A2）┘

处理方案 A：A1、A2 使用各自适配的规则
处理方案 B：对同一份标准化记录使用统一规则
```

## 二、系统边界

### 2.1 数据通道

| 通道 | 负责内容 | 优势 | 边界 |
|---|---|---|---|
| A1 TrendRadar | 11 中文热榜 + 35 RSS 源 | 广覆盖、免费、调度/翻译/分析完整 | X 经 Nitter RSS 接入，无互动指标 |
| A2 X Hosted MCP | ❌ 已放弃 | — | X API 需 Pay-per-use 付费，用户拒绝 |

X 账号的唯一数据源是 [`config/x-accounts.json`](config/x-accounts.json)。文档不再复制完整账号清单，也不手写固定账号总数。

### 2.2 收录边界

收录：

- 模型、产品、Agent、开发工具、论文、开源项目和行业趋势。
- 算力、芯片、融资、财报、监管和地缘政治中，能明确说明其对 AI 供给、成本、竞争或合规影响的内容。

排除：

- 与 AI 无关的政治、生活、娱乐、股票喊单和加密货币内容。
- 只有宽泛词命中、无法证明与 AI 相关的内容。
- 纯转发、重复内容、无新增信息的营销文案。

## 三、Version A：通道原生处理

### 3.1 A1：TrendRadar

TrendRadar 当前上游已经支持：

- `config/config.yaml` 2.x 结构；RSS 字段为 `rss.feeds`，不是旧版 `rss.sources`。
- `config/timeline.yaml` 调度系统。
- `filter.method: keyword | ai` 两种筛选方式。
- `config/frequency_words.txt` 的 `[GLOBAL_FILTER]`、`[WORD_GROUPS]`、正则、必须词和组内排除词。

本项目先使用 `keyword` 方案建立可解释基线，再决定是否启用 TrendRadar 自带的 AI 筛选：

```yaml
app:
  timezone: "Asia/Taipei"

schedule:
  enabled: true
  preset: "morning_evening"

filter:
  method: "keyword"

report:
  display_mode: "keyword"
  max_news_per_keyword: 5

ai_analysis:
  enabled: true
  language: "Chinese"
  include_rss: true

ai_translation:
  enabled: true
  language: "中文"
  scope:
    hotlist: false
    rss: true
    standalone: true
```

`frequency_words.txt` 格式为 `[GLOBAL_FILTER]` → `[WORD_GROUPS]` → 各 `[组别名]`。`[WORD_GROUPS]` 标记不可省略，否则词组区域不会被解析。短英文词必须用 `/\bword\b/i` 正则加词边界，纯文本 `AI` 会误命中 maintain、available 等含 "ai" 子串的词：

```text
[GLOBAL_FILTER]
广告
促销
抽奖
带货

[WORD_GROUPS]

[AI 核心]
/\b(?:AI|AGI|LLM|GPT|ChatGPT|Claude|Gemini|Grok)\b/i
/\b(?:OpenAI|Anthropic|DeepMind|xAI|DeepSeek|Llama|Mistral)\b/i
大模型
大语言模型
智能体
生成式人工智能
@20

[算力与硬件]
+/\b(?:AI|LLM|training|inference)\b/i
/\b(?:GPU|CPU|TPU|NPU|HBM|NVIDIA|AMD|Blackwell|Hopper|Rubin)\b/i
芯片
半导体
算力
数据中心
@10

[AI 经济与政策]
+/\bAI\b/i
融资
估值
收购
财报
监管
法案
出口管制
@10

[论文与研究]
/\b(?:arXiv|ICML|NeurIPS|ICLR|RLHF|RAG|benchmark|reasoning)\b/i
论文
研究
推理
对齐
微调
@10

[开发工具与开源]
/\b(?:Cursor|MCP|LangChain|function calling|tool use|open source)\b/i
AI 编程
开源模型
@10
```

> 上述配置是项目基线，不替代 TrendRadar 上游完整示例。如果上游配置版本变化，先按上游迁移说明更新，再应用本项目差异。

#### 从账号配置派生 RSS feeds

Nitter RSS URL 规则为 `https://nitter.net/<handle>/rss`。派生命令：

```bash
jq -r '
  .groups[].accounts[]
  | "    - id: \"nitter-\(.handle | ascii_downcase)\"\n      name: \"X @\(.handle)\"\n      url: \"https://nitter.net/\(.handle)/rss\""
' config/x-accounts.json
```

把输出追加到 TrendRadar `config/config.yaml` 的 `rss.feeds` 下。不要覆盖上游的 `rss.enabled` 和 `freshness_filter` 配置。Nitter 不稳定，切换数据源时同步更新 `config/trendradar/rss-feeds.yaml` 和 `AGENTS.md` 的 URL 规则。

### 3.2 A2：X Hosted MCP

A2 的接入和执行步骤见 [`x-hosted-mcp-setup.md`](x-hosted-mcp-setup.md)。处理顺序固定为：

1. 使用明确的 UTC 半开时间窗 `[start_time, end_time)` 抓取。
2. 使用 Post ID 去重，查询阶段排除 retweet。
3. 先做确定性过滤，再把边界内容送入人工或 AI 复核。
4. 分类后按内容类别排序和截断。
5. 输出 `raw.json`、`processed.json` 和 `digest.md`。

Version A 的过滤分三档：

| 档位 | 规则 | 结果 |
|---|---|---|
| 强相关 | 明确命中模型、公司、技术或 AI 产品专名 | 保留 |
| 条件相关 | 硬件、经济、政策词与 AI 上下文同时出现 | 保留或复核 |
| 弱相关 | `model`、`release`、`update`、`研究`、`发布`等宽泛词单独出现 | 复核，不得直接保留 |

账号中 `review_policy=strict` 的条目还必须满足对应 `review_note`，否则丢弃。

## 四、Version B：统一处理方案

Version B 第一阶段只用于处理 A2 的同一份 `raw.json`，避免数据源差异污染实验。胜出后再评估是否接入 A1 标准化数据。

统一分析输入至少包含：Post ID、作者、正文、发布时间、互动指标、原文链接。输出必须是可解析 JSON：

```json
{
  "post_id": "string",
  "relevance": "keep | review | drop",
  "relevance_reason": "string",
  "category": "model | hardware | economy | policy | research | product | open_source | trend | zh_cn",
  "summary_zh": "不超过50字",
  "impact_zh": "不超过100字；说明对AI行业的具体影响",
  "importance": "milestone | watch | signal | reference"
}
```

判断要求：

- 不允许仅因作者属于 AI 圈就判定相关。
- 硬件、经济和政治内容必须给出 AI 影响链路；无法说明则 `drop` 或 `review`。
- 摘要不得添加原文没有的事实。
- `relevance_reason` 必须引用正文中的具体证据，而不是泛泛评价。

## 五、标准化输出契约

每次 X 运行创建独立目录：

```text
output/x/YYYY-MM-DD/
├── raw.json        # 原始 API 响应标准化结果，不做内容改写
├── processed.json  # 去重、判定、分类、翻译和分析结果
└── digest.md       # 最终中文日报
```

三份文件必须共享 `run_id` 和 Post ID。`raw.json` 至少保存：

- `schema_version`、`run_id`、`fetched_at`。
- `window.start_time`、`window.end_time`、`window.timezone`。
- 实际查询、账号快照、分页是否完整、错误列表。
- 每条 Post 的 `id`、`author_handle`、`text`、`created_at`、`url`、`lang` 和互动指标快照。

`processed.json` 额外保存：

- `decision`：`keep | review | drop`。
- `decision_reason`、`matched_rules`、`category`。
- 中文摘要、影响判断和重要性标签。
- 使用的处理方案、Prompt 版本和模型名。

## 六、实验设计

### 6.1 实验 S：数据源覆盖

目的：判断 A1 与 A2 各自补充了什么，不评价处理方案优劣。

- 连续运行至少 7 天。
- 将同一事件跨来源归并为一个事件簇。
- 记录 A1 独有、A2 独有、两者共有的事件数。
- 单独检查模型发布、硬件、投融资、政策和中文圈覆盖。

### 6.2 实验 P：处理方案 A/B

目的：比较过滤和分析方法。输入必须是同一份 A2 `raw.json`。

1. 从 7 天数据中随机抽样，并补充容易误判的硬件、政治和生活内容。
2. 人工标注 `keep/drop`、类别和重要性，形成基准集。
3. Version A 与 B 独立处理相同样本。
4. 按以下指标计算，不用主观 1–5 分替代：

| 指标 | 计算方式 |
|---|---|
| 精确率 | 正确保留数 / 全部保留数 |
| 召回率 | 正确保留数 / 基准集中应保留数 |
| 噪音率 | 错误保留数 / 全部保留数 |
| 分类准确率 | 分类正确数 / 正确保留数 |
| 分析可用率 | 摘要忠实且影响链路成立的条数 / 正确保留数 |
| 维护成本 | 每周规则修改次数、人工复核条数和模型成本 |

最终方案优先满足精确率和分析可用率，再比较召回率与维护成本。A/B 差异不显著时，选择规则更少、成本更低的方案。

## 七、实施顺序与验收

1. 配置并验证 TrendRadar A1，只确认采集、存储和本地报告，不直接开启外部推送。
2. 按操作手册接入 X Hosted MCP，先跑单账号、短时间窗、只读测试。
3. 经老板确认成本后，运行全部账号并生成三份本地文件。
4. 连续积累 7 天数据，执行实验 S 和实验 P。
5. 选定处理方案后，再单独确认是否接入飞书推送或生产调度。

验收条件：

- 账号配置 JSON 合法、handle 无重复。
- A1 使用当前 TrendRadar 字段，无 `rss.sources` 等旧配置。
- A2 时间窗、分页状态、错误和成本边界可追溯。
- A/B 使用同一 `raw.json`，人工基准集可复核。
- 未经确认，不写凭据、不授权账号、不调用外部写工具、不发送消息。

## 八、已核验的官方资料

- [TrendRadar 官方仓库](https://github.com/sansan0/TrendRadar)
- [X MCP 官方文档](https://docs.x.com/tools/mcp)
- [xurl 官方仓库](https://github.com/xdevplatform/xurl)
- [X 全量搜索文档](https://docs.x.com/x-api/posts/search-all-posts)
- [X API 限流](https://docs.x.com/x-api/fundamentals/rate-limits)
- [X API 计费](https://docs.x.com/x-api/getting-started/pricing)
- [DeepSeek API 文档](https://api-docs.deepseek.com/)
