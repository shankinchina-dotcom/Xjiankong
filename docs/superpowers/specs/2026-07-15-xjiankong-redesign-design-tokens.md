# Xjiankong AI 情报报告页 · 重构定制设计令牌（DESIGN.md）

> **文档用途**：本文件是「Xjiankong AI 情报报告页」重构的**设计令牌唯一来源**，直接供原型构建师（筑原型）消费。不写页面代码、不部署、不碰 NAS 生产环境。
> **基底**：继承 v2-beta 深空令牌（见 §2.1，不可丢弃）。
> **方向**：低饱和深色情报终端 + 多面板结构化状态丰富（Agent Orchestration 质感）。
> **需求锚点**：R1–R5 五个重构专项、贯穿性准则 A–D、老板三个结构性决定。
> **配套**：v2-beta 来源 `2026-07-10-v2-beta-deep-space-report-ui-design.md`、`2026-07-10-v2-beta-ui-visual-standards.md`（§2.1 / §4.1 / §九 为本文档继承与偏离基准）。

---

## 0. 候选设计系统推荐与选定

### 0.1 推荐对比表

| 方案 | 设计系统 | 匹配度 | 特征 | 适合原因 |
|------|---------|--------|------|---------|
| **A（选定基底）** | **Linear** | ★★★★★ | 低饱和深色、结构化面板、状态 capsule badge、克制蓝紫微光、密集有序 | 最贴近「Agent Orchestration / Agent 竞品」多面板低饱和仪表盘质感；深色底自带蓝紫微光，与深空蓝继承自然融合；其「状态 badge / 面板 / 编号」体系可直接映射本项目的 section-rail、capsule badge、report-section |
| B | **Raycast** | ★★★★☆ | 低饱和深色、面板化命令面板、等宽数据、状态丰富 | 更前倾的「面板 + 等宽数据」组织，对 RSS 等宽双栏（R5）与数据排版最友好；若后续要更强「命令面板」密度可切换 |
| C | **Warp** | ★★★☆☆ | 终端情报质感、等宽优先、深色 | 最「情报终端」字面感，但偏纯终端、弱于长报告可读性，且易触发 v2-beta 担心的「实时监控错觉」；仅作极端终端向备选 |

### 0.2 选定与取舍
- **选定基底：Linear**。理由：在「低饱和 + 多面板 + 状态 badge + 等宽数据 + 面板化」五个维度与老板北极星完全重合，其设计语言是 v2-beta 深空蓝的自然延伸（无需推翻底色）。
- **取舍**：Raycast 在「等宽数据 / 命令面板」更强，但作为长报告页基底，Linear 的「有序面板 + 编号 + 状态」更利于 8 章节连续阅读；Warp 终端感过强，易牺牲报告可读性，仅作备选。
- **融合方式**：以 Linear 的「低饱和面板 + 状态 badge + 等宽数据」为结构骨架，叠加 v2-beta 深空蓝基底（§2.1 原值）与 R4 跨色系低饱和辅助色 ⇒ **「Linear 结构 × 深空蓝底色 × 墨青/深紫/青灰层次」**。

### 0.3 继承与偏离声明（✅ 六处裁定 · 文档状态：已核准）
本重构在以下**六处**显式裁定（①–④ 为对 v2-beta 的偏离 / 授权偏离，⑤ 为老板授权局部高饱和装饰，⑥ 为背景去蓝化且明确非偏离），均已由老板裁定采纳（2026-07-15 初版 ①–④；V3 增量追加 ⑤⑥），令牌按裁定结论定稿：

1. **常驻侧栏（section-rail）**〔✅ 裁定①〕：v2-beta §3.1 / §九 曾否决常驻侧栏。本 R3 要求 ≥1024px 常驻。
   → **裁定采纳**：做成**左侧细导航轨（240px，仅章节索引 + 历史入口，非内容栏）**，报告正文仍是主列；768–1023 折叠为顶条、<768 折叠为抽屉——任何非 PC 宽度都不常驻，避免「研判被挤」。令牌已按此实现（见 §4.4）。
2. **彩色 emoji 系统图标**〔✅ 裁定②〕：v2-beta §4.2 / §九 曾否决彩色 emoji、改用单色线性 SVG。
   → **裁定采纳老板长期偏好**：**emoji 作为板块 / 区块主图标贯穿全站**（降噪 `filter:saturate(.82)`、`size≤18px`），不再退回纯 SVG。单色线性 SVG 降级为可选次级 / 强调图标（仅在 emoji 不适用的极个别场景补充）。令牌已按此实现（见 §3.1 / §4.11）。
3. **section-01 角色变更（R2）**〔✅ 裁定③〕：v2-beta 硬约束 §一.2 曾要求不改 8 板块框架。R2 将 hero 与 section-01 合并，section-01 改为「论证 / 证据支撑」。
   → **裁定采纳 R2**：保留 8 个 rail 条目与 01–08 编号秩序（不破坏框架结构），section-01 渲染为 hero 核心判断的「论证 / 证据支撑」子模块（evidence-stream 型，见 §4.9）。rail 标签保留 `01` 编号，标题可标「论证支撑」。
4. **大厂主题色强调板（用户反馈）**〔✅ 裁定④〕：v2-beta §7.1 红线曾禁高饱和红噪声；用户反馈「整体用色太均匀、缺重点层次」，要求用小红书/西门子/Apple 等大厂主题色突出重点。
   → **用户授权偏离**：新增 §2.9 大厂主题语义强调色（小红书红 `#FF2442` / 西门子青 `#009999` / Apple 蓝 `#0071E3` / 洞察金 `#c9a227`），仅作点状语义标记、禁大面积铺色、每屏强色 ≤3 处（§2.10）。小红书红作为用户明确授权的高饱和红语义强调，列为受控偏离，不触发 §7.1 红线（详见 §2.10「与 Anti-Slop 门控的协调」）。

5. **Hero 指标彩虹渐变（老板授权局部高饱和装饰）**〔✅ 裁定⑤〕：V3 在 `.hero-metrics` 6 项指标数值（核心判断 3 / 引用来源 32 / 热榜命中 5 / RSS 命中 91 / AI 板块 8 / 今日版本 3 版）上施加「赤橙黄绿青蓝紫」连续光谱文字渐变（方案 A，§2.11），作为全站唯一的局部高饱和装饰带。
   → **授权采纳**：彩虹**仅限 hero 指标带**，不外溢到正文数值 / 状态胶囊 / RSS 等宽数据；黄 / 橙段提亮至 `#f5d76e` / `#f0a868` 保证在 `#07111f` 上 ≥AA；该带豁免 §2.10「每屏强色 ≤3」语义强调配额（属装饰非语义标记，见 §2.13 风险裁定），但不得向正文区扩散。列为**第 5 条裁定**〔✅ 裁定⑤〕。
6. **背景青绿山水化（方案 X）**〔✅ 裁定⑥〕：V3 将页面根背景由「蓝→蓝」改为青绿山水多色过渡 `--bg-gradient-v3`（近黑→墨青绿→石绿→远山黛青，绿为主色调，蓝退为远山点缀），并将三层 radial 角光重配为墨青绿 / 石绿 / 秋意金系（绿主导 + 秋意金点缀，§2.1.1）。
   → **裁定采纳且明确非偏离**：背景彩色化**不破坏 §2.1 深空身份**——仍保留近黑角落锚点 `#07111f`、仍深色低噪、卡片反差仍由「底色 + 边框 + 轻投影」承载（§2.3 机制不变，见 §2.13 协调说明）；方案 X 与 §2.1 深空基底兼容，不触发 §7.1 反模式。列为**第 6 条裁定**〔✅ 裁定⑥〕。

> 其余 R1 / R4 / R5 与 v2-beta 不冲突：R1 栅格秩序 ≠ 同质卡片墙；R4 低饱和深空渐变 ≠ 被否决的紫横幅 / 绿滚动；R5 RSS 仍用蓝 / 低饱和体系，NEW 仍低噪非红。裁定④ 为新增的用户授权偏离（大厂主题色强调板），不冲突、仅扩展语义强调层；裁定⑤⑥ 为 V3 增量，⑤ 为局部装饰授权、⑥ 为兼容式背景升级，均不破坏深空身份。

---

## 1. Visual Theme（视觉主题）

