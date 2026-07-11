# Docker Desktop GHCR 构建通道诊断计划

> 状态：**只读诊断已结束，未修改 Docker Desktop 设置。** Gate 9 后续的证据表明临时容器可访问 GHCR 和 Docker Hub 的公开 registry API，而 Docker Engine/BuildKit 对两个 registry 的 metadata/pull 通道均卡住；这不是仅 GHCR 的问题，也没有获得可安全修改 Docker Desktop 配置的单一根因。

**Goal:** 记录 Docker Desktop engine 与普通容器 registry 访问的已知边界，避免在无单一根因时修改本机系统配置；RC 构建恢复改由 Gate 9 的受控本地 cache 路径处理。

**Architecture:** 先只读采集 Docker engine、Docker Desktop 设置键、宿主代理和网络证据；只在单一、可解释的配置根因被确认后，修改该本机 Docker 设置并重启 Docker Desktop，然后重新验证 metadata 与一次构建。每次只改变一个变量。

## Global Constraints

- 只处理本机 Docker Desktop；不得访问 NAS、Cloudflare、生产容器、`.env`、数据库或 TrendRadar 配置。
- 当前 RC 固定为 `codex/v2-beta-rc` / `8f7e385ac1453521a7ffffa9c5de43d725af76b9`，不得修改源码或 Dockerfile。
- 不显示、记录或提交代理凭据、token、完整代理 URL；诊断输出仅保留“已设置／未设置”、开关状态和非敏感错误类别。
- 不修改 Docker Desktop 设置，直到只读证据能指向一个明确的代理、DNS 或 registry 通道根因。
- 任何设置修改必须可通过恢复原文件或关闭该项回滚；修改后只重启 Docker Desktop，不触及任何业务容器。
- 不上传、保存或删除镜像；成功后只回到 Gate 9 的本地 build，不进入 NAS 同步。

## 诊断结论（2026-07-11）

- 宿主机与一次性临时容器能够完成 GHCR / Docker Hub 的 registry API 鉴权、manifest 查询和 blob HEAD。
- `docker pull`、`docker build` / BuildKit 的 metadata/pull 通道仍会卡住，重启 Docker Desktop 后未改善。
- 因没有确认到单一代理、DNS 或 registry 配置根因，未读取或改写 Docker Desktop 设置文件，未修改系统代理、DNS、Docker Desktop 设置或任何业务容器。
- Gate 9 已验证仅含 `/uv`、`/uvx` 的本地 stage cache 能绕过 GHCR metadata 阶段；后续应先完成官方 Python base cache 的受控恢复，而非继续修改 Docker Desktop。

## 已关闭的原始诊断任务

- [x] 记录主机/临时容器 registry API 成功与 Docker Engine metadata/pull 卡住的边界。
- [x] 确认没有足以支持单变量系统配置修改的单一根因。
- [x] 记录“不改 Docker Desktop 设置、转回 Gate 9 local cache recovery”的决定。

## 不执行的系统设置修复

- [ ] 不具备根因证据，故不备份或修改 Docker Desktop 设置、不再重启 Docker Desktop。
- [ ] 若未来需要重开本计划，必须先建立新的单一根因证据，不得将本文件视为设置修改授权。

## Gate Contract

**Gate name:** Gate 9A Docker Desktop registry 通道只读诊断（已关闭）。

**Allowed actions:** 只读本机 Docker／网络诊断；本轮未发生任何 Docker Desktop 设置修改。

**Forbidden actions:** TrendRadar 源码／Dockerfile／配置改动，`.env`、NAS、业务容器、镜像上传/导出/删除、Cloudflare、付费 AI、生产部署。

**Validation:** 已证明普通容器 registry API 与 Docker Engine/BuildKit pull 路径不一致；未发生设置写入，无需回滚。

**Stop conditions:** 没有明确根因，已停止；后续恢复只按 Gate 9 的 local cache 约束执行。

**Next Owner after completion:** Codex 仅执行 Gate 9 Python base cache 的受控恢复；RC 构建与容器验证仍完成前，禁止进入生产同步。
