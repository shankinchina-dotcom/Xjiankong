# X Hosted MCP 接入与每日 AI 情报抓取手册

> **状态：❌ 已放弃。** X API 需要 Pay-per-use 付费（$5+ credits），用户拒绝。保留本文档仅供后续重新评估时参考。  
> X 账号内容目前通过 Nitter RSS（`nitter.net/<handle>/rss`）免费接入 TrendRadar A1 通道。

## 目标与完成标准

完成后应做到：

1. X Hosted MCP 和 X Docs MCP 在选定客户端中可用。
2. 单账号、短时间窗的只读连通性测试通过。
3. 经成本确认后，抓取账号配置中的全部账号，并完整处理分页。
4. 生成可追溯的 `raw.json`、`processed.json` 和 `digest.md`。

未完成 OAuth、付费额度、全量抓取或飞书推送时，不得声称整套任务已完成。

## 操作前确认闸门

执行 Agent 遇到下列步骤必须停下，说明动作和验证方式，取得老板明确确认后才能继续：

| 动作 | 风险 | 验证 |
|---|---|---|
| 下载或安装 xurl | 执行外部软件；全局安装还会修改系统环境 | `xurl --version` 或 npx 版本输出 |
| 写入 `~/.xurl` 或客户端配置 | 涉及 Client Secret、token 或全局配置 | `xurl auth status`、客户端 MCP 状态 |
| 打开 X OAuth 授权 | 授权当前 X 账号，xurl 当前会申请读写 scopes | 授权页 scopes、`getUsersMe` |
| 调用全量搜索 | X API 按用量扣费 | 运行窗口、分页上限、Developer Console 用量 |
| 调用 DeepSeek | 发送推文内容到第三方模型并产生费用 | 模型名、条数、输出 JSON 校验 |
| 发送飞书消息 | 对外写操作 | 指定群、预览内容、发送结果 |

Client Secret、API key、token 和 webhook 不得贴到聊天中，也不得写入仓库或普通日志。

## Step 1：创建 X Developer App

