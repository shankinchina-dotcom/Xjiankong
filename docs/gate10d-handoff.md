# Gate 10D 交接文档（2026-07-14）

> 用途：老板即将把 Gate 10D 的收尾交给另一个 agent。本文档是自包含的交接说明：当前状态、已踩的坑、跑完成判定、以及跑完后必须执行的 10D-2 / 10D-3 命令。
>
> **状态更新（2026-07-14 23:45）：10D-2 机器断言 + 10D-3 验收清单已由本会话执行完成，Gate 10D 通过（attempt 2 RC=0、288s；证据见 `docs/roadmap.md`「Gate 10D 完成记录」）。本文档保留为交接与复现记录。**
> 关联计划：[Gate 10 生产同步实施计划](superpowers/plans/2026-07-13-v2-beta-gate10-production-sync.md)（重点看第六、§10D）。

## 0. 一句话状态

Gate 10D（一次老板批准的付费全链路验收）已触发。手动付费跑 **attempt 2 正在 NAS 上独立运行**（通过 `setsid` 脱离 SSH，SSH 断开也不影响），截至交接时已到「翻译 27 条」阶段、`stderr` 干净、`history.json` 已生成（23:34），预计几分钟内写完完成标记。新 agent **只需等标记完成**，再跑 10D-2 机器断言 + 10D-3 清单，最后更新 `docs/roadmap.md` 与记忆。**不要替老板重跑、改配置、回滚或清理。**

## 1. 固定值（后续 agent 必须沿用）

| 用途 | 值 |
|---|---|
| 备份目录 | `/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051` |
| 备份指针文件 | NAS `/tmp/xjiankong-gate10-backup-dir` |
| 生产镜像 | `xjiankong-trendradar:v2-beta-rc-20260713`（NAS RC ID `sha256:c122cdb56076ed3e0342a2c348537d0f9bd4d48ea2955271489049e7147688b9`） |
| 回滚镜像 | `v2-alpha-20260709` / `sha256:ea2d7183483d9026618a3d85313ac293087200e5a576b4e506366fc3bc83bb9d` |
| SSH | `ssh z5451530@192.168.1.193`（密钥登录；NAS 端临时 NOPASSWD sudoers `/etc/sudoers.d/xjiankong-gate10` 仍存在，**未经老板确认不得删除**） |
| docker 全路径 | `/usr/local/bin/docker`（ContainerManager 软链；NAS `sudo` 默认 PATH 不含，必须写全路径） |
| 容器内 venv python | `/app/.venv/bin/python`（Python 3.12.13，含 pytz 等依赖） |
| 容器内挂载 | `output` ↔ 宿主 `/volume1/docker/trendradar-nas/output`；`config` ↔ 宿主 `/volume1/docker/trendradar-nas/config`（ro） |
| 宿主 python3 | `/usr/bin/python3`（仅 stdlib，够白名单断言用） |
| supercronic 调度 | `0 */4 * * *`（PID 1），下次自动触发 **00:00** |
| 公网 | `https://trend.shankluo.cc`（Cloudflare Tunnel） |

## 2. 已完成的步骤（10D-1 并发预检 + 前置状态）

- 并发预检通过：无运行中的采集进程、无即将到来的调度窗口冲突（本次手动跑 23:29 启动，00:00 才下一次自动触发）。
- 前置状态已记录（2026-07-14 23:21，文件均在备份目录）：
  - `history-before.sha256` = `absent`（跑前 history.json 不存在）
  - `latest-before.txt` = `absent`
  - `snapshots-before.txt` = 59 行（跑前 html 快照数）
  - `old-snapshot-relative-path.txt` = `html/2026-07-13/20-05.html`（10B 冻结旧快照，用于 10D-2/3 #20 公网 200 校验）

## 3. 重要坑：计划命令的 `sh -lc` venv PATH bug（勿重蹈）

