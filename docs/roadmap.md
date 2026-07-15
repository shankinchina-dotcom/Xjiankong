# Xjiankong 项目路线图

> 更新日期：2026-07-15。
>
> 本文件是项目的**主进度源**。进入项目后，先阅读根目录 `AGENTS.md`、适用的 `CLAUDE.md` 与本文件；再按链接进入对应的规格或实施计划。详细计划不等于已完成：只有实际验证过的结果才可改变本文件的状态。

## 一、当前基线

- 活动架构：A1 / TrendRadar；X Hosted MCP 已归档，不属于活动架构。
- 生产基线：`xjiankong-trendradar:v2-beta-rc-20260713`（2026-07-14 经 Gate 10 切换上线，10D 付费全链路验收通过）；回滚基线保留 `v2-alpha-20260709` / `sha256:ea2d7183483d9026618a3d85313ac293087200e5a576b4e506366fc3bc83bb9d`。
- v2-beta RC：功能基线 `8f7e385ac1453521a7ffffa9c5de43d725af76b9`，Docker 构建兼容性提交 `5c02c6ce`，Gate 9.1 最终 HEAD `61ba3932`；已部署至生产（Gate 10，2026-07-14），见下方 Gate 10 完成记录。
- V4 编辑型报告：视觉与信息层级已由老板确认，权威原型为 `docs/superpowers/prototypes/2026-07-15-xjiankong-report-v4-editorial.html`。状态：**本地代码 `18c1fbad`；本地 RC `v2-beta-v4-rc-20260715` 已验证；Task 6 V4-A／V4-B 已完成**（NAS 备份 `v4-rc-20260715-224353`；tar SHA `88b1273f…`；NAS load Config ID `sha256:365c92d5…`；14 层 DiffID 与 chain `a6e19f41…` 全等；NAS 免费断言通过；生产仍为 `v2-beta-rc-20260713`，四容器身份未变）；**尚未切换生产、尚未付费验收；待 Codex 审查后单独确认 Task 7**。设计与交接入口见 [V4 设计规格](superpowers/specs/2026-07-15-v4-editorial-report-ui-design.md) 和 [V4 生产实施计划](superpowers/plans/2026-07-15-v4-editorial-report-production.md)。
- 当前采集来源：中文热榜、X 账号 RSS、GitHub/HuggingFace/Release RSS。小红书和公众号尚未接入。

## 二、执行顺序与状态

| 顺序 | 阶段 | 状态 | 前置条件 | 产出与验证 | 推荐模型 |
|---|---|---|---|---|---|
| 1 | Gate 9／9.1：本地 RC 镜像、无障碍加固与临时容器验证 | 已完成 | 2026-07-13：代码审查、真实 Chrome 交互、`RC_IMPORT_OK`、`RC_CONTAINER_OK` 均通过，且无常驻验证容器 | `xjiankong-trendradar:v2-beta-rc-20260713`；详见 Gate 9.1 实施计划 | Terra 高／Sol 高 |
| 2 | Gate 10：v2-beta 生产同步与回滚方案 | 已完成（10A–10D 全部通过） | 10A/10B 已完成；老板已接受 RootFS 等价作为 10B 通过；10C 已执行（2026-07-14）；10D 一次付费全链路验收已通过（2026-07-14） | 10C/10D 见下方完成记录；[Gate 10D 交接文档](gate10d-handoff.md)；进入阶段 3 稳定性观察 | Sol 高 |
| 3 | v2-beta 上线后稳定性观察 | 进行中 | Gate 10 已获批准并完成生产部署（10A–10D 全通过） | 连续记录热榜、RSS、翻译、AI 分析、历史快照和公网安全路径；异常必须标明来源与影响；已起每 4h 定时只读观察，日志 `docs/stability-observation.md` | Terra 高 |
| 4 | V4 编辑型报告生产化 | V4-A／V4-B 完成，待 Task 7 | Task 1–6 完成；NAS 已 load V4 RC 但生产未切换；禁止自动进入 Task 7 | 下一步：Codex 审查 → 老板单独确认后仅改 `TRENDRADAR_IMAGE` 并只重建 trendradar，见 V4 生产实施计划 | Terra 高／Sol 高 |
| 5 | K/AI 过滤实验 | 未开始 | 冻结连续 7 天的同批新闻与 RSS SQLite 快照；建立不少于 300 条人工标注集 | 同快照下的 Variant K/AI 精确率、重要事件漏报、人工复核量与成本对比 | Sol 中 |
| 6 | 中文内容平台与 AIGC 赛道选型调研 | 未开始 | 阶段 3 已开始且主链无阻塞性问题；不改生产 | GitHub 候选项目清单、淘汰依据、公开来源可用性、四赛道监测设计 | Sol 中 |
| 7 | 单来源试点与质量验证 | 未开始 | 阶段 6 设计经老板确认；获得对应外部配置批准 | 单一来源、最小关键词/分类、命中质量和稳定性报告；不自动扩大范围 | Terra 高；国产模型须先校准 |
| 8 | 扩展来源与报告展示 | 未开始 | 试点达到验收标准并获老板确认 | 受控来源扩展；必要时新增独立内容板块；完整回归和生产闸门 | Sol 中／高 |

