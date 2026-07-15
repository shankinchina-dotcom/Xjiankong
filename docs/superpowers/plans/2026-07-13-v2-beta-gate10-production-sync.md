# v2-beta 生产同步实施计划 (Gate 10)

> 状态：**Gate 10A 通过。Gate 10B 通过（2026-07-13）——老板裁定接受 RootFS 等价**（Mac Config ID `3c02dceafa86...` ≠ NAS Config ID `c122cdb56076...`，但 14 层 DiffID 与 chain SHA `8ca4f36b2b5e...` 全等；tar SHA `be16f6d9...`；`RC_IMPORT_OK`）。生产仍为 v2-alpha。**10C 已批准执行（2026-07-14 会商决议：运行侧身份以 NAS Config ID `c122cdb56076...` 为准；本计划 10C-0/10C-5 的镜像断言已同步为 NAS ID）**。禁止自动进入 10D。
>
> 设计依据：[v2-beta 生产镜像单点升级设计](../specs/2026-07-13-v2-beta-production-image-switch-design.md)（已获老板确认采用修正版“镜像单点升级 + 两个历史文件精确白名单”）。
>
> 前置条件：Gate 9.1 已完成（2026-07-13）。RC 镜像 `xjiankong-trendradar:v2-beta-rc-20260713` 已本地构建并通过代码审查、真实 Chrome 交互和一次性容器验证；未上传、未部署。
>
> 本计划是设计规格的**逐命令实施细化**，覆盖 Gate 10A—10D 四个子闸门。任何生产操作均须老板在当前对话中逐项确认后才能执行。

## 零、模型分配与闸门纪律

| 闸门 | 推荐模型 | 选择依据 | 验证方式 |
|---|---|---|---|
| Gate 10A：NAS 只读基线 | Terra 高 | 命令边界清楚，但需理解 Docker/NAS 状态 | 固定字段输出、敏感扫描、主控逐项比对 |
| Gate 10B：备份与镜像传输 | Terra 高 | 机械执行为主，涉及可回滚生产文件 | 备份清单、SHA-256、镜像 inspect、免费断言 |
| Gate 10C：镜像与 Nginx 切换 | Sol 高 | 生产写入和回滚关键节点 | 单行镜像差异、两个 location、容器/网络/安全路径复核 |
| Gate 10D：一次全链路验收 | Sol 中 | 综合热榜、RSS、AI、历史和公网证据 | 同一次运行日志、HTTP/JSON、安全路径检查 |
| 最终验收或回滚 | Sol 高 | 跨 Agent 最终判断与生产风险控制 | 冻结输入、白名单差异、回滚证据完整性 |

当前 Codex 界面不能保证 Agent 级模型切换；执行指令仍须保留推荐强度，并由 Codex 主控按相应标准复核。10A—10D 必须逐闸门报告并停止，下一闸门需老板确认。

- `[模型：Terra；强度：高] -> [Gate 10A 只读基线] -> 验证: [固定字段输出与主控复核]`
- `[模型：Terra；强度：高] -> [Gate 10B 备份和校验传输] -> 验证: [备份清单、SHA-256、镜像身份与免费断言]`
- `[模型：Sol；强度：高] -> [Gate 10C 生产写入与回滚关键节点] -> 验证: [白名单差异、容器身份、网络和安全路径]`
- `[模型：Sol；强度：中] -> [Gate 10D 同一次全链路证据整合] -> 验证: [日志、HTTP、JSON 和报告结构]`
- `[模型：Sol；强度：高] -> [最终验收或回滚判断] -> 验证: [跨 Agent 独立复核]`

## 一、冻结输入

| 项目 | 固定值 |
|------|-----|
| 生产镜像（当前） | `xjiankong-trendradar:v2-alpha-20260709` |
| v2-beta RC 镜像标签 | `xjiankong-trendradar:v2-beta-rc-20260713` |
| RC 镜像 SHA | `sha256:3c02dceafa861709ce6bbbd0dc2136b5a9b9db0827bf114f280cb1581b87ab4f` |
| RC 镜像平台 | `linux/amd64` |
| RC 镜像大小 | 138,032,730 bytes |
| RC 功能基线 | `codex/v2-beta-rc` / `8f7e385ac1453521a7ffffa9c5de43d725af76b9` |
| RC 构建兼容性提交 | `5c02c6ce` |
| Gate 9.1 最终 HEAD | `61ba393225de1b6d9d165a1dcddc189073f3e2d6` |
| RC 代码差异 | 新增 `v2_beta_deep_space_ui.py`、`v2_beta_history_manifest.py`；修改 `formatter.py`、`context.py`、`generator.py`、`html.py`；Gate 9.1 仅追加 `html.py` 与其 fixture；无 config/docker 差异 |
| NAS 项目路径 | `/volume1/docker/trendradar-nas/` |
| NAS SSH | `ssh z5451530@192.168.1.193`（局域网直连优先） |
| 公网地址 | `https://trend.shankluo.cc` |

## 二、Nginx 精确补丁与通用执行纪律

> **发现**：设计规格 §3.2 写明"不重建 `report-web`"，但 Gate 10D 验收条件要求 `/history.json` 和 `/history.html` 可访问。当前 NAS nginx 配置通过通配规则拦截所有 `.json` 后缀：
>
> ```nginx
> location ~* \.(db|sqlite|sqlite3|env|yaml|yml|json)$ {
>     return 404;
> }
> ```
>
> 不更新 nginx 配置 → `history.json` 返回 404 → 历史抽屉功能失效 → Gate 10D 无法通过。
>
> **解决方案**：候选文件必须在 NAS 上从部署前当前 `nginx.conf` 生成，严禁上传或整份覆盖为本地 `deploy/nas/nginx.conf` 模板。补丁程序只允许在唯一的 JSON 拦截规则前插入下面两个精确匹配块；随后用机器断言证明“删除这两个块后的候选文件”与 NAS 当前文件逐字节一致。更新前执行语法与白名单测试；替换后重建 `report-web`。
>
> ```nginx
> location = /history.json {
>     try_files $uri =404;
> }
>
> location = /history.html {
>     try_files $uri =404;
> }
> ```
>
> **安全说明**：精确匹配只暴露 `/history.json` 和 `/history.html` 两个白名单路径，其他 `.json` 文件仍被拦截。`history.json` 仅含公开报告元数据（版本号、路径、时间），不含 `.env`、DB、config 或 URL 可用性探测结果。

所有 NAS root 所有文件写入统一使用 `sudo sh -c` 或 `sudo tee`，不得依赖普通用户的 shell 重定向。每个写入动作必须紧接内容、权限和 SHA-256 验证；若该验证或任一后续步骤失败，立即停止，并只恢复本步骤触及的文件：`.env` 从 `$BACKUP_DIR/.env` 恢复镜像行，`nginx.conf` 从 `$BACKUP_DIR/nginx.conf` 恢复。恢复后重新验证 SHA-256；不得继续下一写入或扩大回滚范围。

## 三、Gate 10A：NAS 只读基线与回滚可用性核验

> **允许**：只读取得容器状态、镜像身份、磁盘空间、挂载/网络、`.env` 非敏感键存在性与 `TRENDRADAR_IMAGE` 当前值、输出目录统计、旧镜像可引用性。
>
> **禁止**：创建备份、上传、加载镜像、修改文件、重建容器、付费采集。

### 10A-1: NAS 容器状态

先预检 DSM 执行能力；任一命令缺失或失败立即停止：

```bash
ssh -t z5451530@192.168.1.193 "command -v python3; command -v stat; command -v sha256sum; sudo docker compose version; python3 -c 'import json, pathlib, re, sys'; stat -c '%Y|%s' /volume1/docker/trendradar-nas/nginx.conf; printf test | sha256sum"
```

```bash
ssh -t z5451530@192.168.1.193 "sudo docker ps --filter name=xjiankong --format '{{.Names}}\t{{.Image}}\t{{.Status}}'"
```

预期：四个容器（trendradar、cloudflared、rss-proxy、report-web）均 Up。

同时记录四容器的 ID、镜像 ID、启动时间和 restart count，作为 10C 前后对照：

```bash
ssh -t z5451530@192.168.1.193 "for c in xjiankong-trendradar xjiankong-report-web xjiankong-cloudflared xjiankong-rss-proxy; do sudo docker inspect \"\$c\" --format '{{.Name}}|{{.Id}}|{{.Image}}|{{.State.StartedAt}}|{{.RestartCount}}|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}'; done"
```

### 10A-2: NAS 镜像列表

```bash
ssh -t z5451530@192.168.1.193 "sudo docker images xjiankong-trendradar --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}'"
```

预期：存在 `v2-alpha-20260709`；不存在 `v2-beta-rc-20260713`。

```bash
ssh -t z5451530@192.168.1.193 "sudo docker image inspect xjiankong-trendradar:v2-alpha-20260709 --format '{{.Id}}|{{.Architecture}}|{{.Os}}|{{.Size}}'"
```

