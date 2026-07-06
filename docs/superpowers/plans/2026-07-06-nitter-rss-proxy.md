# Nitter RSS 代理隔离 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 NAS Compose 中增加无宿主机端口、无 TUN 的 Mihomo sidecar，只代理 `nitter.net`，并使 TrendRadar 的其他 RSS 继续直连。

**Architecture:** `trendradar` 将全部 RSS HTTP 请求交给内部 `rss-proxy:7890`；Mihomo 通过 `DOMAIN,nitter.net,NITTER` 将 Nitter 发往 Clash 订阅节点，通过 `MATCH,DIRECT` 直连其他源。真实订阅 URL 仅由老板写入 NAS 本地 `proxy/config.yaml`，仓库和部署包只保存 `.invalid` 示例。

**Tech Stack:** Docker Compose、Mihomo v1.19.24 固定 amd64 digest、TrendRadar、Bash、jq、Ruby Psych、Synology Container Manager。

---

## 文件结构

| 路径 | 职责 |
|---|---|
| `AGENTS.md` | 先声明 `deploy/nas/proxy/` 的用途和清理规则 |
| `.gitignore` | 排除真实代理配置和 provider 缓存 |
| `deploy/nas/proxy/config.example.yaml` | 无凭据的 Mihomo 示例与域名分流规则 |
| `deploy/nas/docker-compose.yml` | 增加 `rss-proxy` 服务和内部依赖 |
| `deploy/nas/.env.example` | 固定代理镜像 digest 与非敏感路径 |
| `deploy/nas/test-deployment.sh` | 代理静态、网络隔离、部署包和本地连通性测试 |
| `deploy/nas/build-bundle.sh` | 只复制代理示例，拒绝真实订阅 URL |
| `deploy/nas/README.md` | NAS 凭据写入、升级、验收与回滚手册 |
| `quality-check.sh` | 将代理模板和实际 TrendRadar 代理配置纳入门禁 |
| `../TrendRadar/config/config.yaml` | 实际 RSS 代理入口；保留现有未提交配置，不整文件覆盖 |

## 执行前闸门

- `AGENTS.md` 与相邻 TrendRadar 配置已有老板的未提交改动。实施前先检查两个仓库的状态；不得覆盖、回滚或顺带提交现有改动。
- 修改 `../TrendRadar/config/config.yaml` 前再次获得老板确认。
- 上传 NAS、写入订阅 URL、重建容器和人工采集必须分别在对应步骤前确认。
- 订阅 URL 不得通过聊天、命令参数、`.env` 或 `docker inspect` 传递；由老板在 DSM File Station 中直接写入 NAS 文件。

### Task 1: 声明代理目录并建立失败测试

**Files:**
- Modify: `AGENTS.md`
- Modify: `.gitignore`
- Modify: `deploy/nas/test-deployment.sh:5-156`
- Create: `deploy/nas/proxy/config.example.yaml`

- [ ] **Step 1: 检查并保护脏工作树**

```bash
git status --short
git diff -- AGENTS.md
git -C ../TrendRadar status --short
```

Expected: 看见现有 `AGENTS.md`、`.DS_Store`、WorkBuddy 和 TrendRadar 配置改动；记录但不清理。

- [ ] **Step 2: 先更新目录和忽略规则**

在 `AGENTS.md` 的 `deploy/nas/` 后加入：

```markdown
| `deploy/nas/proxy/` | Mihomo 无凭据示例配置 | 只提交 `config.example.yaml`；真实配置和 provider 缓存只保存在 NAS |
```

在 `.gitignore` 追加：

```gitignore
/deploy/nas/proxy/config.yaml
/deploy/nas/proxy/data/
```

- [ ] **Step 3: 写入代理模板缺失的失败断言**

在测试变量区加入：

```bash
PROXY_EXAMPLE_FILE="$SCRIPT_DIR/proxy/config.example.yaml"
```

在 `require_nonempty` 区加入：

```bash
require_nonempty "$PROXY_EXAMPLE_FILE"
grep -Fq 'DOMAIN,nitter.net,NITTER' "$PROXY_EXAMPLE_FILE" ||
  fail 'proxy_template_missing_nitter_rule'
grep -Fq 'MATCH,DIRECT' "$PROXY_EXAMPLE_FILE" ||
  fail 'proxy_template_missing_direct_fallback'
grep -Fq 'url: "https://subscription.invalid/clash"' "$PROXY_EXAMPLE_FILE" ||
  fail 'proxy_template_invalid_subscription_sentinel'
```

