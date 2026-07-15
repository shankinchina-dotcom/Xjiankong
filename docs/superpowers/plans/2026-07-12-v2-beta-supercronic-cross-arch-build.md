# v2-beta supercronic 跨架构构建兼容性实施计划

> 状态：待执行。只解决 Gate 9 已验证的本机构建阻塞：ARM Docker 模拟执行 amd64 `supercronic -version` 崩溃。

**Goal:** 保留 supercronic 下载 SHA-1 校验、二进制路径和运行时行为，但不在 ARM 主机的 amd64 build 阶段执行该 Go 二进制。

## Gate Contract

**Allowed actions：** 只修改 `/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history/docker/Dockerfile` 第 48 行；运行一次本地 `linux/amd64` build 和 Gate 9 已有的一次性容器断言；本地提交本次 Dockerfile 修复。

**Forbidden actions：** 修改 TrendRadar 源码、配置、锁文件、镜像源、`.env`、Docker 设置、NAS、容器、Cloudflare、生产环境；push、tag、导出镜像或进入 Gate 10。

**Steps：**

1. 将 `supercronic -version && \\` 精确替换为 `test -x /usr/local/bin/supercronic && \\`。保留紧邻的 SHA-1 校验、下载 URL、`TARGETARCH` 分支、安装路径和符号链接。  
   验证：`git diff -- docker/Dockerfile` 仅这一行变化。
2. 仅提交 `docker/Dockerfile`，提交信息 `fix: avoid supercronic cross-arch build execution`。  
   验证：`git show --stat --oneline HEAD` 只含该文件。
3. 用 `--platform linux/amd64 --pull=false` 对冻结 RC 加这一提交执行一次本地 build，标签为 `xjiankong-trendradar:v2-beta-rc-20260712`。  
   验证：image inspect 为 `linux/amd64`；若失败立即停止、不重试。
4. 仅在 build 成功后，复用 Gate 9 的 `RC_IMPORT_OK`、`RC_CONTAINER_OK` 和无常驻容器检查；更新 Gate 9 计划、设计规格和路线图。  
   验证：全部断言成功；不进入 Gate 10。

**Next Owner：** Codex 主控派执行 Agent 完成此 Gate 并独立审核。