预期：退出码 0、ID 非空、平台为 `linux/amd64`；这是回滚准入条件。

### 10A-3: NAS 磁盘空间

```bash
ssh -t z5451530@192.168.1.193 "df -h /volume1 /tmp"
```

预期：可用空间 > 500 MB（新镜像 ~132 MB + tar 传输 ~132 MB + 备份）。

### 10A-4: NAS 配置与 nginx 核验

```bash
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'P=/volume1/docker/trendradar-nas; test -s \"\$P/docker-compose.yml\"; test -s \"\$P/.env\"; test -s \"\$P/nginx.conf\"; test -d \"\$P/config\"; for f in config.yaml ai_analysis_prompt.txt frequency_words.txt timeline.yaml; do test -s \"\$P/config/\$f\"; done; if test -d \"\$P/backups\"; then test -r \"\$P/backups\"; printf \"backups=present\\n\"; else printf \"backups=absent-allowed\\n\"; fi'"
ssh -t z5451530@192.168.1.193 "sudo grep -c 'history' /volume1/docker/trendradar-nas/nginx.conf || test \$? -eq 1"
```

预期：四个受控 config 文件、`nginx.conf`、Compose 均存在；既有备份目录不存在也允许，但必须明确记录。`grep` 退出码 1（0 个命中）是允许的正常基线；若已存在 history，必须只读核对是否正好是已批准白名单，任何其他规则立即停止。

### 10A-5: NAS .env 非敏感键

```bash
ssh -t z5451530@192.168.1.193 "sudo grep '^TRENDRADAR_IMAGE=' /volume1/docker/trendradar-nas/.env"
```

预期：只输出镜像行；当前为 `xjiankong-trendradar:v2-alpha-20260709`（或含 digest 等价形式）。另用固定白名单只记录 `TZ`、`RUN_MODE` 等非敏感键是否存在，不输出值；禁止输出 API key、token、模型和调度值。

```bash
ssh -t z5451530@192.168.1.193 "sudo sh -c 'for k in TZ RUN_MODE; do grep -q \"^\${k}=\" /volume1/docker/trendradar-nas/.env && printf \"%s=present\\n\" \"\$k\" || printf \"%s=absent\\n\" \"\$k\"; done'"
```

### 10A-6: NAS 挂载核验

```bash
ssh -t z5451530@192.168.1.193 "sudo docker inspect xjiankong-trendradar --format '{{json .Mounts}}' | python3 -m json.tool"
ssh -t z5451530@192.168.1.193 "sudo docker inspect xjiankong-report-web --format '{{json .Mounts}}' | python3 -m json.tool"
```

预期：trendradar 挂载 `config`（ro）和 `output`（rw）；report-web 挂载 `nginx.conf`（ro）和 `output`（ro）。

### 10A-7: Compose、网络与 output 完整摘要

```bash
ssh -t z5451530@192.168.1.193 "cd /volume1/docker/trendradar-nas && sudo docker compose config --services && sudo docker compose config --images && sudo docker compose config --networks"
ssh -t z5451530@192.168.1.193 "for c in xjiankong-trendradar xjiankong-report-web xjiankong-cloudflared xjiankong-rss-proxy; do sudo docker inspect \"\$c\" --format '{{.Name}}|{{json .NetworkSettings.Networks}}'; done"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'for d in news rss html; do p=/volume1/docker/trendradar-nas/output/\$d; test -d \"\$p\"; printf \"%s|files=%s|kilobytes=%s\\n\" \"\$d\" \"\$(find \"\$p\" -type f | wc -l | tr -d \" \" )\" \"\$(du -sk \"\$p\" | awk \"{print \\\$1}\")\"; done; stat -c \"index|size=%s|mtime=%Y\" /volume1/docker/trendradar-nas/output/index.html; sha256sum /volume1/docker/trendradar-nas/output/index.html'"
```

预期：Compose 摘要为既有四服务且不暴露环境值；网络、挂载和完整 output 统计可作为 10C/回滚基线；旧镜像可引用且既有备份（若有）可读。

### 10A-8: 本地 RC 镜像确认

```bash
docker image inspect xjiankong-trendradar:v2-beta-rc-20260713 \
  --format '{{.Id}}|{{.Architecture}}|{{.Os}}|{{.Size}}'
```

预期：ID 为 `sha256:3c02dceafa86...`，`linux/amd64`，138,032,730 bytes。

### 10A 通过条件

- 四容器运行正常，trendradar 使用 v2-alpha 镜像。
- 磁盘空间充足。
- v2-alpha 镜像可被精确引用（回滚基础）。
- `.env` 中 `TRENDRADAR_IMAGE` 当前值已记录。
- nginx.conf 当前不含 history 路由（待更新）。
- 本地 RC 镜像身份与 Gate 9.1 一致。

**回报后等待老板确认，才进入 Gate 10B。**

## 四、Gate 10B：受限备份与镜像传输

> **允许**：经老板确认后创建时间戳备份；本地 `docker save`；计算归档 SHA-256；上传 NAS；`docker load`；对导入镜像运行不挂载生产数据的一次性免费断言。
>
> **禁止**：修改 `.env`、切换生产容器、付费采集、清理旧文件。

### 10B-1: 创建备份目录并备份

```bash
BACKUP_DIR="$(ssh z5451530@192.168.1.193 'BACKUP=/volume1/docker/trendradar-nas/backups/v2-beta-$(date +%Y%m%d-%H%M%S); sudo mkdir -m 700 "$BACKUP"; printf "%s" "$BACKUP" | sudo tee /tmp/xjiankong-gate10-backup-dir >/dev/null; printf "%s" "$BACKUP"')"
printf '%s\n' "$BACKUP_DIR" | grep -Eq '^/volume1/docker/trendradar-nas/backups/v2-beta-[0-9]{8}-[0-9]{6}$'
ssh -t z5451530@192.168.1.193 "sudo test -d '$BACKUP_DIR'"
printf 'BACKUP_DIR=%s\n' "$BACKUP_DIR"

# 在一次 root shell 中备份全部回滚单位；proxy/config.yaml 只留 NAS，禁止传回或显示
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c '
  B=\"$BACKUP_DIR\"; P=/volume1/docker/trendradar-nas
  cp \"\$P/docker-compose.yml\" \"\$B/docker-compose.yml\"
  cp \"\$P/.env\" \"\$B/.env\"
  cp \"\$P/nginx.conf\" \"\$B/nginx.conf\"
  mkdir -m 700 \"\$B/config\" \"\$B/proxy\"
  for f in config.yaml ai_analysis_prompt.txt frequency_words.txt timeline.yaml; do cp \"\$P/config/\$f\" \"\$B/config/\$f\"; done
  cp \"\$P/proxy/config.yaml\" \"\$B/proxy/config.yaml\"
  chmod 600 \"\$B/.env\" \"\$B/proxy/config.yaml\"
  docker inspect xjiankong-trendradar --format \"{{.Config.Image}}|{{.Image}}|{{.State.StartedAt}}|{{.RestartCount}}\" | tee \"\$B/current-trendradar-image.txt\" >/dev/null
  for c in xjiankong-trendradar xjiankong-report-web xjiankong-cloudflared xjiankong-rss-proxy; do docker inspect \"\$c\" --format \"{{.Name}}|{{.Id}}|{{.Image}}|{{.State.StartedAt}}|{{.RestartCount}}\"; done > \"\$B/containers-before.txt\"
  for c in xjiankong-trendradar xjiankong-report-web; do docker inspect \"\$c\" | python3 -c 'import json,sys; x=json.load(sys.stdin)[0]; m=sorted((v[\"Source\"],v[\"Destination\"],v.get(\"Mode\",\"\"),v.get(\"RW\")) for v in x[\"Mounts\"]); n=sorted((k,tuple(sorted(v.get(\"Aliases\") or []))) for k,v in x[\"NetworkSettings\"][\"Networks\"].items()); print(x[\"Name\"],m,n,sep=\"|\")'; done > \"\$B/recreated-runtime-shape-before.txt\"
  for c in xjiankong-trendradar xjiankong-report-web xjiankong-cloudflared xjiankong-rss-proxy; do docker inspect \"\$c\" | python3 -c 'import hashlib,json,sys; x=json.load(sys.stdin)[0]; e=sorted(x[\"Config\"].get(\"Env\",[])); h=hashlib.sha256((\"\\n\".join(e)+\"\\n\").encode()).hexdigest(); keys={v.split(\"=\",1)[0] for v in e}; print(x[\"Name\"],\"env_sha256=\"+h,\"TZ=\"+(\"present\" if \"TZ\" in keys else \"absent\"),\"RUN_MODE=\"+(\"present\" if \"RUN_MODE\" in keys else \"absent\"),sep=\"|\")'; done > \"\$B/normalized-env-before.txt\"
  for d in news rss html; do p=\"\$P/output/\$d\"; test -d \"\$p\"; printf \"%s|files=%s|kilobytes=%s\\n\" \"\$d\" \"\$(find \"\$p\" -type f | wc -l | tr -d \" \" )\" \"\$(du -sk \"\$p\" | awk \"{print \\\$1}\")\"; done > \"\$B/output-summary.txt\"
  stat -c \"index|size=%s|mtime=%Y\" \"\$P/output/index.html\" >> \"\$B/output-summary.txt\"
  sha256sum \"\$P/output/index.html\" >> \"\$B/output-summary.txt\"
  SNAPSHOT=\"\$(find \"\$P/output/html\" -type f -exec stat -c \"%Y|%n\" {} \; | sort -t'|' -k1,1nr | head -n 1 | cut -d'|' -f2-)\"; test -n \"\$SNAPSHOT\"; REL=\"\${SNAPSHOT#\$P/output/}\"; printf \"%s\\n\" \"\$REL\" | grep -Eq \"^html/[0-9]{4}-[0-9]{2}-[0-9]{2}/[0-9]{2}-[0-9]{2}\\.html\$\"; case \"\$REL\" in *..*|*'?'*|*'#'*) exit 1;; esac; printf \"%s\\n\" \"\$REL\" > \"\$B/old-snapshot-relative-path.txt\"; sha256sum \"\$SNAPSHOT\" | awk \"{print \\\$1}\" > \"\$B/old-snapshot.sha256\"; stat -c %Y \"\$SNAPSHOT\" > \"\$B/old-snapshot.mtime\"
  : > \"\$B/manifest.sha256\"
  find \"\$B\" -type f ! -name manifest.sha256 -exec sha256sum {} \; >> \"\$B/manifest.sha256\"
  cd /; sha256sum -c \"\$B/manifest.sha256\" >/dev/null
  test \"\$(stat -c %a \"\$B/.env\")\" = 600
  test \"\$(stat -c %a \"\$B/proxy/config.yaml\")\" = 600
'"

# 即时验证：只列路径、权限和摘要，不显示 .env/config/proxy 内容
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; test -s \"\$B/docker-compose.yml\"; test -s \"\$B/nginx.conf\"; test -s \"\$B/.env\"; for f in config.yaml ai_analysis_prompt.txt frequency_words.txt timeline.yaml; do test -s \"\$B/config/\$f\"; done; test -s \"\$B/proxy/config.yaml\"; test -s \"\$B/output-summary.txt\"; test -s \"\$B/containers-before.txt\"; test -s \"\$B/recreated-runtime-shape-before.txt\"; test -s \"\$B/normalized-env-before.txt\"; test -s \"\$B/old-snapshot-relative-path.txt\"; test -s \"\$B/old-snapshot.sha256\"; test -s \"\$B/old-snapshot.mtime\"; cd /; sha256sum -c \"\$B/manifest.sha256\" >/dev/null; printf \"backup_files=%s\\n\" \"\$(find \"\$B\" -type f | wc -l | tr -d \" \" )\"'"
```

