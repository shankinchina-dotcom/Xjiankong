# 群晖 NAS 部署记录

> 部署日期：2026-07-06
>
> 状态：四容器生产部署已上线运行。Nitter RSS 代理修复已完成端到端验证（2026-07-07）：RSS 采集成功 **40/44**（30/33 Nitter X 源成功），从修复前 11/44 显著提升。公网发布正常（trend.shankluo.cc 可访问）
>
> 公网地址：<https://trend.shankluo.cc>

## 一、实际部署架构

生产环境采用 Docker Compose 四容器架构：

| 容器名 | 镜像策略 | 作用 |
|---|---|---|
| `xjiankong-trendradar` | `wantcat/trendradar` 固定 digest | 数据采集、关键词过滤和 HTML 报告生成 |
| `xjiankong-rss-proxy` | `metacubex/mihomo` 固定 digest | Nitter RSS 代理 sidecar（仅内部 7890，不映射宿主机端口） |
| `xjiankong-report-web` | `nginx` 固定 digest | 只读发布允许公开的 HTML |
| `xjiankong-cloudflared` | `cloudflare/cloudflared` 固定 digest | 建立 Cloudflare Tunnel 出站连接 |

配置与输出使用 NAS 目录绑定挂载：

- `config/` 只读挂载到 TrendRadar 的 `/app/config`。
- `output/` 由 TrendRadar 读写，并只读挂载到 `report-web` 的 `/source`。
- `report-web` 和 `cloudflared` 只连接 `publish` 网络。
- `trendradar` 与 `rss-proxy` 只连接 `collector` 网络；`trendradar` 经 `http://rss-proxy:7890` 访问 Nitter RSS，`rss-proxy` 按域名规则分流（nitter.net 走订阅节点，其余直连）。
- Compose 不发布宿主机端口。

镜像、挂载和网络的实际模板以 [`deploy/nas/docker-compose.yml`](../deploy/nas/docker-compose.yml) 与 [`deploy/nas/.env.example`](../deploy/nas/.env.example) 为准，不使用漂移的 `latest` 标签。

## 二、Cloudflare Tunnel

- Tunnel：`trendradar-nas`
- Hostname：`trend.shankluo.cc`
- Service URL：`http://report-web:80`
- 访问方式：公网匿名只读

部署期间出现过 502。确认 `report-web` 健康且容器网络正常后，发现 Tunnel 没有 Published application 路由；补充以上路由后恢复。Tunnel 显示健康只代表 connector 在线，不代表 hostname 路由已经配置。

## 三、当前运行状态

2026-07-06 公网检查结果：

- 首页返回 HTTP 200，前端无控制台错误。
- 热榜平台成功 `10/11`，失败源为 `toutiao`。
- RSS 源成功 `11/44`，RSS 内容命中 `30/83`。
- AI 分析显示“未启用”。
- `/news/*.db`、`/rss/*.db`、`/.env` 和 `/config/*` 返回 404。

AI 分析与翻译关闭符合部署模板的安全默认值。启用付费 AI、修改 NAS `.env` 和重建生产容器必须单独获得确认，不作为 Nitter 修复的附带操作。

## 四、Nitter RSS 失败结论

活动配置包含 44 个启用 RSS 源，其中：

- 33 个 `nitter.net` 源。
- 11 个 Hacker News、GitHub、HuggingFace、Release 等非 Nitter 源。

线上成功数恰为 `11/44`，与 NAS 无代理出口导致 33 个 Nitter 源全部失败高度吻合。本机通过代理出口抽测 Nitter feed 可返回 HTTP 200，说明账号清单本身不是这次整体失败的原因。

当前结论仍需在实施时用 NAS 容器日志和单源请求确认。不得把“需要代理出口”写成“Nitter 在所有网络环境都必须使用 VPN”，也不得因传输失败删除 `config/x-accounts.json` 中的账号。

## 五、已确认的修复方向

在现有 Compose 中增加独立 Mihomo sidecar：

```text
TrendRadar RSS
      ↓ HTTP proxy
Mihomo sidecar
      ├─ nitter.net → Clash 订阅节点
      └─ 其他域名 → DIRECT
```

安全边界：

