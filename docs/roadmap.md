# Xjiankong 项目路线图

> 更新日期：2026-07-13。
>
> 本文件是项目的**主进度源**。进入项目后，先阅读根目录 `AGENTS.md`、适用的 `CLAUDE.md` 与本文件；再按链接进入对应的规格或实施计划。详细计划不等于已完成：只有实际验证过的结果才可改变本文件的状态。

## 一、当前基线

- 活动架构：A1 / TrendRadar；X Hosted MCP 已归档，不属于活动架构。
- 生产基线：`xjiankong-trendradar:v2-alpha-20260709`，TrendRadar `v2-alpha` / `33d80973`。
- v2-beta RC：功能基线 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`，Docker 构建兼容性提交 `5c02c6ce`；本地镜像与一次性容器验证已完成，尚未上传或部署。
- 当前采集来源：中文热榜、X 账号 RSS、GitHub/HuggingFace/Release RSS。小红书和公众号尚未接入。

## 二、执行顺序与状态

| 顺序 | 阶段 | 状态 | 前置条件 | 产出与验证 | 推荐模型 |
|---|---|---|---|---|---|
| 1 | Gate 9：本地 RC 镜像与临时容器验证 | 已完成 | 2026-07-13：固定镜像身份后，`RC_IMPORT_OK`、`RC_CONTAINER_OK` 均以退出码 0 通过，且无常驻验证容器 | `xjiankong-trendradar:v2-beta-rc-20260712`；详见 Gate 9 实施计划 | Terra 高 |
| 2 | Gate 10：v2-beta 生产同步与回滚方案 | 进行中 | 老板已确认采用镜像单点升级；当前仅完成生产同步设计，尚未访问 NAS 或执行生产写入 | Gate 10A—10D 独立闸门、回滚步骤和上线验收清单；每个生产闸门单独确认 | Sol 高 |
| 3 | v2-beta 上线后稳定性观察 | 未开始 | Gate 10 已获批准并完成生产部署 | 连续记录热榜、RSS、翻译、AI 分析、历史快照和公网安全路径；异常必须标明来源与影响 | Terra 高 |
| 4 | K/AI 过滤实验 | 未开始 | 冻结连续 7 天的同批新闻与 RSS SQLite 快照；建立不少于 300 条人工标注集 | 同快照下的 Variant K/AI 精确率、重要事件漏报、人工复核量与成本对比 | Sol 中 |
| 5 | 中文内容平台与 AIGC 赛道选型调研 | 未开始 | 阶段 3 已开始且主链无阻塞性问题；不改生产 | GitHub 候选项目清单、淘汰依据、公开来源可用性、四赛道监测设计 | Sol 中 |
| 6 | 单来源试点与质量验证 | 未开始 | 阶段 5 设计经老板确认；获得对应外部配置批准 | 单一来源、最小关键词/分类、命中质量和稳定性报告；不自动扩大范围 | Terra 高；国产模型须先校准 |
| 7 | 扩展来源与报告展示 | 未开始 | 试点达到验收标准并获老板确认 | 受控来源扩展；必要时新增独立内容板块；完整回归和生产闸门 | Sol 中／高 |

除阶段 3 的稳定性观察与阶段 4 的离线样本准备可并行外，其他阶段必须按顺序推进。阶段 5 只允许研究与设计，不允许接入、部署或修改生产配置。

## 三、Gate 9：已完成

**目标：** 从冻结 RC 构建本地 `linux/amd64` 镜像，并在无生产配置的一次性容器中完成免费验证。

**最终结果：** `xjiankong-trendradar:v2-beta-rc-20260712` 已构建为 `linux/amd64` 镜像，ID `sha256:91983de58c07a12c9fc0ada28474e1d48de26b5a126c3d8fd7f6971f7a748ee4`，大小 `138,047,386` bytes。

**完成边界：** Gate 9 只产生本地 base cache、最小 Dockerfile 兼容性提交、本地 RC 镜像与一次性验证容器；未上传镜像，未访问 NAS、`.env`、现有生产容器、Cloudflare 或付费 AI。

**确认闸门：** 老板已在当前对话明确开始 Gate 9。清理范围仍只限已核验的 714B 标签；导入的 Python base cache 必须先通过官方 OCI config 等价性闸门，才允许重试构建。

**2026-07-12 执行记录：** 执行 Agent 在删除前完成 RC、Docker、714B 标签和 uv cache 的只读复核；其临时 OCI 恢复脚本的 Registry 前置查询没有返回可审计 stdout/stderr，遂按停止条件停止并清理临时脚本。没有删除、下载 layer、写 rootfs、导入镜像、构建、运行容器或访问生产。主控直接验证 `HEAD https://registry-1.docker.io/v2/` 可稳定返回公开的 `401 Bearer` challenge，故当前未知点限定为恢复脚本的可观测性，不是 Docker Hub 路由不可达。下一步仅是新的只读逐阶段可观测性预检。