若备份或即时验证失败，只停止并保留现场；此时尚未改生产文件，无需回滚。禁止进入镜像传输。

### 10B-2: 本地导出镜像

```bash
docker save xjiankong-trendradar:v2-beta-rc-20260713 -o /tmp/v2-beta-rc-20260713.tar
shasum -a 256 /tmp/v2-beta-rc-20260713.tar > /tmp/v2-beta-rc-20260713.tar.sha256
cat /tmp/v2-beta-rc-20260713.tar.sha256
ls -la /tmp/v2-beta-rc-20260713.tar
```

记录归档 SHA-256 和大小。

### 10B-3: 传输到 NAS

```bash
scp -O /tmp/v2-beta-rc-20260713.tar z5451530@192.168.1.193:/tmp/
scp -O /tmp/v2-beta-rc-20260713.tar.sha256 z5451530@192.168.1.193:/tmp/

# NAS 端校验
ssh -t z5451530@192.168.1.193 "cd /tmp && sha256sum -c v2-beta-rc-20260713.tar.sha256 && ls -la v2-beta-rc-20260713.tar"
```

预期：NAS 端 SHA-256 与本地一致。

### 10B-4: NAS 加载镜像

```bash
ssh -t z5451530@192.168.1.193 "sudo docker load -i /tmp/v2-beta-rc-20260713.tar"

# 验证镜像身份
ssh -t z5451530@192.168.1.193 "sudo docker image inspect xjiankong-trendradar:v2-beta-rc-20260713 --format '{{.Id}}|{{.Architecture}}|{{.Size}}'"
```

预期（原设计）：ID 为 `sha256:3c02dceafa861709ce6bbbd0dc2136b5a9b9db0827bf114f280cb1581b87ab4f`，`linux/amd64`，138,032,730 bytes。

**2026-07-13 实测与裁定：** load 后 NAS Config ID 为 `sha256:c122cdb56076ed3e0342a2c348537d0f9bd4d48ea2955271489049e7147688b9`，Size 373,323,120；RootFS 14 层 DiffID 与本地完全一致（chain SHA-256 `8ca4f36b2b5ee7acbff72221b3f9b16a981d6ed81eb7770dc1ea2b45ce735715`）。老板接受 RootFS 等价作为 10B 通过；**10C 运行身份核对建议改用 NAS Config ID**，待另 Agent 会商是否修订本计划中所有 `3c02dceafa86...` 硬编码断言。

### 10B-5: NAS 免费容器断言

```bash
ssh -t z5451530@192.168.1.193 "sudo docker run --rm --platform linux/amd64 --entrypoint python -e LITELLM_LOCAL_MODEL_COST_MAP=True xjiankong-trendradar:v2-beta-rc-20260713 -c \"from trendradar.ai.analyzer import SourceRef; from trendradar.ai.formatter import render_ai_analysis_html_web; from trendradar.report.generator import build_history_manifest, write_history_archive_page; from trendradar.report.html import render_html_content; print('RC_IMPORT_OK')\""
```

预期：输出 `RC_IMPORT_OK`，无 traceback。

```bash
# 确认无残留容器
ssh -t z5451530@192.168.1.193 "sudo docker ps -a --filter ancestor=xjiankong-trendradar:v2-beta-rc-20260713 --format '{{.ID}} {{.Status}}'"
```

预期：无输出。

### 10B-6: 保留传输物并停止

本 Gate 不删除本地或 NAS 临时 tar。记录两端路径、大小和 SHA-256，保留到 Gate 10 完成并由老板另行批准清理。

### 10B 通过条件

- 备份完整且权限受限。
- NAS 归档 SHA-256 与本地一致。
- 导入镜像 ID、平台、大小与冻结输入完全一致。
- 免费断言通过且无残留容器。

**2026-07-13 通过条件修订（老板裁定）：** 在 Mac Docker Desktop → 群晖 Docker 路径下，允许 Config ID / Size 字段与本地冻结值不同，**当且仅当**同时满足：(1) tar SHA-256 一致；(2) RootFS DiffID 全序全等；(3) arch/os 与 Created/Entrypoint 合理一致；(4) `RC_IMPORT_OK` 通过且无残留容器。10B 据此记为通过。原「Config ID 必须等于 `3c02dceafa86...`」不再作为 10B 硬失败条件；是否写入设计规格正文，由后续 Agent 会商后改文档。

**Gate 10B 已通过。Gate 10C 未授权；不得因 10B 通过而自动进入 10C。**

## 五、Gate 10C：镜像切换与免费生产验收

> **允许**：经老板确认后只修改 `.env` 的 `TRENDRADAR_IMAGE` 一行；更新 NAS `nginx.conf`（只添加两个 history 精确路由）；只重建 `trendradar` 与 `report-web`。
>
> **禁止**：修改其他 `.env` 行、Compose、config、代理、输出、除两个精确路由外的 Nginx 内容，或重建 cloudflared/rss-proxy；不得人工触发采集。

进入 10C 时必须重新读取并验证备份目录，不能沿用 10B shell 变量；下面任一步骤或失败恢复前都以这个已验证值为准：

```bash
gate10_backup_preflight() {
  BACKUP_DIR="$(ssh z5451530@192.168.1.193 'sudo cat /tmp/xjiankong-gate10-backup-dir')"
  printf '%s\n' "$BACKUP_DIR" | grep -Eq '^/volume1/docker/trendradar-nas/backups/v2-beta-[0-9]{8}-[0-9]{6}$'
  ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'test -d \"$BACKUP_DIR\"; test -s \"$BACKUP_DIR/.env\"; test -s \"$BACKUP_DIR/nginx.conf\"; test -s \"$BACKUP_DIR/manifest.sha256\"; cd /; sha256sum -c \"$BACKUP_DIR/manifest.sha256\" >/dev/null'"
}
gate10_backup_preflight

```

任一断言失败立即停止，不得执行写入。若进入失败恢复命令，先原样重跑以上三行，验证成功后才能引用 `$BACKUP_DIR`。

### 10C-0：中断状态机

