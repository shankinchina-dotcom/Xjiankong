# v2-alpha 新镜像生产同步方案

> 状态：已完成（2026-07-09）。本地构建、NAS 加载、`.env` 镜像切换、容器重建、免费验证、付费 AI 触发和公网验证均已通过。
> 基线：TrendRadar `v2-alpha` HEAD `33d80973`。
> 前置：config.yaml + ai_analysis_prompt.txt 已于 2026-07-09 上传 NAS。

## 一、当前状态

| 项目 | 值 |
|------|-----|
| NAS config.yaml | ✅ 已更新（`ai_analysis` 在 region_order 首位） |
| NAS ai_analysis_prompt.txt | ✅ 已更新（v2-alpha 7 板块 Prompt） |
| NAS Python 源码 | ✅ 已随新镜像同步（`analyzer.py`/`formatter.py`/`html.py` 含 v2-alpha 代码） |
| NAS 当前镜像 | `xjiankong-trendradar:v2-alpha-20260709` |
| 镜像 ID | `ea2d7183483d` |
| config/prompt 备份目录 | `/volume1/docker/trendradar-nas/backups/v2-alpha-20260709-113527` |
| 镜像切换备份目录 | `/volume1/docker/trendradar-nas/backups/v2-alpha-image-20260709-124505` |

## 二、生产上线结果

| 验证项 | 结果 |
|--------|------|
| 本地镜像验证 | `v2-alpha image OK` |
| tar | `/tmp/xjiankong-trendradar-v2-alpha.tar`，131M |
| NAS 镜像 | `xjiankong-trendradar:v2-alpha-20260709`，373MB |
| 容器状态 | `xjiankong-trendradar` Up |
| 免费容器级验证 | schema OK，formatter OK |
| 热榜 | 11/11 |
| RSS | 38/44 |
| AI 分析 | deepseek-v4-flash 完成 |
| 翻译 | 26/26 |
| v2-alpha 结构 | `ai-section-v2`、8 板块、引用来源索引 |
| 公网 | `https://trend.shankluo.cc` HTTP 200 |
| 敏感路径 | `/.env` 404，`/news/test.db` 404 |

## 三、镜像构建方案

### 3.1 Dockerfile 覆盖分析

TrendRadar Dockerfile `docker/Dockerfile` 第 63 行：
```dockerfile
COPY trendradar/ ./trendradar/
```

v2-alpha 改动的所有 Python 文件都在 `trendradar/` 目录内，**构建镜像时自动包含**，无需修改 Dockerfile。

### 3.2 本地构建与导出（闸门 1）

```bash
# 1. 确认基线
cd /Users/shankluo/AI/Claude/TrendRadar
git checkout v2-alpha
git rev-parse HEAD  # 确认 33d80973

# 2. 构建镜像（linux/amd64）
docker buildx build \
  --platform linux/amd64 \
  -f docker/Dockerfile \
  -t xjiankong-trendradar:v2-alpha-20260709 \
  --load \
  .

# 3. 本地验证（3.4 节）

# 4. 导出 tar
docker save xjiankong-trendradar:v2-alpha-20260709 \
  -o /tmp/xjiankong-trendradar-v2-alpha.tar
```

### 3.3 本地上传 NAS（闸门 2）

```bash
# 上传 tar 到 NAS
scp -O /tmp/xjiankong-trendradar-v2-alpha.tar \
  z5451530@192.168.1.193:/tmp/

# NAS 上加载镜像
sudo docker load -i /tmp/xjiankong-trendradar-v2-alpha.tar
sudo docker images xjiankong-trendradar:v2-alpha-20260709
```

### 3.4 本地镜像验证（构建后立即执行，免费）

构建完成后，在导出 tar 之前，先验证 v2-alpha 源码确实进入了镜像：

