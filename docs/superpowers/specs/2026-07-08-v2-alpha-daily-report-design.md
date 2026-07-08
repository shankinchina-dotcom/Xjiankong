# Xjiankong v2-alpha 设计方案：AI 行业每日研判报告

> 状态：本地验证通过（2026-07-08）。UI 视觉收口已完成；生产同步未执行，需按独立计划逐闸门确认。
> 设计日期：2026-07-08。
>
> 验证报告：`output/html/2026-07-08/20-51.html`（本地 TrendRadar fork）
> 模型：deepseek/deepseek-v4-flash · 费用：几分钱 · source_id 链接 44 个 · 8/8 板块存在
> 最终 TrendRadar 基线：`v2-alpha` HEAD `33d80973`
> 范围：**本地 v2-alpha 验证**。生产环境同步作为独立后续阶段，不在本轮范围。

## 一、目标

将日报从"新闻标题聚合列表"升级为**AI 行业首席分析师风格的研判报告**。用户 3 分钟内读完当天最值得关注的结论。

改造范围（仅 4 项）：
1. **Prompt**：重写 `ai_analysis_prompt.txt`，8 板块研判结构
2. **AIAnalysisResult schema**：扩展 dataclass，新增 4 字段
3. **HTML rich renderer**：重写 `render_ai_analysis_html_rich()`，研判卡片布局
4. **显示顺序配置**：修改 `config.yaml` 中 `display.region_order` 显式配置（仅改 `default_region_order` 代码常量不生效，当前生产配置已显式指定 `region_order`）

不动采集链路、不碰 NAS、不改 Docker Compose。通知渠道（飞书/Telegram/钉钉等）不在 v2-alpha 范围。

## 二、8 板块研判结构

| # | 板块 | JSON key | 说明 |
|---|------|----------|------|
| 1 | 今日核心判断 | `daily_judgment` | 全宽摘要卡片，3-5 条结构化结论。每条 30-50 字，覆盖当日最重要的 3-5 个信号，按重要性排序。AI 不足 3 条时输出已有条目 + 「其余维度暂无高置信信号」 |
| 2 | 研究/模型突破 | `research_breakthroughs` | 新模型/论文/基准测试/技术方向 |
| 3 | 产品与工具变化 | `product_tools` | 新品发布/重大更新/定价变化/API 弃用 |
| 4 | 开源项目与开发者生态 | `opensource_ecosystem` | 新星项目/重要 Release/社区动向 |
| 5 | 大厂/融资/政策/算力动态 | `bigtech_policy` | 战略动作/融资/监管/算力供应链 |
| 6 | X 关键人物观点 | `x_insights` | 追踪账号的技术洞察与趋势判断 |
| 7 | 风险与下周关注 | `risk_outlook` | 新兴风险/即将发生的事件 |
| 8 | 原始来源索引 | 代码生成 | 根据 source_map + AI 引用的 source_id 自动构建可折叠来源列表，不由 AI 输出 |

## 三、来源索引机制：稳定 source_id

### 3.1 设计原则

AI 不能自由编造来源。v2-alpha 在 Prompt 中向 AI 暴露一个预生成的稳定 source_id 映射表，AI 在输出中只引用 source_id，HTML 渲染时由代码反向解析为可点击链接。

### 3.2 source_id 格式（本次报告内稳定枚举 ID）

source_id 的格式为：`类型前缀 + 递增序号 + 来源标识 + 内容短 hash`。rank/item_index 不作为唯一性依据——它们可能为空、重复或随抓取顺序变化。短 hash 取标题或 GUID/URL 的 SHA-256 前 6 位。

```
热榜条目：H<seq>.<platform_id>.<title_sha256_6>
 例：H001.zhihu.a3f2b1 → 知乎热榜某条目

RSS 条目：R<seq>.<feed_id>.<guid_or_url_sha256_6>
 例：R014.nitter-openai.e7d9c2 → Nitter OpenAI RSS 某条目

论文来源：A<seq>.arxiv.<paper_id>
 例：A003.arxiv.2507.01955
```