每次进入 10C 必须用备份原始 SHA、受限候选 SHA、`.env` 原始/目标 masked 摘要和运行容器镜像判定且只允许以下四态：①原始；②仅 Nginx 已写；③两文件已写但未重建；④已重建。任何组合之外的状态立即停止。若不是①，禁止静默续跑：先从已验真的备份恢复 `.env` 与 `nginx.conf`，以 `--no-deps --force-recreate` 重建两服务，验证旧镜像和原始 SHA 后，再从 10C-0 重新开始。

```bash
gate10_backup_preflight
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; P=/volume1/docker/trendradar-nas/.env; test \"\$(grep -c \"^TRENDRADAR_IMAGE=\" \"\$B/.env\")\" -eq 1; test \"\$(grep -c \"^TRENDRADAR_IMAGE=\" \"\$P\")\" -eq 1; OLD=\"\$(grep \"^TRENDRADAR_IMAGE=\" \"\$B/.env\")\"; CUR=\"\$(grep \"^TRENDRADAR_IMAGE=\" \"\$P\")\"; TARGET=TRENDRADAR_IMAGE=xjiankong-trendradar:v2-beta-rc-20260713; test \"\$CUR\" = \"\$OLD\" || test \"\$CUR\" = \"\$TARGET\"'"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; P=/volume1/docker/trendradar-nas; O=\"\$(sha256sum \"\$B/nginx.conf\" | awk \"{print \\\$1}\")\"; N=\"\$(sha256sum \"\$P/nginx.conf\" | awk \"{print \\\$1}\")\"; C=missing; test ! -s \"\$B/nginx.candidate.sha256\" || C=\"\$(cat \"\$B/nginx.candidate.sha256\")\"; sed \"s|^TRENDRADAR_IMAGE=.*|TRENDRADAR_IMAGE=MASKED|\" \"\$B/.env\" | sha256sum | awk \"{print \\\$1}\" > /tmp/env.original.masked; sed \"s|^TRENDRADAR_IMAGE=.*|TRENDRADAR_IMAGE=MASKED|\" \"\$P/.env\" | sha256sum | awk \"{print \\\$1}\" > /tmp/env.current.masked; cmp -s /tmp/env.original.masked /tmp/env.current.masked; E=\"\$(grep \"^TRENDRADAR_IMAGE=\" \"\$P/.env\")\"; I=\"\$(docker inspect xjiankong-trendradar --format \"{{.Image}}\")\"; OLD=\"\$(awk -F\"|\" \"NR==1{print \\\$2}\" \"\$B/current-trendradar-image.txt\")\"; RC=sha256:c122cdb56076ed3e0342a2c348537d0f9bd4d48ea2955271489049e7147688b9; if test \"\$N\" = \"\$O\" && test \"\$I\" = \"\$OLD\" && test \"\$E\" != TRENDRADAR_IMAGE=xjiankong-trendradar:v2-beta-rc-20260713; then S=original; elif test \"\$N\" = \"\$C\" && test \"\$I\" = \"\$OLD\" && test \"\$E\" != TRENDRADAR_IMAGE=xjiankong-trendradar:v2-beta-rc-20260713; then S=nginx-only; elif test \"\$N\" = \"\$C\" && test \"\$I\" = \"\$OLD\" && test \"\$E\" = TRENDRADAR_IMAGE=xjiankong-trendradar:v2-beta-rc-20260713; then S=files-changed-not-recreated; elif test \"\$N\" = \"\$C\" && test \"\$I\" = \"\$RC\" && test \"\$E\" = TRENDRADAR_IMAGE=xjiankong-trendradar:v2-beta-rc-20260713; then S=recreated; else exit 1; fi; printf \"gate10c_state=%s\\n\" \"\$S\"; test \"\$S\" = original'"
```

最后的 `test` 使②—④明确停止。恢复命令必须走第七节完整回滚（含双服务强制重建和原始 SHA/镜像验证），然后重新执行本状态机。

### 10C-1: 从 NAS 当前配置生成并验证 Nginx 候选

```bash
# 由 NAS 当前文件生成候选；要求 JSON 拦截锚点唯一且部署前无 history 规则
ssh -t z5451530@192.168.1.193 "sudo python3 -c 'from pathlib import Path; p=Path(\"/volume1/docker/trendradar-nas/nginx.conf\"); s=p.read_text(); a=\"location ~* \\\\.(db|sqlite|sqlite3|env|yaml|yml|json)\\\\$ {\"; assert s.count(a)==1; assert \"location = /history.json\" not in s and \"location = /history.html\" not in s; b=\"    location = /history.json {\\n        try_files \\\$uri =404;\\n    }\\n\\n    location = /history.html {\\n        try_files \\\$uri =404;\\n    }\\n\\n\"; Path(\"/tmp/nginx-v2-beta.conf\").write_text(s.replace(a,b+a,1))'"

# 机器断言：候选恰好多两个块，移除后与当前文件逐字节相同
ssh -t z5451530@192.168.1.193 "sudo python3 -c 'from pathlib import Path; o=Path(\"/volume1/docker/trendradar-nas/nginx.conf\").read_text(); n=Path(\"/tmp/nginx-v2-beta.conf\").read_text(); b=\"    location = /history.json {\\n        try_files \\\$uri =404;\\n    }\\n\\n    location = /history.html {\\n        try_files \\\$uri =404;\\n    }\\n\\n\"; assert n.count(\"location = /history.json\")==1 and n.count(\"location = /history.html\")==1; assert n.replace(b,\"\",1)==o'"

# 候选及 SHA 写入受限备份，使用独立发布 manifest；不修改原始备份 manifest
gate10_backup_preflight
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; install -m 600 /tmp/nginx-v2-beta.conf \"\$B/nginx.candidate.conf\"; sha256sum \"\$B/nginx.candidate.conf\" | awk \"{print \\\$1}\" > \"\$B/nginx.candidate.sha256\"; sha256sum \"\$B/nginx.candidate.conf\" > \"\$B/release-manifest.sha256\"; cd /; sha256sum -c \"\$B/release-manifest.sha256\" >/dev/null'"

# 用 report-web 当前镜像做临时语法验证，不修改运行容器
ssh -t z5451530@192.168.1.193 "IMAGE=\$(sudo docker inspect xjiankong-report-web --format '{{.Config.Image}}'); sudo docker run --rm --network none --entrypoint nginx -v /tmp/nginx-v2-beta.conf:/etc/nginx/nginx.conf:ro \"\$IMAGE\" -t"

# 临时非敏感 fixture 在同一无网络、无宿主端口容器内启动 Nginx 并用 wget 验证白名单
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'D=/tmp/gate10-nginx-fixture; mkdir -p \"\$D/news\" \"\$D/config\"; printf \"{}\" > \"\$D/history.json\"; printf ok > \"\$D/history.html\"; printf \"{}\" > \"\$D/other.json\"; printf x > \"\$D/.env\"; printf x > \"\$D/news/test.db\"; printf x > \"\$D/config/config.yaml\"'; IMAGE=\$(sudo docker inspect xjiankong-report-web --format '{{.Config.Image}}'); sudo docker run --rm --network none --entrypoint sh -v /tmp/nginx-v2-beta.conf:/etc/nginx/nginx.conf:ro -v /tmp/gate10-nginx-fixture:/source:ro \"\$IMAGE\" -ec 'nginx; test \"\$(wget -q -S -O /dev/null http://127.0.0.1/history.json 2>&1 | awk \"/HTTP\\//{print \\\$2}\" | tail -1)\" = 200; test \"\$(wget -q -S -O /dev/null http://127.0.0.1/history.html 2>&1 | awk \"/HTTP\\//{print \\\$2}\" | tail -1)\" = 200; for p in other.json .env news/test.db config/config.yaml; do test \"\$(wget -q -S -O /dev/null \"http://127.0.0.1/\$p\" 2>&1 | awk \"/HTTP\\//{print \\\$2}\" | tail -1)\" = 404; done'"

# 写入、即时校验；失败则只恢复 nginx.conf 并校验备份 SHA
gate10_backup_preflight
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'install -m 644 /tmp/nginx-v2-beta.conf /volume1/docker/trendradar-nas/nginx.conf; cmp -s /tmp/nginx-v2-beta.conf /volume1/docker/trendradar-nas/nginx.conf; test \"\$(sha256sum /tmp/nginx-v2-beta.conf | awk \"{print \\\$1}\")\" = \"\$(sha256sum /volume1/docker/trendradar-nas/nginx.conf | awk \"{print \\\$1}\")\"; test \"\$(grep -c \"location = /history.json\" /volume1/docker/trendradar-nas/nginx.conf)\" -eq 1; test \"\$(grep -c \"location = /history.html\" /volume1/docker/trendradar-nas/nginx.conf)\" -eq 1'" || ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"\$(cat /tmp/xjiankong-gate10-backup-dir)\"; printf \"%s\\n\" \"\$B\" | grep -Eq \"^/volume1/docker/trendradar-nas/backups/v2-beta-[0-9]{8}-[0-9]{6}\$\"; test -d \"\$B\"; test -s \"\$B/.env\"; test -s \"\$B/nginx.conf\"; cd /; sha256sum -c \"\$B/manifest.sha256\" >/dev/null; cp \"\$B/nginx.conf\" /volume1/docker/trendradar-nas/nginx.conf; cmp -s \"\$B/nginx.conf\" /volume1/docker/trendradar-nas/nginx.conf; test \"\$(sha256sum \"\$B/nginx.conf\" | awk \"{print \\\$1}\")\" = \"\$(sha256sum /volume1/docker/trendradar-nas/nginx.conf | awk \"{print \\\$1}\")\"'"

# 候选文件保留到 Gate 10 完成，清理由老板另行批准
```