```bash
docker run --rm --platform linux/amd64 \
  xjiankong-trendradar:v2-alpha-20260709 \
  python -c "
from trendradar.ai.analyzer import SourceRef, AIAnalysisResult
r = AIAnalysisResult()
assert hasattr(r, 'daily_judgment'), 'missing daily_judgment'
assert hasattr(r, 'research_breakthroughs'), 'missing research_breakthroughs'
assert hasattr(r, 'product_tools'), 'missing product_tools'
assert hasattr(r, 'source_map'), 'missing source_map'
print('v2-alpha image OK')
"
```

此验证通过后才能导出 tar。

### 3.5 镜像标签建议

| 标签 | 用途 |
|------|------|
| `xjiankong-trendradar:v2-alpha-20260709` | 日期版本，可追溯 |
| `xjiankong-trendradar:v2-alpha` | 滚动标签，指向最新 v2-alpha 构建 |

## 四、compose 修改范围

仅修改 `trendradar` 服务的 `image` 行，不改其他任何内容。

```yaml
# 旧：
  trendradar:
    image: ${TRENDRADAR_IMAGE}

# 新（.env 中）：
  TRENDRADAR_IMAGE=xjiankong-trendradar:v2-alpha-20260709
```

| 不修改 | 说明 |
|--------|------|
| `.env` 其他行 | API key、调度、AI 开关等不变 |
| `cloudflared` 服务 | 不变 |
| `report-web` 服务 | 不变 |
| `rss-proxy` 服务 | 不变 |
| `volumes` / `networks` | 不变 |
| Cloudflare Tunnel / DNS | 不在本轮范围 |

## 五、上线步骤

### 5.1 上线前备份

```bash
# NAS 上执行
BACKUP_DIR="/volume1/docker/trendradar-nas/backups/v2-alpha-image-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"

# 备份当前 compose 和 .env
sudo cp /volume1/docker/trendradar-nas/docker-compose.yml "$BACKUP_DIR/"
sudo cp /volume1/docker/trendradar-nas/.env "$BACKUP_DIR/"

# 记录当前镜像信息
sudo docker inspect xjiankong-trendradar --format '{{.Image}}' > "$BACKUP_DIR/current-image.txt"
sudo docker images wantcat/trendradar --format '{{.Repository}}:{{.Tag}} {{.ID}}' > "$BACKUP_DIR/current-image-list.txt"

# 备份当前 config（已在上一闸门备份，但再保一份）
sudo cp /volume1/docker/trendradar-nas/config/config.yaml "$BACKUP_DIR/"
sudo cp /volume1/docker/trendradar-nas/config/ai_analysis_prompt.txt "$BACKUP_DIR/"

echo "BACKUP_DIR=$BACKUP_DIR"
```

### 5.2 修改 .env 镜像标签

> ⚠️ **红线：只允许修改 `TRENDRADAR_IMAGE` 一行。**

硬约束：

- 只改 `TRENDRADAR_IMAGE=`
- **不读取、不输出、不展示 `.env` 其他内容**（含 API key、Tunnel token）
- 不把 `.env` 内容贴到日志或对话
- 修改前后仅用以下命令验证：

```bash
cd /volume1/docker/trendradar-nas

# 修改前确认当前值
grep '^TRENDRADAR_IMAGE=' .env

# 修改
sudo sed -i 's|^TRENDRADAR_IMAGE=.*|TRENDRADAR_IMAGE=xjiankong-trendradar:v2-alpha-20260709|' .env

# 修改后确认
grep '^TRENDRADAR_IMAGE=' .env
```

### 5.3 重建容器

```bash
cd /volume1/docker/trendradar-nas
sudo docker compose up -d trendradar
```

⚠️ **闸门**：执行前需老板确认。

### 5.4 容器启动检查

```bash
# 确认容器启动
sudo docker ps --filter name=xjiankong-trendradar

# 确认使用新镜像
sudo docker inspect xjiankong-trendradar --format '{{.Config.Image}}'

# 检查日志无 import 错误
sudo docker logs xjiankong-trendradar --tail 30
```

