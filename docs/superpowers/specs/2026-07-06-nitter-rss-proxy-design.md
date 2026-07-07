# Nitter RSS 代理隔离设计

> 状态：已实施并通过端到端验证（2026-07-07）。RSS 采集成功 40/44（30/33 Nitter），从修复前 11/44 显著提升。
>
> 确认日期：2026-07-06。
>
> 适用环境：Synology DS220+、Container Manager、现有 Xjiankong Compose 项目。

## 一、问题与目标

生产报告显示 RSS 成功源为 `11/44`。活动配置中包含 33 个 Nitter 源和 11 个非 Nitter 源，数量关系与 NAS 直连 `nitter.net` 失败一致；本机通过代理出口抽测代表性 Nitter feed 可返回 HTTP 200。

本次只解决一个问题：让 TrendRadar 在 NAS 上稳定抓取 Nitter RSS，同时保持其他 RSS、Cloudflare Tunnel、公开报告和 NAS 系统网络不变。

不在本次范围内：

- 不启用 AI 分析或翻译。
- 不修改 X 账号清单、关键词或 K/AI 过滤方法。
- 不安装 DSM 全局 VPN，不修改路由器或 NAS 默认路由。
- 不恢复 X Hosted MCP。
- 不增加代理管理面板或公网入口。

## 二、方案比较

| 方案 | 优点 | 风险 | 结论 |
|---|---|---|---|
| Compose 内 Mihomo sidecar | 只影响 TrendRadar，可复用 Clash URL 订阅，无需 TUN | sidecar 故障会影响本轮 RSS 抓取 | 采用 |
| DSM/NAS 全局 VPN | 所有进程自动走境外出口 | 改变系统网络，可能影响 Tunnel 和其他 NAS 服务 | 不采用 |
| 外部 HTTP 代理服务器 | NAS 无需运行代理内核 | 增加服务器、端口、费用和凭据边界 | 不采用 |

## 三、目标架构

```text
                                  ┌─ nitter.net ── NITTER 策略组 ── Clash 节点
TrendRadar RSS ── HTTP proxy ── rss-proxy
                                  └─ 其他域名 ───────────────────── DIRECT

report-web ── publish network ── cloudflared ── Cloudflare Tunnel
```

新增 `rss-proxy` 服务，只加入现有 `collector` 网络。TrendRadar 的 RSS 抓取器使用 `http://rss-proxy:7890`；Mihomo 按域名分流，`nitter.net` 进入订阅节点策略组，其余请求使用 `DIRECT`。

`report-web` 与 `cloudflared` 继续只使用 `publish` 网络。代理服务不得加入 `publish` 网络，也不得声明 `ports`、`network_mode: host`、TUN 设备或额外 Linux capability。

## 四、组件与配置边界

### 4.1 Mihomo 服务

- 服务名：`rss-proxy`。
- 容器名：`xjiankong-rss-proxy`。
- 镜像：`metacubex/mihomo` v1.19.24 的 linux/amd64 固定镜像 digest：

  ```text
  metacubex/mihomo@sha256:9e37208fae8afa4c8b83d14ff2e9771b99178ebaf65a2c4fb388bc67ecefe4dc
  ```

- 该 digest 已通过 OCI manifest 查询确认存在；生产使用前还必须在隔离环境运行版本检查和配置检查。结果不是 Mihomo v1.19.24、架构不是 amd64 或配置检查失败时立即停止，不回退到 `latest`。
- 监听容器内部 `7890`，不映射宿主机端口。
- 重启策略：`unless-stopped`。
- 不启用 TUN、透明代理、Dashboard、external controller 或 DNS 接管。
- 日志级别使用 `warning`，避免输出订阅细节。

### 4.2 Clash 订阅

Mihomo 使用 `proxy-providers` 的 HTTP provider 读取老板现有 Clash URL 订阅。订阅 URL 是凭据，遵循以下规则：

- 只写入 NAS `/volume1/docker/trendradar-nas/proxy/config.yaml`。
- 文件仅管理员可读写，不进入 Git、部署包、备份日志、命令历史或对话。
- 仓库只提供不含 URL 的 `config.example.yaml`。
- provider 缓存写入 NAS 本地 `proxy/data/`；订阅源短暂不可用时允许使用已有缓存。
- 配置不得把订阅 URL 放入环境变量，因为 `docker inspect` 会公开环境变量值。

策略组使用订阅 provider 中的节点执行健康检查和自动选择。健康检查失败时记录代理不可用，不切换到直连 Nitter。

### 4.3 TrendRadar

实际运行的 `config/config.yaml` 设置：

```yaml
advanced:
  rss:
    use_proxy: true
    proxy_url: "http://rss-proxy:7890"
```

TrendRadar 现有实现会把全部 RSS 请求交给同一个 HTTP 代理，因此按域名选择代理或直连必须由 Mihomo 完成：

```yaml
rules:
  - DOMAIN,nitter.net,NITTER
  - MATCH,DIRECT
```

不修改 RSS 账号、feed URL、关键词和过滤逻辑。