预期：语法成功；机器断言证明只有两个精确 location；写入后 SHA/内容一致。任何失败均停止，不执行 `.env` 写入。

### 10C-2: 更新镜像行后只重建 trendradar 与 report-web

本步骤与 10C-3、10C-4 按顺序执行；不使用热加载替代容器级验收。

### 10C-3: 更新 .env 镜像标签

```bash
# 更新前确认当前值
ssh -t z5451530@192.168.1.193 "sudo grep '^TRENDRADAR_IMAGE=' /volume1/docker/trendradar-nas/.env"

# 用 root shell 原子生成并安装；除镜像行外必须与备份逐字节一致
gate10_backup_preflight
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'P=/volume1/docker/trendradar-nas/.env; B=\"$BACKUP_DIR/.env\"; test \"\$(grep -c \"^TRENDRADAR_IMAGE=\" \"\$P\")\" -eq 1; sed \"s|^TRENDRADAR_IMAGE=.*|TRENDRADAR_IMAGE=xjiankong-trendradar:v2-beta-rc-20260713|\" \"\$P\" > /tmp/xjiankong.env.new; chmod 600 /tmp/xjiankong.env.new; install -m 600 /tmp/xjiankong.env.new \"\$P\"; test \"\$(grep -c \"^TRENDRADAR_IMAGE=xjiankong-trendradar:v2-beta-rc-20260713\$\" \"\$P\")\" -eq 1; sed \"s|^TRENDRADAR_IMAGE=.*|TRENDRADAR_IMAGE=MASKED|\" \"\$P\" | sha256sum > /tmp/env.after.masked; sed \"s|^TRENDRADAR_IMAGE=.*|TRENDRADAR_IMAGE=MASKED|\" \"\$B\" | sha256sum > /tmp/env.before.masked; cmp -s /tmp/env.before.masked /tmp/env.after.masked'" || ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"\$(cat /tmp/xjiankong-gate10-backup-dir)\"; printf \"%s\\n\" \"\$B\" | grep -Eq \"^/volume1/docker/trendradar-nas/backups/v2-beta-[0-9]{8}-[0-9]{6}\$\"; test -d \"\$B\"; test -s \"\$B/.env\"; test -s \"\$B/nginx.conf\"; cd /; sha256sum -c \"\$B/manifest.sha256\" >/dev/null; cp \"\$B/.env\" /volume1/docker/trendradar-nas/.env; chmod 600 /volume1/docker/trendradar-nas/.env; cp \"\$B/nginx.conf\" /volume1/docker/trendradar-nas/nginx.conf; cmp -s \"\$B/.env\" /volume1/docker/trendradar-nas/.env; cmp -s \"\$B/nginx.conf\" /volume1/docker/trendradar-nas/nginx.conf; test \"\$(sha256sum \"\$B/nginx.conf\" | awk \"{print \\\$1}\")\" = \"\$(sha256sum /volume1/docker/trendradar-nas/nginx.conf | awk \"{print \\\$1}\")\"'"

ssh -t z5451530@192.168.1.193 "sudo grep '^TRENDRADAR_IMAGE=' /volume1/docker/trendradar-nas/.env"
```

预期：更新前为 v2-alpha 标签，更新后为 `xjiankong-trendradar:v2-beta-rc-20260713`。

### 10C-4: 只重建 trendradar 与 report-web

> 只重建 `trendradar` 与 `report-web`，不重建 `rss-proxy` 或 `cloudflared`。

```bash
gate10_backup_preflight
ssh -t z5451530@192.168.1.193 "cd /volume1/docker/trendradar-nas && sudo docker compose up -d --no-deps --force-recreate trendradar report-web"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'H=\"\$(sha256sum /volume1/docker/trendradar-nas/nginx.conf | awk \"{print \\\$1}\")\"; C=\"\$(docker exec xjiankong-report-web sha256sum /etc/nginx/nginx.conf | awk \"{print \\\$1}\")\"; test \"\$H\" = \"\$C\"; B=\"$BACKUP_DIR\"; test \"\$H\" = \"\$(cat \"\$B/nginx.candidate.sha256\")\"; cd /; sha256sum -c \"\$B/release-manifest.sha256\" >/dev/null'"
```

若重建失败，立即按第七节局部恢复 `.env` 与 `nginx.conf`，再以同一 `--no-deps --force-recreate` 命令只恢复这两个服务。

### 10C-5: 免费验收

```bash
# 容器状态
ssh -t z5451530@192.168.1.193 "sudo docker ps --filter name=xjiankong --format '{{.Names}}\t{{.Image}}\t{{.Status}}'"

# 四容器身份、启动时间、restart 与 report-web health；对照 10B containers-before.txt
ssh -t z5451530@192.168.1.193 "for c in xjiankong-trendradar xjiankong-report-web xjiankong-cloudflared xjiankong-rss-proxy; do sudo docker inspect \"\$c\" --format '{{.Name}}|{{.Id}}|{{.Config.Image}}|{{.Image}}|{{.State.StartedAt}}|{{.RestartCount}}|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}|{{json .Mounts}}|{{json .NetworkSettings.Networks}}'; done"

# 固定 RC 镜像 ID 必须精确相等
ssh -t z5451530@192.168.1.193 "test \"\$(sudo docker inspect xjiankong-trendradar --format '{{.Image}}')\" = 'sha256:c122cdb56076ed3e0342a2c348537d0f9bd4d48ea2955271489049e7147688b9'"

# trendradar 日志（无 import 错误）
ssh -t z5451530@192.168.1.193 "sudo docker logs xjiankong-trendradar --tail 30"

# 旧报告仍可访问
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/)" = 200

# 敏感路径仍 404
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/.env)" = 404
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/news/test.db)" = 404
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/config/config.yaml)" = 404

# 旧 index 的部署前 SHA/mtime、旧快照路径及 output 统计必须仍成立；并验证其他 JSON
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; P=/volume1/docker/trendradar-nas; test -s \"\$P/output/index.html\"; for d in news rss html; do p=\"\$P/output/\$d\"; printf \"%s|files=%s|kilobytes=%s\\n\" \"\$d\" \"\$(find \"\$p\" -type f | wc -l | tr -d \" \" )\" \"\$(du -sk \"\$p\" | awk \"{print \\\$1}\")\"; done > /tmp/output-summary.after; stat -c \"index|size=%s|mtime=%Y\" \"\$P/output/index.html\" >> /tmp/output-summary.after; sha256sum \"\$P/output/index.html\" >> /tmp/output-summary.after; cmp -s \"\$B/output-summary.txt\" /tmp/output-summary.after; R=\"\$(cat \"\$B/old-snapshot-relative-path.txt\")\"; case \"\$R\" in html/*) ;; *) exit 1;; esac; test -s \"\$P/output/\$R\"; for c in xjiankong-cloudflared xjiankong-rss-proxy; do docker inspect \"\$c\" --format \"{{.Name}}|{{.Id}}|{{.Image}}|{{.State.StartedAt}}|{{.RestartCount}}\"; done > /tmp/untouched.after; grep -E \"^/(xjiankong-cloudflared|xjiankong-rss-proxy)\\|\" \"\$B/containers-before.txt\" > /tmp/untouched.before; cmp -s /tmp/untouched.before /tmp/untouched.after'"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; for c in xjiankong-trendradar xjiankong-report-web; do docker inspect \"\$c\" | python3 -c '\''import json,sys; x=json.load(sys.stdin)[0]; m=sorted((v[\"Source\"],v[\"Destination\"],v.get(\"Mode\",\"\"),v.get(\"RW\")) for v in x[\"Mounts\"]); n=sorted((k,tuple(sorted(v.get(\"Aliases\") or []))) for k,v in x[\"NetworkSettings\"][\"Networks\"].items()); print(x[\"Name\"],m,n,sep=\"|\")'\''; done > /tmp/recreated-runtime.after; cmp -s \"\$B/recreated-runtime-shape-before.txt\" /tmp/recreated-runtime.after; for c in xjiankong-trendradar xjiankong-report-web xjiankong-cloudflared xjiankong-rss-proxy; do docker inspect \"\$c\" | python3 -c '\''import hashlib,json,sys; x=json.load(sys.stdin)[0]; e=sorted(x[\"Config\"].get(\"Env\",[])); h=hashlib.sha256((\"\\n\".join(e)+\"\\n\").encode()).hexdigest(); k={v.split(\"=\",1)[0] for v in e}; print(x[\"Name\"],\"env_sha256=\"+h,\"TZ=\"+(\"present\" if \"TZ\" in k else \"absent\"),\"RUN_MODE=\"+(\"present\" if \"RUN_MODE\" in k else \"absent\"),sep=\"|\")'\''; done > /tmp/normalized-env.after; cmp -s \"\$B/normalized-env-before.txt\" /tmp/normalized-env.after'"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; P=/volume1/docker/trendradar-nas/output; R=\"\$(cat \"\$B/old-snapshot-relative-path.txt\")\"; printf \"%s\\n\" \"\$R\" | grep -Eq \"^html/[0-9]{4}-[0-9]{2}-[0-9]{2}/[0-9]{2}-[0-9]{2}\\.html\$\"; F=\"\$P/\$R\"; test \"\$(sha256sum \"\$F\" | awk \"{print \\\$1}\")\" = \"\$(cat \"\$B/old-snapshot.sha256\")\"; test \"\$(stat -c %Y \"\$F\")\" = \"\$(cat \"\$B/old-snapshot.mtime\")\"'"
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/output/news/data.json)" = 404
```