## 六、验证步骤

### 6.1 容器级验证（免费，无需 AI 调用）

```bash
# 1. SourceRef import
sudo docker exec xjiankong-trendradar python -c "from trendradar.ai.analyzer import SourceRef, AIAnalysisResult; print('import OK')"

# 2. v2-alpha 字段
sudo docker exec xjiankong-trendradar python -c "r = __import__('trendradar.ai.analyzer', fromlist=['AIAnalysisResult']).AIAnalysisResult(); assert hasattr(r, 'daily_judgment'); assert hasattr(r, 'source_map'); print('schema OK')"

# 3. HTML renderer
sudo docker exec xjiankong-trendradar python -c "from trendradar.ai.formatter import render_ai_analysis_html_rich; print('formatter OK')"
```

### 6.2 付费 AI 验证（需老板单独确认）

⚠️ **闸门**：触发前需老板明确确认。调用 deepseek flash，几分钱。

```bash
sudo docker exec xjiankong-trendradar bash -c "cd /app && python -m trendradar"
```

验证清单：

| # | 验证项 | 方式 |
|---|--------|------|
| 1 | AI 分析完成 | 日志含 `[AI] 分析完成` |
| 2 | 无 import 错误 | 日志无 `ModuleNotFoundError` |
| 3 | 无 JSON parse 错误 | 日志无 `JSON 解析错误` |
| 4 | 报告生成 | `ls -lt output/html/` 有新文件 |
| 5 | 公网可访问 | `https://trend.shankluo.cc` HTTP 200 |
| 6 | AI 分析首位 | 页面源码 body 后第一个 section 为 `ai-section-v2` |
| 7 | 8 板块存在 | 页面上包含全部 8 个板块标题 |
| 8 | 来源索引存在 | 页面含「引用来源索引」 |
| 9 | source_id 可点击 | 存在 `href=` 链接 |
| 10 | 热榜正常 | `hotlist-section` 有内容 |
| 11 | RSS 正常 | `rss-section` 有内容 |
| 12 | 敏感路径 404 | `/news/*.db` `/rss/*.db` `/.env` 均 404 |
| 13 | 淡蓝色 UI | 页面头部无大面积紫色横幅 |

## 七、回滚方案

```bash
# 1. 恢复 .env
sudo cp "$BACKUP_DIR/.env" /volume1/docker/trendradar-nas/.env

# 2. 恢复 config/prompt（如果 AI 验证时发现问题）
sudo cp "$BACKUP_DIR/config.yaml" /volume1/docker/trendradar-nas/config/
sudo cp "$BACKUP_DIR/ai_analysis_prompt.txt" /volume1/docker/trendradar-nas/config/

# 3. 重建容器（自动使用旧镜像）
cd /volume1/docker/trendradar-nas
sudo docker compose up -d trendradar

# 4. 验证
sudo docker ps --filter name=xjiankong-trendradar
sudo docker logs xjiankong-trendradar --tail 10
```

> **回滚约束**：
> - 不动数据库（SQLite）。
> - 不动 Cloudflare / DNS / Tunnel。
> - 不动 `rss-proxy` / `report-web` / `cloudflared`。
> - 不删除备份目录。

## 八、确认闸门

| # | 闸门 | 执行前需确认 |
|---|------|-------------|
| 1 | 本地构建镜像 + 镜像验证 + 导出 tar | 已完成 |
| 2 | 上传 tar 到 NAS + `docker load` | 已完成 |
| 3 | 备份 + 修改 `.env` `TRENDRADAR_IMAGE` | 已完成 |
| 4 | 重建 trendradar 容器 + 免费容器级验证 | 已完成 |
| 5 | 付费 AI 触发 + 公网验证 | 已完成 |

**当前状态：v2-alpha 新镜像已生产运行。后续生产变更需另起计划并重新确认。**
