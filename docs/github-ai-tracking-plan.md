# GitHub AI 仓库追踪方案

> 目标：在 TrendRadar 日报中增加 GitHub 上 AI agent、skill 等高星、更新频繁的仓库，以及星增长快的项目。
> 状态：方案设计，待老板确认后执行。

---

## 一、调研结论

GitHub 上有现成的数据源可以直接接入，不需要自己爬。找到 5 类可用资源：

### 1. GitHub Trending RSS（核心数据源，免费可用）

| 服务 | 仓库 | 更新频率 | 数据字段 | 状态 |
|---|---|---|---|---|
| **isboyjc/github-trending-api** | [GitHub](https://github.com/isboyjc/github-trending-api) | 每 15 分钟 | stars, forks, addStars(今日新增), language, contributors | ✅ 推荐 |
| mshibanami/GitHubTrendingRSS | [GitHub](https://github.com/mshibanami/GitHubTrendingRSS) | 每日 | 标准 RSS 字段 | ⚠️ TrendRadar 已接入，但数据不如 isboyjc 丰富 |

**isboyjc 优势**：
- 提供每日/每周/每月三个维度
- 支持按编程语言过滤（python/typescript/rust/go 等）
- RSS item 里带 `addStars` 字段（当日/周/月新增 star 数），可以直接看出星增长速度
- 通过 `raw.githubusercontent.com` 访问，免费且稳定

**实测**（2026-07-03）：
- `daily/all.xml`：17 条，其中 12 条 AI 相关（70%）
- `weekly/all.xml`：可用，35KB
- 语言维度：python/typescript/rust/go 均可用

### 2. HuggingFace Daily Papers RSS（论文补充）

| 服务 | 仓库 | 更新频率 | 数据来源 |
|---|---|---|---|
| **huangboming/huggingface-daily-paper-feed** | [GitHub](https://github.com/huangboming/huggingface-daily-paper-feed) | 每日/周/月 | huggingface.co/papers |

- RSS：`https://raw.githubusercontent.com/huangboming/huggingface-daily-paper-feed/refs/heads/main/feed.xml`
- 提供论文标题、链接、作者、摘要、upvotes
- 正好补充 `frequency_words.txt` 的 `[论文与研究]` 词组

### 3. Awesome Lists（精选项目列表）

| 仓库 | Stars | 更新方式 | 频率 | 内容 |
|---|---|---|---|---|
| **linny006/awesome-agent-skills** | 10 | GitHub Actions 自动 | 每 15 分钟 | 100 个 AI agent skill 仓库，含 star 数 |
| **korchasa/awesome-ai-agents** | — | GitHub Actions 自动 | 不定期 | AI agent 工具框架列表，含 star 数和语言 |
| seb1n/awesome-ai-agent-skills | — | 人工 | 每月 1-2 次 | 90+ 技能，18 分类，SKILL.md 标准 |
| e2b-dev/awesome-ai-agents | 28.6k | 人工 | ❌ 已停更（2025-02） | — |

**问题**：这些 awesome list 都没有原生 RSS，只能订阅 GitHub commit atom feed。commit feed 噪音大（每次更新几十条 diff），不适合直接接入 TrendRadar。

**建议**：暂不接入，作为人工查阅参考。如果后续需要，可以写一个轻量脚本定期拉取 README diff，提取新增项目。

### 4. GitHub Releases Atom（特定项目版本发布）

GitHub 原生支持 `https://github.com/<owner>/<repo>/releases.atom`，可以追踪关键 AI 项目的版本发布。

推荐的 AI 项目 releases feed（待老板筛选）：

| 项目 | Atom Feed | 关注点 |
|---|---|---|
| openai/codex | `https://github.com/openai/codex/releases.atom` | Codex CLI 版本 |
| anthropics/claude-code | `https://github.com/anthropics/claude-code/releases.atom` | Claude Code 版本 |
| langchain-ai/langchain | `https://github.com/langchain-ai/langchain/releases.atom` | LangChain 框架 |
| langflow-ai/langflow | `https://github.com/langflow-ai/langflow/releases.atom` | Langflow 可视化 agent |
| microsoft/autogen | `https://github.com/microsoft/autogen/releases.atom` | AutoGen 多 agent |
| crewAIInc/crewAI | `https://github.com/crewAIInc/crewAI/releases.atom` | CrewAI |

---

## 二、推荐方案

### 方案：加 RSS 源 + 调关键词

**改动范围**：只改 TrendRadar 的 `config/config.yaml` 和 Xjiankong 的 `config/trendradar/frequency_words.txt`，零代码改动。

### 2.1 RSS 源改动（config.yaml）

#### 新增 RSS 源

```yaml
# GitHub Trending（替换现有 mshibanami，数据更丰富）
- id: "github-trending-daily"
  name: "GitHub 每日热榜"
  url: "https://raw.githubusercontent.com/isboyjc/github-trending-api/main/data/daily/all.xml"

- id: "github-trending-weekly"
  name: "GitHub 每周热榜"
  url: "https://raw.githubusercontent.com/isboyjc/github-trending-api/main/data/weekly/all.xml"

# HuggingFace 论文
- id: "hf-papers-daily"
  name: "HuggingFace 每日论文"
  url: "https://raw.githubusercontent.com/huangboming/huggingface-daily-paper-feed/refs/heads/main/feed.xml"

# 关键 AI 项目 Releases
- id: "release-openai-codex"
  name: "OpenAI Codex Releases"
  url: "https://github.com/openai/codex/releases.atom"

- id: "release-claude-code"
  name: "Claude Code Releases"
  url: "https://github.com/anthropics/claude-code/releases.atom"

- id: "release-langchain"
  name: "LangChain Releases"
  url: "https://github.com/langchain-ai/langchain/releases.atom"

- id: "release-langflow"
  name: "Langflow Releases"
  url: "https://github.com/langflow-ai/langflow/releases.atom"

- id: "release-autogen"
  name: "AutoGen Releases"
  url: "https://github.com/microsoft/autogen/releases.atom"

- id: "release-crewai"
  name: "CrewAI Releases"
  url: "https://github.com/crewAIInc/crewAI/releases.atom"
```

#### 删除/替换

- 删除现有的 `mshibanami` 源（`https://mshibanami.github.io/GitHubTrendingRSS/daily/all.xml`），用 isboyjc 替代

### 2.2 关键词改动（frequency_words.txt）

在 `[WORD_GROUPS]` 下新增一个 `[GitHub AI 项目]` 词组，专门匹配 GitHub trending 和 releases 中的 AI 相关项目：

```text
[GitHub AI 项目]
+/\b(?:AI|LLM|agent|skill|MCP|RAG|GPT|Claude|Gemini)\b/i
/\b(?:agent|skill|MCP|tool|framework|autonomous)\b/i
autogen
crewai
langchain
langflow
copilot
codex
@15
```

**逻辑**：
- 必须词（`+`）：标题必须包含 AI/LLM/agent/skill/MCP/RAG/GPT/Claude/Gemini 之一
- 普通词：标题包含 agent/skill/MCP/tool/framework/autonomous 或具体项目名
- 两条都满足才匹配，避免非 AI 的 GitHub 项目混入

---

## 三、数据流

```text
GitHub Trending (isboyjc)     ─┐
  daily/all.xml (17条/天)      │
  weekly/all.xml (25条/周)     │
                                ├─> TrendRadar RSS 抓取
HuggingFace Papers             │    → frequency_words.txt 过滤
  feed.xml (每日论文)           │    → AI 分析 + 翻译
                                │    → HTML 日报
GitHub Releases Atom           │
  openai/codex                 │
  anthropics/claude-code       │
  langchain-ai/langchain       │
  langflow-ai/langflow         │
  microsoft/autogen            │
  crewAIInc/crewAI             ─┘
```

---

## 四、验证清单

改完后执行：

```bash
# 1. RSS 源可达性
for url in \
  "https://raw.githubusercontent.com/isboyjc/github-trending-api/main/data/daily/all.xml" \
  "https://raw.githubusercontent.com/isboyjc/github-trending-api/main/data/weekly/all.xml" \
  "https://raw.githubusercontent.com/huangboming/huggingface-daily-paper-feed/refs/heads/main/feed.xml" \
  "https://github.com/openai/codex/releases.atom" \
  "https://github.com/anthropics/claude-code/releases.atom"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  echo "$code $url"
done
# 预期：全部 200

# 2. 容器内关键词解析
docker exec trendradar python3 -c "
from trendradar.core.frequency import load_frequency_words, matches_word_groups
wg, fw, gf = load_frequency_words('config/frequency_words.txt')
print(f'Word groups: {len(wg)}')
for g in wg:
    print(f'  - {g.get(\"display_name\")}: max={g.get(\"max_count\")}, required={len(g[\"required\"])}, normal={len(g[\"normal\"])}')
"

# 3. 重启后检查 RSS 抓取日志
docker restart trendradar
sleep 60
docker logs trendradar --tail 50 2>&1 | grep -E 'RSS|github|trending|papers|releases'
```

---

## 五、风险与注意事项

### 5.1 GitHub Trending 全语言包含非 AI 项目

`daily/all.xml` 里会有健身数据集、非 AI 工具等。靠 `frequency_words.txt` 的 `[GitHub AI 项目]` 词组过滤，必须词约束确保只保留 AI 相关的。

**如果噪音太多**：可以改用语言维度的 feed（如 `daily/python.xml`），AI 项目在 Python 里占比更高。

### 5.2 isboyjc 仓库的稳定性

isboyjc 由个人维护，GitHub Actions 每 15 分钟跑一次。如果 Actions 配额用完或仓库被删，feed 会停止更新。

**缓解**：
- 保留 mshibanami 作为备份源（设 `enabled: false`），isboyjc 挂了可以快速切换
- 或者自建一个类似的 GitHub Actions 仓库（脚本很简单）

### 5.3 Releases Atom 的噪音

releases.atom 每次发布都会推送，包括 patch 版本。如果某个项目发版频繁（如 LangChain），可能会刷屏。

**缓解**：靠 `max_news_per_keyword: 5` 限制每个词组最多显示 5 条，或在 frequency_words.txt 里用 `@N` 限制。

### 5.4 HuggingFace Papers 的语言

HuggingFace 论文是英文的，TrendRadar 的 `ai_translation` 会自动翻译 RSS 标题，但摘要部分可能不翻译。

---

## 六、不在本方案范围内的事

以下内容暂不做，记录备查：

1. **自建 GitHub Trending 爬虫**：isboyjc 够用，不自建
2. **Star 增长趋势追踪**：isboyjc 的 `addStars` 字段已包含当日新增 star 数，够用；如果需要历史趋势，用 OSS Insight 或 star-history.com
3. **Awesome List 的 commit feed**：噪音大，暂不接入
4. **GitHub Topics API**：需要 token，且 TrendRadar 的 RSS fetcher 不支持 API 调用
5. **npm/PyPI 包发布追踪**：不在本项目目标范围内
