# 群晖 NAS 一键部署 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** 为 Synology DS220+ 生成可由 Container Manager 导入的 TrendRadar 部署包，并通过独立 Cloudflare Tunnel 匿名发布只读 HTML 日报。

**Architecture:** Docker Compose 运行 trendradar、report-web 和 cloudflared，不发布宿主机端口。TrendRadar 每 4 小时生成数据；Nginx 只公开 index.html 与 html/；Cloudflare Tunnel 将 trend.shankluo.cc 转发到内部 report-web:80。

**Tech Stack:** Docker Compose、TrendRadar、Nginx Alpine、Cloudflare Tunnel、Bash、GitHub Actions。

---

## 文件结构

| 路径 | 职责 |
|---|---|
| deploy/nas/docker-compose.yml | 三容器编排、内部网络、卷和调度 |
| deploy/nas/.env.example | 无密钥环境变量和固定镜像 digest |
| deploy/nas/nginx.conf | HTML 白名单与敏感路径拒绝 |
| deploy/nas/test-deployment.sh | 静态检查和 Nginx 集成测试 |
| deploy/nas/build-bundle.sh | 复制非敏感配置并生成 NAS 上传包 |
| deploy/nas/README.md | Cloudflare、群晖与验收手册 |
| .gitignore | 忽略 NAS 密钥和生成物 |
| AGENTS.md | 声明部署目录 |
| quality-check.sh | 将 NAS 模板纳入本地质量门禁 |
| .github/workflows/quality.yml | 将 NAS 静态检查纳入 CI |

固定多架构镜像：

~~~text
wantcat/trendradar@sha256:de396d242c105d697c2765f5341ca71a45d9bcefe934d1d32b511eeae2f0d0be
nginx@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236
cloudflare/cloudflared@sha256:6d91c121b803126f7a5344005d17a9324788fc09d305b6e2560ec6040a7ae283
~~~

三个 manifest 均已核对包含 linux/amd64，适配 DS220+。

### Task 1: 建立规则和失败测试

**Files:**
- Modify: AGENTS.md
- Modify: .gitignore
- Create: deploy/nas/test-deployment.sh

- [x] **Step 1: 声明目录并忽略本地状态**

在 AGENTS.md 文件表加入：

~~~markdown
| deploy/nas/ | 群晖 Container Manager 部署模板和生成器 | 不保存凭据或生成包；外部部署前必须重新确认 |
~~~

在 .gitignore 追加：

~~~gitignore
/dist/
/deploy/nas/.env
/deploy/nas/output/
/deploy/nas/config/
~~~

- [x] **Step 2: 创建失败测试**

> 最终实现：测试脚本在原始草案上增加了 Compose 渲染、网络隔离、敏感路径、部署包事务性以及 AI 分析/翻译默认关闭检查。

创建 deploy/nas/test-deployment.sh：

~~~bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:---static}"
COMPOSE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/.env.example"
NGINX_CONF="$SCRIPT_DIR/nginx.conf"

for file in "$COMPOSE" "$ENV_FILE" "$NGINX_CONF"; do
  test -s "$file" || { echo "missing: $file" >&2; exit 1; }
done

if rg -n '^[[:space:]]*ports:' "$COMPOSE"; then
  echo "host ports are forbidden" >&2
  exit 1
fi
if grep -q 'trendradar-mcp' "$COMPOSE"; then
  echo "MCP service is out of scope" >&2
  exit 1
fi

grep -q '0 \*/4 \* \* \*' "$ENV_FILE"
grep -q '^IMMEDIATE_RUN=false$' "$ENV_FILE"
grep -q '^AI_ANALYSIS_ENABLED=false$' "$ENV_FILE"
grep -q '^AI_TRANSLATION_ENABLED=false$' "$ENV_FILE"
grep -q '^AI_API_KEY=$' "$ENV_FILE"
grep -q '^CLOUDFLARE_TUNNEL_TOKEN=$' "$ENV_FILE"
grep -q 'location ~\* \^/(news|rss|meta|config)' "$NGINX_CONF"
grep -q '\\.(db|sqlite|sqlite3' "$NGINX_CONF"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE" config >/dev/null