- 计划 10D-1 触发命令用 `docker exec ... sh -lc "cd /app && python -m trendradar"`。
- `sh -lc`（**login** shell）会重置 PATH，丢掉 `/app/.venv/bin`，导致 `python` 退化为系统解释器 → `ModuleNotFoundError: No module named 'pytz'`，import 阶段秒挂（RC=1，0 秒，**未消耗任何付费 API**）。
- **镜像本身正常**：在非 login 的 `sh -c` 下，`python` 正确解析到 venv（pytz 2026.1 可用）。生产 supercronic 也是用非 login `sh -c` 触发，所以**生产定时跑不受影响**。
- 修复：触发命令改为 `/usr/local/bin/docker exec xjiankong-trendradar sh -c "cd /app && /app/.venv/bin/python -m trendradar"`（venv python 绝对路径 + 非 login）。attempt 2 用此修复后正常。
- attempt 1 证据已留存（`gate10d-attempt1-*` 四个文件，均 RC=1），可作为「计划命令 bug」的证明，无需重跑验证。

## 4. 当前运行（attempt 2）

- 触发脚本：`/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051/gate10d_trigger.sh`（已修正，含 `setsid` 脱离 + 产物落盘）。
- 产物（均在备份目录）：
  - `gate10d-start.epoch` = `1784042991`（= 2026-07-14 23:29，attempt 2 启动）
  - `gate10d-stdout.log`（115+ 行，进展正常）
  - `gate10d-stderr.log`（**0 字节，干净**，无 import 错误）
  - `gate10d-end.epoch`（完成后写）
  - `gate10d-exit-code.txt`（完成后写）
  - `gate10d-done.marker`（完成后写，覆盖 attempt 1 的旧 `RC=1`）
- 截至交接：stdout 已到 `[AI] 分析完成`（deepseek-chat）+ `[翻译] 开始翻译内容到中文... 共 27 条标题待翻译`；`/app/output/history.json` 已生成（8070 B，23:34）。即跑已基本成功，标记即将写出。
- **注意**：`gate10d-done.marker` 此刻仍显示 attempt 1 的 `DONE RC=1`（旧值）。判定完成以 attempt 2 覆盖后的**新值**为准（见第 5 节）。

## 5. 交接后如何判定跑已完成（必须全部满足）

```bash
ssh z5451530@192.168.1.193 "sudo sh -c 'B=/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051; echo EXIT=\$(cat \"\$B/gate10d-exit-code.txt\"); echo END=\$(cat \"\$B/gate10d-end.epoch\"); echo START=\$(cat \"\$B/gate10d-start.epoch\"); echo MARKER=\$(cat \"\$B/gate10d-done.marker\")'"
```

完成条件（attempt 2 成功）：

- `gate10d-exit-code.txt` == `0`
- `gate10d-end.epoch` > `gate10d-start.epoch`（即 > `1784042991`）
- `gate10d-done.marker` 显示 `DONE RC=0`

任一不满足 → 跑未成功或未结束，先别进 10D-2。若 marker 仍 `RC=1` 且 `end.epoch` 不存在，说明 attempt 2 仍在进行或再次失败（查 `gate10d-stderr.log`）。

## 6. 跑完成后：先造 run.log（计划第 455 行，本触发脚本未自动生成）

```bash
ssh z5451530@192.168.1.193 "sudo sh -c 'B=/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051; cat \"\$B/gate10d-stdout.log\" \"\$B/gate10d-stderr.log\" > \"\$B/gate10d-run.log\"; chmod 600 \"\$B/gate10d-run.log\"; test -s \"\$B/gate10d-run.log\" && echo RUNLOG_OK'"
```

> **纪律**：报告不得 `cat` / 下载 / 回显 `gate10d-run.log` 原始内容；只跑下面的固定解析命令。若解析命中疑似凭据字段，立即停止并只报告「敏感扫描失败」。（日志中 API Key 已被应用掩码为 `sk-29******`，正常情况下不会泄露明文。）

