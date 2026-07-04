# TrendRadar 群晖部署手册

本手册用于将 TrendRadar 日报管道部署到群晖 DS220+，并通过 Cloudflare Tunnel 公开只读报告。部署不包含 MCP，不开放路由器端口，也不复用现有的 Note 或 Photo Tunnel。

## 1. 前提条件

- 群晖 DS220+ 已安装 Container Manager。
- `shankluo.cc` 的 DNS 由 Cloudflare 管理。
- 本项目使用独立 Tunnel，名称为 `trendradar-nas`。
- 公网报告地址为 `https://trend.shankluo.cc`。
- 已在本地生成 `trendradar-nas.tar.gz`。

## 2. 创建 Cloudflare Tunnel

1. 打开 Cloudflare Zero Trust，进入 **Networking > Tunnels**。
2. 新建 Cloudflared Tunnel，Name 填写 `trendradar-nas`，Connector 选择 **Docker**。
3. 从页面上只复制 **Tunnel Token**。不要把 Cloudflare 生成的整条含 token 命令保存到仓库、文档或对话中。
4. 在 Tunnel 列表选择 `trendradar-nas`，进入 **Routes -> Add route -> Published application**。
5. 填写 Published application：
   - Hostname：`trend.shankluo.cc`
   - Service URL：`http://report-web:80`
6. 不创建 Cloudflare Access 应用，因此该 Published application 匿名公开。这个入口只会到达 `report-web`。

Tunnel 必须为本项目独立创建。不要复用 Note 或 Photo 已有的 Tunnel，不要在路由器上做任何端口转发。

**公开边界：** 匿名报告可被搜索、下载和转发。报告中的账号、分析和外链均属公开内容，不得包含任何私人或内部信息。

## 3. 准备 NAS 目录与环境变量

1. 将 `trendradar-nas.tar.gz` 上传到 `/volume1/docker/`。
2. 解压后确认项目目录为 `/volume1/docker/trendradar-nas/`。
3. 在该目录中把 `.env.example` 复制为 `.env`。
4. 只在 `.env` 中填写 `AI_API_KEY` 和 `CLOUDFLARE_TUNNEL_TOKEN`。不要将实际值回写到 `.env.example` 或任何仓库文件。
5. 保留以下默认设置：
   - `AI_MODEL` 使用 `deepseek/deepseek-chat`。
   - `AI_API_BASE` 保持为空。
   - `CRON_SCHEDULE` 保持每 4 小时执行一次。
   - `IMMEDIATE_RUN` 保持为 `false`。
   - `AI_ANALYSIS_ENABLED` 保持为 `false`。
   - `AI_TRANSLATION_ENABLED` 保持为 `false`。
6. 在 DSM File Station 中右键 `.env`，打开 **属性 -> 权限**：仅保留管理员的读写权限，移除 `users` 和 `everyone` 的权限。`.env` 备份副本必须使用相同权限，且不得放入任何同步或公开目录。

## 4. 在 Container Manager 创建项目

1. 打开 Container Manager，进入 **项目 -> 新增/创建**。
2. Project name 填写 `xjiankong`。
3. Project path 填写 NAS 路径 `/volume1/docker/trendradar-nas/`。
4. Source 选择“上传 `docker-compose.yml`”，在当前电脑上从本地生成目录选择 `dist/trendradar-nas/docker-compose.yml` 上传。不要在该上传控件中填写 NAS 路径。
5. 不启用可选的 Web Station portal/网页入口。
6. 启动前在 Container Manager 预览 Compose，确认没有任何宿主机端口映射，再构建并启动项目。

项目启动后应有三个容器：

- `xjiankong-trendradar`：按计划采集、过滤、AI 分析并将报告写入 `output`。
- `xjiankong-report-web`：只读提供 `output` 内允许公开的 HTML 报告。
- `xjiankong-cloudflared`：建立到 Cloudflare 的出站 Tunnel，将公网请求转给 `report-web`。

## 5. 首次启动与验收

