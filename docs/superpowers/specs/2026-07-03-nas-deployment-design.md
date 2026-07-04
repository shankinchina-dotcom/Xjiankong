# 群晖 NAS 部署设计

> 状态：设计已确认，仓库部署模板已实施；Cloudflare 和 NAS 外部部署尚未实施。
>
> 目标设备：Synology DS220+，DSM Container Manager。
>
> 公网地址：`https://trend.shankluo.cc`。

## 一、目标与非目标

### 1.1 目标

- 将当前 A1 TrendRadar 管道部署到群晖 DS220+。
- 通过 Container Manager 项目导入，降低首次部署和后续维护复杂度。
- 每 4 小时采集一次，继续使用 Variant K 关键词过滤和当前 AI 分析配置。
- 公网匿名访问 HTML 日报，不要求用户登录。
- 不开放 NAS 入站端口，不向公网暴露 SQLite、配置或密钥。
- 配置、原始数据库和 HTML 日报在 NAS 上持久化。

### 1.2 非目标

- 不迁移本机历史数据库和 HTML 报告。
- 不部署 `trendradar-mcp`。
- 不恢复 X Hosted MCP。
- 不在本轮执行 K/AI 离线实验或切换到 AI 过滤。
- 不在仓库中保存 AI Key、Cloudflare Tunnel Token 或其他凭据。
- 不修改现有 Note、Photo 或 `nas.shankluo.cc` 的隧道和路由。

## 二、方案选择

### 2.1 已选方案

使用三个独立容器：

1. `trendradar`：采集、关键词过滤、翻译、AI 分析和报告生成。
2. `report-web`：Nginx 匿名只读发布层，只提供 HTML。
3. `cloudflared`：TrendRadar 专用 Cloudflare Tunnel connector。

为 TrendRadar 创建独立 Tunnel，不复用 Note、Photo 的现有 Tunnel。这样可以独立启停、更新和排障，错误不会影响其他 NAS 服务。

### 2.2 未选方案

| 方案 | 不采用原因 |
|---|---|
| Cloudflare Access 登录保护 | 安全性最高，但老板明确希望避免每次登录 |
| 复用现有 Cloudflare Tunnel | 需要修改现有容器网络或发布本地端口，配置错误可能影响 Note、Photo |
| 直接公开 TrendRadar 8080 | TrendRadar 自带静态服务器托管整个 `output/`，可能公开 SQLite 和目录列表 |
| 路由器端口映射 + 群晖反向代理 | 直接暴露 NAS 入站面，且公网 IP 对本方案没有必要 |

## 三、系统架构

```text
公网用户
   |
   | HTTPS: trend.shankluo.cc
   v
Cloudflare Edge
   |
   | 已建立的出站 Tunnel
   v
cloudflared ---- Docker 内部网络 ---- report-web:80
                                           |
                                           | 只读挂载 /source
                                           v
                                     output/index.html
                                     output/html/**

trendradar ---- 写入 ---- output/**
     |
     +---- 只读读取 config/**
     +---- 出站访问热榜、RSS、AI API
```

三个服务只使用 Compose 内部网络。Compose 不声明宿主机 `ports`，路由器不设置 80、443 或 8080 端口转发。

Cloudflare 远程路由固定为：

```text
trend.shankluo.cc -> http://report-web:80
```

## 四、容器职责与边界

### 4.1 trendradar

- 镜像：`wantcat/trendradar`，实施时固定可验证的版本或镜像 digest，不长期使用漂移的 `latest`。
- 运行模式：`cron`。
- 时区：`Asia/Taipei`。
- 采集计划：`0 */4 * * *`，即每天 00:00、04:00、08:00、12:00、16:00、20:00。
- `IMMEDIATE_RUN=false`，避免容器重启触发额外 AI 调用。
- `AI_ANALYSIS_ENABLED=false` 和 `AI_TRANSLATION_ENABLED=false` 作为首次部署的安全默认，同时关闭 AI 分析与翻译；未确认付费调用前，cron 可继续采集，但不调用 AI。
- 生产过滤方式保持 `filter.method=keyword`。
- AI 模型、API Base 和分析行为沿用当前本地部署；AI Key 只从 `.env` 注入。
- `config/` 以只读方式挂载，`output/` 以读写方式挂载。
- 不发布内置 Web 端口。

首次部署完成后，先保持 `AI_ANALYSIS_ENABLED=false` 和 `AI_TRANSLATION_ENABLED=false` 验收容器和公网边界。老板再次明确批准单次付费 AI 调用后，仅在该次容器命令中临时启用：

```bash
AI_ANALYSIS_ENABLED=true AI_TRANSLATION_ENABLED=true python -m trendradar
```

