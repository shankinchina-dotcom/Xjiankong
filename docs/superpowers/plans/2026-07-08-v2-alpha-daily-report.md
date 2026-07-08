# Xjiankong v2-alpha 实施计划

> 基于设计：[2026-07-08-v2-alpha-daily-report-design.md](../specs/2026-07-08-v2-alpha-daily-report-design.md)
>
> 状态：**已完成（2026-07-08）**。Task 1-7 全部通过，本地 v2-alpha 验证完成。生产同步未执行，需另起计划。
>
> 范围：本地验证。不碰 NAS、不改 Docker Compose、不新增数据源。

## 硬约束

1. **SourceRef / source_map 不作持久化**。仅作为 AI 分析模块（`trendradar/ai/`）内的单次报告运行时数据，不改 storage schema，不写 SQLite，不影响历史数据结构。
2. **第一轮验证只做免费 fixture 测试**。构造假 `AIAnalysisResult` + `source_map` + 含 `source_id` 的字段，直接验证 `render_ai_analysis_html_rich()` 能生成 8 板块、正确替换 `source_id`、生成来源索引、escape 标题、过滤非 http/https URL。此轮通过后，再考虑 Task 7 付费单次 AI 验证。
3. **所有改动在 TrendRadar fork**：`/Users/shankluo/AI/Claude/TrendRadar`。不误改 Xjiankong 仓库（`/Users/shankluo/AI/Claude/Xjiankong`）内的同名文档或模板。
4. **实施前检查 TrendRadar fork 的 git 状态**。保留既有未提交改动；只改本次范围内文件，不清理、不回滚、不顺带提交旧输出。
5. **建议为 TrendRadar 创建独立分支或 worktree** 执行 v2-alpha，避免污染当前运行配置工作区。
6. **Task 6/7 本地运行产物默认不提交**。`output/` 下的 db、html 等验证产物不进入 git；如需保留，只作为验证记录写入文档。
7. **生产同步不在本轮**。NAS 上传、重建容器、公网验收全部不在本轮范围，必须另起计划并再次确认。
8. **文件路径使用项目根相对路径**（TrendRadar fork 内）：
   - `trendradar/ai/analyzer.py`
   - `trendradar/ai/formatter.py`
   - `trendradar/report/html.py`
   - `config/ai_analysis_prompt.txt`
   - `config/config.yaml`

## 常规约束

- 每个步骤完成后跑 `python -c "import trendradar"` 确保无导入错误。

---

- [x] **Task 1: 数据结构和 source_id fixture 测试（免费）** ✅ `8576f245`

1. 在 `ai/analyzer.py` 新增 `SourceRef` dataclass，`AIAnalysisResult` 新增 `daily_judgment`、`research_breakthroughs`、`product_tools`、`source_map` 四个字段（均有默认值）。
2. 不删 `core_trends` 和 `standalone_summaries`，保留旧字段空字符串默认值。
3. 构造 fixture：`tests/fixtures/v2_alpha_fixture.py`，包含一个完整的 `AIAnalysisResult` 实例，含 7 个板块文本（含 source_id 引用）和 `source_map`（含 5 条 SourceRef）。
4. 运行 fixture 测试：`python tests/fixtures/v2_alpha_fixture.py` 确认 `AIAnalysisResult` 实例化无报错、`source_map` 键值正确。

验证：`python -c "from trendradar.ai.analyzer import SourceRef, AIAnalysisResult; r = AIAnalysisResult(); assert r.source_map == {}; assert r.daily_judgment == ''"` 通过。

- [x] **Task 2: Prompt 重写（免费）** ✅ `df093a04`

1. 重写 `config/ai_analysis_prompt.txt`：
   - system prompt：AI 行业首席分析师 persona + 输出规则 + 数据解读指南
   - user prompt：7 个 JSON key（source_index 不在内）+ 每条输出格式要求（结论先行、来源引用 source_id、无数据写 `暂无高置信信号`）
   - X 观点板块明确限定只分析 `source_id` 前缀为 `R<n>.nitter-` 的条目
   - 含 2-shot 示例（一好一坏）
2. 验证：`python -c "open('config/ai_analysis_prompt.txt').read(); print('loaded OK')"` 通过。

- [x] **Task 3: analyzer 解析与 source_map 注入（免费）**

1. `_prepare_news_content()` 中为每条输入生成 `source_id`（格式 `H<seq>.<platform>.<hash6>` / `R<seq>.<feed_id>.<hash6>`），构建 `SourceRef` 并存入 `source_map`。在 Prompt 文本中每条前追加 `[source_id: xxx]`。
2. `_parse_response()` 新增 7 个键的提取逻辑，所有键 optional（缺失默认为 `""`）。
3. `analyze()` 中：将 `source_map` 和 `_parse_response()` 结果一起存入 `AIAnalysisResult`。
4. 验证：运行 `python tests/fixtures/v2_alpha_fixture.py` 确认 source_map 数据流正确。

- [x] **Task 4: HTML renderer + CSS（免费）**