**Philosophy**：一份可连续阅读的深空情报研判报告，披上「Agent 编排台」的多面板外壳——左 / 中 / 右分区清晰、状态胶囊明码、数据等宽陈列、面板化信息组织，但每一个数字与链接都真实。

**Direction**：`low-saturation · deep-space · panelized · status-rich · mono-data · structured-grid`

**Personality**：克制（restrained）、专业（precise）、有秩序感（ordered）、情报终端（terminal）、有设计感（designed）

**Reference**：Linear 深色面板体系（结构骨架） + v2-beta 深空蓝（底色） + Agent Orchestration 多面板仪表盘（北极星）

**反幻觉纪律（沿用 v2-beta 硬约束 §一.1）**：只展示真实数据（生成时间、版本数、热榜/RSS 命中、AI 8 板块、是否最新）；**禁止**信号强度 / 熵 / 升温冷却 / 话题簇图 / 昨日差分等无上游数据的伪指标。

---

## 2. Color Palette（色彩令牌）

> 所有色值以 HEX + CSS 变量双格式给出；状态 / 分类色提供「底色 tint + 文字」配对，统一低饱和、低噪。

### 2.1 继承基底（v2-beta 深空令牌，不可丢弃 — 原值）
| Token | HEX / 值 | 用途 |
|-------|---------|------|
| `--bg-base` | `#07111f` | 深空底色（页面根背景） |
| `--bg-field` | `#0c1c33` | 顶部径向信号场 |
| `--surface-report` | `rgba(17,39,70,.82)` | 连续报告主体面板 |
| `--surface-evidence` | `rgba(12,29,52,.76)` | 证据流 / RSS 面板 |
| `--surface-focus` | `linear-gradient(135deg, rgba(27,86,166,.58), rgba(21,52,106,.82))` | Hero / 当前版本高亮 |
| `--line-subtle` | `rgba(153,190,245,.18)` | 常规边界 |
| `--line-active` | `rgba(111,178,255,.55)` | hover / 当前状态 |
| `--text-primary` | `#edf5ff` | 主文字 |
| `--text-secondary` | `#9eb4d3` | 摘要、元信息 |
| `--accent-blue` | `#75b2ff` | 编号、链接、图标（v2-beta 亮蓝，保留作高可读强调） |
| `--accent-cyan` | `#a5d4ff` | 小范围高亮 |

### 2.2 背景跨色系低饱和渐变（R4 · 建立存在感，非寡淡同色）
| Token | 值 | 用途 |
|-------|----|------|
| `--bg-gradient` | `linear-gradient(160deg, #07111f 0%, #0a1729 42%, #0c1c33 100%)` | 页面根背景（深蓝→墨蓝，静态，非滚动） |
| `--bg-glow-ink` | `radial-gradient(120% 80% at 10% -5%, rgba(26,102,110,.30) 0%, rgba(7,17,31,0) 58%)` | 墨青角光（左上） |
| `--bg-glow-violet` | `radial-gradient(90% 70% at 94% 4%, rgba(75,63,115,.26) 0%, rgba(7,17,31,0) 55%)` | 深紫角光（右上，仅作低饱和点缀，**非紫横幅**） |
| `--bg-glow-slate` | `radial-gradient(100% 60% at 50% 102%, rgba(40,58,82,.28) 0%, rgba(7,17,31,0) 60%)` | 青灰底光（底部） |

> 三层 radial glow 叠加在 `--bg-gradient` 之上，使背景有跨色系存在感；角光均 ≤.30 透明度，绝不喧宾夺主。

### 2.1.1 V3 去蓝化背景层（方案 X · 裁定⑥）
> 老板 V3 决定：根背景由「蓝→蓝」改为青绿山水多色过渡（绿为主色调，蓝退为远山点缀），三层角光重配为墨青绿 / 石绿 / 秋意金系（绿主导 + 秋意金点缀）；**仍深色、低噪、不破坏 §2.1 深空身份**（裁定⑥）。原 `--bg-gradient` 与三层旧角光保留为**兼容注释**，新变量为 V3 权威值。

| Token | 值 | 用途 |
|-------|----|------|
| `--bg-gradient-v3` | `linear-gradient(158deg, #07111f 0%, #0c2a2e 30%, #16342d 58%, #1a2b3a 100%)` | **V3 根背景**（近黑→墨青绿→石绿→远山黛青；绿为主色调，蓝退为远山点缀，保留 `#07111f` 近黑锚点） |
| `--bg-glow-1` | `radial-gradient(105% 78% at 6% 8%, rgba(28,110,100,.30) 0%, rgba(7,17,31,0) 60%)` | **墨青绿角光**（左上，绿主导，alpha ≤.30） |
| `--bg-glow-2` | `radial-gradient(100% 72% at 92% 98%, rgba(22,80,66,.22) 0%, rgba(7,17,31,0) 62%)` | **石绿/苔绿角光**（右下，绿主导，alpha ≤.30） |
| `--bg-glow-3` | `radial-gradient(90% 58% at 80% 100%, rgba(201,162,39,.14) 0%, rgba(7,17,31,0) 62%)` | **秋意金角光**（底部，绿主导下的暖色点缀，低 alpha） |

> **兼容注释（V3 前旧值，保留不删，供回滚参考）**：
> `--bg-gradient:linear-gradient(160deg,#07111f 0%,#0a1729 42%,#0c1c33 100%)`
> `--bg-glow-ink:radial-gradient(120% 80% at 10% -5%,rgba(26,102,110,.30) 0%,rgba(7,17,31,0) 58%)`
> `--bg-glow-violet:radial-gradient(90% 70% at 94% 4%,rgba(75,63,115,.26) 0%,rgba(7,17,31,0) 55%)`
> `--bg-glow-slate:radial-gradient(100% 60% at 50% 102%,rgba(40,58,82,.28) 0%,rgba(7,17,31,0) 60%)`
> **body 背景层叠加顺序（V3）**：`var(--bg-glow-1), var(--bg-glow-2), var(--bg-glow-3), var(--bg-gradient-v3)`（替换旧四层）。

### 2.3 面板 / 边框（继承 + 反差强化，满足 v2-beta §2.1「背景与卡片须可辨识反差」）
| Token | 值 | 用途 |
|-------|----|------|
| `--panel-1` | `rgba(17,39,70,.82)` | 主面板（= `--surface-report`） |
| `--panel-2` | `rgba(12,29,52,.76)` | 次面板 / 证据（= `--surface-evidence`） |
| `--panel-solid` | `#0e2038` | 无玻璃需求时的实体面板底（保证对比） |
| `--panel-hover` | `rgba(22,48,84,.90)` | hover 提亮 |
| `--panel-focus` | `var(--surface-focus)` | Hero / 当前版本 |
| `--border-subtle` | `rgba(153,190,245,.18)` | 常规描边 |
| `--border-strong` | `rgba(153,190,245,.32)` | 强描边 / 分区 |
| `--border-accent` | `rgba(14,165,233,.38)` | 强调描边 |

### 2.4 强调色（继承并显式锁定老板指定值 #0369a1 / #0ea5e9）
| Token | HEX | 用途 |
|-------|-----|------|
| `--accent-deep` | `#0369a1` | 深空蓝强调：编号轨道、active 边、焦点环底 |
| `--accent` | `#0ea5e9` | 亮空蓝强调：链接、hover、focus ring、小高亮 |
| `--accent-legacy` | `#75b2ff` | v2-beta 亮蓝，保留作高可读文字 / 图标 currentColor |

> 说明：老板本次指定强调色为 `#0369a1 / #0ea5e9`（Tailwind sky-700/500）；v2-beta 生产曾用 `#75b2ff / #a5d4ff`。本令牌将两者共存：`--accent / --accent-deep` 为本次权威值，`--accent-legacy` 仅用于需要更高对比的文字 / 图标场景，确保深色底上可读性。

### 2.5 低饱和辅助色（R4 · 墨青 / 深紫 / 青灰，具体 hex）
| Token | HEX | 用途 |
|-------|-----|------|
| `--aux-ink-teal` | `#1a666e` | 墨青：分析 / 论证类别、次级面板描边、墨青角光源 |
| `--aux-violet` | `#4b3f73` | 深紫：洞察 / 前瞻类别、深紫角光源（低饱和，禁用为大色块） |
| `--aux-slate` | `#44586e` | 青灰：常规 / 资讯类别、静默结构线、弱分区 |