阶段 3 的稳定性观察可与阶段 4 的本地实现并行，但任何异常未解释前不得执行 V4 生产切换。阶段 5 的离线样本准备可并行；阶段 6 只允许研究与设计，不允许接入、部署或修改生产配置。

## 三、Gate 9：已完成

**目标：** 从冻结 RC 构建本地 `linux/amd64` 镜像，并在无生产配置的一次性容器中完成免费验证。

**最终结果：** Gate 9.1 新 RC `xjiankong-trendradar:v2-beta-rc-20260713` 已构建为 `linux/amd64` 镜像，ID `sha256:3c02dceafa861709ce6bbbd0dc2136b5a9b9db0827bf114f280cb1581b87ab4f`，大小 `138,032,730` bytes。旧 `20260712` 镜像只保留为历史证据，不再作为 Gate 10 输入。

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

**2026-07-13 Gate 9.1 完成记录：** 基于 `awesome-design-md` 的设计审查发现历史抽屉缺少稳定的键盘焦点边界。TrendRadar 先以 TDD 增加无障碍契约与 Node 行为测试，再由提交 `fabe867f`、`61ba3932` 补齐对话框语义、可见焦点、Tab 循环、关闭回焦、关闭态 `inert`、移动端触控尺寸和减弱动画。独立审查首次拦截屏外抽屉仍可进入 Tab 顺序的问题，修正后复审通过；主控以 390px Chrome CDP 验证关闭态 Tab、三条关闭路径、首尾循环、44/44/24px 触控尺寸、无横向滚动和 `reduced-motion`。新 RC `v2-beta-rc-20260713` 的 `RC_IMPORT_OK` 与扩展 `RC_CONTAINER_OK` 均退出码 0，最终无残留验证容器；未上传镜像，未访问 NAS、`.env`、生产容器、付费 AI 或 Cloudflare。

**详细入口：** [Gate 9 实施计划](superpowers/plans/2026-07-11-v2-beta-rc-image-validation.md)、[Gate 9.1 无障碍加固计划](superpowers/plans/2026-07-13-v2-beta-gate9-1-accessibility-hardening.md)、[v2-beta 设计与 Gate 9 验证记录](superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md)。

## 四、Gate 10 与稳定性观察

Gate 10 以 Gate 9.1 的实际镜像 ID、平台、大小和容器验证结果为输入，另行制定：备份点、传输方式、镜像切换、容器重建、功能验收、公开路径安全检查、失败回滚和停止条件。计划完成后仍须老板单独确认，不能因 Gate 9.1 完成而自动执行。