## 五、仓库结构变化

实施时先更新 `AGENTS.md`，再增加：

```text
deploy/nas/proxy/
└── config.example.yaml   # 无订阅 URL 的 Mihomo 配置模板
```

维护规则：

- 只提交示例配置和静态测试。
- `/deploy/nas/proxy/config.yaml`、`/deploy/nas/proxy/data/` 和生成包中的实际代理配置必须被 Git 忽略。
- `build-bundle.sh` 可以复制示例模板，但不得生成、读取或复制真实订阅 URL。
- 敏感字段扫描必须覆盖 URL provider 和常见订阅参数。

预计修改文件：

- `AGENTS.md`
- `.gitignore`
- `deploy/nas/docker-compose.yml`
- `deploy/nas/.env.example`
- `deploy/nas/proxy/config.example.yaml`
- `deploy/nas/test-deployment.sh`
- `deploy/nas/build-bundle.sh`
- `deploy/nas/README.md`
- `quality-check.sh`
- `docs/nas-deployment.md`
- `ai-intelligence-hub-design.md`

这属于跨文件、生产架构和凭据边界变更，必须按实施计划分阶段验证。

## 六、失败行为

| 故障 | 预期行为 | 处理 |
|---|---|---|
| 订阅 URL 首次拉取失败 | `rss-proxy` 不进入可用状态 | 保留现场，检查 NAS 到订阅域名的连通性 |
| 订阅源暂时失败但有缓存 | 使用最近一次成功缓存 | 日志记录 provider 更新失败，下一周期重试 |
| 所有代理节点不可用 | Nitter 抓取失败，不直连绕过 | 等待节点恢复或在 NAS 本地更新订阅 |
| `rss-proxy` 容器停止 | TrendRadar 本轮所有 RSS 连接代理失败 | `unless-stopped` 自动恢复；不修改系统路由 |
| 单个 Nitter 账号 404 | 其他 feed 继续抓取 | 记录账号级失败，不自动删除账号 |
| 非 Nitter 源失败 | 与代理节点无直接关系 | 检查 `MATCH,DIRECT` 与目标源自身状态 |

由于 TrendRadar 只支持一个 RSS 代理入口，sidecar 是 RSS 抓取的单点依赖。实施时通过启动依赖、重启策略和代理连通性预检降低风险，但不隐藏这一限制。

## 七、安全要求

- 不公开 7890 或任何代理控制端口。
- 不使用 `privileged`、`cap_add`、host network 或 `/dev/net/tun`。
- 真实订阅 URL 不写入仓库、Compose、`.env`、命令参数、日志或对话。
- 代理配置与缓存不挂载给 `report-web` 或 `cloudflared`。
- 公开 Nginx 路由继续只允许首页和 `/html/` 报告。
- 不修改 Cloudflare Tunnel 路由。
- 不因本次修复启用付费 AI。

## 八、验证设计

### 8.1 仓库静态验证

- Compose 渲染成功。
- Mihomo 使用固定 digest，且 manifest 为 linux/amd64。
- `rss-proxy` 只属于 `collector` 网络。
- Compose 不存在代理 `ports`、TUN、host network、`privileged` 或额外 capability。
- 示例配置包含 `DOMAIN,nitter.net,NITTER` 和 `MATCH,DIRECT`，不包含真实 URL。
- 构建包敏感扫描拒绝非占位的 provider URL。

### 8.2 本地集成验证

- 使用无真实凭据的测试 provider 或静态测试节点验证配置语法。
- 启动 `rss-proxy` 后，从测试容器访问内部 7890 成功。
- 非 Nitter 测试域名命中 `DIRECT`；Nitter 规则命中 `NITTER` 策略组。
- `report-web` 的首页、报告路径和敏感路径拒绝测试继续通过。

### 8.3 NAS 生产验证

生产变更前先只读记录当前容器状态和最近日志，然后：

1. 在 NAS 本地写入订阅 URL，并检查文件权限。
2. 只重建 Xjiankong Compose 项目，不修改其他 NAS 服务。
3. 验证 `rss-proxy` 版本、配置和 provider 健康状态。
4. 从 TrendRadar 容器经 `http://rss-proxy:7890` 请求至少 3 个代表性 Nitter feed。
5. 人工触发一次采集前再次确认；该次不启用 AI 分析或翻译。
6. 确认 RSS 成功源数明显高于 `11/44`，且原有 11 个非 Nitter 源继续成功。
7. 再次检查公网首页和敏感路径，确认没有代理端口暴露。

## 九、回滚

回滚只恢复 Xjiankong 项目：

1. 将 TrendRadar `advanced.rss.use_proxy` 恢复为 `false`。
2. 从 Compose 移除 `rss-proxy` 服务和依赖关系。
3. 重建 Xjiankong 项目。
4. 验证原有 11 个非 Nitter RSS、首页和 Tunnel 恢复到变更前状态。

真实订阅配置和缓存是否删除属于凭据清理，执行前必须再次获得老板明确确认；回滚过程中不得自行删除。