if [ "$MODE" = "--static" ]; then
  echo "nas_static=passed"
  exit 0
fi
test "$MODE" = "--integration" || { echo "invalid mode" >&2; exit 2; }

TMP_DIR="$(mktemp -d)"
PROJECT="xjiankong-nas-test-$$"
cleanup() {
  CONFIG_DIR="$TMP_DIR/config" OUTPUT_DIR="$TMP_DIR/output" \
    docker compose --project-name "$PROJECT" --env-file "$ENV_FILE" \
    -f "$COMPOSE" down -v >/dev/null 2>&1 || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TMP_DIR/config" "$TMP_DIR/output/html/2026-07-04" \
  "$TMP_DIR/output/news" "$TMP_DIR/output/rss"
printf '%s\n' '<h1>latest</h1>' > "$TMP_DIR/output/index.html"
printf '%s\n' '<h1>archive</h1>' > "$TMP_DIR/output/html/2026-07-04/report.html"
printf '%s\n' private > "$TMP_DIR/output/news/private.db"
printf '%s\n' private > "$TMP_DIR/output/rss/private.db"

CONFIG_DIR="$TMP_DIR/config" OUTPUT_DIR="$TMP_DIR/output" \
  docker compose --project-name "$PROJECT" --env-file "$ENV_FILE" \
  -f "$COMPOSE" up -d report-web

CONFIG_DIR="$TMP_DIR/config" OUTPUT_DIR="$TMP_DIR/output" \
  docker compose --project-name "$PROJECT" --env-file "$ENV_FILE" \
  -f "$COMPOSE" exec -T report-web \
  wget -qO- http://127.0.0.1/index.html | grep -q latest

CONFIG_DIR="$TMP_DIR/config" OUTPUT_DIR="$TMP_DIR/output" \
  docker compose --project-name "$PROJECT" --env-file "$ENV_FILE" \
  -f "$COMPOSE" exec -T report-web \
  wget -qO- http://127.0.0.1/html/2026-07-04/report.html | grep -q archive

for path in news/private.db rss/private.db .env; do
  if CONFIG_DIR="$TMP_DIR/config" OUTPUT_DIR="$TMP_DIR/output" \
    docker compose --project-name "$PROJECT" --env-file "$ENV_FILE" \
    -f "$COMPOSE" exec -T report-web \
    wget -qO- "http://127.0.0.1/$path" >/dev/null 2>&1; then
    echo "private path exposed: $path" >&2
    exit 1
  fi
done

echo "nas_integration=passed"
~~~

- [x] **Step 3: 确认测试先失败**

~~~bash
chmod +x deploy/nas/test-deployment.sh
bash deploy/nas/test-deployment.sh --static
~~~

Expected: FAIL，错误以 missing: deploy/nas/docker-compose.yml 结束。

- [x] **Step 4: 提交**

~~~bash
git add AGENTS.md .gitignore deploy/nas/test-deployment.sh
git commit -m "test: define NAS deployment checks"
~~~

### Task 2: 实现 Compose 和只读发布层

**Files:**
- Create: deploy/nas/docker-compose.yml
- Create: deploy/nas/.env.example
- Create: deploy/nas/nginx.conf
- Test: deploy/nas/test-deployment.sh

- [x] **Step 1: 创建 deploy/nas/docker-compose.yml**

> 最终实现：Compose 文件名按 DSM 导入流程调整为 `docker-compose.yml`，AI 分析与翻译均默认关闭。

~~~yaml
name: xjiankong

services:
  trendradar:
    image: ${TRENDRADAR_IMAGE}
    container_name: xjiankong-trendradar
    restart: unless-stopped
    environment:
      TZ: ${TZ:-Asia/Taipei}
      CRON_SCHEDULE: ${CRON_SCHEDULE:-0 */4 * * *}
      RUN_MODE: ${RUN_MODE:-cron}
      IMMEDIATE_RUN: ${IMMEDIATE_RUN:-false}
      AI_ANALYSIS_ENABLED: ${AI_ANALYSIS_ENABLED:-false}
      AI_TRANSLATION_ENABLED: ${AI_TRANSLATION_ENABLED:-false}
      AI_API_KEY: ${AI_API_KEY:-}
      AI_MODEL: ${AI_MODEL:-deepseek/deepseek-chat}
      AI_API_BASE: ${AI_API_BASE:-}
    volumes:
      - ${CONFIG_DIR:-./config}:/app/config:ro
      - ${OUTPUT_DIR:-./output}:/app/output
    networks: [backend]

  report-web:
    image: ${REPORT_WEB_IMAGE}
    container_name: xjiankong-report-web
    restart: unless-stopped
    read_only: true
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ${OUTPUT_DIR:-./output}:/source:ro
    tmpfs: [/var/cache/nginx, /var/run, /tmp]
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://127.0.0.1/healthz >/dev/null || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
    networks: [backend]

  cloudflared:
    image: ${CLOUDFLARED_IMAGE}
    container_name: xjiankong-cloudflared
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: ${CLOUDFLARE_TUNNEL_TOKEN:-}
    depends_on:
      report-web:
        condition: service_healthy
    networks: [backend]

networks:
  backend:
    internal: false
~~~

- [x] **Step 2: 创建 deploy/nas/.env.example**

~~~dotenv
TRENDRADAR_IMAGE=wantcat/trendradar@sha256:de396d242c105d697c2765f5341ca71a45d9bcefe934d1d32b511eeae2f0d0be
REPORT_WEB_IMAGE=nginx@sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236
CLOUDFLARED_IMAGE=cloudflare/cloudflared@sha256:6d91c121b803126f7a5344005d17a9324788fc09d305b6e2560ec6040a7ae283
TZ=Asia/Taipei
CRON_SCHEDULE=0 */4 * * *
RUN_MODE=cron
IMMEDIATE_RUN=false
AI_ANALYSIS_ENABLED=false
AI_TRANSLATION_ENABLED=false
AI_MODEL=deepseek/deepseek-chat
AI_API_BASE=
AI_API_KEY=
CLOUDFLARE_TUNNEL_TOKEN=
CONFIG_DIR=./config
OUTPUT_DIR=./output
~~~

- [x] **Step 3: 创建 deploy/nas/nginx.conf**

~~~nginx
server {
    listen 80 default_server;
    server_name _;
    root /source;
    autoindex off;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    location = /healthz {
        access_log off;
        default_type text/plain;
        return 200 "ok\n";
    }

    location = / {
        try_files /index.html =404;
    }

    location = /index.html {
        try_files /index.html =404;
    }

    location /html/ {
        try_files $uri =404;
    }

    location ~* ^/(news|rss|meta|config)(/|$) {
        return 404;
    }

    location ~* /\. {
        return 404;
    }

    location ~* \.(db|sqlite|sqlite3|env|ya?ml|json)$ {
        return 404;
    }

    location / {
        return 404;
    }
}
~~~

- [x] **Step 4: 运行测试**

> 最终实现：静态测试同时断言 `.env.example` 值和渲染后 Compose 中的 `AI_ANALYSIS_ENABLED`、`AI_TRANSLATION_ENABLED` 均为 `false`。

~~~bash
bash deploy/nas/test-deployment.sh --static
bash deploy/nas/test-deployment.sh --integration
~~~

Expected: 分别输出 nas_static=passed 和 nas_integration=passed。

- [x] **Step 5: 提交**

~~~bash
git add deploy/nas/docker-compose.yml deploy/nas/.env.example deploy/nas/nginx.conf
git commit -m "feat: add hardened NAS compose stack"
~~~

### Task 3: 实现无密钥部署包生成器

**Files:**
- Create: deploy/nas/build-bundle.sh
- Create: deploy/nas/README.md
- Modify: deploy/nas/test-deployment.sh

- [x] **Step 1: 在 test-deployment.sh 的 compose 检查前增加失败断言**

~~~bash
test -x "$SCRIPT_DIR/build-bundle.sh" || {
  echo "missing executable: $SCRIPT_DIR/build-bundle.sh" >&2
  exit 1
}
bash -n "$SCRIPT_DIR/build-bundle.sh"
~~~

Run: bash deploy/nas/test-deployment.sh --static

Expected: FAIL，错误包含 missing executable。

- [x] **Step 2: 创建仅含标题的 README**

~~~markdown
# TrendRadar 群晖部署
~~~

- [x] **Step 3: 创建 deploy/nas/build-bundle.sh**

> 最终实现：生成器改为事务性发布，输出包内使用 `docker-compose.yml`，并扩展了 YAML/JSON/纯文本凭据扫描和失败恢复。

~~~bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_SOURCE="${CONFIG_SOURCE:-$REPO_ROOT/../TrendRadar/config}"
DIST_ROOT="${DIST_ROOT:-$REPO_ROOT/dist}"
BUNDLE_NAME="trendradar-nas"
BUNDLE_DIR="$DIST_ROOT/$BUNDLE_NAME"
ARCHIVE="$DIST_ROOT/$BUNDLE_NAME.tar.gz"

test -s "$CONFIG_SOURCE/config.yaml" || {
  echo "missing config.yaml in $CONFIG_SOURCE" >&2
  exit 1
}
test -s "$CONFIG_SOURCE/frequency_words.txt" || {
  echo "missing frequency_words.txt in $CONFIG_SOURCE" >&2
  exit 1
}
grep -A3 '^filter:' "$CONFIG_SOURCE/config.yaml" \
  | grep -Eq 'method:[[:space:]]*"?keyword"?' || {
    echo "filter.method must remain keyword" >&2
    exit 1
  }

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/$BUNDLE_NAME/config" "$TMP_DIR/$BUNDLE_NAME/output"

cp "$SCRIPT_DIR/docker-compose.yml" "$TMP_DIR/$BUNDLE_NAME/docker-compose.yml"
cp "$SCRIPT_DIR/.env.example" "$TMP_DIR/$BUNDLE_NAME/.env.example"
cp "$SCRIPT_DIR/nginx.conf" "$TMP_DIR/$BUNDLE_NAME/nginx.conf"
cp "$SCRIPT_DIR/README.md" "$TMP_DIR/$BUNDLE_NAME/README.md"
cp -R "$CONFIG_SOURCE/." "$TMP_DIR/$BUNDLE_NAME/config/"

if find "$TMP_DIR/$BUNDLE_NAME/config" -type f \
  \( -name '.env' -o -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) \
  -print -quit | grep -q .; then
  echo "forbidden file found in config source" >&2
  exit 1
fi

SECRET_PATTERN='(?i)(api[_-]?key|webhook_url|token|secret|password)\s*[:=]\s*(?!"\s*"|'\''\s*'\''|\$\{)[^#\s]+'
if rg -n --pcre2 "$SECRET_PATTERN" "$TMP_DIR/$BUNDLE_NAME/config"; then
  echo "non-empty credential-like value found in copied config" >&2
  exit 1
fi

if rg -n '(sk-[A-Za-z0-9_-]{12,}|gh[pousr]_[A-Za-z0-9_]{20,}|https://[^[:space:]]+/webhook/[^[:space:]]+)' \
  "$TMP_DIR/$BUNDLE_NAME/config"; then
  echo "secret prefix or webhook URL found in copied config" >&2
  exit 1
fi

rm -rf "$BUNDLE_DIR" "$ARCHIVE"
mkdir -p "$DIST_ROOT"
cp -R "$TMP_DIR/$BUNDLE_NAME" "$BUNDLE_DIR"
tar -C "$DIST_ROOT" -czf "$ARCHIVE" "$BUNDLE_NAME"

echo "bundle_dir=$BUNDLE_DIR"
echo "archive=$ARCHIVE"
~~~

- [x] **Step 4: 给 integration 测试增加生成器正反用例**

在 nas_integration=passed 之前加入：

~~~bash
FIXTURE_CONFIG="$TMP_DIR/source-config"
FIXTURE_DIST="$TMP_DIR/dist"
mkdir -p "$FIXTURE_CONFIG"
printf '%s\n' 'app:' '  timezone: Asia/Taipei' 'ai:' '  api_key: ""' \
  'filter:' '  method: "keyword"' > "$FIXTURE_CONFIG/config.yaml"
printf '%s\n' '[GLOBAL_FILTER]' '[WORD_GROUPS]' \
  > "$FIXTURE_CONFIG/frequency_words.txt"

CONFIG_SOURCE="$FIXTURE_CONFIG" DIST_ROOT="$FIXTURE_DIST" \
  "$SCRIPT_DIR/build-bundle.sh" >/dev/null
test -s "$FIXTURE_DIST/trendradar-nas.tar.gz"
test ! -e "$FIXTURE_DIST/trendradar-nas/.env"

printf '%s\n' 'api_key: "test-secret-value"' >> "$FIXTURE_CONFIG/config.yaml"
if CONFIG_SOURCE="$FIXTURE_CONFIG" DIST_ROOT="$FIXTURE_DIST/bad" \
  "$SCRIPT_DIR/build-bundle.sh" >/dev/null 2>&1; then
  echo "bundle accepted a non-empty API key" >&2
  exit 1
fi
~~~

- [x] **Step 5: 运行测试并生成真实包**

~~~bash
chmod +x deploy/nas/build-bundle.sh
bash deploy/nas/test-deployment.sh --static
bash deploy/nas/test-deployment.sh --integration
rm -rf dist/trendradar-nas dist/trendradar-nas.tar.gz
bash deploy/nas/build-bundle.sh
test -s dist/trendradar-nas.tar.gz
test ! -e dist/trendradar-nas/.env
! find dist/trendradar-nas -type f \( -name '*.db' -o -name '*.sqlite' \) | grep -q .
~~~

Expected: 测试通过，包中没有 .env、数据库或历史 HTML。

- [x] **Step 6: 提交**

~~~bash
git add deploy/nas/build-bundle.sh deploy/nas/test-deployment.sh deploy/nas/README.md
git commit -m "feat: generate secret-free NAS bundle"
~~~

### Task 4: 编写操作手册

**Files:**
- Modify: deploy/nas/README.md

- [x] **Step 1: 将 README 替换为完整内容**

> 最终实现：手册使用当前 DSM/Cloudflare 界面，Source 从当前电脑上传本地 `dist/trendradar-nas/docker-compose.yml`，并以分析/翻译双开关落实首次付费闸门。

~~~markdown
# TrendRadar 群晖部署

## 前提

- DS220+ 已安装 Container Manager。
- shankluo.cc 已由 Cloudflare 管理。
- 独立 Tunnel 名称为 trendradar-nas。
- 公网域名为 trend.shankluo.cc。

## 创建 Cloudflare Tunnel

进入 Cloudflare Zero Trust -> Networking -> Tunnels，选择 trendradar-nas，然后进入 Routes -> Add route -> Published application：
- Name: trendradar-nas
- Connector: Docker
- Hostname: trend.shankluo.cc
- Service URL: http://report-web:80

不创建 Cloudflare Access 应用，该 Published application 匿名公开。只复制 Tunnel Token，不复制或保存整条命令。

## 准备 NAS

将 trendradar-nas.tar.gz 上传到 /volume1/docker/ 并解压为
/volume1/docker/trendradar-nas/。

复制 .env.example 为 .env，只填写 AI_API_KEY 和
CLOUDFLARE_TUNNEL_TOKEN。保留 AI_MODEL=deepseek/deepseek-chat、
空 AI_API_BASE、AI_ANALYSIS_ENABLED=false、AI_TRANSLATION_ENABLED=false 和四小时调度。

## 创建 Container Manager 项目

- Project name: xjiankong
- Project path: /volume1/docker/trendradar-nas/
- Source: 从当前电脑的 dist/trendradar-nas/docker-compose.yml 上传
- 不启用可选 Web Station portal/网页入口。
- 启动前确认没有端口映射。

## 首次验收

启动后保持 AI_ANALYSIS_ENABLED=false 和 AI_TRANSLATION_ENABLED=false，先确认三个容器和公网页面安全。未确认前 cron 可继续采集但不调用 AI。老板必须再次明确批准一次人工采集；该运行可能因翻译分批和分析包含多次付费 AI API 请求。获得批准后，
在 xjiankong-trendradar 容器终端执行：

cd /app && AI_ANALYSIS_ENABLED=true AI_TRANSLATION_ENABLED=true python -m trendradar

验证 output/index.html 已生成、trend.shankluo.cc 可访问、敏感路径返回
404、日志显示四小时调度，并且重启项目不会立即采集。验收成功后才将 NAS .env 的 AI_ANALYSIS_ENABLED 和 AI_TRANSLATION_ENABLED 同时改为 true，在 Container Manager 的 xjiankong 项目页停止项目，再重新构建并启动项目，以重建 trendradar 容器并使后续四小时 cron 启用 AI 分析与翻译。

## 更新与回滚

更新前备份 .env 和 config/。新包不得覆盖 NAS 上的 .env 与 output/。
镜像升级必须先通过本地集成测试。只将新 .env.example 的 TRENDRADAR_IMAGE、REPORT_WEB_IMAGE、CLOUDFLARED_IMAGE 三行复制到现有 .env，保留 key/token。回滚时恢复上一份 docker-compose.yml 和这三行旧 digest，然后重建项目。
~~~

- [x] **Step 2: 扫描并重新打包**

~~~bash
! rg -n 'AI_API_KEY=.+|CLOUDFLARE_TUNNEL_TOKEN=.+|ports:|8080:8080' deploy/nas/README.md
bash deploy/nas/build-bundle.sh
tar -xOf dist/trendradar-nas.tar.gz trendradar-nas/README.md \
  | grep -q trend.shankluo.cc
~~~

Expected: 扫描无命中，归档中的手册包含公网域名。

- [x] **Step 3: 提交**

~~~bash
git add deploy/nas/README.md
git commit -m "docs: add Synology deployment runbook"
~~~

### Task 5: 接入质量门禁

**Files:**
- Modify: quality-check.sh
- Modify: .github/workflows/quality.yml

- [x] **Step 1: 在 quality-check.sh 文档检查后加入 NAS 检查**

~~~bash
echo ""
echo "[5/6] NAS 部署模板"
check "NAS Compose 非空" test -s deploy/nas/docker-compose.yml
check "NAS 环境变量模板非空" test -s deploy/nas/.env.example
check "NAS Nginx 配置非空" test -s deploy/nas/nginx.conf
check "NAS 构建脚本可执行" test -x deploy/nas/build-bundle.sh
check "NAS 测试脚本可执行" test -x deploy/nas/test-deployment.sh
check "NAS 静态检查通过" bash deploy/nas/test-deployment.sh --static
~~~

将 TrendRadar 标题改为 [6/6]，其他固定编号统一改为 /6。

- [x] **Step 2: 证明门禁能发现错误**

~~~bash
mv deploy/nas/nginx.conf /tmp/xjiankong-nginx.conf
bash quality-check.sh || true
mv /tmp/xjiankong-nginx.conf deploy/nas/nginx.conf
~~~

Expected: 至少一项 NAS 检查失败。

- [x] **Step 3: 恢复后运行检查**

~~~bash
bash quality-check.sh
bash quality-check.sh --trendradar
~~~

Expected: 两组检查均 0 失败。

- [x] **Step 4: 在 CI custom-checks 中加入**

~~~yaml
      - name: Validate NAS deployment templates
        run: |
          bash -n deploy/nas/build-bundle.sh
          bash -n deploy/nas/test-deployment.sh
          bash deploy/nas/test-deployment.sh --static
~~~

- [x] **Step 5: 本地模拟并提交**

~~~bash
bash -n deploy/nas/build-bundle.sh
bash -n deploy/nas/test-deployment.sh
bash deploy/nas/test-deployment.sh --static
bash quality-check.sh
git diff --check
git add quality-check.sh .github/workflows/quality.yml
git commit -m "ci: validate NAS deployment bundle"
~~~

Expected: 全部成功，git diff --check 无输出。

### Task 6: 仓库内最终验收

**Files:**
- Verify only

- [x] **Step 1: 执行完整测试**

~~~bash
bash quality-check.sh
bash quality-check.sh --trendradar
bash deploy/nas/test-deployment.sh --static
bash deploy/nas/test-deployment.sh --integration
git diff --check
~~~

Expected: 全部退出码为 0。

- [x] **Step 2: 生成并扫描最终包**

~~~bash
rm -rf dist/trendradar-nas dist/trendradar-nas.tar.gz
bash deploy/nas/build-bundle.sh
test -s dist/trendradar-nas.tar.gz
test ! -e dist/trendradar-nas/.env
! find dist/trendradar-nas -type f \( -name '*.db' -o -name '*.sqlite' \) | grep -q .
! rg -n '(sk-[A-Za-z0-9_-]{12,}|CLOUDFLARE_TUNNEL_TOKEN=.+|AI_API_KEY=.+)' \
  dist/trendradar-nas
~~~

Expected: 没有凭据或数据库命中。

- [x] **Step 3: 检查范围**

~~~bash
git status --short
git log --oneline main..HEAD
git diff --stat main...HEAD
~~~

Expected: 只有设计、计划、部署模板、规则和质量检查；dist/ 不在 Git 状态。

### Task 7: 外部部署与付费验收

**Files:**
- External only: Cloudflare dashboard and Synology DSM

- [ ] **Step 1: 请求外部写操作确认**

执行前原样说明：

~~~text
将创建 Cloudflare Tunnel trendradar-nas 和 trend.shankluo.cc；
将在 /volume1/docker/trendradar-nas 写入部署文件和 NAS .env；
将通过 Container Manager 启动三个容器；
首次人工采集会调用当前 AI 模型并产生费用；
批准的是一次人工采集，该运行可能因翻译分批和分析包含多次付费 AI API 请求。
~~~

Expected: 老板在当前对话明确批准四项；否则停止。

- [ ] **Step 2: 创建独立 Tunnel**

~~~text
Tunnel: trendradar-nas
Connector: Docker
Route: Published application
Hostname: trend.shankluo.cc
Service URL: http://report-web:80
Cloudflare Access application: 不创建，因此匿名公开
~~~

Expected: Tunnel 已创建并等待 connector。

- [ ] **Step 3: 上传部署包并填写 NAS .env**

上传 dist/trendradar-nas.tar.gz 到 /volume1/docker/，解压为
/volume1/docker/trendradar-nas/。复制 .env.example 为 .env，只填写现有
AI Key 和新 Tunnel Token，不在日志、截图或对话中显示值。

- [ ] **Step 4: 创建项目**

~~~text
Project name: xjiankong
Path: /volume1/docker/trendradar-nas
Source: 从当前电脑的 dist/trendradar-nas/docker-compose.yml 上传
Web Station portal/网页入口: 不启用
~~~

Expected: 三个容器运行，界面没有端口映射。

- [ ] **Step 5: 确认启动不调用模型**

日志必须显示 CRON_SCHEDULE 为 0 */4 * * *、IMMEDIATE_RUN 为 false、AI_ANALYSIS_ENABLED 为 false、AI_TRANSLATION_ENABLED 为 false，且启动后没有立即采集。未批准前 cron 可采集但不调用 AI。

- [ ] **Step 6: 再次批准一次人工采集**

老板明确批准一次人工采集；该运行可能因翻译分批和分析包含多次付费 AI API 请求。

~~~bash
cd /app && AI_ANALYSIS_ENABLED=true AI_TRANSLATION_ENABLED=true python -m trendradar
~~~

Expected: 退出码 0，生成 index.html 和当天 HTML，日志无密钥。

- [ ] **Step 6a: 启用后续 cron AI 分析与翻译**

首次付费验收成功后，将 NAS `.env` 中 `AI_ANALYSIS_ENABLED` 和 `AI_TRANSLATION_ENABLED` 同时改为 `true`。在 Container Manager 的 `xjiankong` 项目页停止项目，再重新构建并启动项目，以重建 `trendradar` 容器。

- [ ] **Step 7: 公网安全验收**

~~~bash
curl -fsS https://trend.shankluo.cc/ >/dev/null
curl -fsS https://trend.shankluo.cc/index.html >/dev/null
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/news/test.db)" = "404"
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/rss/test.db)" = "404"
test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/.env)" = "404"
~~~

Expected: HTML 返回 200，敏感路径返回 404。

- [ ] **Step 8: 恢复验收**

重启 Container Manager 项目，确认三个容器恢复、没有立即 AI 调用、公网页面恢复，并观察下一次固定四小时调度成功。全部满足后才能标记部署完成。
