# v2-beta Gate 9.1：上线前无障碍加固实施计划

> 状态：已完成（2026-07-13）。TrendRadar 提交 `fabe867f`、`61ba3932` 已通过专项／相关免费回归、独立复审、真实 Chrome 交互和新 RC 容器验证；新 RC 已于 2026-07-14 经 Gate 10 部署至生产，详见 `../../roadmap.md`。

## 范围与边界

- 仅修改 TrendRadar 冻结工作树中的 `trendradar/report/html.py` 与 `tests/fixtures/v2_beta_deep_space_ui.py`。
- 不修改 8 板块结构、报告文案、颜色 Token、历史清单格式或公网路由。
- 不访问 NAS，不修改 `.env`，不调用付费模型，不操作 Cloudflare。
- 重新构建后必须产生新的 RC 镜像身份；旧 Gate 9 镜像只保留为历史证据，不再作为 Gate 10 输入。

## 任务

1. 为历史抽屉语义、可见键盘焦点、关闭回焦、Tab 焦点循环、移动端触控尺寸和减弱动画补失败测试。
   `[模型：Terra；强度：高]` -> 边界明确的测试补齐 -> 验证：专项 fixture 因缺少新行为而失败。
2. 最小修改深空页面 CSS、HTML 与 JS，使测试通过。
   `[模型：Terra；强度：高]` -> 局部实现 -> 验证：专项 fixture 与免费回归通过；390px、1440px 截图复核。
3. 对差异执行独立规格与代码质量复核。
   `[模型：Sol；强度：高]` -> 发布候选前审计 -> 验证：逐条对照本计划边界，无越权和回归。
4. 重新构建 RC 镜像并复跑 Gate 9 导入、容器可观察性验证。
   `[模型：Sol；强度：高]` -> 生产候选最终验收 -> 验证：记录新镜像 ID、平台、大小、`RC_IMPORT_OK` 与 `RC_CONTAINER_OK`。
5. 更新 `docs/roadmap.md`、Gate 9/10 计划和相关状态文档中的 RC 身份与下一步。
   `[模型：Terra；强度：中]` -> 机械性文档同步 -> 验证：项目规定的 JSON、两组质量检查、A2 扫描和 `git diff --check`。

## 通过条件

- 历史抽屉具有对话框语义，打开后焦点进入抽屉，Tab/Shift+Tab 不逃逸，关闭后焦点返回入口。
- 历史入口、关闭按钮、历史链接和来源引用具有清晰的 `:focus-visible` 状态。
- 390px 视口无页面级横向滚动；移动端历史入口与关闭按钮最小高度 44px，来源引用最小高度 24px。
- `prefers-reduced-motion: reduce` 下禁用抽屉位移动画。
- 新 RC 完整通过 Gate 9，且 Gate 10 仅引用新镜像身份。

## 实际结果

- TDD 红灯先后证明缺少对话框语义与关闭态 `inert`；绿灯专项 fixture 为 17/17，相关回归为全部断言、8/8、10/10、2/2。
- 独立审查首次因关闭抽屉仍在 Tab 顺序而拒绝镜像重建；提交 `61ba3932` 修正后复审无 Critical、Important 或阻断 Minor。
- 390px Chrome CDP 验证：关闭态 Tab 跳过抽屉；打开聚焦关闭按钮；首尾循环与三条关闭回焦路径通过；触控高度为 44/44/24px；页面宽度 390px；减弱动画下 transition 为 0s。
- 新镜像：`xjiankong-trendradar:v2-beta-rc-20260713`，`sha256:3c02dceafa861709ce6bbbd0dc2136b5a9b9db0827bf114f280cb1581b87ab4f`，`linux/amd64`，`138,032,730` bytes。
- `RC_IMPORT_OK`、扩展 `RC_CONTAINER_OK` 均退出码 0，且无残留验证容器。旧 `20260712` RC 保留为历史证据，不再用于 Gate 10。
