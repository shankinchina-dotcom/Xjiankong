# Xjiankong v2-beta 生产稳定性观察日志

> Gate 10（10A–10D）通过后进入阶段 3 稳定性观察。每 4h 只读检查四容器 + 公网 + 敏感路径，追加一条记录。
> 纪律：只读；不重启容器、不改 `.env`/nginx/Compose、不触发采集、不调付费 API；异常只记录并提示老板。
> 当前生产预期（2026-07-16 起）：四容器全 Up（report-web healthy，trendradar=`v2-beta-v4-rc-20260716`）；`/`、`/history.json`、`/history.html`=200；`/.env`、`/news/test.db`、`/config/config.yaml`、`/output/news/data.json`=404。更早记录中的 `v2-beta-rc-20260713` 为当时基线，不回溯改写。

## 2026-07-15 00:07 CST（基线·手动）

- 四容器：
  - report-web | Up 58 min (healthy) | nginx
  - trendradar | Up 58 min | xjiankong-trendradar:v2-beta-rc-20260713
  - cloudflared | Up 7 days
  - rss-proxy | Up 7 days
- 公网：`/`=200、`/history.json`=200、`/history.html`=200、`/.env`=404、`/news/test.db`=404、`/config/config.yaml`=404、`/output/news/data.json`=404
- 结论：**PASS**（全部符合预期）

## 2026-07-15 04:03 CST（自动·每4h）

- 四容器：
  - report-web | Up 5 hours (healthy) | nginx
  - trendradar | Up 5 hours | xjiankong-trendradar:v2-beta-rc-20260713
  - cloudflared | Up 7 days
  - rss-proxy | Up 7 days
- 公网：`/`=200、`/history.json`=200、`/history.html`=200、`/.env`=404、`/news/test.db`=404、`/config/config.yaml`=404、`/output/news/data.json`=404
- 结论：**PASS**（全部符合预期）

## 2026-07-15 07:56 CST（自动·每4h）

- 四容器：
  - report-web | Up 9 hours (healthy) | nginx
  - trendradar | Up 9 hours | xjiankong-trendradar:v2-beta-rc-20260713
  - cloudflared | Up 7 days
  - rss-proxy | Up 7 days
- 公网：`/`=200、`/history.json`=200、`/history.html`=200、`/.env`=404、`/news/test.db`=404、`/config/config.yaml`=404、`/output/news/data.json`=404
- 结论：**PASS**（全部符合预期）

## 2026-07-15 14:11 CST（自动·每4h）

- 四容器：**SSH 不可达**（`ssh: connect to host 192.168.1.193 port 22: Operation timed out`），无法获取容器状态
- 公网（本地 curl，受 fake-IP 代理影响，000 为代理超时非真实状态码）：
  - `/` -> 200 ✅
  - `/history.json` -> 000（代理超时，无法判定）
  - `/history.html` -> 000（代理超时，无法判定）
  - `/.env` -> 000（代理超时，无法判定）
  - `/news/test.db` -> 000（代理超时，无法判定）
  - `/config/config.yaml` -> 000（代理超时，无法判定）
  - `/output/news/data.json` -> 404 ✅
- 结论：**FAIL**（异常项：① SSH 到 NAS 192.168.1.193 超时，无法验证四容器状态；② 本地 curl 因 fake-IP 代理导致 5/7 路径返回 000，无法判定。仅 `/`=200 和 `/output/news/data.json`=404 可确认，说明公网服务本身在线）

## 2026-07-15 18:10 CST（自动·每4h）

- 四容器：**SSH 不可达**（`ssh: connect to host 192.168.1.193 port 22: Operation timed out`），无法获取容器状态
- 公网（本地 curl `--noproxy '*'`，绕过 fake-IP 代理，全部成功取到真实状态码）：
  - `/` -> 200 ✅
  - `/history.json` -> 200 ✅
  - `/history.html` -> 200 ✅
  - `/.env` -> 404 ✅
  - `/news/test.db` -> 404 ✅
  - `/config/config.yaml` -> 404 ✅
  - `/output/news/data.json` -> 404 ✅
- 结论：**FAIL**（异常项：SSH 到 NAS 192.168.1.193 超时，无法验证四容器状态。公网 7 路径全部符合预期，说明公网服务在线且敏感路径防护正常。SSH 不可达为连续第二次，可能是 NAS 网络层问题或 SSH 服务异常，需老板关注）
