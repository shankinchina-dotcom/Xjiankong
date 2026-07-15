# V4.1 UI 增量交接摘要（压缩上下文）

> 日期：2026-07-16。供后续 Agent 快速接手；细节见 V4 设计／计划与本仓库 git 历史。

## 生产现状（不要回退）

| 项 | 值 |
|---|---|
| 生产镜像 | `xjiankong-trendradar:v2-beta-v4-rc-20260715` |
| NAS Config ID | `sha256:365c92d50928525df93dfb9943051d914c647ac2337f58f29df245536753d1dc` |
| 直接回滚 | `v2-beta-rc-20260713` / NAS `sha256:c122cdb56076…` |
| 代码基线（已上线） | TrendRadar `18c1fbad` |
| V4.1 代码 | TrendRadar `01264222`（`codex/v2-beta-history`，未部署） |
| Task 8 证据 | `backups/v4-task8-20260715-231822`（勿删） |

## V4 主线结论

- 编辑型层级已上线：`judgment-suite`、J1–J3、208px 导航、metrics label/value。
- 权威视觉是 **V4 editorial**，不是 V3 青绿／彩虹原型。
- 邮件隔离不计入 Task 8 新证据；沿用本地 fixture。

## V4.1 本地增量（已提交代码，待 RC）

仓库：`/Users/shankluo/AI/Claude/TrendRadar-v2-beta-history`

| 改动 | 说明 |
|---|---|
| 证据折叠 | 默认收起 `evidence-toggle` + `evidence-body[hidden]` |
| 大厂色 | `ev-brand-*` / `r-src brand-*`（非彩虹） |
| RSS 折叠 | 组内默认 5 条预览；过长不对等自动折叠 |

文件：`formatter.py`、`html.py`、`v2_beta_deep_space_ui.py`  
验证：fixture **24/24** + v2-alpha 回归通过。提交：`01264222`。

## 禁止

- 自动 push／自动生产切换／自动付费重跑
- 清理备份、tar、旧镜像（须老板批准）
- 在脏的 `TrendRadar` v2-alpha 主 worktree 实施

## 下一步闸门

1. ~~提交 V4.1 代码~~（已完成 `01264222`）
2. 构建 `xjiankong-trendradar:v2-beta-v4-rc-20260716`
3. 一次性容器免费断言
4. 老板确认后：NAS 传输 → 只改 `TRENDRADAR_IMAGE` → 只重建 `trendradar`
5. 可选一次付费验收；并行稳定性观察
