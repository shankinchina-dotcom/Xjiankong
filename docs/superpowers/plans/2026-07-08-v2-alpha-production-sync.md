# v2-alpha 生产同步计划

> 状态：待确认。执行前必须取得老板逐闸门确认。
> 基于：v2-alpha 本地验证通过 + UI 视觉收口完成（TrendRadar `v2-alpha` HEAD `33d80973`）
>
> **本计划只描述同步步骤，不执行任何生产操作。**
>
> 当前下一步：仅允许执行「只读核验闸门」。不得上传、覆盖、重启容器或触发 AI。

## 一、当前基线

| 项目 | 值 |
|------|-----|
| TrendRadar fork 分支 | `v2-alpha` |
| TrendRadar HEAD | `33d80973` |
| 基线说明 | 含 Task 1-8、本地 AI 验证、UI 视觉收口与淡蓝色系统 |
| v2-alpha 本地验证 | 8/8 通过 |
| UI 预览 | `/private/tmp/v2-alpha-ui-preview.html` |

> `20575e25` 是 UI 收口前的旧基线，不得再作为生产同步基线。

## 二、NAS 当前状态核验

> 执行前先通过 SSH 核验以下信息，填入实际值。
> 当前只放行本节只读核验；不得执行 5.2 之后的任何上传、覆盖、重启、AI 触发步骤。

| 核验项 | 命令 | 当前值 |
|--------|------|--------|
| 运行容器 | `sudo docker ps --filter name=xjiankong` | __待核验__ |
| TrendRadar 版本 | `sudo docker exec xjiankong-trendradar python -m trendradar --version` | __待核验__ |
| 配置目录 | `/volume1/docker/trendradar-nas/config/` | __确认存在__ |
| output 目录 | `/volume1/docker/trendradar-nas/output/` | __确认存在__ |
| 当前备份 | 上一次部署备份位置 | __待确认__ |

### 2.1 只读核验输出要求

另一个 agent 执行只读核验后必须回报：

1. 容器列表摘要。
2. `docker inspect` Mounts 结论：
   - `/app` 或 `/app/trendradar` 是否 bind mount。
   - Python 源码应走策略 A 还是策略 B。
3. `config.yaml` diff 审查：
   - 白名单差异。
   - 黑名单差异。
   - 需要人工确认的差异。
4. 是否建议进入下一闸门：
   - 备份 + 上传配置文件。
   - Python 源码同步。
5. 停止执行，等待老板确认。

## 三、需同步的文件清单

从 TrendRadar fork `v2-alpha` 分支同步以下 5 个文件到 NAS：

| # | 本地路径 | NAS 目标路径 | 说明 |
|---|----------|-------------|------|
| 1 | `config/ai_analysis_prompt.txt` | `/volume1/docker/trendradar-nas/config/ai_analysis_prompt.txt` | v2-alpha 7 板块 Prompt |
| 2 | `trendradar/ai/analyzer.py` | NAS TrendRadar 容器内 `/app/trendradar/ai/analyzer.py` | SourceRef + source_map |
| 3 | `trendradar/ai/formatter.py` | NAS TrendRadar 容器内 `/app/trendradar/ai/formatter.py` | 8-panel HTML renderer |
| 4 | `trendradar/report/html.py` | NAS TrendRadar 容器内 `/app/trendradar/report/html.py` | v2 CSS + region_order + 全局头/热榜/RSS 淡蓝色系统 |
| 5 | `config/config.yaml` | `/volume1/docker/trendradar-nas/config/config.yaml` | region_order 前置 |

> **注意**：
> - 文件 2-4 是 Python 源码，同步方式以 5.3 判定结果为准：bind mount 为正式可持久方案；镜像内置时正式方案需另起计划（新镜像或 volume 挂载），`docker cp` 只能作为临时验证。详见 5.3.2 / 5.3.3。
> - 测试文件（`tests/fixtures/v2_alpha_*.py`）**不同步**到 NAS。
> - `config/frequency_words.txt` 不在此次同步范围（遗留改动）。
> - `docker/.env` 不在此次同步范围（含 API key，不通过文件同步传输）。

## 四、同步前备份方案

> ⚠️ **BACKUP_DIR 在执行开始时统一创建一次，后续所有备份操作复用同一目录。**