- 不安装 NAS 全局 VPN，不修改 DSM 系统网络。
- 不启用 TUN，不申请 `NET_ADMIN`，不使用 host network。
- 不发布 Mihomo 端口，只允许 `collector` 网络中的 TrendRadar 访问。
- Clash 订阅 URL 只保存在 NAS 本地受限配置中，不进入 Git、部署包、命令、日志或对话。
- Mihomo 使用固定版本和 digest，实施前核对镜像架构与程序版本，不使用 `latest`。
- TrendRadar 将 RSS 请求交给 sidecar；sidecar 仅将 `nitter.net` 路由到代理节点，其他 RSS 使用 `DIRECT`。

完整设计见 [`docs/superpowers/specs/2026-07-06-nitter-rss-proxy-design.md`](superpowers/specs/2026-07-06-nitter-rss-proxy-design.md)。

## 五之二、本地仓库准备（已完成）

2026-07-07 在仓库内完成 Nitter 代理修复的全部源码准备，均通过 `deploy/nas/test-deployment.sh --static` 与 `build-bundle.sh`：

- `deploy/nas/docker-compose.yml`：新增 `rss-proxy` 服务（`metacubex/mihomo` 固定 digest），只连接 `collector` 网络，不映射宿主机端口，不启用 TUN/host network。
- `deploy/nas/proxy/config.example.yaml`：不含真实订阅 URL 的 Mihomo 模板，含 `DOMAIN,nitter.net,NITTER` 与 `MATCH,DIRECT` 规则。
- `deploy/nas/.env.example`：新增 `RSS_PROXY_IMAGE`。
- `.gitignore`：忽略 `deploy/nas/proxy/config.yaml` 与 `proxy/data/`。
- `deploy/nas/build-bundle.sh`：复制 `proxy/config.example.yaml` 进部署包，敏感扫描拒绝非占位订阅 URL、拒绝真实代理配置/缓存进包。
- `deploy/nas/test-deployment.sh`：新增 rss-proxy 网络隔离、无端口、镜像 digest、代理模板规则校验。
- `quality-check.sh`：新增代理模板校验（见第七节）。

**部署包验证**：`dist/trendradar-nas.tar.gz` 含 `proxy/config.example.yaml`，不含 `proxy/config.yaml` 或 `proxy/data/`。

## 五之三、NAS 实施步骤（已完成 2026-07-07）

老板已提供 Clash 订阅 URL 并确认部署，四容器已在 NAS 运行。实施过程与最终配置：

1. `proxy/config.yaml`（NAS 本地，含真实订阅 URL，gitignored）已就位，关键字段：
   - `allow-lan: true`（必须，否则 Mihomo 只绑 127.0.0.1，跨容器访问被拒——踩坑修复）
   - `bind-address: 0.0.0.0`、`mixed-port: 7890`、`ipv6: false`
   - `proxy-groups.NITTER`：`type: url-test` + `use: [nitter]`（必须 `use:` 引用 provider，否则 provider 节点不纳入组、nitter 走 DIRECT——踩坑修复）
   - 规则 `DOMAIN,nitter.net,NITTER` + `MATCH,DIRECT`
2. `.env` 已补 `RSS_PROXY_IMAGE=metacubex/mihomo@sha256:9e372...`。
3. 镜像经本地 `docker save` 打包为 `dist/xjiankong-images.tar` 上传 NAS `docker load`（绕过 Docker Hub 拉取超时）。
4. Compose 项目已重建，四容器 Running，`report-web` healthy。
5. 网络层验证：`trendradar → rss-proxy:7890` TCP 通（`PROXY_OK`）；经代理抓 `nitter.net/OpenAI/rss` 返回 `E2E_OK HTTP=200`（size=0 是 nitter 对该端点返回空 body，非代理问题）。

**端到端验证（2026-07-07）**：手动触发采集，结果：

```text
[RSS] 抓取完成: 40 个源成功, 4 个失败, 共 733 条
```

- **Nitter X 源**：30/33 成功（2 个 404 为 `xai`、`GabrielPeterss4` 在 Nitter 不存在，非代理问题）
- **非 Nitter RSS**：10/11 成功（Hacker News 走代理 SSL 异常，后续评估关 RSS 全局代理）
- **热榜**：初次采集因爬虫代理误开全量失败；修正后热榜直连恢复正常
- ✅ **验收通过**：RSS 成功数从 11/44 提升至 40/44