**2026-07-13 设计决策：** 老板确认采用修正版“镜像单点升级 + 两个历史文件精确白名单”。Gate 10 不同步整个部署包，不覆盖 Compose、运行配置、代理或输出；只在完成 NAS 只读基线与受限备份后，导入固定 RC 镜像、修改 `.env` 的 `TRENDRADAR_IMAGE` 一行，并为 `/history.json`、`/history.html` 增加精确白名单。执行拆为 Gate 10A 只读基线、10B 备份与镜像传输、10C 镜像/Nginx 切换与免费验收、10D 一次付费全链路验收，禁止自动连续执行。详细设计见 [v2-beta 生产镜像单点升级设计](superpowers/specs/2026-07-13-v2-beta-production-image-switch-design.md)，逐命令实施计划见 [Gate 10 生产同步实施计划](superpowers/plans/2026-07-13-v2-beta-gate10-production-sync.md)。

**2026-07-13 实施计划补充：** 当前 Nginx 通用规则会拦截 `.json`，因此两个精确白名单是 v2-beta 历史功能的必要发布变更。老板已确认 Gate 10C 只重建 `trendradar` 与 `report-web`；`rss-proxy`、`cloudflared`、Cloudflare 及其他配置保持不变。实施计划已补齐模型分配、SHA-256 传输校验、受限备份、禁止自动清理和回滚条件；下一步仅为 Gate 10A 只读核验。

**2026-07-13 Gate 10A 首次预检停止记录：** 主控与独立执行 Agent 对 `192.168.1.193:22` 的首条只读 SSH 预检均连接超时，未建立会话，也未读取 NAS 配置或执行任何写入。

**2026-07-13 Gate 10A 完成记录：** 局域网可达后完成 Mac→NAS 公钥登录与 `sudo -n docker` 免密；从 10A-1 起完整只读核验通过。未创建备份、未上传/加载镜像、未修改 `.env`/nginx/Compose、未重建容器、未触发采集。

| 字段 | 实测 |
|---|---|
| 四容器 | trendradar / report-web(healthy) / cloudflared / rss-proxy 均 running |
| 生产镜像标签 | `xjiankong-trendradar:v2-alpha-20260709` |
| 生产镜像 ID（可回滚引用） | `sha256:ea2d7183483d9026618a3d85313ac293087200e5a576b4e506366fc3bc83bb9d`（amd64，372,556,889 bytes） |
| NAS 上 v2-beta RC | 不存在（符合 10A 预期） |
| 磁盘 | `/volume1` 可用 1.3T |
| 挂载 | trendradar：`config` ro + `output` rw；report-web：`nginx.conf` ro + `output` ro |
| 网络 | trendradar+rss-proxy → `xjiankong_collector`；report-web+cloudflared → `xjiankong_publish` |
| nginx history | 0 命中；仍有通用 `.json` 拦截 |
| output | news 8 / rss 8 / html 53 文件；`index.html` SHA-256 `b63a12cea7e2ab44eeec8216e611425502df637c24584833a79c26a975649a99` |
| 本地 RC | `sha256:3c02dceafa861709ce6bbbd0dc2136b5a9b9db0827bf114f280cb1581b87ab4f`，linux/amd64，138,032,730 bytes |
| 公网抽检 | `/` 200；`/.env` 与 `/news/test.db` 404 |
| 备注 | report-web `RestartCount=43`（历史累计，当前 healthy）；DSM Compose 无 `config --networks`，网络以 inspect 为准 |

**2026-07-13 Gate 10B 执行记录：** 老板确认后执行。备份、归档传输与 NAS 免费断言均完成；**生产仍为 v2-alpha，未改 `.env`/nginx、未重建容器、未触发采集。**