```bash
# 创建备份目录（一次性，整个同步过程复用）
BACKUP_DIR="/volume1/docker/trendradar-nas/backups/v2-alpha-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"
echo "BACKUP_DIR=$BACKUP_DIR"

# 备份 config 文件
sudo cp /volume1/docker/trendradar-nas/config/config.yaml "$BACKUP_DIR/"
sudo cp /volume1/docker/trendradar-nas/config/ai_analysis_prompt.txt "$BACKUP_DIR/"

# 如果 Python 文件通过 bind mount 挂载，也备份
# 路径取决于 docker inspect 输出（见 5.3.1）
```

> **安全约束**：
> - `.env` 文件不备份。
> - 备份目录仅管理员可读（`sudo chmod 700 "$BACKUP_DIR"`）。
> - 不将备份目录内容写入仓库、日志或聊天记录。

## 五、执行步骤

### 5.1 config.yaml diff 闸门

⚠️ **此步必须在任何 config.yaml 上传操作前完成。**

#### 5.1.1 获取 NAS 当前配置

```bash
# 使用统一 BACKUP_DIR 备份（BACKUP_DIR 在第四节已创建）
sudo cp /volume1/docker/trendradar-nas/config/config.yaml "$BACKUP_DIR/config.yaml.bak"

# 拉取到本地用于 diff
scp -O z5451530@192.168.1.193:/volume1/docker/trendradar-nas/config/config.yaml /tmp/nas-config-current.yaml
```

#### 5.1.2 生成 diff 并审查

```bash
diff /tmp/nas-config-current.yaml config/config.yaml
```

#### 5.1.3 允许的差异（白名单）

以下差异属于 v2-alpha 预期改动，允许进入生产：

| 配置项 | 预期差异 |
|--------|----------|
| `display.region_order` | `ai_analysis` 从末尾移至首位 |
| `rss.feeds[].url` | `rsshub.app/twitter/user/` → `nitter.net/.../rss`（如果 NAS 当前已是 nitter URL，此差异不出现） |
| `rss.feeds[].id` | `x-xxx` → `nitter-xxx`（同上） |
| `advanced.rss.use_proxy` | `false` → `true`（如果 NAS 当前已是 `true`，此差异不出现） |
| `advanced.rss.proxy_url` | `""` → `"http://rss-proxy:7890"`（同上） |
| `ai_analysis.include_standalone` | `true` → `false`（如果 NAS 当前已是 `false`，此差异不出现） |

#### 5.1.4 禁止覆盖的配置（黑名单）

以下配置即使出现 diff，也**不得**用本地 config.yaml 覆盖 NAS 版本：

| 配置项 | 原因 |
|--------|------|
| `ai.api_key` | 环境专属，NAS 通过 `AI_API_KEY` 环境变量注入 |
| `ai.model` | NAS 可能与本地不同 |
| `notification.*` | webhook URL、飞书密钥等环境专属 |
| `schedule.*` | NAS 调度配置可能与本地不同 |
| `storage.*` | 本地路径与 NAS 路径不同 |
| `advanced.crawler.*` | 代理配置环境专属 |
| 任何包含 `127.0.0.1`、`localhost`、本地绝对路径的行 | 本地专属 |

#### 5.1.5 diff 确认闸门

- diff 输出中所有差异必须能归入 5.1.3 白名单。
- 任何不在白名单中的差异，暂停同步，先向老板说明并确认。
- 确认通过后，再执行 5.2（上传配置文件）。

### 5.2 上传配置文件（config.yaml + ai_analysis_prompt.txt）

```bash
# 从本地上传（scp 到 NAS /tmp 后 sudo cp）
scp -O config/ai_analysis_prompt.txt z5451530@192.168.1.193:/tmp/
scp -O config/config.yaml z5451530@192.168.1.193:/tmp/

# SSH 到 NAS
ssh z5451530@192.168.1.193

# 替换文件
sudo cp /tmp/ai_analysis_prompt.txt /volume1/docker/trendradar-nas/config/
sudo cp /tmp/config.yaml /volume1/docker/trendradar-nas/config/

# 检查权限
sudo chmod 644 /volume1/docker/trendradar-nas/config/ai_analysis_prompt.txt
sudo chmod 644 /volume1/docker/trendradar-nas/config/config.yaml
```

### 5.3 Python 源码同步策略判定

⚠️ **此步必须在任何源码同步操作前完成。** 判定基于 NAS 上 `docker inspect` 的实际输出，不做假设。

#### 5.3.1 判定命令

```bash
sudo docker inspect xjiankong-trendradar --format '{{json .Mounts}}' | python3 -m json.tool
```

检查返回的 Mounts 数组中是否存在 `Destination` 为 `/app` 或 `/app/trendradar` 的 bind mount。