- [ ] **Step 4: 确认测试先失败**

Run: `bash deploy/nas/test-deployment.sh --static`

Expected: FAIL，包含 `missing_or_empty:.../deploy/nas/proxy/config.example.yaml`。

- [ ] **Step 5: 创建最小示例配置**

```yaml
mixed-port: 7890
allow-lan: true
bind-address: "*"
mode: rule
log-level: warning
ipv6: false

proxy-providers:
  subscription:
    type: http
    url: "https://subscription.invalid/clash"
    path: ./providers/subscription.yaml
    interval: 86400
    health-check:
      enable: true
      url: https://cp.cloudflare.com/generate_204
      interval: 600

proxy-groups:
  - name: NITTER
    type: url-test
    use: [subscription]
    url: https://cp.cloudflare.com/generate_204
    interval: 600

rules:
  - DOMAIN,nitter.net,NITTER
  - MATCH,DIRECT
```

- [ ] **Step 6: 验证模板基线**

Run: `bash deploy/nas/test-deployment.sh --static`

Expected: `nas_static=passed`。

### Task 2: 增加隔离的 Mihomo Compose 服务

**Files:**
- Modify: `deploy/nas/test-deployment.sh:107-156`
- Modify: `deploy/nas/docker-compose.yml:3-62`
- Modify: `deploy/nas/.env.example:1-15`

- [ ] **Step 1: 先增加 Compose 安全断言**

```bash
printf '%s\n' "$COMPOSE_JSON" | jq -e '
  (.services["rss-proxy"].networks | keys) == ["collector"]
  and (.services["rss-proxy"] | has("ports") | not)
  and (.services["rss-proxy"] | has("network_mode") | not)
  and (.services["rss-proxy"] | has("cap_add") | not)
  and (.services["rss-proxy"].privileged // false) == false
  and (.services["rss-proxy"].read_only == true)
' >/dev/null || fail 'compose_invalid_rss_proxy_isolation'

printf '%s\n' "$COMPOSE_JSON" | jq -e '
  .services["rss-proxy"].image ==
    "metacubex/mihomo@sha256:9e37208fae8afa4c8b83d14ff2e9771b99178ebaf65a2c4fb388bc67ecefe4dc"
  and .services.trendradar.depends_on["rss-proxy"].condition == "service_started"
' >/dev/null || fail 'compose_invalid_rss_proxy_contract'
```

- [ ] **Step 2: 确认服务缺失失败**

Run: `bash deploy/nas/test-deployment.sh --static`

Expected: FAIL，包含 `compose_invalid_rss_proxy_isolation`。

- [ ] **Step 3: 增加固定镜像和路径**

```dotenv
RSS_PROXY_IMAGE=metacubex/mihomo@sha256:9e37208fae8afa4c8b83d14ff2e9771b99178ebaf65a2c4fb388bc67ecefe4dc
RSS_PROXY_CONFIG_FILE=./proxy/config.yaml
RSS_PROXY_DATA_DIR=./proxy/data
```

- [ ] **Step 4: 增加服务和依赖**

为 `trendradar` 加入：

```yaml
    depends_on:
      rss-proxy:
        condition: service_started
```

增加服务：

```yaml
  rss-proxy:
    image: ${RSS_PROXY_IMAGE}
    container_name: xjiankong-rss-proxy
    restart: unless-stopped
    command: ["-d", "/var/lib/mihomo", "-f", "/run/mihomo/config.yaml"]
    read_only: true
    volumes:
      - ${RSS_PROXY_CONFIG_FILE:-./proxy/config.yaml}:/run/mihomo/config.yaml:ro
      - ${RSS_PROXY_DATA_DIR:-./proxy/data}:/var/lib/mihomo
    tmpfs: [/tmp]
    networks: [collector]
```

- [ ] **Step 5: 验证镜像身份和配置语法**

```bash
docker buildx imagetools inspect \
  metacubex/mihomo@sha256:9e37208fae8afa4c8b83d14ff2e9771b99178ebaf65a2c4fb388bc67ecefe4dc
docker run --rm --platform linux/amd64 \
  metacubex/mihomo@sha256:9e37208fae8afa4c8b83d14ff2e9771b99178ebaf65a2c4fb388bc67ecefe4dc \
  -v 2>&1 | grep -F 'v1.19.24'
docker run --rm --platform linux/amd64 \
  -v "$PWD/deploy/nas/proxy/config.example.yaml:/run/mihomo/config.yaml:ro" \
  metacubex/mihomo@sha256:9e37208fae8afa4c8b83d14ff2e9771b99178ebaf65a2c4fb388bc67ecefe4dc \
  -t -f /run/mihomo/config.yaml
```