### 2.6 文字色阶
| Token | HEX | 用途 |
|-------|-----|------|
| `--text-primary` | `#edf5ff` | 主文字（标题 / 正文，非纯白） |
| `--text-secondary` | `#9eb4d3` | 次级（摘要 / 元信息） |
| `--text-tertiary` | `#6c7f99` | 弱（placeholder / 脚注 / 序号） |
| `--text-inverse` | `#06121f` | 反白（亮强调底上的文字） |
| `--text-mono` | `#a9c2dc` | 等宽数据文字（略亮于 secondary，便于扫读） |

### 2.7 状态色（低饱和，禁用高饱和红 — 准则 C）
| 状态 | 底色 tint | 文字 | 语义 |
|------|----------|------|------|
| `--status-success` | `rgba(58,143,122,.16)` | `#7fc9b6` | 成功 / 已验证 / 最新 |
| `--status-progress` | `rgba(90,127,176,.16)` | `#9cc0e8` | 进行 / 监测中 |
| `--status-warning` | `rgba(176,138,74,.16)` | `#e0c088` | 警告（**低饱和琥珀，非红**） |
| `--status-critical` | `rgba(154,90,95,.16)` | `#d99aa0` | 关键（**低饱和砖红，非高饱和红**） |

> 警告用琥珀、关键用砖红，二者均低饱和；绝不使用 `#ff0000` 系高饱和红噪声（v2-beta §一.3 / §2.5 红线）。

### 2.8 分类色映射（墨青=分析 / 深紫=洞察 / 青灰=常规）
| 类别 | 主色 | 底色 tint | 文字 | 应用 |
|------|------|----------|------|------|
| 分析 / 论证 | `--aux-ink-teal` `#1a666e` | `rgba(26,102,110,.16)` | `#7fc0c4` | section-01 论证支撑、分析类 badge |
| 洞察 / 前瞻 | `--aux-violet` `#4b3f73` | `rgba(75,63,115,.18)` | `#b3a6d6` | 洞察类 badge、前瞻标记 |
| 常规 / 资讯 | `--aux-slate` `#44586e` | `rgba(68,88,110,.18)` | `#a7b6c8` | 常规资讯、静默结构 |

### 2.9 大厂主题色强调板（语义强调色 · 裁定④）

> **定位**：本组色为「语义强调色」——**非主色、非状态色、不进 §2.2–2.8 的面板/状态体系**。它们是用户对「整体用色太均匀、缺重点层次」反馈的直接回应：借互联网大厂的高辨识主题色，在**局部语义锚点**上制造视觉焦点，打破全站低饱和同权的均匀感。
> **硬约束**：① 只用于**点状语义标记**（关键词包裹、左光轨、胶囊、链接、徽标）；② **绝不**用于大面积背景铺色；③ 每屏强色标记 ≤ 3 处（详见 §2.10）。

| Token | HEX | 语义 | 典型落点 |
|-------|-----|------|---------|
| `--brand-xhs` | `#FF2442` | **小红书红** · 热度 / 重点焦点 / 风险警示重点 | hero 核心判断关键词、今日最热信号、风险类强证据光轨、热度焦点词 |
| `--brand-siemens` | `#009999` | **西门子青** · 技术 / 工程 / 工具 / 开源 | 技术类强证据光轨、工具/开源板块焦点词、技术信源高亮 |
| `--brand-apple` | `#0071E3` | **Apple 蓝** · 产品 / 生态 / 平台 / 大厂 | 产品类强证据光轨、大厂/平台焦点词、产品信源高亮 |
| `--brand-insight-gold` | `#c9a227` | **洞察金**（低饱和）· 观点 / 洞察类 | 观点类焦点词、洞察类强证据光轨（低饱和，克制点缀） |

**配套 tint / 文字安全变体**（alpha ≤ .12，避免满屏彩；深底对比自检见下）：

| Token | 值 | 用途 |
|-------|----|------|
| `--brand-xhs-tint` | `rgba(255,36,66,.10)` | 小红书红极轻背景（强证据卡左侧光轨旁底色，≤.12） |
| `--brand-siemens-tint` | `rgba(0,153,153,.12)` | 西门子青极轻背景 |
| `--brand-apple-tint` | `rgba(0,113,227,.12)` | Apple 蓝极轻背景 |
| `--brand-insight-gold-tint` | `rgba(201,162,39,.10)` | 洞察金极轻背景 |
| `--brand-apple-lift` | `#3a93ff` | Apple 蓝在深底作**小号正文级文字**时的提亮变体（`#0071E3` 在 `#07111f` 上对比 4.03 略低于 AA 4.5；≥15px/600 权重或大号文字仍可用原值，小号内联文字改用此提亮值，对比 6.13 ✓） |

> **深底对比度自检（基底 `--bg-base` `#07111f`）**：`--brand-xhs` 5.04 ✓、`--brand-siemens` 5.43 ✓、`--brand-apple` 4.03（大号/加权达标，小号用 `--brand-apple-lift` 6.13 ✓）、`--brand-insight-gold` 7.83 ✓（均满足 AA 大号文字阈值，普通正文级文字按上表加权/提亮）。四色明度均高于基底，自然跳出，无需额外降噪；仅 emoji 维持 `saturate(.82)`（见 §3.1 / 裁定②）。

### 2.10 高亮语义映射（三类）与用量节奏

#### (a) 重点文字 key-highlight
- **对象**：章节关键句、judgment-hero 核心判断关键词、sec-summary 分散式一句总结里的核心词。
- **实现**：用对应大厂色做「文字色」或「1–2px 下划线 / 细胶囊包裹」，**不整段铺色**。
- **选色**：热度/风险焦点 → `--brand-xhs`；技术/工具/开源 → `--brand-siemens`；产品/大厂/平台 → `--brand-apple`；观点/洞察 → `--brand-insight-gold`。
- **密度**：每屏（viewport）强色文字 ≤ **2** 处（例：hero 判断句只高亮 1 个主焦点词；sec-summary 只高亮 1 个核心名词）。
- **文字安全**：高亮文字建议 ≥15px 或 ≥600 字重（满足「大号文字」AA）；Apple 蓝小号内联改用 `--brand-apple-lift`。

#### (b) 强证据 evidence-strong
- **对象**：evidence-stream 中**高置信 claim 卡**（原「强证据」badge 卡）。
- **实现**：卡左侧加 **3px 大厂色光轨**（`border-left: 3px solid <品牌色>`）+ 极轻背景 tint（`background: <品牌色-tint>`，alpha ≤ .12）。
- **选色（按证据类型）**：技术类（模型/工具/开源/论文）→ `--brand-siemens`；产品类（大厂发布/产品/平台）→ `--brand-apple`；风险/热度类（漏洞/泄露/过度授权/今日最热）→ `--brand-xhs`；观点/洞察类（评论/解读/趋势判断）→ `--brand-insight-gold`。
- **纪律**：光轨仅 3px 细线 + 极轻 tint，视觉权重「次亮」于 hero 焦点词（见本条末「不均等层次」），不喧宾夺主。

#### (c) 参考 reference-highlight（**选择性**高亮 · 计入每屏 ≤3 总纪律）
- **对象（仅选择性）**：**关键信源 / 强证据对应的信源**（如 hero 核心判断援引的 `OpenAI`、强证据卡对应的 `arXiv`、风险类强证据对应的漏洞通告源）。**普通 `[R-xx]` 不上色**，保持原有的低饱和灰蓝（`--accent-legacy` 灰蓝描边 + 灰蓝文字），避免整屏彩字。
- **实现（仅对选中的关键信源）**：其信源名用大厂色高亮（非灰色），hover 加深（提亮背景 tint 或加粗/描边）；**按信源语义归类选色**（技术源 → 西门子青、产品/大厂源 → Apple 蓝、风险源 → 小红书红、观点源 → 洞察金），无明确归类时用 `--accent-legacy` 蓝灰兜底。
- **`[R-xx]` 标记（仅选中者上色）**：被选中高亮的关键 `[R-xx]` 改用**低饱和描边胶囊**——`border: 1px solid <品牌色对应 rgba 描边>`、`color: <对应大厂色>`、`background: <品牌色-tint>`；**普通 `[R-xx]` 维持 `--accent-legacy` 低饱和灰蓝胶囊**（与原风格一致，不引入色彩），形成「可点 = 有色彩」仅作用于关键信源的语义。
- **密度并入总纪律**：参考高亮的「上色处数」**计入** §2.10 用量节奏的每屏 ≤3 总配额（与 key-highlight、evidence-strong 共享），不另计；单屏内即便有 9 个 `[R-xx]`，被上色的也 ≤3 处，其余保持灰蓝。

