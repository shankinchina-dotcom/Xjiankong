# v2-beta RC 容器验证可观测性计划

> 状态：已完成。2026-07-13 更换为可保留输出的主控本地执行会话后，`RC_IMPORT_OK` 与 `RC_CONTAINER_OK` 均以退出码 0 通过；最终无残留容器，镜像身份未漂移。

**Goal:** 以可审计 stdout、退出码和无残留容器证明 `xjiankong-trendradar:v2-beta-rc-20260712` 可以完成原 Gate 9 的模块导入与报告断言。

## Gate Contract

**Allowed actions：** 仅对现有本地 RC 镜像运行原 Gate 9 的两条 `docker run --rm` 断言，使用临时、非敏感日志记录 stdout/stderr、退出码与超时状态；执行结束后清理日志。

**Forbidden actions：** build、修改镜像、Docker 设置、NAS、`.env`、生产容器、Cloudflare、付费 AI、Gate 10。

1. 先用 `docker run --rm --entrypoint python` 执行原 `RC_IMPORT_OK` 命令，并将 stdout/stderr 与退出码写入系统临时日志。
   验证：退出码 0，日志包含且只包含一次 `RC_IMPORT_OK`，日志无敏感内容。
2. 仅在步骤 1 通过后，执行原 `RC_CONTAINER_OK` heredoc 断言，同样记录 stdout/stderr 与退出码。
   验证：退出码 0，日志包含 `RC_CONTAINER_OK`；无宿主机输出文件。
3. 检查 `docker ps -a --filter ancestor=xjiankong-trendradar:v2-beta-rc-20260712` 无输出，审查并删除临时日志。
   验证：无残留容器、日志不含凭据。

## Gate 9.7 最终记录

- 目标镜像：`xjiankong-trendradar:v2-beta-rc-20260712`，ID `sha256:91983de58c07a12c9fc0ada28474e1d48de26b5a126c3d8fd7f6971f7a748ee4`，`linux/amd64`，`138,047,386` bytes。
- `RC_IMPORT_OK`：退出码 0，唯一 stdout 为成功标记，无 traceback。
- `RC_CONTAINER_OK`：仅在导入断言通过后执行；退出码 0，唯一 stdout 为成功标记，测试文件只存在于容器临时目录。
- 残留检查：`docker ps -a --filter ancestor=xjiankong-trendradar:v2-beta-rc-20260712` 无输出。
- 独立验收：新的 Sol 高标准验收 Agent 复核固定镜像身份、执行顺序、断言结果和禁止边界后，同意 Gate 9 完成。
- 未执行：build、镜像上传、NAS、`.env`、生产容器、Cloudflare、付费 AI 或 Gate 10。

**Next Owner：** Codex 主控完成文档质量检查；Gate 10 必须由老板单独确认后才可执行。