Expected: manifest 存在，版本包含 `v1.19.24`，配置检查退出码为 0；失败时停止，不用 `latest`。

- [ ] **Step 6: 测试并提交模板基础**

Run: `bash deploy/nas/test-deployment.sh --static`

Expected: `nas_static=passed`。

```bash
git add .gitignore deploy/nas/proxy/config.example.yaml \
  deploy/nas/docker-compose.yml deploy/nas/.env.example deploy/nas/test-deployment.sh
git add -p AGENTS.md
git diff --cached --check
git commit -m "feat: add isolated RSS proxy service"
```

执行 `git add -p AGENTS.md` 时只接受新增 `deploy/nas/proxy/` 行，拒绝此前状态段落改动；随后用 `git diff --cached -- AGENTS.md` 再确认。

### Task 3: 让部署包只携带无凭据示例

**Files:**
- Modify: `deploy/nas/test-deployment.sh:163-313`
- Modify: `deploy/nas/build-bundle.sh:94-144`

- [ ] **Step 1: 增加部署包断言**

```bash
[[ -s "$BUNDLE_DIST_DIR/trendradar-nas/proxy/config.example.yaml" ]] ||
  fail 'bundle_proxy_example_missing'
[[ ! -e "$BUNDLE_DIST_DIR/trendradar-nas/proxy/config.yaml" ]] ||
  fail 'bundle_contains_real_proxy_config'
```

在模板泄密 fixture 中加入：

```bash
mkdir -p "$TEMPLATE_DIR/proxy"
cp "$PROXY_EXAMPLE_FILE" "$TEMPLATE_DIR/proxy/config.example.yaml"
sed 's#https://subscription.invalid/clash#https://provider.example/sub/SECRET123#' \
  "$TEMPLATE_DIR/proxy/config.example.yaml" > \
  "$TEMPLATE_DIR/proxy/config.example.yaml.tmp"
mv "$TEMPLATE_DIR/proxy/config.example.yaml.tmp" \
  "$TEMPLATE_DIR/proxy/config.example.yaml"

if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$TEMPLATE_DIR/build-bundle.sh" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_proxy_secret_fixture_succeeded'
fi
grep -Fq 'proxy_template_subscription_url_invalid' "$BUNDLE_LOG" ||
  fail 'bundle_proxy_secret_reason_missing'
if grep -Fq 'SECRET123' "$BUNDLE_LOG"; then
  fail 'bundle_proxy_secret_value_logged'
fi
```

- [ ] **Step 2: 确认测试先失败**

Run: `bash deploy/nas/test-deployment.sh --integration`

Expected: FAIL，包含 `bundle_proxy_example_missing`。

- [ ] **Step 3: 复制示例并验证 sentinel**

在 staging layout 中加入：

```bash
mkdir -p "$BUNDLE_DIR/config" "$BUNDLE_DIR/output" \
  "$BUNDLE_DIR/proxy/data" || fail 'staging_layout_failed'
cp "$SCRIPT_DIR/proxy/config.example.yaml" \
  "$BUNDLE_DIR/proxy/config.example.yaml" || fail 'proxy_template_copy_failed'
```

在通用敏感扫描前加入：

```bash
PROXY_TEMPLATE="$BUNDLE_DIR/proxy/config.example.yaml"
proxy_subscription_url="$(
  ruby -rpsych - "$PROXY_TEMPLATE" <<'RUBY'
data = Psych.safe_load(File.read(ARGV.fetch(0)), aliases: false)
url = data.dig('proxy-providers', 'subscription', 'url')
exit 1 unless url.is_a?(String)
print url
RUBY
)" || fail 'proxy_template_invalid_yaml'
[[ "$proxy_subscription_url" == 'https://subscription.invalid/clash' ]] ||
  fail 'proxy_template_subscription_url_invalid'
```

- [ ] **Step 4: 验证并提交**

Run: `bash deploy/nas/test-deployment.sh --integration`

Expected: `nas_integration=passed`；生成包只有代理示例。

```bash
git add deploy/nas/build-bundle.sh deploy/nas/test-deployment.sh
git diff --cached --check
git commit -m "fix: keep RSS subscription out of NAS bundle"
```

### Task 4: 将实际 TrendRadar 配置切到内部代理