`rank`、`feed_id`、`title`、`url` 完整保留在 `SourceRef` 元数据中，不作为 source_id 的唯一性依赖。

### 3.3 实现方式：source_map 闭环数据流

核心原则：**AI 只引用 source_id，不生成来源内容。来源索引由代码根据 source_map 自动构建。**

```
_prepare_news_content()
    │
    ├── 为每条输入生成 source_id
    ├── 构建 source_map: {source_id: SourceRef}
    │     SourceRef { id, type, feed_id, title, url, rank }
    │
    ├── 将 source_id 注入 Prompt（每条输入前加 [source_id: xxx]）
    ├── 将 source_map 随 prepared_data 返回
    │
    ▼
analyzer.analyze()
    │
    ├── AI 在输出中引用 source_id（如 [来源: hotlist:zhihu:3, rss:nitter-karpathy:2]）
    ├── AI 不输出 source_index 字段（该字段不由 AI 生成）
    │
    ├── _parse_response() 解析 AI 返回的 7 个文本字段
    ├── 从 prepared_data 中取出 source_map，存入 AIAnalysisResult.source_map
    │
    ▼
render_ai_analysis_html_rich(result)
    │
    ├── 扫描所有 7 个文本板块，正则提取被引用的 source_id
    ├── 从 result.source_map 中查出对应的标题和链接
    ├── title 做 HTML escape 后再拼入 href
    ├── URL 只允许 http:// 和 https:// 协议，其他协议不生成链接
    ├── 将 source_id 替换为可点击链接（如 [知乎热榜 #3](url)）
    ├── 自动生成 08 原始来源索引（按板块分组列出被引来源）
    └── source_index 完全由代码生成，不依赖 AI 输出
```

### 3.4 数据结构定义

```python
@dataclass
class SourceRef:
    source_id: str       # "H001.zhihu.a3f2b1"
    type: str            # "hotlist" | "rss" | "arxiv"
    feed_id: str         # "zhihu" | "nitter-openai" | ...
    title: str           # 新闻/RSS 标题（需 HTML escape 后使用）
    url: str             # 可点击链接（仅 http/https 协议）
    rank: int = 0        # 热榜排名或 RSS 条目索引（放在元数据，不作为唯一 ID）
    hash6: str = ""      # 内容 SHA-256 前 6 位

# AIAnalysisResult 新增字段：
source_map: Dict[str, SourceRef]  # 所有可能被引用的 source 映射
```

### 3.5 Prompt 设计原则

1. **结论先行**：每条以一句话判断开头，不是话题描述
2. **来源追溯**：每条结尾 `[来源: source_id]`，source_id 由系统预生成，AI 只负责引用
3. **承认未知**：数据不足时输出 `暂无高置信信号`，不编造
4. **去重复**：同一话题只出现在最相关的板块

**输出示例（好的）**：
```
DeepSeek V4 在数学推理 benchmark 上首次超越 GPT-5，标志中国团队在推理能力上实现里程碑式追赶，但代码能力仍有 12% 差距。 [来源: H003.zhihu.a3f2b1, R014.nitter-karpathy.e7d9c2]
```

## 四、Persona 设计

当前：`高级情报分析师`（描述式分析）
v2-alpha：`AI 行业首席分析师（Chief AI Industry Analyst）`

核心理念转变：从"今天发生了什么"→"这意味着什么"→"我该关注什么"

## 五、JSON 字段映射

### 5.1 AI 输出的 7 个 Prompt key（AI 负责生成）

| Prompt key | Python 字段 | 状态 |
|------------|------------|------|
| `daily_judgment` | `daily_judgment` | **新增** |
| `research_breakthroughs` | `research_breakthroughs` | **新增** |
| `product_tools` | `product_tools` | **新增** |
| `opensource_ecosystem` | `signals` | 语义替换 |
| `bigtech_policy` | `sentiment_controversy` | 语义替换 |
| `x_insights` | `rss_insights` | 语义替换 |
| `risk_outlook` | `outlook_strategy` | 语义替换 |