## 7. 10D-2 机器断言（逐条；任一失败即停，进入 Sol 高复核，禁止重跑 / 改配置 / 回滚）

### 7.1 history.json 白名单（宿主 python3，可用）

```bash
ssh z5451530@192.168.1.193 "sudo python3 -c 'import json,re; from pathlib import Path; p=Path(\"/volume1/docker/trendradar-nas/output/history.json\"); d=json.loads(p.read_text()); assert set(d)=={\"schema_version\",\"latest\",\"dates\"}; assert set(d[\"latest\"])=={\"date\",\"time\",\"path\"}; path=re.compile(r\"^/html/[0-9]{4}-[0-9]{2}-[0-9]{2}/[0-9]{2}-[0-9]{2}\\.html$\"); assert path.fullmatch(d[\"latest\"][\"path\"]); versions=[]; sensitive=re.compile(r\"(env|token|secret|password|api.?key|database|sqlite|config|source_map)\",re.I); assert not any(sensitive.search(str(k)) for x in [d]+d[\"dates\"] for k in x if isinstance(x,dict)); [(versions.extend(day[\"versions\"]), (_ for _ in ()).throw(AssertionError()) if set(day)!={\"date\",\"versions\"} else None) for day in d[\"dates\"]]; assert versions; assert all(set(v)=={\"time\",\"path\",\"is_latest\"} and path.fullmatch(v[\"path\"]) for v in versions); assert sum(v[\"is_latest\"] is True for v in versions)==1; assert any(v[\"path\"]==d[\"latest\"][\"path\"] and v[\"is_latest\"] is True for v in versions); assert (p.parent / d[\"latest\"][\"path\"].lstrip(\"/\")).is_file(); assert not sensitive.search(json.dumps(d,ensure_ascii=False))'"
```

> 若宿主 python3 不可用，改用容器内 venv：`sudo /usr/local/bin/docker exec xjiankong-trendradar /app/.venv/bin/python -c '...'`，并把路径改成 `/app/output/history.json`。

### 7.2 前后差分（history 已改变、新增快照在运行窗口、latest 指向新文件）

```bash
ssh z5451530@192.168.1.193 "sudo sh -eu -c 'B=/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051; P=/volume1/docker/trendradar-nas/output; test -s \"\$P/history.json\"; test \"\$(sha256sum \"\$P/history.json\" | awk \"{print \\\$1}\")\" != \"\$(cat \"\$B/history-before.sha256\")\"; find \"\$P/html\" -type f | sort > /tmp/snapshots-after.txt; comm -13 \"\$B/snapshots-before.txt\" /tmp/snapshots-after.txt > /tmp/snapshots-new.txt; test \"\$(wc -l < /tmp/snapshots-new.txt | tr -d \" \" )\" -ge 1; L=\"\$(python3 -c '\''import json,sys; print(json.load(open(sys.argv[1]))[\"latest\"][\"path\"])'\'' \"\$P/history.json\")\"; test \"\$L\" != \"\$(cat \"\$B/latest-before.txt\")\"; F=\"\$P/\${L#/}\"; grep -Fxq \"\$F\" /tmp/snapshots-new.txt; M=\"\$(stat -c %Y \"\$F\")\"; S=\"\$(cat \"\$B/gate10d-start.epoch\")\"; E=\"\$(cat \"\$B/gate10d-end.epoch\")\"; test \"\$M\" -ge \"\$S\"; test \"\$M\" -le \"\$E\"'"
```

> `history-before.sha256` / `latest-before.txt` 内容为 `absent`，与跑后真实值不同 → diff 成立。

### 7.3 页面结构精确为 8 个 report-section

```bash
ssh z5451530@192.168.1.193 "test \"$(sudo grep -o 'class=\"report-section' /volume1/docker/trendradar-nas/output/index.html | wc -l | tr -d ' ')\" -eq 8"
```

### 7.4 冻结旧快照公网 200

