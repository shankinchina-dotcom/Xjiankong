# 群晖 NAS 部署记录

> 部署日期：2026-07-06
>
> 状态：三容器生产部署与公网发布已完成；Nitter RSS 代理修复尚未实施
>
> 公网地址：<https://trend.shankluo.cc>

## 一、实际部署架构

生产环境采用 Docker Compose 三容器架构：

| 容器名 | 镜像策略 | 作用 |
|---|---|---|
| `xjiankong-trendradar` | `wantcat/trendradar` 固定 digest | 数据采集、关键词过滤和 HTML 报告生成 |
| `xjiankong-report-web` | `nginx` 固定 digest | 只读发布允许公开的 HTML |
| `xjiankong-cloudflared` | `cloudflare/cloudflared` 固定 digest | 建立 Cloudflare Tunnel 出站连接 |

配置与输出使用 NAS 目录绑定挂载：

- `config/` 只读挂载到 TrendRadar 的 `/app/config`。
- `output/` 由 TrendRadar 读写，并只读挂载到 `report-web` 的 `/source`。
- `report-web` 和 `cloudflared` 只连接 `publish` 网络。
- `trendradar` 只连接 `collector` 网络。
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