### 5.2 代码生成的 2 个字段（不由 AI 输出）

| Python 字段 | 生成方式 |
|-------------|----------|
| `source_map` | `_prepare_news_content()` 生成，存入 `AIAnalysisResult` |
| 来源索引 HTML | `render_ai_analysis_html_rich()` 根据 `source_map` + AI 引用到的 `source_id` 自动构建 |

旧 `core_trends` 和 `standalone_summaries` 字段保留在 dataclass 中但不从 v2 prompt 提取，默认空字符串——向后兼容旧格式。

### 5.3 X 观点来源隔离

`x_insights` 板块的 Prompt 必须明确：**只从 Nitter/X 账号 RSS 中提取观点**。实现方式：

- 在 source_map 中，所有 Nitter feed 标记 `type: "rss"` + `feed_id` 前缀 `nitter-`
- Prompt 指令：`x_insights 只分析 source 前缀为 rss:nitter- 的条目，不要将 Hacker News、GitHub Release、arXiv 等内容纳入本板块`
- 若当日无 X 相关高置信信号，输出 `暂无高置信信号`

## 六、HTML 改造

### 6.1 版面顺序调整

AI 分析区从**报告末尾**移到**报告顶部**（header 之后、热榜之前）。

**关键约束**：当前生产 `config.yaml` 已显式配置 `display.region_order`，仅改 `html.py` 中的 `default_region_order` 代码常量**不会生效**。必须同时修改两处：

1. **`config/config.yaml`**：将 `region_order` 列表中的 `ai_analysis` 移到首位
   ```yaml
   display:
     region_order:
       - ai_analysis      # ← 从末尾移到这里
       - hotlist
       - rss
       - standalone
   ```
2. **`report/html.py`**：同步修改 `default_region_order`（兜底默认值，配置缺失时使用）
   ```python
   default_region_order = ["ai_analysis", "hotlist", "rss", "new_items", "standalone"]
   ```

### 6.2 最终 UI 结构

```
┌─────────────────────────────────────┐
│ 报告全局头（浅色信息头）              │  ← 报告类型、生成时间、热榜/RSS/AI 统计
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ AI 行业每日研判报告 Hero              │  ← 深蓝低饱和主视觉、核心判断/引用来源计数
├─────────────────────────────────────┤
│ 01 今日核心判断（全宽摘要卡片）        │
├─────────────────────────────────────┤
│ 快速导航：研究/产品/开源/政策/X/风险   │
├──────────────────┬──────────────────┤
│ 02 研究/模型突破  │ 03 产品与工具变化  │  ← 高权重双卡
├──────────────────┴──────────────────┤
│ 05 大厂/融资/政策/算力动态            │  ← 宽卡突出
├────────────┬────────────┬───────────┤
│ 04 开源生态 │ 06 X 观点   │ 07 风险关注│  ← 紧凑三卡
├─────────────────────────────────────┤
│ 08 引用来源索引（可折叠 details）      │
├─────────────────────────────────────┤
│ 热榜/RSS 内容区（淡蓝渐变卡片体系）     │  ← 与 AI 分析区统一配色
└─────────────────────────────────────┘
```

### 6.3 新增 CSS

- `.ai-report-hero`：日报级 Hero，承载报告标题、定位语和核心指标。
- `.ai-executive-summary`：全宽摘要卡片，左侧强调线 + 淡蓝渐变底。
- `.ai-report-nav`：板块快速导航。
- `.ai-priority-layout`：按阅读权重排列 2-7 号面板。
- `.ai-judgment-card` / `.ai-feature-card` / `.ai-wide-card` / `.ai-compact-card`：研判卡片层级。
- `.ai-source-index`：可折叠引用来源索引。
- 热榜/RSS 旧区域统一为淡饱和蓝色系渐变卡片，避免与 AI 分析区割裂。
- 暗色模式适配

## 七、涉及修改的文件