#### 用量与节奏规范（打破均匀感的核心）
1. **语义强调密度**：每屏（viewport）强色标记（key-highlight 文字 + evidence-strong 光轨 + **选择性** reference 高亮）合计 ≤ **3** 处，制造视觉锚点而非均匀涂抹。**reference 高亮为「选择性」——仅关键信源/强证据对应信源上色，普通 `[R-xx]` 保持低饱和灰蓝不计入**，故 sec-08 即便罗列 9 个 `[R-xx]` 也只上色 ≤3 处，杜绝整屏彩字。
2. **对比原则**：大厂色明度高于基底，自然跳出；**单色饱和度不做额外降噪**（保留大厂识别度）；仅 emoji 维持 `saturate(.82)`（裁定②）。
3. **不均等层次（示例）**：`hero 焦点词（最亮）` → `强证据光轨（次亮）` → `参考链接点缀` → `普通正文（保持低饱和灰蓝）`。层次由强到弱，避免满屏同权。
4. **反模式**：禁止把大厂色当主背景铺满卡片；禁止单屏 ≥4 处强色标记；禁止用大厂色替代 §2.7 状态色（风险仍走 `--status-critical` 砖红，仅在「风险类强证据」这一特定语义叠加小红书红光轨）。

#### 与 Anti-Slop 门控的协调（裁定④ · 用户授权偏离）
- 原 §7.1 红线「禁高饱和红噪声（#ff0000 系、无解释红数字）」**仍然成立**：禁止大面积高饱和红背景、禁止满屏红告警、禁止无解释红数字。
- 本次 `--brand-xhs` `#FF2442` 是**用户明确授权用于语义强调**的高饱和红；用量克制（局部标记、非大面积红背景/告警噪声），故作为「**用户授权偏离**」处理，列为**第 4 条裁定**〔✅ 裁定④〕，与 §0.3 既有 3 条并列，供审查官认可。
- 偏离边界：小红书红**仅**作点状语义标记（关键词、光轨、胶囊、链接、徽标）；一旦触及「大面积红背景 / 满屏红 / 红告警噪声」，立即回到 §7.1 红线处置。

---

### 2.11 Hero 指标彩虹渐变（裁定⑤ · 局部高饱和装饰）

> **定位**：本令牌为全站**唯一**的局部高饱和装饰带——仅在 `.hero-metrics` 的 6 项指标数值上施加「赤橙黄绿青蓝紫」连续光谱文字渐变（裁定⑤，老板授权）。它**不属于** §2.9 语义强调色体系、不占 §2.10「每屏强色 ≤3」配额（属装饰非语义标记），但**严禁向正文区扩散**。

| Token | 值 | 用途 |
|-------|----|------|
| `--rainbow` | `linear-gradient(90deg, #ff5b5b 0%, #f0a868 16%, #f5d76e 33%, #7fc9a0 50%, #5fd0d0 66%, #6aa8ff 83%, #b48cff 100%)` | **V3 Hero 指标彩虹渐变**（赤→橙→黄→绿→青→蓝→紫 连续光谱） |

**光谱构造**：赤 `#ff5b5b` → 橙 `#f0a868` → 黄 `#f5d76e` → 绿 `#7fc9a0` → 青 `#5fd0d0` → 蓝 `#6aa8ff` → 紫 `#b48cff`，七段连续、无跳变。

**AA 提亮处理**：在基底 `#07111f` 上，黄 / 橙两段（视觉上最易被深底吞没）提亮至 `#f5d76e` / `#f0a868`，确保渐变文字相对深底的对比满足 AA 可读性（光谱其余段在深底上明度已足够，维持自然饱和度）。

**唯一落点（硬约束）**：仅作用于 `.hero-metrics .metric-value`：
```css
.hero-metrics .metric-value{
  background:var(--rainbow);
  -webkit-background-clip:text;
  background-clip:text;
  color:transparent;
}
```
**外溢禁令**：彩虹**绝不**外溢到——正文数值、状态胶囊（§4.10）、RSS 等宽数据（§4.6）、顶栏指标（§4.1 `--metric-value` 维持近白 `#e2e8f0`，不接彩虹）。该带为 Hero 专属装饰，越出 `.hero-metrics` 即视为违反裁定⑤。

---

## 3. Typography（排版令牌）

### 3.1 字体族
- **UI（标题 + 正文）**：`--font-ui: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", "PingFang SC", "Microsoft YaHei", "Hiragino Sans GB", sans-serif`
- **等宽数据（时间 / 版本 / 指标 / 来源 ID）**：`--font-mono: "JetBrains Mono", "IBM Plex Mono", "SF Mono", "Roboto Mono", ui-monospace, "DejaVu Sans Mono", monospace`
- **图标（✅ 裁定②）**：**emoji 作为板块 / 区块主图标贯穿全站**，统一降噪处理 `filter: saturate(.82)`、`font-size: 18px`（最大不超过 18px），不使用第三方图标库；单色线性 SVG（`viewBox="0 0 24 24"` `stroke="currentColor"` `stroke-width="1.7"`，默认 16px）保留为可选次级 / 强调图标，仅在 emoji 不适用的极个别场景补充（v2-beta §4.2 的 SVG 规范降级沿用，非主图标）。emoji ↔ 语义 ↔ SVG 映射见 §4.11。深空蓝底上 emoji 偏暗时，推荐按 §4.12「emoji 亮色系徽章」提亮（B 方案：保留 `saturate(.82)` 低饱和基调，不改用高饱和滤镜——避免触发 §7.1 红线）。

### 3.2 字号阶梯（桌面 ≥1024）
| Level | Size | Weight | Line-height | Letter-spacing | 用途 |
|-------|------|--------|-------------|----------------|------|
| Display | 30px / 1.875rem | 700 | 1.22 | -0.01em | judgment-hero 核心判断句 |
| H1 | 20px / 1.25rem | 600 | 1.32 | -0.005em | 区块大标题 / Hero eyebrow |
| H2 | 18px / 1.125rem | 600 | 1.36 | 0 | report-section 标题 |
| H3 | 15px / .9375rem | 600 | 1.45 | 0 | 子块 / 面板标题 |
| Body | 15px / .9375rem | 400 | 1.70 | 0 | 正文 / 条目 |
| Small | 13px / .8125rem | 400 | 1.55 | 0 | 摘要 / 元信息 |
| Micro | 12px / .75rem | 500 | 1.40 | 0.04em | badge / 标签 / 编号 |
| Mono | 13px / .8125rem | 450 | 1.50 | 0.01em | 等宽数据（时间/版本/指标） |

### 3.3 手机端字号上扬（<768，解决小屏可读 — R3）
| Level | 手机值 | 说明 |
|-------|-------|------|
| Display | 26px / 1.625rem | 略收以适配窄宽，仍居首 |
| H1 | 21px / 1.3125rem | 上扬 |
| H2 | 19px / 1.1875rem | 上扬 |
| H3 | 16px / 1rem | 上扬 |
| Body | **16px / 1rem** | 上扬（基准可读） |
| Small | **14px / .875rem** | 上扬 |
| Micro | 12px / .75rem | 维持 |
| Mono | 13px / .8125rem | 维持（等宽不宜过大） |

---

## 4. Component Styles（组件令牌）

> 每个组件给出可消费的令牌化规格；状态 / 分类用 §2.7–2.8 的 badge 令牌。

