# Xjiankong v2.0 设计方案：AI 行业多维情报系统

> 状态：设计完成，待确认实施。
>
> 设计日期：2026-07-07。

## 一、问题诊断

当前 v1.1 系统已实现 61 个数据源采集 + AI 分析 + 翻译，但用户感知价值低。根因：

- **输出是标题列表，不是结论**。用户需要逐条阅读 700+ 条目才能提取有用信息。
- **AI 分析 Prompt 是通用新闻模板**（舆论风向、热点态势），不是 AI 行业专业分析。
- **数据源以国内热榜为主**，缺少论文、产品、开源项目等 AI 行业核心信息维度。

参考站点（智谱 Coding 状态播报）的做法：极致聚焦一个主题 → 从多源数据中提炼判断结论 → 给出决策支撑。

## 二、核心改造：AI 分析 Prompt 重构

当前 TrendRadar `config/ai_analysis_prompt.txt` 定义了 6 个通用新闻分析板块。v2.0 将其替换为 AI 行业的 6 个专业维度：

```
板块映射：
  core_trends           → 研究突破（模型/论文/技术）
  sentiment_controversy → 产品与工具（新品/更新）
  signals               → 开源项目（新项目/快速上升）
  rss_insights          → 行业动态（融资/合作/政策）
  outlook_strategy      → X 大佬观点（技术洞察/趋势判断）
  standalone_summaries  → 下周关注（事件日历）
```

每个维度输出 3-5 条结论，每条包含：一句话结论 + 支撑信息 + 影响标记（🟢利好/🔴风险/🟡待观察）。

这是 v2.0 的核心价值提升——不改架构、不加容器、不改代码，只改一个 Prompt 文件。

## 三、数据源扩展（全免费，不改代码）

TrendRadar 的 RSS 解析器基于 `feedparser`，天然支持 RSS 2.0 / Atom / JSON Feed。新增以下源只需在 `config/config.yaml` 的 `rss.feeds` 中追加 YAML 条目：

| 类别 | 源名 | URL | 格式 |
|------|------|-----|------|
| AI 论文 | arxiv AI | `https://rss.arxiv.org/rss/cs.AI` | Atom |
| AI 论文 | arxiv NLP | `https://rss.arxiv.org/rss/cs.CL` | Atom |
| AI 论文 | arxiv ML | `https://rss.arxiv.org/rss/cs.LG` | Atom |
| AI 产品 | Product Hunt AI | `https://www.producthunt.com/topics/artificial-intelligence/feed` | RSS |
| 中文社区 | V2EX AI | `https://www.v2ex.com/feed/ai.xml` | RSS |

这些是标准 RSS/Atom，TrendRadar 零代码修改即可消费。

## 四、小红书接入方案

60s API（`60s.viki.moe/v2/xiaohongshu?encoding=json`）免费、无需 Cookie、返回 JSON 热搜。

接入方案：在 NAS TrendRadar 容器内部署一个极简 Python 脚本（约 30 行），cron 定时调用 60s API → 生成标准 RSS 2.0 XML 文件 → TrendRadar 通过 `file://` RSS 源读取。不增新容器，不改 TrendRadar 源码。

备选方案：RSSHub 自建（需定期更新 Cookie，维护成本高），作为降级方案。

## 五、公众号/微信

调研结论：**不可行**。搜狗微信搜索已关闭，RSSHub 微信路由需认证号 Cookie 且极不稳定。从 v2.0 范围中剔除。

## 六、GitHub 项目发现增强（v2.1 规划）

GitHub Topics 页面（如 `github.com/topics/llm`）没有 Atom feed。增强方案需写自定义 Python 爬虫调用 GitHub Search API（免费 10 次/分钟），不是纯配置变更，因此划入 v2.1：

- GitHub Search API：按 topic + stars 排序发现高星 AI 项目
- OSSInsight API：追踪重点仓库的 star 增长曲线
- 保留现有的 Trending RSS + agents-radar + Release feed

## 七、架构总览（不变更 NAS 拓扑）

```
                    ┌── arxiv RSS（新增 3 源）
                    ├── Product Hunt RSS（新增）
                    ├── V2EX RSS（新增）
 61 个数据源 ────→  ├── 小红书 60s API → RSS 桥接（新增）
                    ├── Nitter X 30 源（保留）
                    ├── GitHub 10 源（保留）
                    └── 国内热榜 11 源（保留）
                           │
                           ▼
                    TrendRadar 采集 + 关键词过滤
                           │
                           ▼
                    AI 分析（6 维度 Prompt，重写）
                           │
                           ▼
                    AI 翻译（保留）
                           │
                           ▼
                    HTML 日报 → report-web → Cloudflare Tunnel
```

**不新增容器，不改 Docker Compose，不改 TrendRadar 源码。** 只改配置文件。

## 八、涉及修改的文件

| 文件 | 变更 | 位置 |
|------|------|------|
| `ai_analysis_prompt.txt` | 重写为 6 维度 AI 行业 Prompt | TrendRadar fork `config/` |
| `ai_interests.txt` | 更新 AI 关注领域描述 | TrendRadar fork `config/` |
| `config.yaml` | 追加 5 个 RSS 源 | TrendRadar fork `config/` |
| `config.yaml` | 同步 RSS 源到 NAS | NAS `/volume1/docker/trendradar-nas/config/` |
| `ai_analysis_prompt.txt` | 同步 Prompt 到 NAS | NAS `/volume1/docker/trendradar-nas/config/` |
| 小红书桥接脚本 | 新增 30 行 Python | NAS TrendRadar 容器内 |

## 九、验收标准

1. 新 RSS 源在 NAS 上 curl 测试全部返回 HTTP 200
2. AI 分析输出包含 6 个维度（研究突破 / 产品工具 / 开源项目 / 行业动态 / X 大佬观点 / 下周关注）
3. 每个维度有 3-5 条带结论的分析
4. 公网报告可读性明显提升
5. 微信公众号明确标记为"不可行"，不进入后续规划