预期：
- 四容器均 Up；trendradar 使用 `v2-beta-rc-20260713` 镜像。
- 日志无 ModuleNotFoundError 或配置错误。
- 公网 HTTP 200（旧报告仍在）。
- 敏感路径全 404。

### 10C 通过条件

- 四容器保持运行，report-web healthy。
- trendradar 使用固定 RC 镜像且无持续重启。
- 挂载、网络和非敏感环境摘要未漂移。
- 旧 `index.html` 和旧快照仍可访问。
- 敏感路径仍为 404。
- nginx 已加载 history 路由（首次新报告生成前 `/history.json` 仍可能是 404，不作为失败条件）。
- 除 `trendradar` 与 `report-web` 外，`rss-proxy`、`cloudflared` 的容器 ID、启动时间和 restart count 未变化。

**回报后等待老板确认，才进入 Gate 10D。**

## 六、Gate 10D：一次付费全链路验收

> **允许**：经老板再次确认后，只人工触发一次现有生产采集；完整审查同一次运行结果。
>
> **禁止**：因结果不理想连续重跑、改模型、改代理、改 Cloudflare 或扩大配置范围。

### 10D-1: 手动触发采集

付费触发前先证明没有 cron 或人工运行并发：记录当前时间、容器进程、最近日志中的调度窗口；若发现 `python -m trendradar`、采集锁、活跃 cron 任务或即将到来的调度窗口，停止并等待，不触发第二实例。

```bash
ssh -t z5451530@192.168.1.193 "date; sudo docker top xjiankong-trendradar; sudo docker logs xjiankong-trendradar --since 30m 2>&1 | tail -n 100"
```

只有主控确认无并发且仍在老板批准的一次付费窗口内，才执行：

```bash
BACKUP_DIR="$(ssh z5451530@192.168.1.193 'sudo cat /tmp/xjiankong-gate10-backup-dir')"
printf '%s\n' "$BACKUP_DIR" | grep -Eq '^/volume1/docker/trendradar-nas/backups/v2-beta-[0-9]{8}-[0-9]{6}$'
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'test -d \"$BACKUP_DIR\"; test -s \"$BACKUP_DIR/.env\"; test -s \"$BACKUP_DIR/nginx.conf\"; test -s \"$BACKUP_DIR/manifest.sha256\"; test -s \"$BACKUP_DIR/release-manifest.sha256\"; cd /; sha256sum -c \"$BACKUP_DIR/manifest.sha256\" >/dev/null; sha256sum -c \"$BACKUP_DIR/release-manifest.sha256\" >/dev/null'"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; P=/volume1/docker/trendradar-nas/output; if test -s \"\$P/history.json\"; then sha256sum \"\$P/history.json\" | awk \"{print \\\$1}\" > \"\$B/history-before.sha256\"; stat -c %Y \"\$P/history.json\" > \"\$B/history-before.mtime\"; python3 -c '\''import json,sys; print(json.load(open(sys.argv[1]))[\"latest\"][\"path\"])'\'' \"\$P/history.json\" > \"\$B/latest-before.txt\"; else printf absent > \"\$B/history-before.sha256\"; printf absent > \"\$B/history-before.mtime\"; printf absent > \"\$B/latest-before.txt\"; fi; find \"\$P/html\" -type f | sort > \"\$B/snapshots-before.txt\"'"
# 同一 NAS root shell 记录 NAS epoch、直接捕获 docker exec stdout/stderr 和真实退出码
ssh -t z5451530@192.168.1.193 "sudo sh -c 'B=\"$BACKUP_DIR\"; umask 077; START=\$(date +%s); printf \"%s\\n\" \"\$START\" > \"\$B/gate10d-start.epoch\"; docker exec xjiankong-trendradar sh -lc \"cd /app && python -m trendradar\" > \"\$B/gate10d-stdout.log\" 2> \"\$B/gate10d-stderr.log\"; RC=\$?; END=\$(date +%s); printf \"%s\\n\" \"\$END\" > \"\$B/gate10d-end.epoch\"; printf \"%s\\n\" \"\$RC\" > \"\$B/gate10d-exit-code.txt\"; chmod 600 \"\$B\"/gate10d-*.log \"\$B\"/gate10d-*.epoch \"\$B/gate10d-exit-code.txt\"; test \"\$RC\" -eq 0; exit \"\$RC\"'"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; test \"\$(cat \"\$B/gate10d-exit-code.txt\")\" -eq 0; cat \"\$B/gate10d-stdout.log\" \"\$B/gate10d-stderr.log\" > \"\$B/gate10d-run.log\"; chmod 600 \"\$B/gate10d-run.log\"; test -s \"\$B/gate10d-run.log\"'"
```

运行日志只允许在 NAS 受限目录内由固定解析命令读取，报告不得 `cat`、下载或回显原始 stdout/stderr；如解析命中疑似凭据字段，立即停止并只报告“敏感扫描失败”。

### 10D-2：机器断言与固定证据