| 文件 | 操作 | 说明 |
|------|------|------|
| `config/ai_analysis_prompt.txt` | **重写** | 7 板块 system + user prompt（source_index 由代码生成）+ source_id 引用规则 + X 来源隔离 |
| `ai/analyzer.py` | 新增 | `SourceRef` dataclass；`AIAnalysisResult` 新增 4 字段 + `source_map`；`_prepare_news_content()` 生成 source_map；`_parse_response()` 新增键提取 |
| `ai/formatter.py` | 重写 | `render_ai_analysis_html_rich()` → 8 面板布局 + source_id→链接解析 + 代码生成来源索引 |
| `report/html.py` | 修改 | `default_region_order` + v2 UI CSS + 全局头、热榜、RSS 配色统一 |
| `config/config.yaml` | 修改 | `display.region_order` 显式配置：`ai_analysis` 移至首位 |

## 八、不修改的文件

- 通知频道 formatter（飞书/Telegram/钉钉等）：不在 v2-alpha 范围。只保证不崩溃（旧 6 字段引用不变，新字段被静默忽略），不保证 v2 完整展示体验。v2-alpha 仅验收 HTML 报告
- `ai_interests.txt`：用于关键词过滤，非 AI 分析
- Docker Compose / 部署脚本：纯应用层变更，不碰容器

## 九、风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| Token 用量增加 ~30-50% | 高 | 成本 + 延迟 | deepseek flash 极便宜；设 `max_tokens=4096` |
| AI 输出不稳定（编造内容） | 中 | 高 | `暂无高置信信号` 锚定短语 + 后处理检查 |
| JSON 解析失败 | 中 | 中 | 新字段 optional（默认 ""），旧 JSON 修复机制兜底 |
| 新字段破坏下游消费者 | 低 | 低 | 所有新字段有默认值，旧 formatter 只读 6 个旧字段 |
| 报告过长 | 低 | 中 | 每面板限 150-200 字，总量 ~1500 字，3 分钟可读 |

## 十、本地验证步骤

> **闸门**：步骤 3（单次采集测试）涉及本地调用 AI 模型（deepseek flash），会产生几毛钱的 API 费用。执行前必须获得老板确认。

1. **语法检查**（免费）：`python -c "from trendradar.ai.analyzer import AIAnalysisResult; r = AIAnalysisResult()"` 确认新字段
2. **Prompt 渲染**（免费）：dry-run 检查变量替换、source_id 注入、JSON schema
3. **单次采集测试**（付费，需确认）：本地跑一次完整分析，检查 8 个字段输出 + source_id 溯源
4. **HTML 检查**（免费）：浏览器打开报告，验证全宽摘要 + 2 列网格 + 可折叠来源索引 + source_id 链接 + 暗色模式
5. **回归检查**（免费）：旧频道推送 formatter 仍正常工作

## 十一、实施顺序

1. 重写 Prompt 文件（零代码依赖，可独立 review）
2. 扩展 `AIAnalysisResult` + 更新 `_parse_response()` + `_prepare_news_content()` 注入 source_id
3. 重写 `render_ai_analysis_html_rich()`（8 面板布局 + source_id→链接解析）
4. 改 `config/config.yaml` 的 `display.region_order` + `report/html.py` 的 `default_region_order` + CSS
5. 老板确认后执行步骤 3（单次 AI 验证）
6. 本地验证通过后，**生产同步作为独立后续阶段**，不在本轮范围

## 十二、与 v2.0 方案的关系

v2-alpha 是 v2.0 中"AI 分析 Prompt 升级 + 报告展示优化"的细化和落地版本。与 v2.0 的差异：

- v2-alpha **专注**：Prompt + Schema + HTML + 显式配置，不碰采集链路
- v2-alpha **明确排除**：新数据源接入、小红书、GitHub Search API、通知渠道改造
- v2-alpha **新增**：source_id 稳定溯源机制（v2.0 未覆盖）
- v2-alpha **修正**：`display.region_order` 显式配置问题（v2.0 只提了默认值）
- v2.0 剩余项（数据源扩展、小红书接入、GitHub Search API）在 v2-alpha 本地验证通过后再推进