| 字段 | 实测 |
|---|---|
| 备份目录 | `/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051`（17 文件，manifest SHA 校验通过，`.env`/proxy 权限 600） |
| 旧快照冻结 | `html/2026-07-13/20-05.html` |
| 本地 tar SHA-256 | `be16f6d9f34e43f9e3e12658819705ab001a98ef5e526e54febe07f979cc7dce`（138,057,216 bytes） |
| NAS tar 校验 | 与本地一致（`sha256sum -c` OK） |
| 本地 RC Config ID（冻结） | `sha256:3c02dceafa861709ce6bbbd0dc2136b5a9b9db0827bf114f280cb1581b87ab4f`，Size 138,032,730 |
| NAS load 后 Config ID | `sha256:c122cdb56076ed3e0342a2c348537d0f9bd4d48ea2955271489049e7147688b9`，Size 373,323,120 |
| RootFS DiffID 链 | 本地与 NAS **14 层完全一致**；chain SHA-256 `8ca4f36b2b5ee7acbff72221b3f9b16a981d6ed81eb7770dc1ea2b45ce735715` |
| 平台 / Created / Entrypoint | amd64/linux；Created `2026-07-13T06:58:18Z`；entrypoint `/entrypoint.sh`；WorkingDir `/app` — 一致 |
| `RC_IMPORT_OK` | 退出成功，打印 `RC_IMPORT_OK`；无残留验证容器 |
| 生产未变 | 运行中仍为 `v2-alpha-20260709` / `sha256:ea2d7183483d...`；`.env` 镜像行未改 |
| 传输物保留 | NAS `/tmp/v2-beta-rc-20260713.tar` 与 `.sha256` 未删除（计划要求 Gate 10 完成前保留） |

**判定（初判）：** 严格按设计「镜像 ID/大小必须等于冻结值」→ Config ID 与 Size 未通过。内容等价证据为 tar 校验 + RootFS DiffID 全等 + 免费 import 断言。常见原因是 Docker Desktop（Mac）与群晖 Docker 引擎的镜像 store/config 摘要算法不同，load 后 Config digest 重算而 DiffID 不变。

**2026-07-13 老板裁定（Gate 10B 身份）：** **接受 RootFS 等价** 作为 Gate 10B 通过。同时明确：**不立即执行 10C**；保留完整证据，由老板另开 Agent 会商后再决定 10C 身份核对策略与是否批准生产切换。接受不等于批准 10C/10D。

| 用途 | 固定值（后续 Agent 必须沿用） |
|---|---|
| 标签 | `xjiankong-trendradar:v2-beta-rc-20260713` |
| 本地 Config ID（Gate 9.1 冻结，Mac Docker Desktop） | `sha256:3c02dceafa861709ce6bbbd0dc2136b5a9b9db0827bf114f280cb1581b87ab4f` |
| **NAS 运行侧 Config ID（load 后，10C 核对建议用此值）** | `sha256:c122cdb56076ed3e0342a2c348537d0f9bd4d48ea2955271489049e7147688b9` |
| RootFS DiffID chain SHA-256（14 层，Mac=NAS） | `8ca4f36b2b5ee7acbff72221b3f9b16a981d6ed81eb7770dc1ea2b45ce735715` |
| 传输 tar SHA-256 | `be16f6d9f34e43f9e3e12658819705ab001a98ef5e526e54febe07f979cc7dce` |
| 备份目录 | `/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051` |
| 备份指针文件 | NAS `/tmp/xjiankong-gate10-backup-dir` |
| NAS 身份摘录 | 备份内 `nas-rc-identity.txt`（若存在） |
| 回滚镜像 | `v2-alpha-20260709` / `sha256:ea2d7183483d9026618a3d85313ac293087200e5a576b4e506366fc3bc83bb9d` |
| 当前生产 | 仍为 v2-alpha；未改 `.env`、nginx、Compose；未重建容器；未付费采集 |

**会商决议（2026-07-14 老板裁定，已落实至设计规格）：**

1. 10C 运行侧断言以 NAS load 后 Config ID `sha256:c122cdb56076...` 为准；Mac 冻结 ID `3c02dceafa86...` 仅作构建来源记录。
2. 设计规格 §二/§四/§六 的「ID/大小必须等于冻结值」已修订为「tar SHA-256 + RootFS DiffID chain 全等 + 平台一致；运行侧 Config ID 以 NAS load 后值为准」。
3. 可选加固（在 linux/amd64 宿主直接 build 或 skopeo/crane 同源传输以使 Config ID 也一致）非 10C 前置硬阻塞，排到 10C 之后。
4. 10C 仍须单独批准：只改 `TRENDRADAR_IMAGE` 一行 + nginx 两个精确 history 白名单 + 只重建 trendradar/report-web。
5. 不得删除备份、NAS/本地 tar、v2-alpha 镜像；清理须老板另行批准。

