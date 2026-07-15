# V4 编辑型情报报告 UI 设计

> 状态：**老板已确认视觉方向；Codex 最终复审通过；本地代码 `18c1fbad`；本地 RC `v2-beta-v4-rc-20260715` 已构建并通过一次性容器免费验证；尚未访问 NAS、尚未部署生产。**
>
> 权威视觉原型：[`../prototypes/2026-07-15-xjiankong-report-v4-editorial.html`](../prototypes/2026-07-15-xjiankong-report-v4-editorial.html)。原型仅用于视觉和结构裁定，不得直接复制其中的模拟新闻、固定统计或来源编号进入生产。

## 一、目标

把当前 v2-beta 深空报告从“并列的 Hero + 01 核心判断”调整为更明确的编辑型层级：

```text
今日研判总览（父层）
├── 当日主结论
├── 真实指标
├── J1 / J2 / J3 三条判断索引
└── 01 证据验证与置信度（子层）
    ├── J1 完整判断与信源
    ├── J2 完整判断与信源
    └── J3 完整判断与信源

02–08 其他报告章节（与父层并列）
```

V4 的重点不是换一组颜色，而是让用户一眼看出“总览包含三条判断，01 负责验证这三条判断”。

## 二、已确认的视觉裁定

1. 保留深色情报报告骨架、左侧章节导航、历史抽屉、RSS 更新区与 8 章节。
2. 主色收敛为深空蓝、青灰、近白和单一亮蓝；不用彩虹数字。
3. 圆形 emoji 徽章大幅减少；生产继续优先使用现有单色线性 SVG。
4. Hero 缩短，主结论桌面目标为 2–3 行；不使用关键词下划线。
5. 指标值使用近白色，只有一个最重要指标可使用亮蓝强调。
6. 左侧导航目标宽度约 208px；active 状态使用细蓝竖线和轻背景，不形成第二内容栏。
7. 减少框套框：章节保留外层边界，内部判断使用分隔线和轻底色。
8. 顶栏只保留必要状态；历史入口低权重，状态不堆叠多枚彩色胶囊。
9. `今日研判总览` 与 `01 证据验证与置信度` 必须位于同一个 `.judgment-suite` 容器内。
10. J1–J3 在总览与证据层一一映射；不得再用两个视觉相近的独立模块重复完整正文。

## 三、生产数据映射

### 3.1 不改变数据源

- 主结论和 J1–J3 仍来自 `AIAnalysisResult.daily_judgment`；为空时回退 `core_trends`。
- 引用链接仍从本地 `source_map` 生成，继续走 `_web_source_link()` 与 `_web_panel_content()` 的转义和 URL 白名单。
- 热榜、RSS、来源数、板块数和今日版本必须使用现有真实派生数据，不写模拟值。
- 不修改 AI Prompt、AI 返回 schema、数据库、历史 manifest 或邮件渲染器。

### 3.2 判断索引生成

- 把 `daily_judgment` 规范化为非空行，移除行首列表符号，仅取前三条作为 J1–J3。
- 总览层显示每条判断的短标题；证据层显示完整判断及来源。
- 短标题只能从原判断文本派生，不允许模型外二次补写事实。
- 实际不足三条时只渲染现有条目；不得补虚构的 J2/J3。
- 多于三条时，总览只显示前三条，01 的完整正文仍保留全部内容，避免丢失信息。

## 四、生产代码边界

活动实现仓库与 worktree：

```text
/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history
branch: codex/v2-beta-history
baseline HEAD: 61ba393225de1b6d9d165a1dcddc189073f3e2d6
```

预计只修改：

| 文件 | 职责 |
|---|---|
| `trendradar/ai/formatter.py` | J1–J3 派生、`.judgment-suite` 结构、01 证据映射；只影响网页 renderer |
| `trendradar/report/html.py` | 所有 V4 CSS，必须限定在 `body.deep-space-report` 下；保留现有历史抽屉脚本和安全逻辑 |
| `tests/fixtures/v2_beta_deep_space_ui.py` | 结构、转义、邮件隔离、无障碍与响应式契约 |

默认不修改：`generator.py`、`context.py`、Dockerfile、Compose、Nginx、Cloudflare、AI Prompt、邮件 renderer。

## 五、不得回归的能力

- `render_ai_analysis_html_rich()` 输出保持不变。
- AI 失败／跳过时仍使用安全的深空 shell，不强行生成 J1–J3。
- 外部 AI 文本和来源字段继续 HTML escape；来源 URL 只允许 `http://`／`https://`。
- Nitter 来源继续生成 X 原文 fallback。
- 历史抽屉保留 `dialog`、`aria-modal`、`inert`、焦点进入、Tab 循环、关闭回焦和 `reduced-motion`。
- 390px 页面级横向滚动为 0；触控面积不低于已通过 Gate 9.1 的标准。
- 仍精确渲染 8 个 `report-section`；01 计入 8 章节，Hero 不计入。

## 六、验收标准

### 免费本地验收

1. fixture 全部通过，新增断言证明 `.judgment-suite` 直接包含 Hero 与 `report-section-01`。
2. 总览与 01 均存在相同的 J1–J3 映射；不足三条的 fixture 不产生空占位。
3. 1280px、768px、573px、390px 浏览器检查无页面级横向滚动。
4. 573px 首屏可识别“总览 → 三条判断 → 证据层”关系。
5. 浏览器控制台无错误；历史抽屉三种关闭路径和焦点行为继续通过。
6. 普通非 AI HTML 和邮件 HTML 的既有输出不变。

### 生产验收

1. 新镜像使用独立 RC 标签，不覆盖 `v2-beta-rc-20260713`。
2. 只重建 `trendradar`；`report-web`、`cloudflared`、`rss-proxy`、Nginx 和 Cloudflare 不变。
3. 免费静态／容器验收通过后，另行获得老板确认才允许触发一次付费报告生成。
4. 新报告包含 8 章节、`.judgment-suite`、J1–J3 映射、历史功能和来源链接。
5. 公网 `/`、`/history.json`、`/history.html` 和新快照为 200；敏感路径继续为 404。
6. 任一关键断言失败，回滚到 `xjiankong-trendradar:v2-beta-rc-20260713`，不得回退到更老的 v2-alpha，除非另有事故裁定。

## 七、当前边界与交接说明

- 实施 worktree 为 `TrendRadar-v2-beta-history`（`codex/v2-beta-history`）；V4 网页 renderer 本地提交 `18c1fbad`（相对基线 `61ba3932`）。本地 RC `xjiankong-trendradar:v2-beta-v4-rc-20260715` / `sha256:18d49e97f936…` / `linux/amd64` / 138,116,057 bytes；`RC_IMPORT_OK` 与扩展 `RC_CONTAINER_OK` 通过，无残留验证容器。旧生产回滚基线仍为 `v2-beta-rc-20260713`。
- Codex 最终复审通过（证据单次渲染、208px 桌面导航、统一 metrics、history-page-notice 在 suite 外、reduced-motion、chip 44px、四视口与历史抽屉验收）。**尚未访问 NAS、付费调用或部署生产**；后续按实施计划 Task 6+ 逐闸门确认。
- `/Users/shankluo/AI/Claude/TrendRadar` 主 worktree 位于 `v2-alpha` 且有多项用户修改，禁止在该 worktree 实施 V4。
- 实施入口见 [`../plans/2026-07-15-v4-editorial-report-production.md`](../plans/2026-07-15-v4-editorial-report-production.md)。
