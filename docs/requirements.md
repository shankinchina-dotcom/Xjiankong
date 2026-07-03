# GitHub AI 仓库追踪需求

## 目标

监控 GitHub 上 AI 相关的仓库，追踪高星、快速增长的、更新频繁的项目。

## 具体想要的数据

| 维度 | 说明 |
|---|---|
| 仓库名称 | 仓库全名（owner/repo） |
| 星数 | 当前总星数 + 当日/当周新增星数 |
| 更新频率 | commit 频率、最近 release 时间 |
| 分类 | Agent 框架 / Skill/Plugin / 模型 / 工具 / MCP 等 |

## 重点关注的方向

- AI agent 框架（LangChain、CrewAI、AutoGPT 等生态）
- AI skill / plugin 类项目
- MCP（Model Context Protocol）相关项目
- CLI AI 工具
- 星增长很快的新项目（daily/weekly star velocity）

## 当前方案的局限

- `agents-radar` RSS：只有日报标题，没有具体仓库名和星数
- `GitHubTrendingRSS`：全语言热榜，不区分 AI/非 AI，且只有标题
- 都不提供 star velocity 和更新频率数据

## 约束

- 不自己写爬虫/追踪系统
- 优先用现成开源工具或服务
- 免费方案优先
- 最好能通过 RSS/MCP/API 接入到现有的 TrendRadar 管道
