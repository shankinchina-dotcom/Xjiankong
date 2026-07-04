#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/compose.yaml"
ENV_FILE="$SCRIPT_DIR/.env.example"
NGINX_FILE="$SCRIPT_DIR/nginx.conf"
MODE="${1:---static}"

fail() {
  printf 'nas_test=failed reason=%s\n' "$1" >&2
  exit 1
}

require_nonempty() {
  local path="$1"
  [[ -s "$path" ]] || fail "missing_or_empty:$path"
}

env_value() {
  local key="$1"
  local value

  value="$(sed -n "s/^${key}=//p" "$ENV_FILE" | tail -n 1 | tr -d '\r')"
  if [[ "$value" == \"*\" && "$value" == *\" ]] ||
    [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

require_env_key() {
  local key="$1"
  grep -q "^${key}=" "$ENV_FILE" || fail "env_missing_${key}"
}

require_nginx_denial() {
  local token="$1"

  awk -v token="$token" '
    {
      line = $0
      sub(/#.*/, "", line)

      if (!active && line ~ token) {
        candidate = 1
      }
      if (!active && candidate && line ~ /\{/) {
        active = 1
        depth = gsub(/\{/, "{", line) - gsub(/\}/, "}", line)
      } else if (active) {
        depth += gsub(/\{/, "{", line) - gsub(/\}/, "}", line)
      }

      if (active && line ~ /(deny[[:space:]]+all|return[[:space:]]+(403|404))/) {
        denied = 1
      }
      if (active && depth <= 0) {
        if (denied) {
          success = 1
        }
        active = 0
        candidate = 0
        denied = 0
      }
    }
    END { exit(success ? 0 : 1) }
  ' "$NGINX_FILE" || fail "nginx_missing_denial:$token"
}

case "$MODE" in
  --static | --integration) ;;
  *) fail "usage:$0 [--static|--integration]" ;;
esac

require_nonempty "$COMPOSE_FILE"
require_nonempty "$ENV_FILE"
require_nonempty "$NGINX_FILE"

if grep -Eq '^[[:space:]]*ports[[:space:]]*:' "$COMPOSE_FILE"; then
  fail 'compose_exposes_ports'
fi
if grep -Fq 'trendradar-mcp' "$COMPOSE_FILE"; then
  fail 'compose_contains_trendradar-mcp'
fi

[[ "$(env_value CRON_SCHEDULE)" == '0 */4 * * *' ]] ||
  fail 'env_invalid_CRON_SCHEDULE'
[[ "$(env_value IMMEDIATE_RUN)" == 'false' ]] ||
  fail 'env_invalid_IMMEDIATE_RUN'
require_env_key AI_API_KEY
require_env_key CLOUDFLARE_TUNNEL_TOKEN
[[ -z "$(env_value AI_API_KEY)" ]] || fail 'env_nonempty_AI_API_KEY'
[[ -z "$(env_value CLOUDFLARE_TUNNEL_TOKEN)" ]] ||
  fail 'env_nonempty_CLOUDFLARE_TUNNEL_TOKEN'

for path in news rss meta config; do
  require_nginx_denial "$path"
done
for extension in db sqlite; do
  require_nginx_denial "$extension"
done

PROJECT_NAME="nas-deployment-test-$$"
COMPOSE=(docker compose --project-name "$PROJECT_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_FILE")
"${COMPOSE[@]}" config >/dev/null

if [[ "$MODE" == '--static' ]]; then
  printf 'nas_static=passed\n'
  exit 0
fi

OUTPUT_DIR="$SCRIPT_DIR/output"
[[ ! -e "$OUTPUT_DIR" ]] || fail "temporary_output_exists:$OUTPUT_DIR"

cleanup() {
  "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$OUTPUT_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR/html/2026-07-04" "$OUTPUT_DIR/news" "$OUTPUT_DIR/rss"
printf '%s\n' 'NAS index fixture' >"$OUTPUT_DIR/index.html"
printf '%s\n' 'NAS dated report fixture' >"$OUTPUT_DIR/html/2026-07-04/report.html"
printf '%s\n' 'private news database' >"$OUTPUT_DIR/news/private.db"
printf '%s\n' 'private rss database' >"$OUTPUT_DIR/rss/private.db"

"${COMPOSE[@]}" up -d --no-deps report-web >/dev/null

"${COMPOSE[@]}" exec -T report-web \
  wget -qO- http://127.0.0.1/ | grep -Fq 'NAS index fixture' ||
  fail 'index_not_readable'
"${COMPOSE[@]}" exec -T report-web \
  wget -qO- http://127.0.0.1/html/2026-07-04/report.html |
  grep -Fq 'NAS dated report fixture' || fail 'dated_report_not_readable'

for path in news/private.db rss/private.db meta/private.db config/private.sqlite; do
  if "${COMPOSE[@]}" exec -T report-web \
    wget -qO- "http://127.0.0.1/$path" >/dev/null 2>&1; then
    fail "sensitive_path_readable:/$path"
  fi
done

printf 'nas_integration=passed\n'