```bash
# history.json：根字段白名单、嵌套字段、敏感键、路径格式和 latest 对应实体
ssh -t z5451530@192.168.1.193 "sudo python3 -c 'import json,re; from pathlib import Path; p=Path(\"/volume1/docker/trendradar-nas/output/history.json\"); d=json.loads(p.read_text()); assert set(d)=={\"schema_version\",\"latest\",\"dates\"}; assert set(d[\"latest\"])=={\"date\",\"time\",\"path\"}; path=re.compile(r\"^/html/[0-9]{4}-[0-9]{2}-[0-9]{2}/[0-9]{2}-[0-9]{2}\\.html$\"); assert path.fullmatch(d[\"latest\"][\"path\"]); versions=[]; sensitive=re.compile(r\"(env|token|secret|password|api.?key|database|sqlite|config|source_map)\",re.I); assert not any(sensitive.search(str(k)) for x in [d]+d[\"dates\"] for k in x if isinstance(x,dict)); [(versions.extend(day[\"versions\"]), (_ for _ in ()).throw(AssertionError()) if set(day)!={\"date\",\"versions\"} else None) for day in d[\"dates\"]]; assert versions; assert all(set(v)=={\"time\",\"path\",\"is_latest\"} and path.fullmatch(v[\"path\"]) for v in versions); assert sum(v[\"is_latest\"] is True for v in versions)==1; assert any(v[\"path\"]==d[\"latest\"][\"path\"] and v[\"is_latest\"] is True for v in versions); assert (p.parent / d[\"latest\"][\"path\"].lstrip(\"/\")).is_file(); assert not sensitive.search(json.dumps(d,ensure_ascii=False))'"

# 前后差分：history 已改变，新增快照位于本次运行窗口，latest 不同且正好指向新增文件
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; P=/volume1/docker/trendradar-nas/output; test -s \"\$P/history.json\"; test \"\$(sha256sum \"\$P/history.json\" | awk \"{print \\\$1}\")\" != \"\$(cat \"\$B/history-before.sha256\")\"; find \"\$P/html\" -type f | sort > /tmp/snapshots-after.txt; comm -13 \"\$B/snapshots-before.txt\" /tmp/snapshots-after.txt > /tmp/snapshots-new.txt; test \"\$(wc -l < /tmp/snapshots-new.txt | tr -d \" \" )\" -ge 1; L=\"\$(python3 -c '\''import json,sys; print(json.load(open(sys.argv[1]))[\"latest\"][\"path\"])'\'' \"\$P/history.json\")\"; test \"\$L\" != \"\$(cat \"\$B/latest-before.txt\")\"; F=\"\$P/\${L#/}\"; grep -Fxq \"\$F\" /tmp/snapshots-new.txt; M=\"\$(stat -c %Y \"\$F\")\"; S=\"\$(cat \"\$B/gate10d-start.epoch\")\"; E=\"\$(cat \"\$B/gate10d-end.epoch\")\"; test \"\$M\" -ge \"\$S\"; test \"\$M\" -le \"\$E\"'"

# 页面结构精确为 8 个 report-section
ssh -t z5451530@192.168.1.193 "test \"\$(sudo grep -o 'class=\"report-section' /volume1/docker/trendradar-nas/output/index.html | wc -l | tr -d ' ')\" -eq 8"

# 冻结旧快照路径，严格校验后安全拼接 URL 并精确断言 200
OLD_SNAPSHOT="$(ssh z5451530@192.168.1.193 "sudo cat '$BACKUP_DIR/old-snapshot-relative-path.txt'")"
printf '%s\n' "$OLD_SNAPSHOT" | grep -Eq '^html/[0-9]{4}-[0-9]{2}-[0-9]{2}/[0-9]{2}-[0-9]{2}\.html$'
case "$OLD_SNAPSHOT" in *..*|*'?'*|*'#'*) false;; esac
test "$(printf %s "$OLD_SNAPSHOT" | wc -c | tr -d ' ')" -eq "$(printf %s "$OLD_SNAPSHOT" | tr -d '[:cntrl:]' | wc -c | tr -d ' ')"
test "$(curl -sS -o /dev/null -w '%{http_code}' "https://trend.shankluo.cc/$OLD_SNAPSHOT")" = 200

# 同一运行窗口日志固定解析字段；每个字段必须保留原始匹配行和机器计数
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'L=\"$BACKUP_DIR/gate10d-run.log\"; grep -E \"热榜.*([0-9]+/[0-9]+)|hotlist.*([0-9]+/[0-9]+)\" \"\$L\" > \"$BACKUP_DIR/evidence-hotlist.txt\"; grep -E \"Nitter.*([0-9]+/[0-9]+)|非 Nitter.*([0-9]+/[0-9]+)|RSS.*([0-9]+/[0-9]+)\" \"\$L\" > \"$BACKUP_DIR/evidence-rss.txt\"; grep -E \"翻译.*([0-9]+/[0-9]+)|translation.*([0-9]+/[0-9]+)\" \"\$L\" > \"$BACKUP_DIR/evidence-translation.txt\"; grep -E \"\\[AI\\].*分析完成|AI.*analysis.*complete\" \"\$L\" > \"$BACKUP_DIR/evidence-ai.txt\"; test -s \"$BACKUP_DIR/evidence-hotlist.txt\"; test -s \"$BACKUP_DIR/evidence-rss.txt\"; test -s \"$BACKUP_DIR/evidence-translation.txt\"; test -s \"$BACKUP_DIR/evidence-ai.txt\"'"
```

若日志格式无法稳定自动解析，禁止凭印象判定通过，也不得重跑。固定人工证据必须逐项记录：运行窗口、热榜成功/总数、RSS 总成功/总数、Nitter 成功/总数、非 Nitter 成功/总数、翻译成功/本次待翻译数、AI 完成原始行、对应报告和新快照路径；任何字段缺失即 Gate 10D 停止并进入 Sol 高复核。

### 10D-3: 验收清单

| # | 验证项 | 命令/方式 | 预期 |
|---|--------|----------|------|
| 1 | 容器全 Up | `sudo docker ps --filter name=xjiankong` | 4/4 Up |
| 2 | 无 import 错误 | `sudo docker logs xjiankong-trendradar --tail 50` | 无 ModuleNotFoundError |
| 3 | AI 分析完成 | 同上 | `[AI] 分析完成` |
| 4 | 新报告生成 | `ls -lt /volume1/docker/trendradar-nas/output/html/` | 新 html 文件 |
| 5 | history.json 生成 | `ls -la /volume1/docker/trendradar-nas/output/history.json` | 文件存在 |
| 6 | history.html 生成 | `ls -la /volume1/docker/trendradar-nas/output/history.html` | 文件存在 |
| 7 | 公网可访问 | `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/)" = 200` | 200 |
| 8 | 深空报告渲染 | 浏览器打开 `https://trend.shankluo.cc` | 深色蓝渐变主题 |
| 9 | 8 板块存在 | 搜索 `report-section` | 8 个 |
| 10 | 历史抽屉可用 | 点击顶部历史按钮 | 右侧抽屉滑出 |
| 11 | history.json 可访问 | `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/history.json)" = 200` | 200 |
| 12 | history.html 可访问 | `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/history.html)" = 200` | 200 |
| 13 | 热榜正常 | 搜索 `hotlist-section` | 存在 |
| 14 | RSS 证据流 | 搜索 `evidence-stream` | 存在 |
| 15 | 敏感路径 404 | 分别执行 `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/.env)" = 404`，并以同一形式精确断言 `/news/test.db`、`/config/config.yaml` | 全 404 |
| 16 | 其他 .json 仍 404 | `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/output/news/data.json)" = 404` | 404 |
| 17 | Nitter fallback | 搜索 `x.com` 链接 | 存在 |
| 18 | 来源引用标记 | 搜索 `[R0` | 存在 |
| 19 | 旧快照保留 | `ls output/html/` | 含旧日期目录 |
| 20 | 旧报告仍可访问 | 从备份 `old-snapshot-relative-path.txt` 读取已冻结相对路径，校验仅匹配 `html/*` 后请求对应公网 URL，并精确断言 HTTP 200 | 200 |
| 21 | 运行唯一性 | 对照触发前后 PID、日志起止时间和新快照 mtime | 只有本次一次运行 |

### 10D 通过条件

- 热榜目标 11/11；若有波动，必须按来源解释。
- RSS 分开记录 Nitter 与非 Nitter；健康参考总计 38—41/44、Nitter 约 30/33。单个 404 不触发整体回滚。
- 翻译以本次实际待翻译数为分母，全部成功。
- AI 分析成功完成，页面含 8 板块、来源索引、安全链接和 Nitter → X fallback。
- 新快照生成，旧快照保留；`/history.json` 为合法受控结构且 latest 指向新快照。
- `/history.html`、历史抽屉和旧版提示可用。
- 敏感路径全 404。

## 七、回滚方案

如果 v2-beta 部署后出现问题，按以下步骤回滚到 v2-alpha：