**Files:**
- Modify: `deploy/nas/test-deployment.sh:184-203`
- Modify: `deploy/nas/build-bundle.sh:294-401`
- Modify: `quality-check.sh:55-70`
- Modify external runtime source: `../TrendRadar/config/config.yaml:601-622`

- [ ] **Step 1: 在 bundle fixture 中加入期望配置**

```yaml
filter:
  method: keyword
advanced:
  rss:
    use_proxy: true
    proxy_url: http://rss-proxy:7890
ai:
  api_key: ""
```

- [ ] **Step 2: 为生成器增加 YAML 结构验证**

对 `config/config.yaml` 使用 `Psych.safe_load_file`，要求：

```ruby
rss = data.dig('advanced', 'rss')
unless rss.is_a?(Hash) && rss['use_proxy'] == true &&
       rss['proxy_url'] == 'http://rss-proxy:7890'
  warn "bundle_build=failed reason=config_rss_proxy_invalid:config/config.yaml"
  exit 1
end
```

不得用正则替代 YAML 结构校验。

- [ ] **Step 3: 为质量检查增加实际 fork 断言**

```bash
check "config.yaml RSS 使用内部代理" ruby -rpsych -e '
  c = Psych.safe_load_file(ARGV.fetch(0), aliases: false)
  exit 1 unless c.dig("advanced", "rss", "use_proxy") == true
  exit 1 unless c.dig("advanced", "rss", "proxy_url") == "http://rss-proxy:7890"
' "$TR/config/config.yaml"
```

- [ ] **Step 4: 确认实际配置检查先失败**

Run: `bash quality-check.sh --trendradar`

Expected: FAIL，仅新增的内部代理检查失败。

- [ ] **Step 5: 再次确认后精准修改相邻 fork**

先展示 `git -C ../TrendRadar diff -- config/config.yaml`。获得明确确认后，仅把现有 `advanced.rss` 改为：

```yaml
    use_proxy: true
    proxy_url: "http://rss-proxy:7890"
```

不得修改、暂存或提交相邻仓库的其他配置、`docker/.env` 或输出。

- [ ] **Step 6: 验证配置和真实部署包**

```bash
bash quality-check.sh --trendradar
bash deploy/nas/test-deployment.sh --integration
bash deploy/nas/build-bundle.sh
test -s dist/trendradar-nas/proxy/config.example.yaml
test ! -e dist/trendradar-nas/proxy/config.yaml
```

Expected: 全部通过；相邻 TrendRadar 改动保持未暂存。

- [ ] **Step 7: 只提交 Xjiankong 门禁**

```bash
git add quality-check.sh deploy/nas/build-bundle.sh deploy/nas/test-deployment.sh
git diff --cached --check
git commit -m "test: require internal RSS proxy configuration"
```

### Task 5: 更新操作手册与仓库实现状态

**Files:**
- Modify: `deploy/nas/README.md`
- Modify: `docs/nas-deployment.md`
- Modify: `ai-intelligence-hub-design.md`
- Modify: `docs/superpowers/specs/2026-07-06-nitter-rss-proxy-design.md`

- [ ] **Step 1: 更新 README**

必须写明：部署包只含示例；老板在 NAS File Station 复制为 `proxy/config.yaml` 并替换 `.invalid` URL；文件仅管理员可读写；四容器无端口/TUN/host network；两个 AI 开关继续为 `false`。

- [ ] **Step 2: 更新状态但不提前宣称生产完成**

统一写为“仓库代理模板已实施并通过本地验证，NAS 生产变更尚未执行”；规格状态改为“仓库实现完成，NAS 实施待确认”。

- [ ] **Step 3: 完整验证与提交**

```bash
jq empty config/x-accounts.json
bash quality-check.sh
bash quality-check.sh --trendradar
rg -n 'A2.*(实施|运行|待接入)|X Hosted MCP.*(主线|当前)' \
  AGENTS.md CLAUDE.md ai-intelligence-hub-design.md docs --glob '!docs/archive/**'
git diff --check
git add deploy/nas/README.md docs/nas-deployment.md \
  ai-intelligence-hub-design.md \
  docs/superpowers/specs/2026-07-06-nitter-rss-proxy-design.md
git diff --cached --check
git commit -m "docs: document NAS RSS proxy rollout"
```

Expected: JSON、质量检查和 diff check 通过；A2 仍非活动主线。

### Task 6: NAS 生产实施与验收