**2026-07-12 预检通过记录：** 修正规则后，执行 Agent 以 HTTP `401` 加 Bearer challenge 作为 `HEAD /v2/` 成功条件；Registry token 仅存在于进程内，manifest 查询返回 HTTP `200` 并解析到 7 个架构描述符。临时脚本和 6 行无敏感日志均已清理。该预检不证明 OCI layer/config 或 base cache 恢复，仅允许重新开始 Gate 9 的删除前精确核验。

**2026-07-12 恢复尝试记录：** 执行 Agent 再次核验后，仅删除 `python:3.12-slim-bookworm` 的已记录 714B 无效标签，并立即确认标签不存在；唯一 `linux/amd64` child manifest 与 digest 校验通过。官方 config blob 的原始字节未与 descriptor sha256 匹配，脚本未证明是否正确处理 Registry 重定向，遂停止。没有下载 layer、写 rootfs、import、build、容器运行、项目文件或生产操作；临时脚本、日志和目录均已清理。下一步仅为只读 Gate 9B 传输保真审计。

**2026-07-12 Gate 9B 通过记录：** config blob 初始 endpoint 返回 307 且有 Location；安全跟随后为 HTTP 200，最终原始字节 sha256 与官方 descriptor 完全一致。日志只含状态、布尔值和退出码，敏感扫描无命中并已清理。该结果仅解除 config blob 传输疑点；layers、DiffID、rootfs、import config 等价性和 RC 构建仍待验证。

**恢复路径修订：** 本机没有 `skopeo`、`crane`、`regctl`、`oras` 等专用 OCI 工具，手工 rootfs 路径又两次止于脚本可观测性。Gate 9 改用无新增依赖的 Docker load archive：对官方 config/layers 做原始 digest 与 DiffID 校验后，以官方原始 config 和未压缩 layer tar 构造临时 Docker image archive，再由 `docker load` 应用 layers。该路径不手工处理 whiteout，也不使用会丢失 config 的 `docker import`；仍只生成本地缓存、不得上传或接触生产。

**2026-07-12 base cache／build 记录：** Docker load archive 恢复通过，`python:3.12-slim-bookworm` 当前为 `linux/amd64`、`129,079,727` bytes，Python 运行验证通过，临时 archive/blob/layer/日志均已清理。随后按“仅一次”约束执行 RC build，失败于 Dockerfile 的构建期 `supercronic -version`：本机 ARM Docker 在模拟执行 amd64 Go 二进制时崩溃。RC 镜像未生成，未重试，未运行 RC 容器验证。下一步是单独的最小兼容性修复 Gate：保留 supercronic 下载 SHA-1 校验和运行时二进制，只移除该构建期跨架构执行自检。

**2026-07-13 构建兼容性修复记录：** 隔离 worktree 提交 `5c02c6ce` 仅将构建期 `supercronic -version` 改为 `/usr/local/bin/supercronic` 的可执行权限断言；下载 SHA-1 校验、路径和运行时行为未变。唯一重新 build 成功，RC 镜像 `xjiankong-trendradar:v2-beta-rc-20260712` 为 `linux/amd64`、`138,047,386` bytes。第一次 `RC_IMPORT_OK` 临时容器没有留下成功输出，故不记为通过；容器已自动移除，尚未执行后续 `RC_CONTAINER_OK`。下一步仅为不重建镜像的可观测容器验证 Gate。

**2026-07-13 Gate 9.6 停止记录：** 执行 Agent 以 120 秒超时启动原 `RC_IMPORT_OK`，但执行通道结束后没有返回 stdout、stderr、退出码，且预定系统临时日志不可见；因此没有可审计成功证据。严格未执行 `RC_CONTAINER_OK`，最终无基于 RC 镜像的容器。下一步必须更换为能可靠保留命令输出和临时日志的执行上下文；不得在当前通道继续重复容器断言。

**2026-07-13 Gate 9.7 完成记录：** 独立 Agent 先只读审计原断言与执行边界；主控随后在可保留输出的本地会话中对固定镜像顺序执行两条一次性容器断言。`RC_IMPORT_OK` 与 `RC_CONTAINER_OK` 均为退出码 0 且只有对应成功标记；最终 `docker ps -a --filter ancestor=xjiankong-trendradar:v2-beta-rc-20260712` 无输出，镜像身份未漂移。新的独立验收 Agent 复核证据链后同意 Gate 9 完成；未执行 Gate 10 或任何生产动作。