### 4.1 intel-topbar（顶部情报栏）
- 形态：sticky 顶栏，`height: 56px`（桌面）/ 52px（平板）/ 48px（手机），`background: rgba(7,17,31,.86)` + `backdrop-filter: blur(8px)`，`border-bottom: 1px solid var(--border-subtle)`。
- 布局（桌面同行）：`📡 AI 情报终端`（品牌锚，单色 satellite SVG + 文字） · `版本 2026-07-15 20:00`（mono） · `最新` badge（`--status-success`） · `今日 N 版`（mono，仅 manifest 提供时） · `🕘 历史` 按钮（打开抽屉）。
- 窄屏：版本 / 状态换行到第二行；历史按钮保持 ≥44×44 触控面积。
- z-index：`--z-sticky: 200`。
- **强调色落点（裁定④）**：当存在「今日最热信号」时，可在状态区追加一个小红书红焦点胶囊（`--brand-xhs` 文字 + `--brand-xhs-tint` 底），作为全页唯一的「热度焦点」锚点；每屏至多 1 处，禁满屏红。
- **指标可读化（intel-topbar metrics · 老板反馈 #1）**：深空蓝背景 `#07111f`/`#0c1c33` 上，顶栏指标（版本时间 / 今日 N 版；及其在 §4.2 hero 指标行的延伸：热榜 M/N、RSS X/Y、AI 8 板块、生成时间、今日版本数）需一眼可读。规范：
  - **数字 / 主值**：`color: var(--metric-value) #e2e8f0`（近白非纯白，避免纯白刺眼），`font-family: var(--font-mono)`，`font-size: 15px`（比正文 mono 13px 略大以突出），`font-weight: 600`，`letter-spacing: .01em`，`text-shadow: var(--metric-glow)`（= `0 0 10px rgba(14,165,233,.22)`，极淡蓝微光，低饱和不刺眼）。
  - **标签 / 单位**：`color: var(--metric-label) #94a3b8`（比数字稍暗，形成层次），`font-family: var(--font-ui)`（中文标签用 UI 字体），`font-size: 12px`（micro），`font-weight: 500`，`letter-spacing: .04em`。
  - **字号比例与对齐**：值 15px : 标签 12px ≈ 1.25:1；同一指标项内 value 与 label 基线对齐（`align-items: baseline`），指标项之间 `gap: var(--space-3)`（12px）。
  - **顶栏内对齐**：指标组在 56px 顶栏内垂直居中（`align-items: center`）；与品牌锚 / 状态胶囊之间用 `var(--space-4)`（16px）分隔，保持呼吸感。
  - **不受影响**：状态胶囊（已同步 / 更新中 / 本期焦点）维持 §4.10 低饱和胶囊，不受本可读化调整影响。
  - **令牌**：见 §9.3 `--metric-value` / `--metric-label` / `--metric-glow`。

### 4.2 judgment-hero（单一核心判断模块 — R2 合并产物）
- 形态：主列顶部大面板，`background: var(--surface-focus)`，`border: 1px solid var(--border-accent)`，`border-radius: var(--radius-lg)`，`padding: 28px 32px`（桌面）。
- 结构：
  1. eyebrow：`AI DAILY INTELLIGENCE / 当前版`（mono，micro，--text-tertiary）。
  2. 图标：`🧭`（主图标，降噪 saturate(.82)，size≤18px；见 ✅ 裁定② / §3.1 / §4.11）。
  3. 核心判断句：Display 字号，≤3 行，`--text-primary`；其中**至多 1 个**主焦点词用 key-highlight（热度焦点→`--brand-xhs`、产品/大厂焦点→`--brand-apple`、技术焦点→`--brand-siemens`），作 1–2px 下划线或细胶囊包裹，不整句铺色（§2.10-a，每屏强色文字 ≤2 处）。
  4. 指标行（横排，真实数据）：热榜 M/N · RSS X/Y · AI 8 板块 · 生成时间 · 今日版本数；每项 `label + value`，可读化规范同 §4.1 指标可读化（值 = `--metric-value #e2e8f0` / 600 + 极淡蓝微光，标签 = `--metric-label #94a3b8` / 500，字号比 15:12，基线对齐）——不再用 `--text-tertiary` / `--text-mono` 的低对比组合（老板反馈 #1）。
  5. 支撑 chips：2–3 个 `capsule badge`（分类色，见 §4.10）指向 section-01 论证。
- 纪律：不放大数字、不加动态图表、不把采集成功率包装成业务分（v2-beta §3.2）。

### 4.3 report-section（栅格卡片 — R1 栅格秩序）
- 形态：连续报告主体内 8 个有序章节；每章 `background: var(--panel-1)`，`border: 1px solid var(--border-subtle)`，`border-radius: var(--radius-md)`，`padding: var(--card-pad)`。
- 头部：`[NN]` 编号（mono，--accent-deep）+ **emoji 主图标**（降噪 saturate(.82)，size≤18px；见 ✅ 裁定② / §4.11）+ H2 标题 + 右侧 meta badge（分类 / 状态）+ `sec-summary` 引导句（§4.7）。
- 左轨：章节左侧 2px `var(--accent-deep)` 细光轨；hover / 当前仅提亮边框与轨道（不放大）。
- **强调色落点（裁定④）**：章节标题/正文中的焦点关键词可加 key-highlight（按语义选大厂色，§2.10-a），每屏 ≤2 处；section 本体仍走蓝紫体系，大厂色只作局部锚点，不铺卡片背景。
- 内容栅格（R1）：桌面 PC **≥2 列对齐**（`grid-template-columns: repeat(2, minmax(0,1fr))`，gutter `--space-5`），统一基线；条目为连续列表，单条不再套独立卡片；内容多时维持 4–6 条（v2-beta §四）。
- 编号 01–08 固定（框架不变），section-01 语义见 §4.9 / §0.3#3。

### 4.4 section-rail（常驻 / 折叠 / 抽屉 — R3）
- 桌面 ≥1024：**左侧细导航轨**，`width: 240px`，`position: sticky; top: 56px; height: calc(100vh - 56px)`，背景 `var(--panel-solid)` 半透明 + 右描边；含 8 章节索引（编号 + emoji + 标题，点击平滑滚动 / 高亮当前）+ `🕘 历史` 入口。
- 平板 768–1023：**折叠为顶条**——横向可滚动 chip 行（章节 01–08 + 历史），置于 topbar 下方。
- 手机 <768：**折叠为抽屉**——默认隐藏，由 topbar `🕘/☰` 触发右侧滑出（复用 history-drawer 动效体系），关闭支持遮罩 / × / ESC。
- 激活指示：左侧 2px `var(--accent)` 亮条 + 背景 `rgba(14,165,233,.10)`。
- 绝不挤占报告主列宽度（仅 PC 常驻，且为细轨非内容栏 — 见 §0.3#1）。

### 4.5 history-drawer（右侧历史浮层）
- 形态：从右滑出，`width: 360px`（桌面）/ 88vw（平板）/ 92vw（手机），`background: var(--panel-solid)`，`border-left: 1px solid var(--border-strong)`，`box-shadow: var(--shadow-drawer)`，`padding: 24px`。
- 动效：`transform: translateX(100%) → 0`，`transition: 280ms cubic-bezier(.4,0,.2,1)`；遮罩 `rgba(3,8,16,.55)`。
- 内容：`map-pin` 当前版本（高亮边框）+ `clock-3` 今日时间线（多版倒序，mono）+ `calendar-days` 近期（逐日）+ 历史归档（可滚动列表，mono 日期 + 标题）。
- 旧版提示（打开非最新时，报告顶部可见）：`当前查看：YYYY-MM-DD HH:MM 版本 · 这不是最新版本 · 查看最新`。
- 关闭：遮罩 / × / ESC；关闭态 `inert` + 移出 Tab 顺序（v2-beta Gate 9.1）。

### 4.6 rss-dual（RSS 等宽双栏 — R5 / 决定#1）
- 形态：两栏**等宽并排**（`grid-template-columns: 1fr 1fr`，gutter `--space-5`），**各自 `min-height` 填平**（取两栏较高者，避免错位；`min-height: 420px` 桌面下限）。
- 左栏 `新增更新` / 右栏 `订阅更新`，两区保留各自语义与标题（左 `🔄 新增更新`、右 `🔔 订阅更新`）。
- 每栏面板：`background: var(--panel-2)`，`border: 1px solid var(--border-subtle)`，`border-radius: var(--radius-md)`，`padding: var(--card-pad)`。
- 行条目（**等宽数据排版**）：`[mono 时间] · [来源名] · [标题 3 行截断] · [分类 badge]`；hover 仅提亮边框（v2-beta §3.5）。
- 双语义保留：`NEW` 低噪胶囊（`--status-warning` 琥珀，非红，非绿主题）；RSS 整体融入蓝 / 低饱和体系（v2-beta §一.3 红线）。
- 手机 <768：双栏折为单列上下堆叠，仍各自 `min-height` 不塌陷。