```bash
# 1. 重新读取并严格验证 10B 的备份目录；不得沿用 10C 变量
BACKUP_DIR="$(ssh z5451530@192.168.1.193 'sudo cat /tmp/xjiankong-gate10-backup-dir')"
printf '%s\n' "$BACKUP_DIR" | grep -Eq '^/volume1/docker/trendradar-nas/backups/v2-beta-[0-9]{8}-[0-9]{6}$'
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'test -d \"$BACKUP_DIR\"; test -s \"$BACKUP_DIR/.env\"; test -s \"$BACKUP_DIR/nginx.conf\"; test -s \"$BACKUP_DIR/manifest.sha256\"; cd /; sha256sum -c \"$BACKUP_DIR/manifest.sha256\" >/dev/null'"

# 回滚写入前冻结当前 output；回滚不得改变这些值
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'P=/volume1/docker/trendradar-nas; for d in news rss html; do p=\"\$P/output/\$d\"; printf \"%s|files=%s|kilobytes=%s\\n\" \"\$d\" \"\$(find \"\$p\" -type f | wc -l | tr -d \" \" )\" \"\$(du -sk \"\$p\" | awk \"{print \\\$1}\")\"; done > /tmp/gate10-rollback-output-before; stat -c \"index|size=%s|mtime=%Y\" \"\$P/output/index.html\" >> /tmp/gate10-rollback-output-before; sha256sum \"\$P/output/index.html\" >> /tmp/gate10-rollback-output-before'"

# NAS root shell 内读取、验证并替换旧镜像行；不把备份值插入跨 shell 命令
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR/.env\"; P=/volume1/docker/trendradar-nas/.env; test \"\$(grep -c \"^TRENDRADAR_IMAGE=\" \"\$B\")\" -eq 1; OLD=\"\$(grep \"^TRENDRADAR_IMAGE=\" \"\$B\")\"; printf \"%s\\n\" \"\$OLD\" | grep -Eq \"^TRENDRADAR_IMAGE=[A-Za-z0-9_./:@-]+\$\"; test \"\$(grep -c \"^TRENDRADAR_IMAGE=\" \"\$P\")\" -eq 1; sed \"s|^TRENDRADAR_IMAGE=.*|\$OLD|\" \"\$P\" > /tmp/xjiankong.env.rollback; install -m 600 /tmp/xjiankong.env.rollback \"\$P\"; test \"\$(grep -c \"^\$OLD\$\" \"\$P\")\" -eq 1; sed \"s|^TRENDRADAR_IMAGE=.*|TRENDRADAR_IMAGE=MASKED|\" \"\$P\" | sha256sum > /tmp/env.rollback.masked; sed \"s|^TRENDRADAR_IMAGE=.*|TRENDRADAR_IMAGE=MASKED|\" \"\$B\" | sha256sum > /tmp/env.backup.masked; cmp -s /tmp/env.rollback.masked /tmp/env.backup.masked'"

# 2. 恢复 nginx.conf（从备份）
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'cd /; sha256sum -c \"$BACKUP_DIR/manifest.sha256\" >/dev/null; install -m 644 \"$BACKUP_DIR/nginx.conf\" /volume1/docker/trendradar-nas/nginx.conf; cmp -s \"$BACKUP_DIR/nginx.conf\" /volume1/docker/trendradar-nas/nginx.conf; test \"\$(sha256sum \"$BACKUP_DIR/nginx.conf\" | awk \"{print \\\$1}\")\" = \"\$(sha256sum /volume1/docker/trendradar-nas/nginx.conf | awk \"{print \\\$1}\")\"; test \"\$(grep -c \"location = /history.json\\|location = /history.html\" /volume1/docker/trendradar-nas/nginx.conf || true)\" -eq 0'"

# 3. 只重建 trendradar 与 report-web
ssh -t z5451530@192.168.1.193 "cd /volume1/docker/trendradar-nas && sudo docker compose up -d --no-deps --force-recreate trendradar report-web"

# 4. 严格验证：旧镜像行/镜像 ID、两服务、其他容器、挂载网络、output 与安全边界
ssh -t z5451530@192.168.1.193 "sudo grep '^TRENDRADAR_IMAGE=' /volume1/docker/trendradar-nas/.env; OLD_ID=\$(sudo awk -F'|' 'NR==1{print \$2}' \"$BACKUP_DIR/current-trendradar-image.txt\"); test \"\$(sudo docker inspect xjiankong-trendradar --format '{{.Image}}')\" = \"\$OLD_ID\""
ssh -t z5451530@192.168.1.193 "for c in xjiankong-trendradar xjiankong-report-web xjiankong-cloudflared xjiankong-rss-proxy; do sudo docker inspect \"\$c\" --format '{{.Name}}|{{.Id}}|{{.Image}}|{{.State.StartedAt}}|{{.RestartCount}}|{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}|{{json .Mounts}}|{{json .NetworkSettings.Networks}}'; done"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; P=/volume1/docker/trendradar-nas; for d in news rss html; do p=\"\$P/output/\$d\"; test -d \"\$p\"; printf \"%s|files=%s|kilobytes=%s\\n\" \"\$d\" \"\$(find \"\$p\" -type f | wc -l | tr -d \" \" )\" \"\$(du -sk \"\$p\" | awk \"{print \\\$1}\")\"; done > /tmp/gate10-rollback-output-after; stat -c \"index|size=%s|mtime=%Y\" \"\$P/output/index.html\" >> /tmp/gate10-rollback-output-after; sha256sum \"\$P/output/index.html\" >> /tmp/gate10-rollback-output-after; cmp -s /tmp/gate10-rollback-output-before /tmp/gate10-rollback-output-after; R=\"\$(cat \"\$B/old-snapshot-relative-path.txt\")\"; case \"\$R\" in html/*) ;; *) exit 1;; esac; test -s \"\$P/output/\$R\"; for c in xjiankong-cloudflared xjiankong-rss-proxy; do docker inspect \"\$c\" --format \"{{.Name}}|{{.Id}}|{{.Image}}|{{.State.StartedAt}}|{{.RestartCount}}\"; done > /tmp/rollback-untouched.after; grep -E \"^/(xjiankong-cloudflared|xjiankong-rss-proxy)\\|\" \"\$B/containers-before.txt\" > /tmp/rollback-untouched.before; cmp -s /tmp/rollback-untouched.before /tmp/rollback-untouched.after; docker logs xjiankong-trendradar --tail 20'"
ssh -t z5451530@192.168.1.193 "sudo sh -eu -c 'B=\"$BACKUP_DIR\"; for c in xjiankong-trendradar xjiankong-report-web; do docker inspect \"\$c\" | python3 -c '\''import json,sys; x=json.load(sys.stdin)[0]; m=sorted((v[\"Source\"],v[\"Destination\"],v.get(\"Mode\",\"\"),v.get(\"RW\")) for v in x[\"Mounts\"]); n=sorted((k,tuple(sorted(v.get(\"Aliases\") or []))) for k,v in x[\"NetworkSettings\"][\"Networks\"].items()); print(x[\"Name\"],m,n,sep=\"|\")'\''; done > /tmp/rollback-runtime.after; cmp -s \"\$B/recreated-runtime-shape-before.txt\" /tmp/rollback-runtime.after; for c in xjiankong-trendradar xjiankong-report-web xjiankong-cloudflared xjiankong-rss-proxy; do docker inspect \"\$c\" | python3 -c '\''import hashlib,json,sys; x=json.load(sys.stdin)[0]; e=sorted(x[\"Config\"].get(\"Env\",[])); h=hashlib.sha256((\"\\n\".join(e)+\"\\n\").encode()).hexdigest(); k={v.split(\"=\",1)[0] for v in e}; print(x[\"Name\"],\"env_sha256=\"+h,\"TZ=\"+(\"present\" if \"TZ\" in k else \"absent\"),\"RUN_MODE=\"+(\"present\" if \"RUN_MODE\" in k else \"absent\"),sep=\"|\")'\''; done > /tmp/rollback-env.after; cmp -s \"\$B/normalized-env-before.txt\" /tmp/rollback-env.after'"
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/)" = 200
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/.env)" = 404
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/news/test.db)" = 404
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/config/config.yaml)" = 404
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/history.json)" = 404
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/history.html)" = 404
```

预期：旧镜像行和部署前镜像 ID 精确恢复；`trendradar`、`report-web` 新 ID 且健康，`cloudflared`、`rss-proxy` 的 ID、启动时间和 restart count 与 `containers-before.txt` 一致；挂载和网络回到基线；output 统计不减少，新快照仍保留；敏感路径为 404，两个 history 白名单已撤销，因此公网 history 路径回到部署前行为（通常 404）。任何验证失败停止，不删除现场、不触发采集，由 Sol 高重新审计。

> **回滚约束**：
> - 不动数据库（SQLite）。
> - 不动 Cloudflare Tunnel / DNS。
> - 不动 NAS 系统配置。
> - 不删除备份目录、RC 镜像或传输归档。
> - 保留 `output/`、新快照和 history 文件（不影响 v2-alpha 运行）。
> - 不再次触发付费采集。

### 回滚触发条件

**立即回滚**：
- 镜像身份与冻结值不一致。
- trendradar crash loop 或持续重启。
- `.env`/Compose/配置/挂载/网络/输出出现未知漂移。
- 旧 `index.html`、旧快照或 SQLite 被覆盖或不可读。
- 敏感路径不再返回 404。
- `history.json` 非法或泄露内部路径。

**进入回滚评估**：
- 热榜大面积失败。
- RSS 退化到约 11/44 且 Nitter 集体失败。
- 翻译或 AI 分析整批失败。
- 8 板块、来源安全、历史抽屉等核心功能回归。

单个 Nitter 404、既有 38—41/44 波动或 Cloudflare 短时异常不自动触发回滚。

## 八、不在此次范围

- 不新增数据源。
- 不修改 Cloudflare Tunnel / DNS。
- 不修改 `.env` 中 API key、token、AI 模型、调度和开关（仅改 `TRENDRADAR_IMAGE` 一行）。
- 不修改 `config/config.yaml` 或 `config/ai_analysis_prompt.txt`（v2-beta 无 config 差异）。
- 不同步整个部署包或 `docker-compose.yml`。
- 除已批准的 `trendradar` 与 `report-web` 外，不重建 `cloudflared`、`rss-proxy`。
- 不清理 NAS 遗留文件。
- 不删除 v2-alpha 镜像（保留用于回滚）。
- 不修改 cron 调度。
- 不提交 `output/` 产物。

## 九、执行后稳定性观察

部署完成后的连续 3 个 cron 周期（约 12 小时）内，记录以下指标：

| 指标 | v2-alpha 基线 | v2-beta 预期 | 观察方式 |
|------|--------------|-------------|----------|
| 热榜命中 | 11/11 | ≥ 11/11 | 报告页面 |
| RSS 命中 | 38/44 | ≥ 38/44 | 报告页面 |
| 翻译完成 | 26/26 | 全部成功 | 容器日志 |
| AI 分析 | 成功 | 成功 | 容器日志 |
| 公网 HTTP | 200 | 200 | curl |
| history.json | N/A | 存在且可访问 | curl |
| 历史快照 | N/A | 每版生成 | ls output/html/ |
| 容器重启 | 0 | 0 | docker ps |

异常必须标明来源（采集、翻译、AI、渲染、nginx）和影响范围。
