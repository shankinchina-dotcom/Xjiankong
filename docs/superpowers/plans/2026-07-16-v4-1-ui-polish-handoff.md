# V4.1 UI 增量交接摘要（压缩上下文）

> 日期：2026-07-16。V4.1 **NAS 免费切换 + 一次付费全链路均已通过**。

## 生产现状

| 项 | 值 |
|---|---|
| 生产镜像 | `xjiankong-trendradar:v2-beta-v4-rc-20260716` |
| NAS Config ID | `sha256:c0262e755c50274e36c9f44726379f83621628f93e4464aa8aff414b6c825153` |
| 容器 | `xjiankong-trendradar` Id `4537d590…` Started `2026-07-15T16:18:04Z` RC=0 |
| 代码基线 | TrendRadar `01264222`（`codex/v2-beta-history`） |
| 直接回滚 | `v2-beta-v4-rc-20260715` / `365c92d5…`；或 `v2-beta-rc-20260713` / `c122cdb56076…` |
| 切换备份 | `backups/v4-1-rc-20260716-20260716-001621` |
| 付费证据 | `backups/v4-1-task8-20260716-002145` |
| 新报告 | `/html/2026-07-16/00-25.html`（公网 200；index 已同步） |

## V4.1 内容（已在生产新页验证）

| 改动 | 公网计数（00-25） |
|---|---|
| 证据折叠 `evidence-toggle` / `evidence-body[hidden]` | toggle×8；body×1 且 `hidden` |
| 大厂色 `ev-brand-*` | ×7 |
| RSS `feed-toggle` | ×7 |
| suite / J1 / history-drawer | 均在 |

## 付费全链路（2026-07-16 一次）

| 字段 | 实测 |
|---|---|
| 触发 | `docker exec … sh -c "cd /app && /app/.venv/bin/python -m trendradar"`（非 login，绝对 venv） |
| exit | **0**；stderr **0 字节** |
| 热榜 | **11/11** 成功（失败: []） |
| RSS | **41 成功 / 3 失败**（xai 404、elonmusk 429、GabrielPeterss4 404） |
| 翻译 | **25/25** |
| AI | `分析完成`；`deepseek/deepseek-chat` |
| history.latest | `/html/2026-07-16/00-25.html`；schema 仅 `dates/latest/schema_version` |
| 旧快照 | `00-05.html` 保留且公网 200 |
| peers | report-web / cloudflared / rss-proxy Id/StartedAt/RC **未变** |
| 公网安全 | `/` history 新/旧页 **200**；`/.env` `/news/test.db` `/config/config.yaml` `/output/news/data.json` **404** |
| DOM | 容器内 + 公网 **`V4_1_DOM_OK` / `PUBLIC_V4_1 OK`** |

## 禁止

- 自动再付费 / 自动 push / 清理备份·tar·旧镜像（须老板批准）
- 在脏 `TrendRadar` v2-alpha 主 worktree 实施

## 下一步

1. 稳定性观察继续（cron `0 */4 * * *`）。
2. 清理 NAS `/tmp` tar、旧镜像 —— **不要自动做**。