### 4.7 sec-summary（分散式一句话总结 — 准则 B）
- 形态：每区块标题下、详情列表前的低饱和引导句；`font-size: var(--small)`，`color: var(--text-secondary)`，`font-style: normal`，前缀 `▸` 或 emoji 标记，与标题间 `margin-bottom: var(--space-3)`。
- **key-highlight（裁定④）**：引导句中**至多 1 个**核心名词可用对应大厂色高亮（热度→`--brand-xhs`、技术→`--brand-siemens`、产品/大厂→`--brand-apple`、观点→`--brand-insight-gold`），作文字色或细胶囊，不整句铺色（§2.10-a，每屏强色文字 ≤2 处）。
- 分布：Hero 后一句全局总览 + 每个 report-section 各一句 + 关键节点（RSS 区、历史入口）各一句。文案由 AI 生成阶段产出，缺失时不显示空框（v2-beta §3.3 / §六）。

### 4.8 source-ref（🔖 信源引用）
- 形态：行内可点击标记 `[Rxxx]`，`font-family: var(--font-mono)`，`font-size: var(--micro)`，`padding: 1px 6px`，`border-radius: var(--radius-sm)`。
- **reference-highlight（裁定④ · 选择性，计入每屏 ≤3）**：**仅关键信源 / 强证据对应信源**的 `[R-xx]` 与信源名上色——`border: 1px solid <品牌色对应 rgba 描边>`、`color: <对应大厂色>`、`background: <品牌色-tint>`（按信源语义：技术→西门子青、产品/大厂→Apple 蓝、风险→小红书红、观点→洞察金，无归类用 `--accent-legacy` 蓝灰兜底），信源名（handle）同步高亮、hover 加深；**普通 `[R-xx]` 维持 `--accent-legacy` 低饱和灰蓝胶囊，不上色**。上色处数计入 §2.10 每屏 ≤3 总配额（细则 §2.10-c）。
- 状态（v2-beta §3.4）：已验证 canonical → 蓝灰边框，新窗打开；X/Nitter 有 fallback → 标后展来源名，双入口；无可用链接 / 诊断未完成 → 中性不可点击文字，绝不伪造可回溯。
- 统计行（section-08）：`33 源 · 19 条 [R] · 2 条 [H]`（真实可得数量）。

### 4.9 evidence-stream（section-01 论证 / 证据支撑 — R2）
- 语义：原「今日核心判断」slot 改为 hero 的**论证 / 证据支撑**子模块（R2）。
- 形态：桌面 **2 列网格**（`repeat(2, minmax(0,1fr))`），每卡 `background: var(--panel-2)`，`border: 1px solid var(--border-subtle)`，`border-radius: var(--radius-md)`，`padding: var(--card-pad)`；视觉权重低于研判正文（v2-beta §3.5）。
- 每卡：claim 句（body）+ `source-ref`（🔖）+ 权重 badge（分类色：墨青=强证据 / 青灰=参考）。
- **evidence-strong（裁定④）**：高置信 claim 卡（原「强证据」badge）左侧加 **3px 大厂色光轨**（`border-left: 3px solid <品牌色>`）+ 极轻背景 tint（`background: <品牌色-tint>`，alpha ≤ .12）；选色按证据类型（技术→西门子青、产品→Apple 蓝、风险/热度→小红书红、观点→洞察金，§2.10-b）。光轨仅细线+极轻 tint，视觉权重次亮于 hero 焦点词。
- rail 标签：保留 `01` 编号，标题标「论证支撑」（✅ 裁定③，见 §0.3 / §4.9）。

### 4.10 capsule badge（状态 / 分类胶囊）
- 通用：inline-flex，`height: 22px`，`padding: 0 10px`，`border-radius: var(--radius-pill)`，`font-size: var(--micro)`，`font-weight: 500`，`letter-spacing: .04em`，`border: 1px solid`（与底色同色系偏弱），配前导 dot（6px 圆，`background: 当前文字色`）。
- 状态型（§2.7）：success / progress / warning / critical。
- 分类型（§2.8）：分析(墨青) / 洞察(深紫) / 常规(青灰)。
- 置信型：高 / 中 / 低 → 用 status 色系（高=success、中=progress、低=warning）。
- 反模式：禁用纯红、禁用无解释红数字、禁用 inline 红色（v2-beta §2.5）。

### 4.11 emoji 语义映射表（准则 A）
> **✅ 裁定②**：emoji 作为板块 / 区块**主图标**贯穿全站，统一降噪 `filter: saturate(.82)`、`size≤18px`；单色线性 SVG 仅作可选次级 / 强调图标（见 §3.1）。下表为 emoji ↔ 语义 ↔ 继承 SVG 的映射，供筑原型对齐。深空蓝底上 emoji 偏暗时，按 §4.12「emoji 亮色系徽章」提亮（推荐 B，保留 `saturate(.82)`）。

| 语义 | emoji | 继承 SVG id | 应用位置 |
|------|-------|-----------|---------|
| 情报 / 顶部 | 📡 | `satellite` | intel-topbar 品牌锚 |
| 判断 / 核心 | 🧭 | `crosshair` | judgment-hero |
| 章节 / 导航 | 📚 | （rail 专用） | section-rail 标题前缀 |
| 信源 | 🔖 | `book-open` | source-ref / section-08 |
| 更新 / RSS | 🔄 | （rss 专用） | rss-dual 双栏标题 |
| 历史 | 🕘 | `history` | history-drawer / rail 入口 |
| 证据 / 论证 | 🔍 | （evidence 专用） | evidence-stream |
| 数据 / 指标 | 📊 | （metric 专用） | hero 指标行 |
| 风险 | ⚠️ | `triangle-alert` | section-07 |
| 洞察 | 💡 | （insight 专用） | 分类 badge / 前瞻标记 |
| 研究 / 模型 | 🔬 | `flask` | section-02 |
| 产品 / 工具 | 🛠️ | `wrench` | section-03 |
| 开源 / 生态 | 🕸️ | `network` | section-04 |
| 大厂 / 融资 / 政策 / 算力 | 🏛️ | `cpu` | section-05 |
| 观点 | 💬 | `message-circle` | section-06 |

---

### 4.12 emoji 亮色系徽章（裁定② 衍生 · 老板反馈 #2）

> **问题**：老板反馈截图中 `🔭 / 🔍 / 🛠️` 等 emoji 在深空蓝背景上偏暗、辨识度不足。原 `.emoji{filter:saturate(.82)}` 为低饱和降噪处理（裁定②），但单 glyph 在 `#07111f` 上对比偏弱。
> **推荐方案：B（浅色背景徽章）**。理由：
> 1. **不破坏低饱和基调**：徽章方案保留 emoji 本体 `saturate(.82)` 降噪（A 方案会把饱和度抬到 `1.05`，轻微偏离 §7.1 红线「未降噪彩色 emoji」），B 与 Anti-Slop 纪律完全兼容。
> 2. **与深空情报终端风协调**：浅色圆形徽章（`rgba(255,255,255,.08)` + 内阴影）复用了系统既有的「胶囊 / 面板」浅边光语言（§4.10 / §5.4），与情报终端气质一致，而非生硬提亮 glyph。
> 3. **辨识度提升机制**：emoji 落于 28px 浅色徽章上，周缘形成一致浅色光环，把图标从深色底中「托起」隔离，扫读时单元更清晰；全站图标因此获得统一可视锚框，秩序感更强。

**实现（推荐 B）**：
```css
.emoji-badge{
  display:inline-flex; align-items:center; justify-content:center;
  width:28px; height:28px; border-radius:50%;
  background:var(--emoji-badge-bg);          /* rgba(255,255,255,.08) */
  box-shadow:var(--emoji-badge-shadow);      /* inset 0 0 8px rgba(255,255,255,.06) */
}
.emoji-badge .emoji{
  font-size:18px; line-height:1;             /* emoji 本体 ≤18px（裁定②） */
  filter:saturate(.82);                       /* 保留低饱和降噪 */
}
```
- **用法**：板块 / 区块主图标统一用 `<span class="emoji-badge"><span class="emoji">🔍</span></span>`；emoji 仍作为全站主图标（`size ≤18px`），徽章 28px 仅作提亮托底，不替代 emoji 语义。
- **小尺寸回退**：板块标题行等空间受限处，可省去徽章、直接 `.emoji{filter:saturate(.82)}`（维持现状），仅在 hero / 章节头 / 卡片主图标等「需要一眼定位」的位置用徽章。