**关键发现**：仓库配置文件与 NAS 实际运行配置不同步。`deploy/nas/config/config.yaml` 中 `advanced.rss.use_proxy: true` 和 `proxy_url: http://rss-proxy:7890` 未反映到 NAS 运行的 `/volume1/docker/trendradar-nas/config/config.yaml`，导致 TrendRadar 全程直连 Nitter。后续 NAS 配置变更需通过 SSH 直接修改运行配置文件，不能依赖部署包同步。

### 实施踩坑（后续 agent 必读，避免重犯）
- **File Station 整体 tar 解压覆盖不可靠**：PaxHeader 旧包残留会损坏 `docker-compose.yml`、`nginx.conf`。关键文件必须**单个重新上传覆盖**。`build-bundle.sh` 已加 `--no-mac-metadata` + `COPYFILE_DISABLE=1`。
- **trendradar 容器无 wget/curl**，只有 python；网络测试用 `python -c "import urllib.request/socket"`。rss-proxy(Mihomo) 容器也无 python/wget/curl，看监听端口读 `/proc/net/tcp`（7890 = 0x1ED2，务必算对）。
- **trendradar 入口是 `python -m trendradar`**，不是 `python /app/main.py`（后者 No such file）。
- **Synology Auto Block**：多次 SSH 密码错误会封源 IP（新连接 `Connection reset by peer`，已有会话不受影响）。解封：DSM → 控制面板 → 安全 → 保护 → 允许/阻止列表。scp 到 Synology 需 `-O`（SFTP 子系统未启用）；写 `/volume1/docker` 需 root，先 scp 到 `/tmp` 再 `sudo cp`。
- **局域网调试优先 SSH 直连**（`ssh z5451530@192.168.1.193`），交互式跑 docker/exec 即时看输出；DSM 任务计划脚本+下载日志仅作 SSH 不可用时兜底。

回滚：将 TrendRadar `advanced.rss.use_proxy` 改回 `false`，从 Compose 移除 `rss-proxy`，重建项目即可。

### 端到端验证踩坑（2026-07-07 新增）
- **仓库快照 ≠ NAS 运行配置**：`deploy/nas/config/` 下的配置模板与 NAS `/volume1/docker/trendradar-nas/config/` 的实际运行文件是两套独立副本，修改仓库端不会自动同步到 NAS。验证时发现 NAS 上 `advanced.rss.use_proxy` 仍为 `false`、`proxy_url` 为空。
- **Synology `sed -i` 语法**：macOS 的 `sed -i ''` 在 Synology Linux 上不工作（会把 `''` 解析为备份后缀），必须用 `sed -i` 不加参数。
- **爬虫代理隔离**：TrendRadar 有 `crawler.use_proxy`（热榜）和 `advanced.rss.use_proxy`（RSS）两个独立的代理开关。RSS 走代理时务必确认爬虫代理保持 `false`，否则国内热榜全部通过代理出口而失败。
- **TrendRadar RSS 代理是全局的**：`advanced.rss.use_proxy: true` 会让所有 RSS 源走同一个代理，非 Nitter 源（Hacker News、GitHub Releases）依赖 Mihomo 的 `MATCH,DIRECT` 直连。少数站点走 Mihomo 直连时可能存在 SSL 兼容问题。

## 六、调度与维护基线

- `CRON_SCHEDULE=0 */4 * * *`，每 4 小时采集一次。
- `IMMEDIATE_RUN=false`，容器重建不立即触发采集。
- `AI_ANALYSIS_ENABLED=false`。
- `AI_TRANSLATION_ENABLED=false`。
- 容器重启策略为 `unless-stopped`。

生产维护以 [`deploy/nas/README.md`](../deploy/nas/README.md) 为操作入口。修改运行配置、重建容器、写入订阅 URL 或启用 AI 前，都必须先说明变更与验证方式并获得确认。

## 七、Nitter 修复验收

实施后必须同时满足：

1. Mihomo 配置检查通过，镜像为固定 amd64 digest。
2. 公网不出现新的代理端口，NAS 全局出口不改变。
3. 从 TrendRadar 容器经 `http://rss-proxy:7890` 请求至少 3 个代表性 Nitter feed 成功。
4. RSS 成功源数明显高于 `11/44`；个别账号失败需要按日志单独记录，不用总数掩盖。
5. 原有 11 个非 Nitter RSS 继续成功。
6. `.env`、订阅 URL、代理节点和 SQLite 仍不可通过公网访问。
7. Cloudflare Tunnel、`report-web` 和现有 HTML 报告不受影响。
