# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Claude 进入本项目必须先完整读取 `AGENTS.md`，并将其作为通用项目规则来源。本文件只补充 Claude 专属约束和实际操作经验，不复制 `AGENTS.md` 内容。

## 部署状态

TrendRadar 通过 Docker 本地运行。

```bash
# 位置
/Users/shankluo/AI/Claude/TrendRadar

# 管理
docker restart trendradar          # 重启（配置变更后必须）
docker logs trendradar --tail 30   # 查看日志
# Web 报告：http://localhost:8080
# 质量检查：bash quality-check.sh --trendradar
```

## 数据通道

| 通道 | 状态 | 说明 |
|---|---|---|
| A1 TrendRadar | ✅ 运行中 | Docker 本地，11 中文热榜 + RSS + AI 分析+翻译 |
| X 账号 | ✅ Nitter | `nitter.net/<handle>/rss`，@GabrielPeterss4 已失效(404) |
| GitHub AI 追踪 | ✅ | isboyjc daily/weekly trending + HuggingFace papers + 6 releases atom |
| A2 X Hosted MCP | ❌ 已放弃 | X API Pay-per-use 付费，用户拒绝 |

## RSS 源清单

| 类型 | 数量 | 源 |
|---|---|---|
| X AI 账号 | 33 | Nitter（1 个失效） |
| GitHub 热榜 | 2 | isboyjc daily + weekly |
| AI 论文 | 1 | HuggingFace daily papers |
| 版本发布 | 6 | Codex / Claude Code / LangChain / Langflow / AutoGen / CrewAI |
| AI 仓库日报 | 1 | agents-radar |
| 技术讨论 | 1 | Hacker News |

## 关键词配置规则（已踩坑验证）

1. `frequency_words.txt` 格式：`[GLOBAL_FILTER]` → `[WORD_GROUPS]` → 各组 `[group-name]`。**缺 `[WORD_GROUPS]` 会导致所有组被忽略。**
2. 短词必须用正则+词边界：`/\bAI\b/i`，纯文本 `AI` 会误命中 maintain、available 等所有含 "ai" 子串的词。
3. 硬件/经济类关键词必须用 `+正则` 做必须词约束，确保只有 AI 相关才匹配。
4. TrendRadar 的 `re.compile(pattern, re.IGNORECASE).search()` 完整支持 `/pattern/flags` 语法。
5. 源文件在 `config/trendradr/frequency_words.txt`，容器同步后必须 `docker restart trendradar` 生效。

## 已废弃

- **GitHub Actions 部署**：fork 后 workflow 永久 queued
- **X Hosted MCP**：需付费
- **CodeBuddyCLI**：key 格式不兼容
- **RSSHub X 路由**：公开实例已挂，改用 Nitter

## 遗留待办

| 事项 | 状态 |
|---|---|
| 飞书推送 | 未配，等报告质量确认 |
| @GabrielPeterss4 | Nitter 404，需从 x-accounts.json 移除 |
| 小红书/公众号/知识星球 | 公开 RSS 均不可用，暂无方案 |

## Claude Code 专属

- MCP 用 `claude mcp add` / `claude mcp add-json`，不用 `claude_desktop_config.json`
- 凭据通过文件写入，不走 shell echo
- 不修改 `AGENTS.md` 除非用户明确要求