**备选方案 A（直接提亮，不推荐）**：
```css
.emoji{ filter:saturate(1.05) brightness(1.08) drop-shadow(0 0 4px rgba(255,255,255,.12)); }
```
A 直接抬高 glyph 亮度 / 饱和度，提亮更直接，但 `saturate(1.05)` 偏离低饱和降噪（§7.1 红线边缘），且全站无统一锚框、易显得零散。仅当 B 的徽章在个别极窄场景不可用时作兜底。

---

## 5. Layout（布局令牌）

### 5.1 栅格与容器
| Token | 值 | 用途 |
|-------|----|------|
| `--container-max` | `1320px` | 桌面总容器（含左轨 + 主列 + 右留白） |
| `--rail-width` | `240px` | 常驻左细轨（仅 PC） |
| `--content-max` | `880px` | 报告阅读主列最大行宽（避免大屏一行过长，v2-beta §4.3） |
| `--gutter` | `20px`（PC）/ `16px`（平板）/ `12px`（手机） | 栅格间距 |
| `--grid-cols-section` | `repeat(2, minmax(0,1fr))` | report-section / evidence / rss 双栏基准列 |

### 5.2 间距尺度（8px 基准栅格，R1 统一基线）
| Token | 值 | 用途 |
|-------|----|------|
| `--space-1` | 4px | 行内微距 |
| `--space-2` | 8px | 紧凑 |
| `--space-3` | 12px | 标签 / 引导句间距 |
| `--space-4` | 16px | 默认 |
| `--space-5` | 20px | 栅格 gutter（桌面） |
| `--space-6` | 24px | 区块内距 |
| `--space-8` | 32px | 主分隔 |
| `--space-10` | 40px | 大分隔 |
| `--space-12` | 48px | 章节间距 |
| `--space-16` | 64px | Hero 留白 |

### 5.3 圆角
- `--radius-sm: 8px`（badge / 小 chip）· `--radius-md: 12px`（卡片 / 面板）· `--radius-lg: 16px`（Hero / 抽屉）· `--radius-pill: 999px`（胶囊 badge）。

### 5.4 阴影 / 描边（低噪，v2-beta §2.1 / §4.3）
- `--shadow-flat: none`（玻璃面板靠边框 + 底色分离）
- `--shadow-raised: 0 2px 12px rgba(20,40,80,.25)`（卡片浮起，轻量）
- `--shadow-floating: 0 8px 30px rgba(0,0,0,.40)`（弹层 / popover）
- `--shadow-drawer: -16px 0 44px rgba(0,0,0,.50)`（历史抽屉）
- 描边优先级：`1px solid var(--border-subtle)`；分区用 `--border-strong`。

---

## 6. Depth & Elevation（深度与层级）

| Level | Shadow | 应用 |
|-------|--------|------|
| Flat | none | 默认玻璃面板 |
| Raised | `var(--shadow-raised)` | report-section / rss / evidence 卡 |
| Floating | `var(--shadow-floating)` | 弹层 / 顶栏下拉 |
| Overlay | `var(--shadow-drawer)` | history-drawer |

**Z-index 尺度**：`--z-base: 0` · `--z-dropdown: 100` · `--z-rail: 150` · `--z-sticky: 200` · `--z-drawer: 300` · `--z-overlay: 400` · `--z-toast: 500`。

**层级纪律**：亮区（glow / focus）只服务于 Hero、当前历史版本与 hover，不让全页发光（v2-beta §4.1）；面板靠「底色 + 边框 + 轻投影」与背景分离，满足反差要求（§2.3）。

---

## 7. Cautions（Anti-Slop 反模式）

### 7.1 Never Do（准则 C / D 红线）
- ❌ **纯白卡片**（`#fff` 卡底）——卡片须为 `var(--panel-1/2)` 半透明深蓝面板。
- ❌ **高饱和红噪声**（`#ff0000` 系、无解释红数字）——状态用 §2.7 低饱和琥珀 / 砖红。
- ⚠️ **受控例外（裁定④）**：`--brand-xhs` `#FF2442` 小红书红为用户**授权偏离**，仅作点状语义标记（关键词/光轨/胶囊/链接/徽标），禁大面积红背景/满屏红/红告警噪声；一旦越界即回到上条红线处置（细则见 §2.10）。
- ❌ **背景与卡片同色**——背景用 §2.2 跨色系低饱和渐变 + 角光建立存在感，卡片浮于其上（边框 + 轻投影）保持可读反差。
- ❌ **随机宽度 / 瀑布流**——所有区块走 §5 栅格（PC≥2 列对齐、统一 gutter 与基线）。
- ❌ **伪指标**——信号强度 / 熵 / 升温冷却 / 簇图 / 昨日差分一律不出现（v2-beta §一.1 / §九）。
- ❌ **RSS 绿主题 / 紫横幅 / 红色 NEW**——RSS 入蓝体系，NEW 低噪琥珀（v2-beta §一.3）。
- ❌ **未降噪的彩色 emoji / 第三方图标库**——emoji 作为主图标须统一 `filter:saturate(.82)` 且 `size≤18px`（✅ 裁定②）；深空蓝底上提亮须用 §4.12 浅色徽章（B 方案）保留降噪，禁用 `saturate>1` 的高饱和滤镜（A 方案仅作极窄场景兜底）；不引入第三方图标依赖（v2-beta §4.2）。

### 7.2 Prefer（推荐替代）
- ✅ 玻璃面板 + 1px 低饱和描边 + 轻投影分离背景。
- ✅ 等宽字体承载一切数值 / 时间 / 版本 / 来源 ID。
- ✅ 状态 / 分类用低噪 capsule badge（dot + tint 底 + 低饱和文字）。
- ✅ emoji 作为板块 / 区块主图标贯穿全站（降噪 `saturate(.82)`、`size≤18px`），单色线性 SVG 仅作可选次级 / 强调图标（✅ 裁定②）。
- ✅ 颜色不是唯一状态表达——最新 / 历史 / 不可点击来源必须有文字（v2-beta §5）。

### 7.3 四处偏离裁定结论（见 §0.3，均已核准）
1. **常驻侧栏** = 左侧细导航轨 240px（仅章节索引 + 历史，非内容栏），报告仍为主列（裁定①）。
2. **emoji** = 采纳老板长期偏好，作为板块 / 区块主图标贯穿全站（降噪 `saturate(.82)`、`size≤18px`），不退回纯 SVG（裁定②）；深空蓝底上偏暗时按 §4.12 用浅色徽章（B）提亮，保留降噪（老板反馈 #2）。
3. **section-01** = 采纳 R2，保留 01–08 编号与 8 条目，渲染为 hero 核心判断的「论证 / 证据支撑」子模块（裁定③）。
4. **大厂主题色强调板** = 用户授权偏离 §7.1 高饱和红红线，新增 §2.9 大厂主题语义强调色（小红书红/西门子青/Apple 蓝/洞察金），仅作点状语义标记、禁大面积铺色、每屏强色 ≤3 处（裁定④，详见 §2.10）。

---

## 8. Responsive Behavior（响应式 — R3）

### 8.1 三档断点
| 档位 | 宽度 | 侧栏形态 | 栅格列数 | 密度 | 字号 |
|------|------|---------|---------|------|------|
| **PC** | ≥1024px | 常驻左细轨 240px（仅导航，非内容栏） | 主列内 section/evidence/rss ≥2 列对齐 | 高密度 | 基准（§3.2） |
| **平板** | 768–1023px | 折叠为顶条（横向滚动 chip 行） | 主列单栏，evidence/rss 可保留 2 列 | 中密度 | 基准 |
| **手机** | <768px | 折叠为抽屉（☰/🕘 触发，右滑出） | 全站单列 | 低密度 | **上扬**（§3.3） |

### 8.2 适配规则
- PC：container 1320px 居中；左轨 sticky 常驻；报告主列 ≤880px 行宽；rss 双栏等宽填平；history-drawer 360px。
- 平板：左轨转顶条 chip；container 960px；gutter 16px；card-pad 16px；block-gap 22px；rss 仍可 2 列。
- 手机：container 流体 + 16px 边距；gutter 12px；card-pad 14px；block-gap 18px；**字号上扬**（body 16 / small 14 / H2 19）；rss 双栏折单列；history-drawer 92vw；所有可点元素 ≥44×44 触控；`prefers-reduced-motion` 时关闭滑出动效。
- 全局：长标题 `-webkit-line-clamp` 截断不撑破容器；颜色非唯一状态（文字兜底）；ESC 关抽屉；焦点环 `0 0 0 2px rgba(14,165,233,.5)`。