```bash
OLD_SNAPSHOT="$(ssh z5451530@192.168.1.193 "sudo cat /volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051/old-snapshot-relative-path.txt")"
printf '%s\n' "$OLD_SNAPSHOT" | grep -Eq '^html/[0-9]{4}-[0-9]{2}-[0-9]{2}/[0-9]{2}-[0-9]{2}\.html$'
case "$OLD_SNAPSHOT" in *..*|*'?'*|*'#'*) false;; esac
test "$(curl -sS -o /dev/null -w '%{http_code}' "https://trend.shankluo.cc/$OLD_SNAPSHOT")" = 200
```

### 7.5 固定证据提取（run.log 必须先造好，见第 6 节）

```bash
ssh z5451530@192.168.1.193 "sudo sh -eu -c 'B=/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051; L=\"\$B/gate10d-run.log\"; grep -E \"热榜.*([0-9]+/[0-9]+)|hotlist.*([0-9]+/[0-9]+)\" \"\$L\" > \"\$B/evidence-hotlist.txt\"; grep -E \"Nitter.*([0-9]+/[0-9]+)|非 Nitter.*([0-9]+/[0-9]+)|RSS.*([0-9]+/[0-9]+)\" \"\$L\" > \"\$B/evidence-rss.txt\"; grep -E \"翻译.*([0-9]+/[0-9]+)|translation.*([0-9]+/[0-9]+)\" \"\$L\" > \"\$B/evidence-translation.txt\"; grep -E \"\\[AI\\].*分析完成|AI.*analysis.*complete\" \"\$L\" > \"\$B/evidence-ai.txt\"; test -s \"\$B/evidence-hotlist.txt\"; test -s \"\$B/evidence-rss.txt\"; test -s \"\$B/evidence-translation.txt\"; test -s \"\$B/evidence-ai.txt\"'"
```

> 若日志格式无法稳定自动解析，**禁止凭印象判定通过，也不得重跑**。固定人工证据必须逐项记录：运行窗口、热榜成功/总数、RSS 总成功/总数、Nitter 成功/总数、非 Nitter 成功/总数、翻译成功/本次待翻译数、AI 完成原始行、对应报告和新快照路径；任何字段缺失即 Gate 10D 停止并进入 Sol 高复核。

## 8. 10D-3 验收清单（21 项）

逐项核对（下方为可直接执行的命令/方式）：

| # | 验证项 | 命令/方式 | 预期 |
|---|--------|----------|------|
| 1 | 容器全 Up | `sudo /usr/local/bin/docker ps --filter name=xjiankong` | 4/4 Up |
| 2 | 无 import 错误 | `sudo tail -n 50 /volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051/gate10d-stderr.log`（**本次是 exec 跑，docker logs 不含，看 stderr 文件**） | 无 ModuleNotFoundError |
| 3 | AI 分析完成 | 同上 stderr 为空 + `evidence-ai.txt` 非空 | `[AI] 分析完成` |
| 4 | 新报告生成 | `sudo ls -lt /volume1/docker/trendradar-nas/output/html/` | 新 html 文件 |
| 5 | history.json 生成 | `sudo ls -la /volume1/docker/trendradar-nas/output/history.json` | 文件存在 |
| 6 | history.html 生成 | `sudo ls -la /volume1/docker/trendradar-nas/output/history.html` | 文件存在 |
| 7 | 公网可访问 | `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/)" = 200` | 200 |
| 8 | 深空报告渲染 | 浏览器打开 `https://trend.shankluo.cc` | 深色蓝渐变主题 |
| 9 | 8 板块存在 | 搜索 `report-section` | 8 个 |
| 10 | 历史抽屉可用 | 点击顶部历史按钮 | 右侧抽屉滑出 |
| 11 | history.json 可访问 | `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/history.json)" = 200` | 200 |
| 12 | history.html 可访问 | `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/history.html)" = 200` | 200 |
| 13 | 热榜正常 | 搜索 `hotlist-section` | 存在 |
| 14 | RSS 证据流 | 搜索 `evidence-stream` | 存在 |
| 15 | 敏感路径 404 | 分别 `curl ... /.env`、`/news/test.db`、`/config/config.yaml` 精确断言 404 | 全 404 |
| 16 | 其他 .json 仍 404 | `test "$(curl -sS -o /dev/null -w '%{http_code}' https://trend.shankluo.cc/output/news/data.json)" = 404` | 404 |
| 17 | Nitter fallback | 搜索 `x.com` 链接 | 存在 |
| 18 | 来源引用标记 | 搜索 `[R0` | 存在 |
| 19 | 旧快照保留 | `sudo ls /volume1/docker/trendradar-nas/output/html/` | 含旧日期目录 |
| 20 | 旧报告仍可访问 | 见 7.4（用 `old-snapshot-relative-path.txt` 冻结路径，校验仅 `html/*` 后请求公网 URL，精确 200） | 200 |
| 21 | 运行唯一性 | 对照触发前后 PID、日志起止时间和新快照 mtime | 只有本次一次运行 |

