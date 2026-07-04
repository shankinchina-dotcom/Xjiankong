#!/bin/bash
# Xjiankong 项目质量检查脚本
# 用法: bash quality-check.sh [--trendradar]
RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' NC='\033[0m'
pass=0 fail=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} $desc"; ((pass++))
  else
    echo -e "  ${RED}✗${NC} $desc"; ((fail++))
  fi
}

echo -e "${YELLOW}════════ Xjiankong 项目质量检查 ════════${NC}"
echo ""

# 1. 配置文件合法性
echo "[1/6] 配置文件"
check "config/x-accounts.json JSON 合法"          jq empty config/x-accounts.json
check "handle 无重复"                               jq -e '[.groups[].accounts[].handle] as $h | ($h|length)>0 and (($h|map(ascii_downcase)|unique|length)==($h|length))' config/x-accounts.json
check "handle 格式合法"                             jq -e 'all(.groups[].accounts[].handle; test("^[A-Za-z0-9_]{1,15}$"))' config/x-accounts.json

# 2. 活动文档禁止模式（归档文档不参与）
echo ""
echo "[2/6] 禁止模式"
ACTIVE_DOCS=(AGENTS.md CLAUDE.md ai-intelligence-hub-design.md docs/requirements.md docs/github-ai-tracking-plan.md)
check "无 '30 个账号' 硬编码"                       test -z "$(grep -rl '30 个账号' "${ACTIVE_DOCS[@]}" 2>/dev/null || true)"
check "无 'since:2026-07-01' 硬编码日期"            test -z "$(grep -rl 'since:2026-07-01' "${ACTIVE_DOCS[@]}" 2>/dev/null || true)"
check "无 'v4-flash.*deepseek-chat' 混写"           test -z "$(grep -rl 'v4-flash' "${ACTIVE_DOCS[@]}" 2>/dev/null || true)"
check "无旧 Pipeline A/B 术语"                      test -z "$(grep -n 'Pipeline [AB]' "${ACTIVE_DOCS[@]}" 2>/dev/null || true)"
check "无 'rss.sources' 旧配置"                     test -z "$(grep -A1 'rss:' "${ACTIVE_DOCS[@]}" 2>/dev/null | grep 'sources:' || true)"

# 3. 交叉引用
echo ""
echo "[3/6] 交叉引用"
check "ai-intelligence-hub-design.md 存在"          test -f ai-intelligence-hub-design.md
check "X Hosted MCP 手册已归档"                     test -f docs/archive/x-hosted-mcp-setup.md
check "根目录无 X Hosted MCP 执行入口"              test ! -e x-hosted-mcp-setup.md
check "AGENTS.md 引用 config/x-accounts.json"       grep -q 'config/x-accounts.json' AGENTS.md
check "主设计引用 A2 归档手册"                       grep -q 'docs/archive/x-hosted-mcp-setup.md' ai-intelligence-hub-design.md

# 4. 文档非空
echo ""
echo "[4/6] 文档完整性"
for f in ai-intelligence-hub-design.md AGENTS.md CLAUDE.md docs/requirements.md docs/github-ai-tracking-plan.md docs/archive/x-hosted-mcp-setup.md; do
  check "$f 非空且可读" test -s "$f"
done

# 5. NAS 部署模板
echo ""
echo "[5/6] NAS 部署模板"
for f in deploy/nas/docker-compose.yml deploy/nas/.env.example deploy/nas/nginx.conf deploy/nas/README.md; do
  check "$f 非空且可读" test -s "$f"
done
check "deploy/nas/build-bundle.sh 存在且可执行"     test -x deploy/nas/build-bundle.sh
check "deploy/nas/test-deployment.sh 存在且可执行"  test -x deploy/nas/test-deployment.sh
check "NAS 部署模板静态检查通过"                    bash deploy/nas/test-deployment.sh --static

# 6. TrendRadar fork
if [ "$1" = "--trendradar" ]; then
  TR="../TrendRadar"
  echo ""
  echo "[6/6] TrendRadar fork"
  check "$TR 目录存在"                              test -d "$TR"
  check "frequency_words.txt 非空"                  test -s "$TR/config/frequency_words.txt"
  check "frequency_words.txt 含 [GLOBAL_FILTER]"    grep -q '\[GLOBAL_FILTER\]' "$TR/config/frequency_words.txt"
  check "frequency_words.txt 含 [WORD_GROUPS]"      grep -q '\[WORD_GROUPS\]' "$TR/config/frequency_words.txt"
  check "config.yaml schedule 已启用"               grep -A1 'schedule:' "$TR/config/config.yaml" | grep -q 'enabled: true'
  check "config.yaml rss feeds >= 30 个 X 账号"     test "$(grep -cE 'nitter\.net/.+/rss|rsshub\.app/twitter/user/' "$TR/config/config.yaml" 2>/dev/null || echo 0)" -ge 30
  check "config.yaml include_rss: true"             grep -q 'include_rss: true' "$TR/config/config.yaml"
  check "config.yaml 时区 Taipei"                   grep -q 'Asia/Taipei' "$TR/config/config.yaml"
fi

echo ""
echo -e "${YELLOW}════════ 通过: ${GREEN}${pass}${NC}  失败: ${RED}${fail}${NC} ════════${NC}"
[ $fail -eq 0 ] && exit 0 || exit 1