---

## 9. Agent Prompt Guide（生成指南）

### 9.1 Key Instructions（给筑原型 / 下游生成）
- 严格消费 §2 色彩令牌与 §3 排版令牌，禁止硬编码 `#fff` 卡底或高饱和红；**§2.9 大厂主题色仅作点状语义标记（key-highlight / evidence-strong / reference-highlight），禁大面积铺色，每屏强色标记 ≤3 处**（§2.10）。
- key-highlight 每屏 ≤2 处文字、evidence-strong 用 3px 大厂色光轨 + ≤.12 tint、**reference 仅对关键信源/强证据对应信源**的 `[R-xx]` 与信源名上色（普通 `[R-xx]` 维持 `--accent-legacy` 灰蓝胶囊），三类上色处合计每屏 ≤3（§2.10 a/b/c）。
- **小红书红 `--brand-xhs` 为裁定④用户授权偏离**：仅作语义强调局部标记，不触发 §7.1 高饱和红红线；禁大面积红背景/满屏红（见 §2.10 协调说明）。
- 所有数值 / 时间 / 版本 / 来源 ID 用 `--font-mono` 等宽呈现。
- 面板统一 `var(--panel-1/2)` + `1px var(--border-subtle)` + `var(--shadow-raised)`，绝不随机宽度。
- 状态 / 分类一律 capsule badge（§4.10），NEW 用低噪琥珀。
- emoji 作为板块 / 区块主图标贯穿全站（降噪 `saturate(.82)`、`size≤18px`，✅ 裁定②）；深空蓝底上偏暗时按 §4.12 用浅色徽章（B）提亮，保留降噪、不抬饱和度；单色线性 SVG 仅作可选次级 / 强调图标（§3.1 / §4.11）。
- 只渲染真实数据；空态显示真实说明（如「本版未生成 AI 研判」「暂无高置信信号」），不填 mock 文案（v2-beta §六）。
- 三档断点严格按 §8 实现，手机端字号上扬、侧栏转抽屉。

### 9.2 一句话痛点解决
> 这套令牌以 **Linear 低饱和面板结构**为骨架、承袭 **v2-beta 深空蓝基底**（#07111f / 面板 / #0369a1·#0ea5e9 强调）并注入 **墨青 / 深紫 / 青灰跨色系低饱和渐变背景**与统一 8px 栅格——用 `report-section` 栅格卡片 + R1 解决瀑布流失序，用合并后的 `judgment-hero` 单模块 + `evidence-stream` 论证支撑解决判断割裂（R2），用三档响应式 + `section-rail` 常驻/折叠/抽屉形态解决多端阅读（R3），用跨色系渐变 + §2.5 辅助色解决层次扁平（R4），用 `rss-dual` 等宽双栏 + capsule badge 解决更新区信息密度（R5），整体以 emoji 语义映射（A）+ 低噪 capsule badge（C/D）统一情报终端气质。

### 9.3 Quick CSS Snippet（核心令牌速查）
```css
:root{
  /* 继承基底 */
  --bg-base:#07111f; --bg-field:#0c1c33;
  --surface-report:rgba(17,39,70,.82); --surface-evidence:rgba(12,29,52,.76);
  --line-subtle:rgba(153,190,245,.18); --line-active:rgba(111,178,255,.55);
  --text-primary:#edf5ff; --text-secondary:#9eb4d3; --text-tertiary:#6c7f99;
  /* 强调（老板指定） */
  --accent-deep:#0369a1; --accent:#0ea5e9; --accent-legacy:#75b2ff;
  /* R4 跨色系低饱和（V3 前旧值，保留为兼容注释，不删） */
  /* --bg-gradient:linear-gradient(160deg,#07111f 0%,#0a1729 42%,#0c1c33 100%); */
  /* --bg-glow-ink:radial-gradient(120% 80% at 10% -5%,rgba(26,102,110,.30) 0%,rgba(7,17,31,0) 58%); */
  /* --bg-glow-violet:radial-gradient(90% 70% at 94% 4%,rgba(75,63,115,.26) 0%,rgba(7,17,31,0) 55%); */
  /* --bg-glow-slate:radial-gradient(100% 60% at 50% 102%,rgba(40,58,82,.28) 0%,rgba(7,17,31,0) 60%); */
  /* V3 权威背景层（裁定⑥ · 青绿山水，绿为主色调） */
  --bg-gradient-v3:linear-gradient(158deg,#07111f 0%,#0c2a2e 30%,#16342d 58%,#1a2b3a 100%);
  --bg-glow-1:radial-gradient(105% 78% at 6% 8%,rgba(28,110,100,.30) 0%,rgba(7,17,31,0) 60%);
  --bg-glow-2:radial-gradient(100% 72% at 92% 98%,rgba(22,80,66,.22) 0%,rgba(7,17,31,0) 62%);
  --bg-glow-3:radial-gradient(90% 58% at 80% 100%,rgba(201,162,39,.14) 0%,rgba(7,17,31,0) 62%);
  --aux-ink-teal:#1a666e; --aux-violet:#4b3f73; --aux-slate:#44586e;
  /* 状态（低饱和，非高饱和红） */
  --status-success:rgba(58,143,122,.16); --status-success-text:#7fc9b6;
  --status-progress:rgba(90,127,176,.16); --status-progress-text:#9cc0e8;
  --status-warning:rgba(176,138,74,.16); --status-warning-text:#e0c088;
  --status-critical:rgba(154,90,95,.16); --status-critical-text:#d99aa0;
  /* 大厂主题语义强调色（裁定④ · 语义强调，非主色/状态色，仅点状标记） */
  --brand-xhs:#FF2442; --brand-xhs-tint:rgba(255,36,66,.10);
  --brand-siemens:#009999; --brand-siemens-tint:rgba(0,153,153,.12);
  --brand-apple:#0071E3; --brand-apple-tint:rgba(0,113,227,.12); --brand-apple-lift:#3a93ff;
  --brand-insight-gold:#c9a227; --brand-insight-gold-tint:rgba(201,162,39,.10);
  /* Hero 指标彩虹渐变（裁定⑤ · 局部装饰带，仅 .hero-metrics .metric-value 使用，不外溢） */
  --rainbow:linear-gradient(90deg,#ff5b5b 0%,#f0a868 16%,#f5d76e 33%,#7fc9a0 50%,#5fd0d0 66%,#6aa8ff 83%,#b48cff 100%);
  /* 顶栏指标可读化（intel-topbar / hero 指标行 · 老板反馈 #1） */
  --metric-value:#e2e8f0; --metric-value-weight:600;
  --metric-label:#94a3b8; --metric-label-weight:500;
  --metric-glow:0 0 10px rgba(14,165,233,.22);
  /* emoji 亮色系徽章（§4.12 · 老板反馈 #2 · 推荐 B，保留 saturate(.82)） */
  --emoji-badge-bg:rgba(255,255,255,.08); --emoji-badge-shadow:inset 0 0 8px rgba(255,255,255,.06);
  /* 字体 */
  --font-ui:"Inter",-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;
  --font-mono:"JetBrains Mono","IBM Plex Mono","SF Mono",ui-monospace,monospace;
  /* 间距/圆角/阴影 */
  --space-1:4px;--space-2:8px;--space-3:12px;--space-4:16px;--space-5:20px;--space-6:24px;--space-8:32px;--space-12:48px;
  --radius-sm:8px;--radius-md:12px;--radius-lg:16px;--radius-pill:999px;
  --shadow-raised:0 2px 12px rgba(20,40,80,.25); --shadow-drawer:-16px 0 44px rgba(0,0,0,.50);
}
```

---
*文档状态：✅ 已核准（含裁定④ 大厂主题色强调板与高亮语义，2026-07-15 追加；含 2026-07-15 老板反馈 #1 顶栏指标可读化、#2 emoji 亮色系徽章，均不引入新偏离；**含 2026-07-15 V3 增量（裁定⑤ Hero 彩虹渐变、裁定⑥ 青绿山水背景）已定稿**），可直接移交筑原型。本文件不进入生产代码、不部署。*
