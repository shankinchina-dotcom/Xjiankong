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

require_nginx_selector() {
  local name="$1"
  local pattern="$2"

  grep -Eq "$pattern" "$NGINX_FILE" || fail "nginx_missing_selector:$name"
}

require_nginx_database_selector() {
  local selector
  local extensions
  local required

  selector="$(
    grep -E '^[[:space:]]*location[[:space:]]+~[*]?[[:space:]]+\\[.]\([^)]*\)[$][[:space:]]*\{' \
      "$NGINX_FILE" | head -n 1 || true
  )"
  [[ -n "$selector" ]] || fail 'nginx_missing_selector:databases'

  extensions="$(
    printf '%s\n' "$selector" |
      awk 'match($0, /\\[.]\([^)]*\)[$]/) { print substr($0, RSTART + 3, RLENGTH - 5) }'
  )"
  for required in db sqlite sqlite3; do
    case "|$extensions|" in
      *"|$required|"*) ;;
      *) fail "nginx_missing_database_extension:$required" ;;
    esac
  done
}

http_status() {
  local path="$1"
  local response

  response="$(
    "${COMPOSE[@]}" exec -T report-web \
      wget -S -O /dev/null "http://127.0.0.1/$path" 2>&1 || true
  )"
  printf '%s\n' "$response" |
    awk '/^[[:space:]]*HTTP\/[0-9.]+[[:space:]]+[0-9][0-9][0-9]/ { status = $2 } END { print status }'
}

require_rejected_status() {
  local path="$1"
  local status

  status="$(http_status "$path")"
  [[ "$status" == '403' || "$status" == '404' ]] ||
    fail "sensitive_path_status:/$path:${status:-missing}"
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

require_nginx_selector directories \
  '^[[:space:]]*location[[:space:]]+~[*]?[[:space:]]+\^/\(news\|rss\|meta\|config\)\(/\|[$]\)[[:space:]]*\{'
require_nginx_database_selector

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config >/dev/null

if [[ "$MODE" == '--static' ]]; then
  printf 'nas_static=passed\n'
  exit 0
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nas-deployment-test.XXXXXX")"
CONFIG_DIR="$TEMP_DIR/config"
OUTPUT_DIR="$TEMP_DIR/output"
PROJECT_NAME="nas-deployment-test-$$"
mkdir -p "$CONFIG_DIR" "$OUTPUT_DIR"

COMPOSE=(
  env CONFIG_DIR="$CONFIG_DIR" OUTPUT_DIR="$OUTPUT_DIR"
  docker compose --project-name "$PROJECT_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_FILE"
)

cleanup() {
  "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

mkdir -p \
  "$OUTPUT_DIR/html/2026-07-04" \
  "$OUTPUT_DIR/news" \
  "$OUTPUT_DIR/rss" \
  "$OUTPUT_DIR/meta" \
  "$OUTPUT_DIR/config"
printf '%s\n' 'NAS index fixture' >"$OUTPUT_DIR/index.html"
printf '%s\n' 'NAS dated report fixture' >"$OUTPUT_DIR/html/2026-07-04/report.html"
printf '%s\n' 'private news database' >"$OUTPUT_DIR/news/private.db"
printf '%s\n' 'private rss database' >"$OUTPUT_DIR/rss/private.db"
printf '%s\n' 'private metadata database' >"$OUTPUT_DIR/meta/private.db"
printf '%s\n' 'private config database' >"$OUTPUT_DIR/config/private.sqlite"
printf '%s\n' 'private HTML database' >"$OUTPUT_DIR/html/private.db"
printf '%s\n' 'private SQLite 3 database' >"$OUTPUT_DIR/html/private.sqlite3"
printf '%s\n' 'private environment fixture' >"$OUTPUT_DIR/.env"
printf '%s\n' 'private undeclared fixture' >"$OUTPUT_DIR/private.txt"

"${COMPOSE[@]}" up -d --no-deps report-web >/dev/null

"${COMPOSE[@]}" exec -T report-web \
  wget -qO- http://127.0.0.1/ | grep -Fq 'NAS index fixture' ||
  fail 'index_not_readable'
"${COMPOSE[@]}" exec -T report-web \
  wget -qO- http://127.0.0.1/html/2026-07-04/report.html |
  grep -Fq 'NAS dated report fixture' || fail 'dated_report_not_readable'

for path in \
  news/private.db \
  rss/private.db \
  meta/private.db \
  config/private.sqlite \
  html/private.db \
  html/private.sqlite3 \
  .env \
  private.txt; do
  require_rejected_status "$path"
done

printf 'nas_integration=passed\n'
