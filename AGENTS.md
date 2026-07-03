# AGENTS.md

本文件定义 Xjiankong 项目的仓库级规则。项目当前处于**设计与接入验证阶段**：仓库内只有设计、操作手册和静态配置，不代表外部服务已经部署成功。

## 项目目标

从 TrendRadar 和 X 聚合 AI 行业信息，经相关性过滤、分类和中文分析后生成日报。经济、政治、CPU、GPU、内存等内容只有在明确影响 AI 行业时才收录。

## 术语边界

- **数据通道 A1**：TrendRadar，负责热榜和 RSS 的广覆盖采集。
- **数据通道 A2**：X Hosted MCP，负责 X 全文和互动数据的深度补充。
- **处理方案 A**：每个通道使用适合自身数据形态的原生过滤与分析规则。
- **处理方案 B**：对同一批原始数据使用统一相关性判断、分类和分析格式。
- 不得把 A1/A2 数据通道称为 Pipeline A/Pipeline B；这会与处理方案 A/B 混淆。

## 文件与目录约定

| 路径 | 作用 | 维护规则 |
|---|---|---|
| `ai-intelligence-hub-design.md` | 系统边界、数据流、处理方案和实验方法 | 不放易漂移的完整账号清单 |
| `x-hosted-mcp-setup.md` | X Hosted MCP 接入、抓取、处理和验收手册 | 外部命令必须有来源和验证日期 |
| `config/x-accounts.json` | X 账号唯一数据源 | 账号只在此处新增、删除、改组或改审核策略 |
| `AGENTS.md` | 所有 Agent 共用的项目规则 | 规范变化先改本文件，再改实践 |
| `CLAUDE.md` | Claude 专属补充 | 不复制通用规则；默认不由 Codex 修改 |
| `output/x/YYYY-MM-DD/` | 运行时生成的原始数据、候选集和日报 | 不作为配置源；确认不再复盘后按需清理 |

新目录必须先在本节声明用途、命名和清理策略。代码、命令、变量名和文件名使用英文；项目文档默认中文。

## 单一数据源约束

1. X 账号数量、分组、handle 和严格审核说明以 `config/x-accounts.json` 为准。
2. 文档不得再次内嵌完整账号清单，也不得手写固定账号总数。
3. TrendRadar RSS 配置应从该文件派生，RSS URL 规则为 `https://nitter.net/<handle>/rss`。RSSHub 公开实例的 Twitter 路由已失效，改用 Nitter；Nitter 不稳定，切换数据源时必须同步更新本规则和 `config/trendradar/rss-feeds.yaml`。
4. 修改账号后必须运行：

   ```bash
   jq -e '
     [.groups[].accounts[].handle] as $handles
     | ($handles | length) > 0
       and (($handles | map(ascii_downcase) | unique | length) == ($handles | length))
       and (all($handles[]; test("^[A-Za-z0-9_]{1,15}$")))
   ' config/x-accounts.json
   ```

## A/B 实验约束

- 比较数据源覆盖时，评估 A1 与 A2；这不是处理方案 A/B 实验。
- 比较处理方案时，A 与 B 必须使用相同的原始数据快照。
- 精确率和召回率必须基于人工标注样本计算，不得仅凭 1–5 分主观打分得出结论。
- 原始数据、人工判定和最终输出必须保留稳定 ID，确保结果可追溯。

## 外部依赖与安全边界

- 外部接入基线最后核验日期：**2026-07-02**。执行前若官方文档或工具版本已变化，先重新核验。
- TrendRadar 以其当前 `config/config.yaml`、`config/frequency_words.txt` 和 `config/timeline.yaml` 为准，不沿用旧字段。
- X Hosted MCP 通过 `@xdevplatform/xurl` 的 `mcp` bridge 接入；xurl、客户端配置和 OAuth 参数修改前必须对照官方文档或源码。
- Client Secret、API key、token、webhook 不得写入仓库、命令历史、日志或对话。涉及凭据写入时必须先获得老板明确确认。
- 安装全局依赖、修改客户端全局配置、授权 X 账号和发送飞书消息均属于需确认操作。操作手册必须设置确认闸门，不能让执行 Agent 自动越过。
- 不部署、不发消息、不创建或修改外部资源，除非老板在当前对话中明确要求。

## 文档修改与验证

修改后至少执行：

```bash
jq empty config/x-accounts.json
rg -n '30 个账号|since:2026-07-01|v4-flash.*deepseek-chat' --glob '!AGENTS.md' .
rg -n 'Pipeline B' ai-intelligence-hub-design.md x-hosted-mcp-setup.md
rg -n -U 'rss:\s*\n\s*sources:' --glob '!AGENTS.md' .
```

预期：JSON 校验通过；后三条命令没有命中。涉及外部命令时，还要记录本次核验的官方来源和日期。