#### 5.3.2 策略 A：bind mount 已存在

如果 `/app/trendradar/` 或 `/app/` 已通过 bind mount 挂载到宿主机目录：

- 先将 3 个 Python 文件从本地 scp 到 NAS 临时目录，再从临时目录复制到 bind mount 路径。
- 重建容器后改动保留（bind mount 不会被容器重建清除）。
- 回滚：将备份的旧 `.py` 文件复制回挂载目录，重建容器。

```bash
# 1. 先在 NAS 上创建临时目录
ssh z5451530@192.168.1.193 "mkdir -p /tmp/v2-alpha-src"

# 2. 从本地 scp 到 NAS /tmp/v2-alpha-src/
scp -O trendradar/ai/analyzer.py z5451530@192.168.1.193:/tmp/v2-alpha-src/
scp -O trendradar/ai/formatter.py z5451530@192.168.1.193:/tmp/v2-alpha-src/
scp -O trendradar/report/html.py z5451530@192.168.1.193:/tmp/v2-alpha-src/

# 3. SSH 到 NAS，从 /tmp 复制到 bind mount 目录
ssh z5451530@192.168.1.193
MOUNT_SRC="/volume1/docker/trendradar-nas/app"  # 实际值以 docker inspect 为准
sudo cp /tmp/v2-alpha-src/analyzer.py "$MOUNT_SRC/trendradar/ai/"
sudo cp /tmp/v2-alpha-src/formatter.py "$MOUNT_SRC/trendradar/ai/"
sudo cp /tmp/v2-alpha-src/html.py "$MOUNT_SRC/trendradar/report/"

# 4. 可选：清理临时目录
# rm -rf /tmp/v2-alpha-src
```

#### 5.3.3 策略 B：镜像内置（无 bind mount）

如果 `/app/trendradar/` 在镜像内，无 bind mount：

- **正式方案**：构建新镜像（含 v2-alpha 源码）或新增明确的源码 volume 挂载。不在本轮生产同步范围，需另起计划。
- `docker cp` 到运行中容器**只能作为临时验证手段**，容器 recreate 后所有 `docker cp` 改动丢失。
- `docker cp` 验证流程：
  1. 先从本地 scp 三个 `.py` 文件到 NAS `/tmp/v2-alpha-src/`
  2. `docker cp` 从 `/tmp/v2-alpha-src/` 到运行中容器
  3. 立即手动触发采集，验证功能
  4. 验证通过后，确认正式方案（新镜像或 volume 挂载）
  5. 容器 recreate 前，改动都在；recreate 后消失

```bash
# 1. 先在 NAS 上创建临时目录
ssh z5451530@192.168.1.193 "mkdir -p /tmp/v2-alpha-src"

# 2. scp 到 NAS /tmp/v2-alpha-src/（从本地执行）
scp -O trendradar/ai/analyzer.py z5451530@192.168.1.193:/tmp/v2-alpha-src/
scp -O trendradar/ai/formatter.py z5451530@192.168.1.193:/tmp/v2-alpha-src/
scp -O trendradar/report/html.py z5451530@192.168.1.193:/tmp/v2-alpha-src/

# 3. SSH 到 NAS，docker cp 到容器（临时验证）
ssh z5451530@192.168.1.193
sudo docker cp /tmp/v2-alpha-src/analyzer.py xjiankong-trendradar:/app/trendradar/ai/analyzer.py
sudo docker cp /tmp/v2-alpha-src/formatter.py xjiankong-trendradar:/app/trendradar/ai/formatter.py
sudo docker cp /tmp/v2-alpha-src/html.py xjiankong-trendradar:/app/trendradar/report/html.py

# 4. 可选：清理临时目录
# rm -rf /tmp/v2-alpha-src
```

> ⚠️ **docker cp 回滚**：容器 recreate 后自动恢复到镜像内置版本。如需紧急回滚，重建容器即可。

#### 5.3.4 两种策略的回滚对照

| 策略 | 同步方式 | 回滚方式 |
|------|----------|----------|
| A：bind mount | 文件复制到宿主机目录 | 恢复备份文件到宿主机目录 + 重建容器 |
| B：镜像内置 + docker cp | docker cp 到运行中容器 | 重建容器（自动恢复镜像版本） |
| B：正式方案 | 新镜像或新增 volume 挂载 | 回退到旧镜像/compose 配置，重建容器

### 5.4 重建容器

```bash
cd /volume1/docker/trendradar-nas
sudo docker compose up -d trendradar
```