1. 重写 `render_ai_analysis_html_rich(result)`：
   - 8 面板布局：全宽 executive summary + 2 列 judgment grid + 可折叠来源索引
   - 扫描 7 个文本板块，正则匹配 `source_id`，从 `result.source_map` 查出对应 `SourceRef`
   - 标题 HTML escape 后拼入 `<a href="url">title</a>`（仅 `http://` / `https://` 协议生成链接）
   - 来源索引由代码根据 `source_map` + 被引用到的 `source_id` 自动生成，按板块分组
2. `report/html.py` 新增 v2 CSS 类：`.ai-executive-summary`、`.ai-judgment-card`、`.ai-judgment-card.empty`、`.ai-source-index` + 暗色模式适配。
3. 验证：编写 fixture 渲染测试 `python tests/test_v2_render.py`，确认 fixture 数据生成正确 HTML 结构 + source_id 被替换为 `<a>` 链接。

- [x] **Task 5: region_order 显式配置（免费）**

1. `config/config.yaml`：`display.region_order` 列表中将 `ai_analysis` 移至首位。
2. `report/html.py`：同步修改 `default_region_order`（兜底默认值）。
3. 验证：`grep -A6 "region_order" config/config.yaml` 确认 `ai_analysis` 在首位。

- [x] **Task 6: 免费回归验证（免费）**

1. 在本地跑 TrendRadar 但不调 AI（mode 或 dry-run），确认：
   - RSS 抓取正常（不与 AI 分析冲突）
   - 热榜采集正常
   - 无 import error、无 config parse error
2. 验证 html.py 旧代码路径未断：未传 `source_map` 时旧 `AIAnalysisResult` 仍正常渲染（向后兼容）。
3. 验证旧频道 formatter（飞书/Telegram）引用旧 6 字段不崩溃，新字段被静默忽略。

- [x] **Task 7: 付费单次 AI 验证闸门** ⚠️

> **执行前必须获得老板确认。** 调用 deepseek flash API，费用几分钱。

1. 本地跑一次完整 `python -m trendradar`，确认：
   - AI 返回有效 JSON，7 个 key 均有内容或 `暂无高置信信号`
   - HTML 报告生成成功，8 板块布局正确
   - source_id 被替换为可点击 `<a>` 链接
   - 来源索引自动生成，条目可点
2. 打开 HTML 报告，确认 3 分钟可读性。

- [x] **Task 8: 文档更新** ✅ 本 commit

1. 更新 `docs/superpowers/specs/2026-07-08-v2-alpha-daily-report-design.md` 状态为「本地验证通过」。
2. 更新 `AGENTS.md` 和 `ai-intelligence-hub-design.md` 状态，标注 v2-alpha 验证结果。
3. 质量检查 + git commit。

---

## 验证总览

| 阶段 | 费用 | 验证内容 |
|------|------|----------|
| Task 1-5 | 免费 | 数据结构、Prompt、解析、渲染、配置 |
| Task 6 | 免费 | 旧路径向后兼容、频道 formatter 不崩溃 |
| Task 7 | ~几分钱 | 完整 AI 调用、端到端 HTML 报告 |
| Task 8 | 免费 | 文档同步 |

生产同步（NAS 文件上传 + 手动触发 + 公网验收）另起独立实施计划。

---

## Task 7 验证结果

| 项目 | 值 |
|------|-----|
| 模型 | deepseek/deepseek-v4-flash |
| 费用 | 几分钱，1 次 API 调用 |
| 报告路径 | `output/html/2026-07-08/20-51.html` |
| AI section 位置 | body 中第一个 section |
| 8 板块 | 8/8 全部存在 |
| source_id 链接 | 44 个 |
| 来源索引 | 存在 |
| 暂无高置信信号 | 有空板块正确显示 |
| output 提交 | 未提交 |

## 后续增强：AI HOT 风格情报展示层

v2-alpha 保持「AI 行业每日研判报告」8 板块为核心，不把 AI HOT 五分类替代为分析框架。

AI HOT 可作为后续 v2-beta 的信息展示层参考，用于在核心研判之后展示「过去 24 小时精选情报」。建议五类为：

1. 行业动态
2. 模型发布/更新
3. 产品发布/更新
4. 论文研究
5. 技巧与观点

页面顺序建议：

1. AI 行业每日研判报告（8 板块核心分析）
2. 过去 24 小时精选情报（AI HOT 风格卡片流）
3. 原始来源索引 / 全部来源

实现原则：

- 五分类只作为信息展示标签，不替代 8 板块研判结构。
- 每条精选情报仍由本地 SourceRef/source_map 溯源。
- source_map 仅单次运行时存在，不持久化。
- URL 继续只允许 http/https。
- 不信任 AI 生成的标题或链接，展示内容优先使用本地抓取数据。
- v2-beta 如需接入 AI HOT 或新增数据源，必须另起设计和实施计划。

## 遗留注意事项

- `config/frequency_words.txt`：遗留修改，未触碰，未提交
- `docker/.env`：遗留修改，未触碰，不提交
- `output/`：历史/验证产物，不提交
- `__pycache__/`：不提交
