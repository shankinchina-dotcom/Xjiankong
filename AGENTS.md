# AGENTS.md

本文件定义 Xjiankong 项目的仓库级规则。项目当前处于 **A1 已部署、质量验证阶段**：TrendRadar 通过本地 Docker 运行，外部推送尚未启用；X Hosted MCP 已归档，不属于活动架构。

## 项目目标

从中文热榜、X 账号 RSS、GitHub/HuggingFace/Release RSS 聚合 AI 行业信息，经相关性过滤、分类和中文分析后生成本地 HTML 日报。经济、政治、CPU、GPU、内存等内容只有在明确影响 AI 行业时才收录。

## 活动架构与实验术语

- **A1 / 活动管道**：TrendRadar，负责采集、SQLite 存储、过滤、翻译、AI 分析和 HTML 报告。
- **Variant K**：使用 `config/trendradar/frequency_words.txt` 的关键词过滤基线。
- **Variant AI**：使用 TrendRadar 内置 `filter.method=ai` 的 AI 相关性过滤。
- K/AI 实验必须只读处理同一批 SQLite 快照；不得用不同时间生成的实时日报比较。
- **X Hosted MCP / A2**：历史候选方案，已因 Pay-per-use 成本归档。除非老板重新确认费用与 OAuth，不得恢复执行。

## 文件与目录约定

| 路径 | 作用 | 维护规则 |
|---|---|---|
| `ai-intelligence-hub-design.md` | 活动架构、数据边界和 K/AI 实验方法 | 只描述当前主线；历史方案只保留归档链接 |
| `docs/requirements.md` | GitHub AI 追踪原始需求 | 需求变化先改此文件 |
| `docs/github-ai-tracking-plan.md` | GitHub/HuggingFace/Release RSS 接入记录 | 必须区分“已接入”和“指标能力待复核” |
| `docs/archive/` | 已放弃或暂停的历史方案 | 不作为执行入口；恢复前重新核验外部依赖 |
| `config/x-accounts.json` | X 账号唯一数据源 | 账号只在此处新增、删除、改组或改审核策略 |
| `config/trendradar/` | 同步到 TrendRadar 的受控配置快照 | 修改后对照实际 fork 并运行质量检查 |
| `output/experiments/filter-ab/<run_id>/` | 未来 K/AI 离线实验产物 | 不作为运行配置；完成复盘并确认无保留价值后清理 |
| `quality-check.sh` | 本仓库与相邻 TrendRadar 的只读质量检查 | 不得修改运行配置或重启容器 |
| `AGENTS.md` | 所有 Agent 共用的项目规则 | 规范变化先改本文件，再改实践 |
| `CLAUDE.md` | Claude 专属操作补充 | 不复制部署状态或完整源清单 |

新目录必须先在本节声明用途、命名和清理策略。代码、命令、变量名和文件名使用英文；项目文档默认中文。

## 单一数据源约束

1. X 账号、分组、handle 和审核说明以 `config/x-accounts.json` 为准。
2. 文档不得再次内嵌完整账号清单，也不得手写固定账号总数。
3. TrendRadar RSS 配置应从账号文件派生，当前 URL 规则为 `https://nitter.net/<handle>/rss`。
4. Nitter 是不稳定的免费传输层；账号目标与 feed 可用性不是同一概念。不得仅因 Nitter 失败就删除监控账号。
5. 修改账号后必须运行：

   ```bash
   jq -e '
     [.groups[].accounts[].handle] as $handles
     | ($handles | length) > 0
       and (($handles | map(ascii_downcase) | unique | length) == ($handles | length))
       and (all($handles[]; test("^[A-Za-z0-9_]{1,15}$")))
   ' config/x-accounts.json
   ```

## K/AI 实验约束

- 冻结连续 7 天的 `output/news/*.db` 与 `output/rss/*.db` 后再开始实验，两个变体使用同一份只读副本。
- 人工标注集不少于 300 条，按热榜、Nitter、GitHub、论文和 Release 分层抽样，并加入硬件、政治、生活类困难负样本。
- Variant K 与 Variant AI 的下游翻译、分析 Prompt 和报告格式必须一致；实验只比较过滤和分类。
- 精确率低于 90% 或漏掉人工定义的重要事件集合时直接淘汰。
- 精确率差距小于 3 个百分点时选择人工复核量和成本更低者；AI 方案至少提升 5 个百分点或显著减少人工复核，才替换 K。
- 结果必须记录稳定 ID、来源、人工标签、判定理由、模型名、Prompt 版本和成本。

## 外部依赖与安全边界

- TrendRadar 以实际 fork 的 `config/config.yaml`、`config/frequency_words.txt` 和 `config/timeline.yaml` 为运行来源。
- Client Secret、API key、token、webhook 不得写入仓库、命令历史、日志或对话。涉及凭据写入时必须先获得老板明确确认。
- 修改运行中的 TrendRadar 配置、重启容器、调用付费模型、恢复 X Hosted MCP 或发送飞书消息，均需老板在当前对话中明确要求。
- 默认只允许读取容器状态、日志和 SQLite 快照；不得因文档变更顺带修改运行环境。

## 文档修改与验证

修改后至少执行：

```bash
jq empty config/x-accounts.json
bash quality-check.sh
bash quality-check.sh --trendradar
rg -n 'A2.*(实施|运行|待接入)|X Hosted MCP.*(主线|当前)' AGENTS.md CLAUDE.md ai-intelligence-hub-design.md docs --glob '!docs/archive/**'
git diff --check
```

预期：JSON 与两组质量检查通过；活动文档没有把 A2 当作当前或待实施主线；`git diff --check` 无输出。