⚠️ **闸门**：执行前确认老板已授权。

### 5.5 手动触发采集

```bash
sudo docker exec xjiankong-trendradar bash -c "cd /app && python -m trendradar"
```

⚠️ **闸门**：执行前确认老板已授权（触发付费 AI 调用，几分钱）。

## 六、验证步骤

| # | 验证项 | 命令/方式 | 预期 |
|---|--------|----------|------|
| 1 | 容器 Running | `sudo docker ps --filter name=trendradar` | Up |
| 2 | 无 import 错误 | `sudo docker logs xjiankong-trendradar --tail 50` | 无 ModuleNotFoundError |
| 3 | 无 JSON parse 错误 | 同上 | 无 "JSON 解析错误" |
| 4 | AI 分析完成 | 同上 | `[AI] 分析完成` |
| 5 | 报告生成 | `ls -lt /volume1/docker/trendradar-nas/output/html/` | 新 html 文件 |
| 6 | 公网可访问 | 浏览器打开 `https://trend.shankluo.cc` | HTTP 200 |
| 7 | AI 分析首位 | 查看页面源码 `<body>` 后第一个 section | `ai-section-v2` |
| 8 | 8 板块存在 | 搜索「今日核心判断」「研究/模型突破」等 | 8/8 |
| 9 | source_id 链接 | 搜索 `href=` | 可点击链接 |
| 10 | 来源索引 | 搜索「引用来源索引」 | 存在 |
| 11 | 热榜正常 | 搜索「hotlist-section」 | 存在，有内容 |
| 12 | RSS 正常 | 搜索「rss-section」 | 存在 |
| 13 | 敏感路径 404 | `/news/*.db` `/rss/*.db` `/.env` | 404 |

## 七、回滚方案

```bash
# 1. 恢复备份的配置文件
BACKUP_DIR="/volume1/docker/trendradar-nas/backups/v2-alpha-<timestamp>"
sudo cp "$BACKUP_DIR/config.yaml" /volume1/docker/trendradar-nas/config/
sudo cp "$BACKUP_DIR/ai_analysis_prompt.txt" /volume1/docker/trendradar-nas/config/

# 2. 重建容器（恢复旧配置）
cd /volume1/docker/trendradar-nas
sudo docker compose up -d trendradar

# 3. 验证
sudo docker logs xjiankong-trendradar --tail 20
curl -s -o /dev/null -w "%{http_code}" https://trend.shankluo.cc
```

> **回滚约束**：
> - 不动数据库（SQLite）。
> - 不动 Cloudflare Tunnel / DNS。
> - 不动 NAS 系统配置。
> - 不删除备份目录。

## 八、风险与确认闸门

| # | 闸门 | 风险 | 执行前需确认 |
|---|------|------|-------------|
| 1 | Python 源码同步方式 | 容器内路径不可写导致失败 | 确认挂载方案后再同步 |
| 2 | 配置文件上传 | 覆盖后旧配置丢失 | 备份后确认 |
| 3 | 容器重建 | 服务短暂中断（< 1 分钟） | 确认可接受 |
| 4 | 手动触发采集 | 调用付费 AI（几分钱） | 确认 |
| 5 | 公网验证 | 访问公网 URL | 确认 |
| 6 | Cloudflare | 不在本轮修改范围 | — |

**每个闸门执行前必须获得老板在当前对话中明确确认。**

## 九、不在此次范围

- 不新增数据源
- 不修改 Cloudflare Tunnel
- 不修改 `docker/.env`
- 不清理 NAS 遗留文件
- 不提交 `output/` 产物
- 不同步测试文件
- 不修改 `frequency_words.txt`

## 十、跨 Agent 配合方式

| 角色 | 职责 |
|------|------|
| 另一个 agent | 执行生产同步计划中的只读核验、后续经确认的 NAS 操作，并逐闸门回报结果 |
| Codex | 维护本地 v2-alpha 基线、审查计划和回报、把关是否进入下一闸门 |
| 老板 | 对每个生产闸门做单独确认 |

配合约束：

1. 另一个 agent 不得再引用旧基线 `20575e25`，必须使用 TrendRadar `v2-alpha` HEAD `33d80973`。
2. 只读核验、配置上传、Python 源码同步、容器重建、付费 AI 触发、公网验证必须分开确认。
3. 如果只读核验发现 `/app/trendradar` 是镜像内置，本轮不得把 `docker cp` 当正式生产方案；只能回报事实并等待下一步确认。
4. UI 后续再调整时，必须先本地预览确认，再更新本计划基线。