1. 启动项目后，先在 Container Manager 确认三个容器都处于运行状态，且 `report-web` 健康检查通过。
2. `IMMEDIATE_RUN=false` 表示创建或重启容器时不会立即采集。`AI_ANALYSIS_ENABLED=false` 和 `AI_TRANSLATION_ENABLED=false` 表示首次启动时 AI 分析与 AI 翻译都关闭；未确认前，cron 可继续采集，但不调用 AI。
3. 先在保持两个 AI 开关都为 `false` 的状态下完成三个容器状态、无端口映射和公网页面安全检查。
4. 首次付费 AI 验收前，必须再次获得老板明确批准一次人工采集；该运行可能因翻译分批和分析包含多次付费 AI API 请求。获得批准后，在 `xjiankong-trendradar` 容器的终端中执行：

   ```bash
   cd /app
   AI_ANALYSIS_ENABLED=true AI_TRANSLATION_ENABLED=true python -m trendradar
   ```

5. 该次人工采集完成后，确认 `/volume1/docker/trendradar-nas/output/index.html` 存在并可读。
6. 打开 `https://trend.shankluo.cc`，确认返回最新日报；打开 `https://trend.shankluo.cc/index.html` 应得到同一报告。
7. 用浏览器或 `curl` 检查敏感路径，如 `/news/`，`/rss/`，`/config/`，`/.env` 和任意数据库文件，必须全部返回 `404`。
8. 检查 `xjiankong-trendradar` 日志，确认 cron 已按每 4 小时的调度加载。
9. 在不触发手动运行的前提下重启项目，然后立即检查日志：应只恢复调度，不应立即采集或调用 AI。
10. 以上验收成功后，才将 NAS `.env` 中 `AI_ANALYSIS_ENABLED` 和 `AI_TRANSLATION_ENABLED` 同时改为 `true`。在 Container Manager 的 `xjiankong` 项目页停止项目，再重新构建并启动项目；该操作会按新 `.env` 重建 `trendradar` 容器，使后续每 4 小时 cron 启用 AI 分析与翻译。

如果尚未生成任何报告，根路径返回 `404` 是预期结果，不表示 Web 容器故障。

## 6. 更新与回滚

### 更新

1. 更新前备份现有 `.env` 和 `config/`，并记录当前 `docker-compose.yml` 以及三个镜像 digest。备份 `.env` 仍须仅管理员可读写，不得进入同步公开目录。
2. 新包只替换部署模板和经审核的配置文件；不覆盖 NAS 上的 `.env` 和 `output/`。
3. 任何镜像升级前，先在本地对新 Compose 和固定 digest 运行 `deploy/nas/test-deployment.sh --integration`。只在集成验证通过后才更新 NAS。
4. 新 `.env.example` 不会自动更新现有 `.env`。只把 `TRENDRADAR_IMAGE`、`REPORT_WEB_IMAGE`、`CLOUDFLARED_IMAGE` 三行复制到现有 `.env`，保留现有 key/token 和其他设置。
5. 重新构建项目后，重复“首次启动与验收”中的非付费检查；不要为了验证更新而默认再调用 AI。

### 回滚

1. 停止当前项目。
2. 恢复上一版 `docker-compose.yml`，并将现有 `.env` 中 `TRENDRADAR_IMAGE`、`REPORT_WEB_IMAGE`、`CLOUDFLARED_IMAGE` 三行恢复为上一版 digest；保留 key/token。
3. 如配置同时变更，恢复与上一版配套的 `config/`；保留现有 `.env` 和 `output/`。
4. 在 Container Manager 重新构建并启动项目，然后检查容器、Tunnel、报告和 cron，不主动发起付费 AI 调用。

## 7. 故障处理

- **Tunnel 断开**：只影响 `trend.shankluo.cc` 公网访问。TrendRadar 的本地采集、生成和 NAS 上已有报告不受影响。检查 `xjiankong-cloudflared` 状态与日志，不要改为路由器端口转发。
- **AI 调用失败**：查看 `xjiankong-trendradar` 日志中的错误，保留现场并等待下一调度周期。不要在未获确认时反复手动触发付费请求。
- **Nitter 单源失败**：Nitter 是 best effort 的不稳定传输层。记录失败并等待后续周期，不要仅因单源不可用就删除监控账号。
- **域名返回 `404`**：先检查 `output/index.html` 是否存在。无报告时 `404` 是预期行为；有报告时再检查 `report-web` 挂载和健康状态。

## 8. 不在本次部署范围内

- 不部署或恢复 X Hosted MCP 或任何 TrendRadar MCP 服务。
- 不开放路由器端口，不使用 NAS 公网 IP 直连报告服务。
- 不复用 Note 或 Photo 的现有 Cloudflare Tunnel。