**2026-07-14 Gate 10C 完成记录：** 经老板批准，主理人从沙箱经密钥 SSH 接手执行 10C（NAS 端临时启用 NOPASSWD sudoers 以便免密 sudo）。结果：

- 10C-0 中断状态机：`original`（v2-alpha 仍运行、生产 nginx 未改、.env 仅镜像行待改）。
- 10C-1 Nginx：候选 `f64f603bc6702fb84cdf8395601f8e9643c22ec8766f4be47fdeb1eeca7c4f4c` 已写入生产；在通用 `.json` 拦截前插入两个精确白名单 `location = /history.json`、`location = /history.html`（`try_files $uri =404;`）；`nginx -t` 通过；fixture 容器内 `history.json`/`history.html`=200、`other.json`/`.env`/`news/test.db`/`config/config.yaml`=404（busybox wget 在 404 时退出码非零，原 `set -e` 误判为假失败，改为逐路径断言后通过）；写入带备份回滚陷阱。
- 10C-3 .env：仅 `TRENDRADAR_IMAGE` 改为 `xjiankong-trendradar:v2-beta-rc-20260713`；masked-SHA 证明仅该行变化。
- 10C-4 重建：仅 `--no-deps --force-recreate trendradar report-web`；容器内 `/etc/nginx/nginx.conf` SHA = 主机 = 候选；trendradar 镜像 = `sha256:c122cdb56076ed3e0342a2c348537d0f9bd4d48ea2955271489049e7147688b9`（NAS RC ID）。
- 10C-5 免费验收：四容器均 Up（report-web healthy）；trendradar 为 RC 镜像且无 ModuleNotFoundError/ImportError；公网 `/`=200、`.env`/`news/test.db`/`config/config.yaml`/`output/news/data.json`=404；`/history.json`、`/history.html`=404（首份 v2-beta 报告未生成前属预期，Gate 10D 付费运行后转 200）；10B 冻结旧快照 `html/2026-07-13/20-05.html` 字节级一致（SHA+mtime）；cloudflared/rss-proxy 的 ID/StartedAt/RestartCount 与 10B 完全一致（未被部署触碰）。output 目录较 10B 增长（news 8→9、rss 8→9、html 53→59 文件）系 7 天正常 cron 采集所致，无删除或缩减，非部署问题。
- 结论：Gate 10C 通过，生产已切换至 v2-beta-rc-20260713；v2-alpha-20260709 保留作回滚基线。Gate 10D（一次付费全链路验收）待老板单独确认，禁止自动进入。

**2026-07-14 Gate 10D 进行中（交接）记录：** 经老板确认「先做 10D」，主理人从沙箱触发一次付费全链路验收。结果（进行中）：

- 10D-1 并发预检通过：无运行中的采集进程；supercronic 调度 `0 */4 * * *`，本次手动跑 23:29 启动，下一次自动触发 00:00，无窗口冲突。
- 前置状态已记录（23:21）：`history-before.sha256=absent`、`latest-before.txt=absent`、`snapshots-before.txt=59` 行、旧快照冻结 `html/2026-07-13/20-05.html`。
- attempt 1 触发失败（计划命令坑）：`docker exec ... sh -lc "cd /app && python -m trendradar"` 的 **login shell 重置 PATH 丢掉 venv**，误报 `ModuleNotFoundError: pytz`，import 阶段秒挂（RC=1，0 秒，**未消耗付费 API**）。证据存 `gate10d-attempt1-*`。**镜像正常**，生产 cron 用非 login `sh -c` 不受影响。
- attempt 2 已用修正命令（`/app/.venv/bin/python` 绝对路径 + 非 login `sh -c`，`setsid` 脱离 SSH）重新触发；截至交接 stdout 已到 `[AI] 分析完成` + `翻译 27 条`，stderr 0 字节，`/app/output/history.json` 已生成（8070 B，23:34），完成标记即将写出。
- **交接**：老板准备另开 agent 接手跑完 10D-2 机器断言 + 10D-3 清单。完整状态、坑说明与逐条命令见 [Gate 10D 交接文档](gate10d-handoff.md)。纪律不变：禁止重跑/改配置/回滚/清理；任何断言缺失即停并进入 Sol 高复核。