**详细入口：** [Gate 9 实施计划](superpowers/plans/2026-07-11-v2-beta-rc-image-validation.md)、[v2-beta 设计与 Gate 9 验证记录](superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md)。

## 四、Gate 10 与稳定性观察

Gate 10 以 Gate 9 的实际镜像 ID、平台、大小和容器验证结果为输入，另行制定：备份点、传输方式、镜像切换、容器重建、功能验收、公开路径安全检查、失败回滚和停止条件。计划完成后仍须老板单独确认，不能因 Gate 9 完成而自动执行。

**2026-07-13 设计决策：** 老板确认采用“镜像单点升级”。Gate 10 不同步整个部署包，不覆盖 Compose、配置、代理或输出；只在完成 NAS 只读基线与受限备份后，导入固定 RC 镜像、修改 `.env` 的 `TRENDRADAR_IMAGE` 一行并只重建 `trendradar`。执行拆为 Gate 10A 只读基线、10B 备份与镜像传输、10C 镜像切换与免费验收、10D 一次付费全链路验收，禁止自动连续执行。详细设计见 [v2-beta 生产镜像单点升级设计](superpowers/specs/2026-07-13-v2-beta-production-image-switch-design.md)。

生产部署、NAS 操作、`.env` 改动、容器重建、Cloudflare 变更、付费 AI 调用均需要老板在当前对话中逐项确认。稳定性观察只记录实际结果；不得把单次成功写成长期稳定。

## 五、后续能力：中文内容平台与 AIGC 赛道

### 5.1 范围

第一批赛道固定为：AI 漫剧、AIGC 视频制作、AI 小说、AI 音乐。

初始目标是记录可追溯的信号和证据来源：平台规则、榜单/热度、公开播放或互动数据、工具更新、价格/版权变化与可核验商业化案例。新闻热度不等于创业机会；第一阶段不输出投资建议或确定性创业结论。

### 5.2 数据源选型规则

每个新渠道先搜索 GitHub 上持续维护的项目或适配器，再决定是否集成或自建。候选项目至少审查：近 90 天提交或 release 活跃度、开放 issue 响应、许可证、认证/Cookie 依赖、输出格式、部署成本、维护风险和与 TrendRadar 的 RSS/JSON 对接方式。

- 小红书：优先验证公开热搜或公开趋势来源；不以 Cookie 爬取作为主方案。
- 公众号：只接受无需登录、无需 Cookie、可长期追溯的公开来源；没有满足条件的方案即明确暂缓，不绕过平台限制。
- 能使用稳定 RSS、JSON 或既有适配器时，优先集成；仅当候选项目不满足需求、不可维护或不合规时，才设计最小自建桥接。

### 5.3 阶段 5 的交付物

1. `中文内容平台情报源可行性与集成选型`：小红书、公众号候选 GitHub 项目、活跃度证据、淘汰理由与建议。
2. `AIGC 内容赛道监测设计`：四赛道的来源、关键词、分类规则、可信度层级、命中/误报验收标准与报告归位。

这两个交付物完成并经老板确认前，不创建新生产数据源、不写抓取器、不写 Cookie 方案、不修改 NAS 配置。

## 六、进度更新规则

- 每完成一个 Gate、生产动作、重要调研或状态变化，先更新本文件，再更新对应详细计划或规格。
- 状态只能使用“未开始”“进行中”“阻塞”“待确认”“已完成”；“已完成”必须附验证日期与链接。
- 发现新的阻塞或实际复杂度变化时，记录事实、影响范围和恢复条件；不得静默跳过闸门。
- 多 Agent 或预计超过 30 分钟的任务，在详细计划中为每个任务写明具体模型、强度、选择依据和验证方式；当前表中的模型为推荐分配，不代表平台一定支持实际切换。

## 七、详细资料索引

- [活动架构与数据边界](../ai-intelligence-hub-design.md)
- [Gate 9 本地镜像验证计划](superpowers/plans/2026-07-11-v2-beta-rc-image-validation.md)
- [v2-beta 设计与 Gate 9 验证记录](superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md)
- [Gate 10 v2-beta 生产镜像单点升级设计](superpowers/specs/2026-07-13-v2-beta-production-image-switch-design.md)
- [AIGC 应用风向的既有设计](superpowers/specs/2026-07-09-v2-beta-intelligence-history-ui-design.md)
- [GitHub AI 追踪现状](github-ai-tracking-plan.md)
