# CLAUDE.md

Claude 进入本项目后必须先完整读取根目录 `AGENTS.md`。活动架构和部署状态以 `ai-intelligence-hub-design.md` 为准；本文件只补充 Claude Code 的本地操作经验。

## TrendRadar 本地环境

TrendRadar fork 位于：

```text
/Users/shankluo/AI/Claude/TrendRadar
```

只读检查命令：

```bash
docker ps --filter name=trendradar
docker logs trendradar --tail 30
bash quality-check.sh --trendradar
```

Web 报告地址为 `http://localhost:8080`。修改配置后需要重启容器，但修改运行配置和执行 `docker restart trendradar` 前必须获得老板明确确认。

## 已验证的关键词规则

1. 受控源文件是 `config/trendradar/frequency_words.txt`；实际运行文件是相邻 TrendRadar fork 的 `config/frequency_words.txt`。
2. 文件顺序为 `[GLOBAL_FILTER]` → `[WORD_GROUPS]` → 各 `[group-name]`；缺少 `[WORD_GROUPS]` 会导致后续词组被错误解析。
3. 短英文词使用正则和词边界，例如 `/\bAI\b/i`，避免误命中 `maintain`、`available`。
4. 硬件和经济类关键词使用 `+正则` 作为 AI 上下文必须词。
5. TrendRadar 使用 `re.compile(pattern, re.IGNORECASE).search()` 解析 `/pattern/flags`。

## Claude Code 专属约束

- X Hosted MCP 已归档；除非老板重新确认 Pay-per-use 和 OAuth，不执行归档手册中的命令。
- MCP 配置优先使用 `claude mcp add` / `claude mcp add-json`，不用 Claude Desktop 的 `claude_desktop_config.json`。
- 凭据只能写入老板明确批准的安全存储，不使用 shell `echo`，不写入项目文件。
- 除非老板明确要求，不修改 `AGENTS.md`。