验收成功后才将 NAS `.env` 中的 `AI_ANALYSIS_ENABLED` 和 `AI_TRANSLATION_ENABLED` 同时改为 `true`。在 Container Manager 的 `xjiankong` 项目页停止项目，再重新构建并启动项目；该操作会按新 `.env` 重建 `trendradar` 容器，使后续每 4 小时 cron 启用 AI 分析与翻译。

### 4.2 report-web

- 使用固定版本的 Nginx Alpine 镜像。
- 将完整 `output/` 只读挂载到容器内 `/source`，但 Nginx 只建立以下路由：
  - `/` -> `/source/index.html`
  - `/index.html` -> `/source/index.html`
  - `/html/` -> `/source/html/`
- 禁止目录列表。
- 拒绝 `/news/`、`/rss/`、`/meta/`、隐藏文件和所有 `.db` 请求。
- 对未声明路径返回 `404`；对明确敏感路径返回 `403` 或 `404` 均视为合格。
- 不代理 TrendRadar 管理命令、API 或内置 Web 服务。

日报本身是公开内容。任何写入 HTML 的账号、原文、分析和外链都可被搜索、下载和转发，不得包含私人或内部信息，不能依赖“不公开网址”获得保密性。

### 4.3 cloudflared

- 使用固定版本的官方 `cloudflare/cloudflared` 镜像。
- 通过 `CLOUDFLARE_TUNNEL_TOKEN` 连接远程管理的独立 Tunnel。
- 只访问 Docker 内部的 `report-web:80`。
- 不使用宿主机网络，不需要公网 IP 或路由器端口映射。
- Tunnel Token 只保存在 NAS `.env`，不得提交 Git 或写入 Compose。

## 五、目录与持久化

NAS 目标目录：

```text
/volume1/docker/trendradar-nas/
├── docker-compose.yml
├── .env
├── nginx.conf
├── config/
└── output/
```

规则：

- `config/`：从当前实际运行的 TrendRadar 配置生成，不携带凭据。
- `output/`：首次部署为空，由 TrendRadar 创建数据库和日报。
- `.env`：只在 NAS 保存；通过 File Station 的“属性 -> 权限”限制为仅管理员可读写，移除 `users` 和 `everyone`，不进入 Git、部署压缩包或同步公开目录。备份副本使用相同权限。
- 未来升级不得覆盖 `.env`、`config/` 和 `output/`。
- 建议通过 Hyper Backup 备份 `config/`；`output/` 是否备份由数据保留需求决定。

## 六、一键部署包

仓库实施阶段提供以下模板：

```text
deploy/nas/
├── docker-compose.yml
├── .env.example
├── nginx.conf
├── build-bundle.sh
└── README.md
```

`build-bundle.sh` 只负责在本机生成可上传的部署目录或压缩包：

- 从相邻 TrendRadar fork 复制当前非敏感配置。
- 不复制 `docker/.env`、历史 `output/`、Git 元数据或缓存。
- 对输出执行敏感字段扫描；发现非空 API Key、Webhook、Token 或密码时失败退出。
- 生成物放入仓库忽略的临时输出目录，不作为配置源提交。

群晖端操作保持为：将 tar 包上传 NAS 并解压、复制 `.env.example` 为 `.env`、只填写两个凭据变量。在 Container Manager 的“项目 -> 新增/创建”中，项目路径填 NAS 路径 `/volume1/docker/trendradar-nas/`；Source 选择“上传 `docker-compose.yml`”时，从当前电脑的本地生成目录 `dist/trendradar-nas/docker-compose.yml` 选择上传，不在上传控件中填写 NAS 路径。不启用可选的 Web Station portal/网页入口。

必须填写的环境变量：

```text
AI_API_KEY
CLOUDFLARE_TUNNEL_TOKEN
```

`AI_MODEL` 保留 `deepseek/deepseek-chat`，`AI_API_BASE` 保持为空，`AI_ANALYSIS_ENABLED` 和 `AI_TRANSLATION_ENABLED` 默认为 `false`。

## 七、Cloudflare 配置

在 Cloudflare Zero Trust 进入 **Networking > Tunnels**，选择 `trendradar-nas`，然后进入 **Routes -> Add route -> Published application**：

```text
名称：trendradar-nas
Hostname：trend.shankluo.cc
Service URL：http://report-web:80
```

不创建 Cloudflare Access 应用，因此该 Published application 匿名公开。HTTPS 在 Cloudflare 边缘终止，NAS 端只接收 Tunnel 内部流量。

现有 `nas.shankluo.cc`、Note、Photo 的 DNS、Tunnel 和容器配置不在实施范围内。