**Files on NAS:**
- Modify: `/volume1/docker/trendradar-nas/docker-compose.yml`
- Modify: `/volume1/docker/trendradar-nas/.env`
- Modify: `/volume1/docker/trendradar-nas/config/config.yaml`
- Create: `/volume1/docker/trendradar-nas/proxy/config.yaml`
- Create directory: `/volume1/docker/trendradar-nas/proxy/data/`

- [ ] **Step 1: 生产写入前再次确认**

说明将上传四容器 Compose、写入 RSS 代理配置并重建 Xjiankong 项目；不会启用 AI、修改 Tunnel 或其他 NAS 项目。未获当前步骤确认不得继续。

- [ ] **Step 2: 只读记录变更前状态**

记录三个现有容器状态、镜像 digest、最近 RSS 日志；备份当前 Compose 与 `config/config.yaml`。不读取、复制或公开 `.env`。

Expected: 基线为三容器，RSS 约 `11/44`，公网首页可访问。

- [ ] **Step 3: 由老板在 NAS 写入订阅 URL**

通过 File Station：复制 `proxy/config.example.yaml` 为 `proxy/config.yaml`，替换 `.invalid` URL，限制为仅管理员读写，创建不公开的 `proxy/data/`。订阅 URL 不经过聊天或终端。

- [ ] **Step 4: 上传并重建项目**

上传新 Compose 和 `config/config.yaml`。现有 `.env` 只增加 `RSS_PROXY_IMAGE`、`RSS_PROXY_CONFIG_FILE`、`RSS_PROXY_DATA_DIR`，不改 AI Key、AI 开关或 Tunnel Token。预览确认无端口映射后停止并重新构建 `xjiankong`。

Expected: 四个容器运行，`report-web` 健康，Tunnel 恢复；没有新增宿主机端口。

- [ ] **Step 5: 在不触发 AI 的情况下验证代理**

在 TrendRadar 容器终端分别测试 `OpenAI`、`karpathy`、`dotey`：

```bash
python -c 'import requests; p={"http":"http://rss-proxy:7890","https":"http://rss-proxy:7890"}; r=requests.get("https://nitter.net/OpenAI/rss",proxies=p,timeout=20); print(r.status_code, len(r.content))'
```

Expected: 三个 feed 均为 HTTP 200 且正文非空；输出不含订阅 URL。

- [ ] **Step 6: 再次确认后人工采集**

获得确认后执行：

```bash
cd /app
AI_ANALYSIS_ENABLED=false AI_TRANSLATION_ENABLED=false python -m trendradar
```

Expected: RSS 成功源明显高于 `11/44`，原有 11 个非 Nitter 源继续成功；个别失败按 feed ID 记录。

- [ ] **Step 7: 公网安全回归**

确认首页为 200；`/news/test.db`、`/rss/test.db`、`/.env`、`/config/config.yaml` 为 404；路由器和 Container Manager 没有 7890、9090 或其他新增端口。

- [ ] **Step 8: 失败时回滚**

若代理、原有 RSS、Tunnel 或安全验收失败，停止采集并取得确认后恢复上一版 Compose 和 `config/config.yaml`，重建原三容器项目。保留 `proxy/config.yaml` 和缓存现场，不自行删除。

### Task 7: 记录生产结果

**Files:**
- Modify: `docs/nas-deployment.md`
- Modify: `ai-intelligence-hub-design.md`
- Modify: `docs/superpowers/specs/2026-07-06-nitter-rss-proxy-design.md`
- Modify: `docs/superpowers/plans/2026-07-06-nitter-rss-proxy.md`

- [ ] **Step 1: 写入真实验收结果**

记录部署时间、四容器状态、RSS 成功/失败数、代表性 Nitter 测试和安全回归。不得记录订阅 URL、节点名称或代理服务器地址。

- [ ] **Step 2: 更新状态与复选框**

只有 NAS 验收全部通过，才把设计改为“已实施”、活动架构改为“四容器生产运行”，并勾选本计划完成步骤。

- [ ] **Step 3: 最终验证并提交**

```bash
jq empty config/x-accounts.json
bash quality-check.sh
bash quality-check.sh --trendradar
bash deploy/nas/test-deployment.sh --integration
git diff --check
git add docs/nas-deployment.md ai-intelligence-hub-design.md \
  docs/superpowers/specs/2026-07-06-nitter-rss-proxy-design.md \
  docs/superpowers/plans/2026-07-06-nitter-rss-proxy.md
git diff --cached --check
git commit -m "docs: record NAS RSS proxy deployment"
```

Expected: 全部通过，且提交不包含订阅 URL 或无关工作树改动。