在 [X Developer Portal](https://developer.x.com) 创建 App。当前 xurl 的 OAuth2 流程需要：

| 配置 | 要求 |
|---|---|
| Environment | Production |
| Package | Pay-per-use，并按已批准预算购买 credits |
| App type | Web App、Automated App or Bot |
| Permissions | Read and Write |
| Callback URI | `http://localhost:8080/callback` |

虽然本项目只执行读取，但 xurl 当前源码会申请读写 scopes。因此：

- 不启用 MCP 工具自动执行。
- 不调用名称含 `create`、`delete`、`update`、`like`、`repost`、`follow`、`bookmark`、`send` 的工具。
- 授权页展示的 scopes 与预期不一致时停止操作。

记录 OAuth 2.0 Client ID 和 Client Secret，但不要复制到对话。

**验收**：Portal 显示 App 位于 Production 和 Pay-per-use；Callback URI 完全一致。

## Step 2：准备 xurl

推荐使用 npx，避免全局安装：

```bash
node --version
npm --version
npx -y @xdevplatform/xurl --version
```

第一次执行 `npx -y` 会下载并运行包，必须先通过“下载或安装 xurl”确认闸门。需要永久安装时，按 [xurl 官方 README](https://github.com/xdevplatform/xurl) 选择 Homebrew、npm、shell script 或 Go；全局安装必须另行确认。

## Step 3：登记 App 并完成 OAuth

下面示例适用于 zsh。由老板在本机终端输入凭据；Agent 不读取值，也不回显值：

```bash
read "X_CLIENT_ID?X Client ID: "
read -s "X_CLIENT_SECRET?X Client Secret: "; print

npx -y @xdevplatform/xurl auth apps add xjiankong \
  --client-id "$X_CLIENT_ID" \
  --client-secret "$X_CLIENT_SECRET" \
  --redirect-uri "http://localhost:8080/callback"

unset X_CLIENT_ID X_CLIENT_SECRET
```

凭据会写入 `~/.xurl`。执行前必须通过“写入 `~/.xurl`”确认闸门。

完成浏览器 OAuth：

```bash
npx -y @xdevplatform/xurl auth oauth2 --app xjiankong
npx -y @xdevplatform/xurl auth status
```

无头环境使用：

```bash
npx -y @xdevplatform/xurl auth oauth2 --app xjiankong --headless
```

**验收**：`auth status` 显示 `xjiankong`、有效 OAuth2 用户和正确的 redirect URI。输出不得包含完整 secret 或 token。

## Step 4：配置 MCP 客户端

### 4.1 Claude Code（首选）

从项目根目录执行。Claude Code 默认 local scope 会写入 `~/.claude.json` 当前项目项：

```bash
claude mcp add-json xapi '{"type":"stdio","command":"npx","args":["-y","@xdevplatform/xurl","--app","xjiankong","mcp","https://api.x.com/mcp"]}'
claude mcp add --transport http x-docs https://docs.x.com/mcp
claude mcp list
```

在 Claude Code 会话内使用 `/mcp` 查看连接状态。不要把 Claude Desktop 的 `claude_desktop_config.json` 当成 Claude Code 配置。

### 4.2 Cursor

项目级配置写入 `.cursor/mcp.json`；全局配置写入 `~/.cursor/mcp.json`。两者选一个，不要重复配置：

```json
{
  "mcpServers": {
    "xapi": {
      "command": "npx",
      "args": ["-y", "@xdevplatform/xurl", "--app", "xjiankong", "mcp", "https://api.x.com/mcp"]
    },
    "x-docs": {
      "url": "https://docs.x.com/mcp"
    }
  }
}
```

### 4.3 VS Code

工作区配置路径为 `.vscode/mcp.json`。用户级配置应通过命令面板 `MCP: Open User Configuration` 打开：

```json
{
  "servers": {
    "xapi": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@xdevplatform/xurl", "--app", "xjiankong", "mcp", "https://api.x.com/mcp"]
    },
    "x-docs": {
      "type": "http",
      "url": "https://docs.x.com/mcp"
    }
  }
}
```

**验收**：`xapi` 和 `x-docs` 均为已连接状态；客户端未开启自动批准工具调用。

## Step 5：只读连通性测试

按顺序执行，任一失败都不要进入全量抓取：

1. 调用 `x-docs.search_x` 搜索 `search all posts`，确认文档 MCP 可用。
2. 调用 `xapi.getUsersMe`，确认返回的 X 用户符合预期。
3. 调用 `xapi.searchPostsAll`，查询单账号最近 1 小时内容：
   - query：`from:XDevelopers -is:retweet`
   - `start_time`、`end_time`：UTC RFC3339，开始时间包含、结束时间不包含。
   - `max_results`：10。
   - 不调用任何写工具。

**验收**：测试 3 返回 Post ID、正文、作者和时间；没有结果也可以接受，但请求本身必须成功。如果没有结果，再把窗口扩大到最近 24 小时，不更换为写操作测试。

## Step 6：生成全量查询

先验证账号配置：

```bash
jq -e '
  [.groups[].accounts[].handle] as $handles
  | ($handles | length) > 0
    and (($handles | map(ascii_downcase) | unique | length) == ($handles | length))
    and (all($handles[]; test("^[A-Za-z0-9_]{1,15}$")))
' config/x-accounts.json
```

生成一个合并查询，避免逐账号固定截断：

```bash
jq -r '
  [.groups[].accounts[].handle | "from:" + .]
  | "(" + join(" OR ") + ") -is:retweet"
' config/x-accounts.json
```

查询长度必须不超过 X Full-Archive Search 当前限制。执行前确定：

- `run_id`：UTC 时间戳，例如 `20260702T120000Z`。
- `start_time`、`end_time`：UTC RFC3339 半开区间 `[start_time, end_time)`。
- 首次运行默认最近 24 小时；后续从上次成功的 `end_time` 接续，避免空洞和重复窗口。
- `max_results`：每页 100。
- 安全上限：最多 10 页或 1000 条，先到者停止；触发上限时必须把 `pagination_complete` 记为 `false`。

在调用前向老板展示时间窗、查询长度、页数上限和预计付费动作，获得确认。

## Step 7：抓取并生成 `raw.json`

向执行 Agent 发出以下指令：

```text
读取 config/x-accounts.json，生成由所有 handle 组成的
(from:a OR from:b ...) -is:retweet 查询。

只调用 xapi.searchPostsAll，不调用任何写工具。
使用已确认的 start_time、end_time 和 max_results=100。
请求字段至少包含 id、text、author_id、created_at、lang、public_metrics、referenced_tweets，
并展开 author_id。按 next_token 分页，直到没有 next_token，或达到已确认的 10 页/1000 条安全上限。

保留每页错误；不要因部分账号或单页失败而伪造完整结果。
将标准化结果保存到 output/x/YYYY-MM-DD/raw.json。
```

`raw.json` 结构：

```json
{
  "schema_version": "1.0",
  "run_id": "20260702T120000Z",
  "fetched_at": "2026-07-02T12:00:00Z",
  "window": {
    "start_time": "2026-07-01T12:00:00Z",
    "end_time": "2026-07-02T12:00:00Z",
    "timezone": "UTC"
  },
  "query": "(from:...) -is:retweet",
  "account_snapshot": ["OpenAI"],
  "pagination_complete": true,
  "pages_fetched": 1,
  "posts": [
    {
      "id": "string",
      "author_handle": "string",
      "text": "string",
      "created_at": "RFC3339",
      "lang": "string",
      "url": "https://x.com/<handle>/status/<id>",
      "metrics": {
        "likes": 0,
        "reposts": 0,
        "replies": 0,
        "quotes": 0
      }
    }
  ],
  "errors": []
}
```

`raw.json` 只做字段标准化，不翻译、不摘要、不删帖。互动量是抓取时快照，不代表最终累计数据。

## Step 8：Version A 过滤与分类

### 8.1 去重

- 以 Post ID 为唯一键。
- 同一 Post 重复出现时保留字段最完整的一条。
- 引用同一链接但观点不同的 Post 不合并。

### 8.2 相关性判定

按顺序判断：

1. 作者若为 `review_policy=strict`，先应用其 `review_note`；不满足则 `drop`。
2. 明确出现模型、AI 公司、AI 技术、AI 产品或 AI 研究专名，标记 `keep`。
3. GPU、CPU、芯片、融资、财报、监管、法案、出口管制等条件词，必须同时出现 AI、LLM、模型公司或 AI 工作负载上下文；否则标记 `review`。
4. `model`、`release`、`update`、`research`、`研究`、`发布`等弱词单独出现时只能 `review`。
5. 纯政治、生活、娱乐、股票喊单、加密货币或其他行业内容标记 `drop`。

每条记录必须保存 `decision_reason` 和 `matched_rules`。不能只输出结论。

### 8.3 内容分类与截断

Version A 使用六个互斥内容类别：

- `model_update`
- `product_update`
- `industry`
- `research`
- `engineering_opinion`
- `zh_cn`

先分类，再在每个内容类别内按 `likes + reposts + replies + quotes` 降序排序；并列时按 `created_at` 降序。每类最多 5 条，全局最多 30 条。这里的“类”指内容类别，不是账号来源组。

中文作者不自动归入 `zh_cn`；只有内容主要反映中文 AI 社区动态、且不适合更具体类别时才使用该类别。

## Step 9：翻译、分析与 `processed.json`

英文内容需要中文摘要时，可使用当前客户端模型；如果明确选择 DeepSeek API，直接 API 的已核验基线为：

- endpoint：`https://api.deepseek.com/chat/completions`
- model：`deepseek-chat`

不要把 TrendRadar 的 LiteLLM 模型别名与 DeepSeek 官方 API model 混写。调用前必须确认数据发送范围和费用。

每条保留或复核记录输出：

```json
{
  "post_id": "string",
  "decision": "keep | review | drop",
  "decision_reason": "string",
  "matched_rules": ["string"],
  "category": "model_update",
  "summary_zh": "不超过50字",
  "impact_zh": "不超过100字",
  "importance": "milestone | watch | signal | reference",
  "source_url": "https://x.com/<handle>/status/<id>"
}
```

根对象还必须记录 `schema_version`、`run_id`、处理方案 `version_a`、模型名和 Prompt 版本。输出保存为同目录的 `processed.json`。

## Step 10：生成中文日报

输出路径：`output/x/YYYY-MM-DD/digest.md`。

```markdown
# AI 圈日报 — YYYY-MM-DD

> 数据窗口：<start_time> 至 <end_time>（UTC，左闭右开）
> 抓取：<post_count> 条；保留：<keep_count> 条；待复核：<review_count> 条
> 分页完整：<true/false>

## 模型发布/更新

1. **<中文摘要>** — @<handle>
   - 影响：<为什么重要>
   - 互动：❤️ <likes> 🔁 <reposts> 💬 <replies> 💭 <quotes>
   - 标签：<importance>
   - [原文](https://x.com/<handle>/status/<id>)

## 产品发布/更新
...

## 行业动态
...

## 论文研究
...

## 工程与观点
...

## 中文圈动态
...
```

待复核内容不进入正式日报，单独保留在 `processed.json`。

## Step 11：推送（独立可选步骤）

默认只生成本地文件。需要飞书推送时：

1. 先展示目标群和完整消息预览。
2. 取得老板明确确认。
3. 使用能正确 JSON 序列化和处理平台长度限制的客户端或连接器发送。
4. 不使用 `"$(cat digest.md)"` 拼接 JSON；引号、换行和反斜杠会破坏请求体。
5. 记录成功响应；失败时不自动重复发送，避免重复消息。

## 排障

| 症状 | 检查 | 处理 |
|---|---|---|
| MCP 首次启动超时 | 是否尚未完成 OAuth | 先单独运行 `xurl auth oauth2`；Claude Code 可提高 `MCP_TIMEOUT` 后重启 |
| 无头环境无法回调 | 是否在远程机器 | 使用 `--headless`，在本地浏览器授权后粘贴回调 URL 或 code |
| `client-not-enrolled` / `client-forbidden` | App package 和 environment | 确认 Pay-per-use + Production |
| 401 / token refresh failed | `xurl auth status` | 重新执行 OAuth；不要把 token 打进日志 |
| `searchPostsAll` 无权限 | 访问级别和 credits | 在 Developer Console 核对；不要改用写工具测试 |
| 429 | 是否触发端点限流 | 按 reset 时间等待并指数退避；不要假设读请求不会限流 |
| 分页达到安全上限 | `next_token` 仍存在 | 标记 `pagination_complete=false`，缩短时间窗后重跑 |
| npx 使用旧包 | registry 或缓存 | 对照官方最新版本，明确指定可信 registry 后再执行 |
| 工具列表没有 `xapi` | 客户端配置或进程启动失败 | 查看 MCP 日志，核对 `--app xjiankong mcp` 参数顺序 |
| 输出出现非 JSON-RPC 文本 | stdout 被其他日志污染 | 移除额外 verbose 参数；诊断信息应只写 stderr |

调试超过两轮仍未解决时，停止猜测，逐字段对照 xurl 源码、官方 MCP 配置和实际错误响应。

## 最终验收清单

- [ ] 所有确认闸门均有明确授权记录。
- [ ] `xurl auth status` 正常，输出未泄露 secret/token。
- [ ] `xapi`、`x-docs` 均连接成功。
- [ ] `search_x`、`getUsersMe`、单账号 `searchPostsAll` 测试通过。
- [ ] 账号配置 JSON 合法且 handle 无重复。
- [ ] 全量查询记录了 UTC 半开时间窗、页数上限和成本确认。
- [ ] `raw.json` 保存完整分页状态和错误，没有伪造完整性。
- [ ] `processed.json` 每条都有决定、原因、规则和分类。
- [ ] `digest.md` 与同一 `run_id` 对应，待复核内容未混入正式日报。
- [ ] 未经单独确认，没有发送飞书消息或调用任何 X 写工具。

## 官方资料

- [X MCP](https://docs.x.com/tools/mcp)
- [xurl](https://github.com/xdevplatform/xurl)
- [X Full-Archive Search](https://docs.x.com/x-api/posts/search-all-posts)
- [X Search 概览](https://docs.x.com/x-api/posts/search/introduction)
- [X API 限流](https://docs.x.com/x-api/fundamentals/rate-limits)
- [X API 计费](https://docs.x.com/x-api/getting-started/pricing)
- [Claude Code MCP](https://code.claude.com/docs/en/mcp)
- [Cursor MCP](https://docs.cursor.com/context/model-context-protocol)
- [VS Code MCP](https://code.visualstudio.com/docs/agent-customization/mcp-servers)
- [DeepSeek API](https://api-docs.deepseek.com/)