## 八、失败处理

| 故障 | 预期行为 | 处理方式 |
|---|---|---|
| AI API 不可用或限流 | 本轮分析失败，容器记录错误；不公开密钥 | 检查日志和额度，下一调度周期继续运行 |
| RSS/Nitter 单源失败 | 其他来源继续采集 | 保留 best-effort 行为，不因单源失败退出整套服务 |
| Cloudflare Tunnel 中断 | 公网暂时无法访问；采集和本地输出继续 | `cloudflared` 自动重启和重连 |
| report-web 启动时尚无日报 | 首页暂时返回 404 | 首次人工采集成功后恢复 |
| NAS 或容器重启 | 不立即调用模型 | 三个容器自动恢复；未批准前 cron 只采集不调用 AI |
| 配置缺失 | TrendRadar 启动失败并记录明确错误 | 补齐配置后重启项目，不绕过校验 |
| Tunnel Token 缺失 | 仅 `cloudflared` 无法连接 | 在 NAS `.env` 补齐 Token，其他容器不受影响 |

## 九、安全约束

- Compose 不得包含宿主机端口映射。
- `.env`、AI Key、Tunnel Token、Webhook 和密码不得进入 Git、部署压缩包、日志或对话。
- Nginx 必须采用默认拒绝，只开放明确列出的 HTML 路径。
- `config/` 对 TrendRadar 和发布层保持只读；发布层不需要读取 `config/`。
- `report-web` 和 `cloudflared` 不得获得 `output/` 写权限。
- 不以公开 URL 难猜作为安全措施。
- 不修改现有 NAS 服务和隧道。

## 十、验证计划

### 10.1 部署前静态验证

- `docker compose config` 成功。
- Compose 中不存在 `ports:`。
- `.env` 被 Git 忽略，模板只包含空值或安全示例。
- 部署包敏感字段扫描无命中。
- Nginx 配置测试通过。
- 镜像支持 DS220+ 的 `linux/amd64`。

### 10.2 容器验证

- `trendradar`、`report-web`、`cloudflared` 均处于运行状态。
- 容器重启策略为 `unless-stopped`。
- `trendradar` 日志显示 cron 为 `0 */4 * * *`，且启动时未自动采集。
- 人工确认后使用 `AI_ANALYSIS_ENABLED=true AI_TRANSLATION_ENABLED=true python -m trendradar` 执行一次采集，成功生成 `output/index.html` 和日期 HTML。
- AI 分析成功，日志不包含 AI Key 或 Tunnel Token。
- 验收后将 NAS `.env` 中 `AI_ANALYSIS_ENABLED` 和 `AI_TRANSLATION_ENABLED` 同时改为 `true`，在 Container Manager 的 `xjiankong` 项目页停止项目，再重新构建并启动项目，以重建 `trendradar` 容器；下一个 4 小时 cron 启用 AI 分析与翻译。

### 10.3 公网验证

- `https://trend.shankluo.cc/` 返回最新 HTML 日报。
- `https://trend.shankluo.cc/index.html` 可访问。
- `/html/` 下的有效报告可访问。
- `/news/任意.db`、`/rss/任意.db`、`/.env` 和目录遍历请求返回 `403/404`。
- 公网扫描看不到 NAS 的 TrendRadar 8080 端口。

### 10.4 恢复验证

- 重启项目后不会立即触发 AI 调用。
- 重启 NAS 后三个容器自动恢复。
- 临时停止 `cloudflared` 时 TrendRadar 仍继续生成本地数据；恢复后公网访问自动恢复。

## 十一、实施边界

设计文档提交不代表部署授权。后续实施分为两段：

1. 在仓库创建、测试并提交 NAS 部署模板和本地部署包生成器。
2. 在老板明确确认后，才登录 Cloudflare 创建 Tunnel、将文件上传 NAS、填写凭据、启动容器和执行首次付费 AI 验收。

第二段涉及外部资源、凭据和 NAS 运行环境，必须在实际执行前再次说明变更和验证方式。

## 十二、参考资料

- [TrendRadar Docker 编排](https://github.com/sansan0/TrendRadar/blob/master/docker/docker-compose.yml)
- [Cloudflare Tunnel](https://developers.cloudflare.com/tunnel/)
- [Cloudflare Tunnel 配置](https://developers.cloudflare.com/tunnel/configuration/)
- [Cloudflare Access 应用类型](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/choose-application-type/)
- [Synology DS220+ 数据表](https://global.download.synology.com/download/Document/Hardware/DataSheet/DiskStation/20-year/DS220%2B/enu/Synology_DS220_Plus_Data_Sheet_enu.pdf)
