# V4.1 UI 增量交接摘要（压缩上下文）

> 日期：2026-07-16。V4.1 **已完成 NAS 免费切换**；未付费重跑。

## 生产现状

| 项 | 值 |
|---|---|
| 生产镜像 | `xjiankong-trendradar:v2-beta-v4-rc-20260716` |
| NAS Config ID | `sha256:c0262e755c50274e36c9f44726379f83621628f93e4464aa8aff414b6c825153` |
| 容器 | `xjiankong-trendradar` Id `4537d590…` Started `2026-07-15T16:18:04Z` RC=0 |
| 代码基线 | TrendRadar `01264222`（`codex/v2-beta-history`） |
| 直接回滚 | `v2-beta-v4-rc-20260715` / NAS `sha256:365c92d5…`；或 `v2-beta-rc-20260713` / `c122cdb56076…` |
| 备份 | `/volume1/docker/trendradar-nas/backups/v4-1-rc-20260716-20260716-001621` |
| 传输 tar | `/tmp/v2-beta-v4-rc-20260716.tar` · SHA-256 `d148ff549481886e93a16b91f61b041a4002a425b917e7220c56696f39fb696b` |
| DiffID chain | `1a54fd0b36a1c48678dab2845c932f6ace1f1fd6069fe4a505e0625f17bcccfa`（Mac=NAS） |
| 付费 | **未触发**；公网 index 仍为切换前快照 HTML（含 V4 suite，无 V4.1 evidence-toggle） |

## V4.1 内容

| 改动 | 说明 |
|---|---|
| 证据折叠 | 默认收起 `evidence-toggle` + `evidence-body[hidden]` |
| 大厂色 | `ev-brand-*` / `r-src brand-*`（非彩虹） |
| RSS 折叠 | 组内默认 5 条预览；过长不对等自动折叠 |

## 切换摘要（2026-07-16）

1. 只读基线：生产曾为 `v4-rc-20260715` / `365c92d5…`；四容器 Up。
2. 备份 `.env` + 身份 → `backups/v4-1-rc-20260716-20260716-001621`。
3. SCP + `docker load`；tar SHA OK；DiffID chain OK；NAS free `RC_IMPORT_OK`。
4. 仅改 `TRENDRADAR_IMAGE`（行数 16=16；masked SHA 变化）。
5. 仅 `docker compose up -d --no-deps --force-recreate trendradar`。
6. peers（report-web / cloudflared / rss-proxy）Id/StartedAt/RC **未变**。
7. 日志：crontab 有效、Web 8080 启动、无 ImportError/Traceback。
8. 公网：`/` `/history.json` `/history.html`=200；`/.env` `/news/test.db` `/config/config.yaml` `/output/news/data.json`=404。

## 禁止

- 自动付费重跑 / 自动 push / 清理备份·tar·旧镜像（须老板批准）
- 在脏 `TrendRadar` v2-alpha 主 worktree 实施

## 下一步（可选，须另批）

1. 一次付费全链路：验证新页含 `evidence-toggle` / `feed-toggle` / brand class。
2. 稳定性观察继续。
3. 清理 NAS `/tmp` tar、旧镜像等 —— **不要自动做**。