> 注：#2/#3 原计划写 `docker logs xjiankong-trendradar`，但本次是 `docker exec` 跑，输出在 `gate10d-stderr.log` / `gate10d-run.log`，**务必查文件而非 docker logs**。

## 9. 通过条件与纪律

- **通过条件**（计划 §10D 通过条件）：
  - 热榜目标 11/11；若有波动，必须按来源解释。
  - RSS 分开记录 Nitter 与非 Nitter；健康参考总计 38–41/44、Nitter 约 30/33。单个 404 不触发整体回滚。
  - 翻译以本次实际待翻译数为分母，全部成功。
  - AI 分析成功完成，页面含 8 板块、来源索引、安全链接和 Nitter → X fallback。
  - 新快照生成，旧快照保留；`/history.json` 为合法受控结构且 latest 指向新快照。
  - `/history.html`、历史抽屉和旧版提示可用。
  - 敏感路径全 404。
- **禁止**：因结果不理想连续重跑、改模型 / 代理 / Cloudflare / 配置、自动清理、自动回滚、删 NOPASSWD sudoers、删备份 / tar / v2-alpha 镜像。
- 任何 10D-2 字段缺失或 10D-3 关键项失败 → **停，回报进入 Sol 高复核**。

## 10. 残留风险

- **00:00 supercronic 自动触发**：若 attempt 2 在 00:00 前未完成，会与自动跑并发。attempt 2 于 23:29 启动、预计 23:4x 完成，应无冲突。若接手时 marker 仍 `RC=1` 且时间已过 00:00，可能是并发导致；10D-3 #21 运行唯一性会暴露，按「停 + 复核」处理。
- **NOPASSWD sudoers** `/etc/sudoers.d/xjiankong-gate10` 仍在 NAS，仅老板确认后可删。
- 备份 `/volume1/docker/trendradar-nas/backups/v2-beta-20260713-210051`、NAS tar `/tmp/v2-beta-rc-20260713.tar`、v2-alpha 镜像均保留，不得删。

## 11. 跑通过后要做的事

1. `docs/roadmap.md`：新增「2026-07-14 Gate 10D 完成记录」，把 Gate 10 状态行改为「已完成」，更新「当前停点」为「进入阶段 3 稳定性观察」。记录实测（热榜/RSS/翻译/AI 证据、history.json 合法、公网 200、敏感 404）。
2. 记忆：`.workbuddy/memory/2026-07-14.md` 追加 10D 完成记录；跨会话注意项记入 `MEMORY.md`（如 `sh -lc` venv bug 教训）。
3. 向老板汇报 TL;DR + 交付概览 + 文件清单 + 下一步（建议连续 3 个 cron 周期 ~12h 稳定性观察）。
4. **不要**自动清理、回滚或删任何东西。