**2026-07-14 Gate 10D 完成记录：** 主理人接手完成 10D-2 机器断言 + 10D-3 验收清单（attempt 2 已于 23:34 完成，RC=0，288 秒，stderr 干净）。结果：

- 10D-2：`history.json` 白名单全过（根键/`latest`/路径格式/敏感键扫描/唯一 `is_latest`/latest 指向实体文件；58 个历史版本，`latest=/html/2026-07-14/23-34.html`）；前后差分通过（history `absent`→`09d8c0b2…`，新增快照正好 1 个，新文件 mtime 落在运行窗口 `[1784042991,1784043279]`）；页面精确 8 个 `report-section`（id 01–08）。
- 10D-3：四容器 Up（report-web healthy）；无 import 错误（stderr 0 字节）；`[AI] 分析完成`（deepseek-chat）；新快照 `html/2026-07-14/23-34.html`；`history.json`(8070B)+`history.html`(3884B) 已生成；公网 `/`、`/history.json`、`/history.html`、新/旧快照均 200；`/.env`、`/news/test.db`、`/config/config.yaml`、`/output/news/data.json` 全 404；8 板块；深空主题（gradient + 深蓝调色板）；`hotlist-section`/`evidence-stream`/`x.com`(21,Nitter→X fallback)/`history-drawer`/`R0`(52)+`source-ref`(176) 标记均在；旧快照 `html/2026-07-13/20-05.html` 保留且 200；运行唯一（一次跑 288s，一个新快照）。
- 固定证据：热榜 10/11（baidu 上游 `newsnow.busiyi.world` 返回 500，按来源解释的波动；5 最新+5 缓存）；RSS 41/44——Nitter 30/33（xai 404、elonmusk 429、GabrielPeterss4 404；单个不触发回滚）、非 Nitter 11/11；翻译 27/27 全成功；AI `分析完成`。
- 计划 pattern 不精确（非报告缺陷，已记录）：8-section 朴素 pattern 数到 16（=8 `report-section` + 8 `report-section-content`）；hotlist pattern `热榜.*X/Y` 未命中（日志用「成功:[…], 失败:[…]」格式）；`[R0` pattern 未命中（报告用裸 `R0` + `source-ref`，非 `[R0` 带括号）。
- 结论：**Gate 10D 通过，Gate 10（10A–10D）全部完成**；生产基线 `xjiankong-trendradar:v2-beta-rc-20260713` 稳定。未自动清理/回滚/删 NOPASSWD sudoers/备份/tar/v2-alpha 镜像。

**当前停点：** Gate 10（10A–10D）全部通过，v2-beta 已完成生产同步与一次付费全链路验收；**进入阶段 3 稳定性观察**（建议连续 3 个 cron 周期 ~12h 记录热榜/RSS/翻译/AI/历史快照/公网安全路径）。NAS 上 NOPASSWD sudoers `/etc/sudoers.d/xjiankong-gate10` 仍在，清理须老板确认。进度与计划入口：[Gate 10 设计](superpowers/specs/2026-07-13-v2-beta-production-image-switch-design.md)、[Gate 10 实施计划](superpowers/plans/2026-07-13-v2-beta-gate10-production-sync.md)、[Gate 10D 交接文档](gate10d-handoff.md)。

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
- [Gate 9.1 上线前无障碍加固计划](superpowers/plans/2026-07-13-v2-beta-gate9-1-accessibility-hardening.md)
- [v2-beta 设计与 Gate 9 验证记录](superpowers/specs/2026-07-10-v2-beta-deep-space-report-ui-design.md)
- [Gate 10 v2-beta 生产镜像单点升级设计](superpowers/specs/2026-07-13-v2-beta-production-image-switch-design.md)
- [Gate 10 v2-beta 生产同步实施计划](superpowers/plans/2026-07-13-v2-beta-gate10-production-sync.md)
- [Gate 10D 交接文档](gate10d-handoff.md)
- [AIGC 应用风向的既有设计](superpowers/specs/2026-07-09-v2-beta-intelligence-history-ui-design.md)
- [GitHub AI 追踪现状](github-ai-tracking-plan.md)
