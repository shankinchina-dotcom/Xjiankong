#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/compose.yaml"
ENV_FILE="$SCRIPT_DIR/.env.example"
NGINX_FILE="$SCRIPT_DIR/nginx.conf"
BUILD_BUNDLE_FILE="$SCRIPT_DIR/build-bundle.sh"
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
  [[ "$status" == '404' ]] ||
    fail "sensitive_path_status:/$path:${status:-missing}"
}

require_body_absent() {
  local path="$1"
  local forbidden="$2"
  local body

  body="$(
    "${COMPOSE[@]}" exec -T report-web \
      wget -qO- "http://127.0.0.1/$path" 2>/dev/null || true
  )"
  [[ "$body" != *"$forbidden"* ]] || fail "sensitive_body_exposed:/$path"
}

case "$MODE" in
  --static | --integration) ;;
  *) fail "usage:$0 [--static|--integration]" ;;
esac

require_nonempty "$COMPOSE_FILE"
require_nonempty "$ENV_FILE"
require_nonempty "$NGINX_FILE"
require_nonempty "$BUILD_BUNDLE_FILE"
[[ -x "$BUILD_BUNDLE_FILE" ]] || fail "not_executable:$BUILD_BUNDLE_FILE"
bash -n "$BUILD_BUNDLE_FILE" || fail "invalid_bash:$BUILD_BUNDLE_FILE"

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

COMPOSE_JSON="$(
  docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config --format json
)"

printf '%s\n' "$COMPOSE_JSON" | jq -e '
  (.services.trendradar.networks | keys) == ["collector"]
  and (.services["report-web"].networks | keys) == ["publish"]
  and (.services.cloudflared.networks | keys) == ["publish"]
' >/dev/null || fail 'compose_invalid_network_isolation'

if [[ "$MODE" == '--static' ]]; then
  printf 'nas_static=passed\n'
  exit 0
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nas-deployment-test.XXXXXX")"
CONFIG_DIR="$TEMP_DIR/config"
OUTPUT_DIR="$TEMP_DIR/output"
BUNDLE_CONFIG_DIR="$TEMP_DIR/bundle-config"
BUNDLE_DIST_DIR="$TEMP_DIR/bundle-dist"
BUNDLE_LOG="$TEMP_DIR/build-bundle.log"
FAKE_BIN="$TEMP_DIR/fake-bin"
MV_FAIL_STATE="$TEMP_DIR/mv-fail-state"
SYSTEM_MV="$(command -v mv)"
PROJECT_NAME="nas-deployment-test-$$"
mkdir -p "$CONFIG_DIR" "$OUTPUT_DIR" "$BUNDLE_CONFIG_DIR" "$FAKE_BIN"

COMPOSE=(
  env CONFIG_DIR="$CONFIG_DIR" OUTPUT_DIR="$OUTPUT_DIR"
  docker compose --project-name "$PROJECT_NAME" --env-file "$ENV_FILE" -f "$COMPOSE_FILE"
)

cleanup() {
  "${COMPOSE[@]}" down --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

cat >"$BUNDLE_CONFIG_DIR/config.yaml" <<'YAML'
filter:
  method: keyword
ai:
  api_key: ""
credentials:
  - token: ""
  - token: ${BUNDLE_TOKEN}
metadata:
  max_tokens: retained-nonsecret-value
nullable_credentials:
  token:
  next_key: same-level-value
list_nullable_credentials:
  - token:
    next_key: same-list-item-value
YAML
printf '%s\n' '[WORD_GROUPS]' >"$BUNDLE_CONFIG_DIR/frequency_words.txt"
printf '%s\n' 'timeline: enabled' >"$BUNDLE_CONFIG_DIR/timeline.yaml"
cat >"$BUNDLE_CONFIG_DIR/multiline-safe.yaml" <<'YAML'
newline_null:
  token:
    null
empty_block:
  token: |
env_block:
  token: |
    ${BLOCK_TOKEN}
YAML
cat >"$BUNDLE_CONFIG_DIR/multiline-safe.json" <<'JSON'
{
  "token":
    null,
  "nested": {
    "api_key":
      "${JSON_API_KEY}"
  }
}
JSON
cat >"$BUNDLE_CONFIG_DIR/plaintext-safe.txt" <<'TEXT'
token = ""
token=${ENV_TOKEN}
export TOKEN=""
export TOKEN=${ENV_EXPORTED_TOKEN}
bot_token=
access_token='${ENV_ACCESS_TOKEN}'
secret_access_key=''
max_tokens=1000
TEXT
printf '%s\n' 'must not be copied' >"$BUNDLE_CONFIG_DIR/.env"
printf '%s\n' 'must not be copied' >"$BUNDLE_CONFIG_DIR/history.db"
for uppercase_extension in DB SQLITE SQLITE3; do
  printf '%s\n' 'token: uppercase-database-secret-value' > \
    "$BUNDLE_CONFIG_DIR/archive.$uppercase_extension"
done
mkdir -p "$BUNDLE_CONFIG_DIR/output"
printf '%s\n' 'historical report' >"$BUNDLE_CONFIG_DIR/output/history.html"
for cache_dir in .pytest_cache .mypy_cache .ruff_cache; do
  mkdir -p "$BUNDLE_CONFIG_DIR/$cache_dir"
  printf '%s\n' 'token: cache-secret-value' >"$BUNDLE_CONFIG_DIR/$cache_dir/state"
done

CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1 || fail 'bundle_safe_fixture_failed'
[[ -d "$BUNDLE_DIST_DIR/trendradar-nas" ]] || fail 'bundle_directory_missing'
[[ -s "$BUNDLE_DIST_DIR/trendradar-nas.tar.gz" ]] || fail 'bundle_archive_missing'
[[ -s "$BUNDLE_DIST_DIR/trendradar-nas/config/timeline.yaml" ]] ||
  fail 'bundle_config_incomplete'
[[ ! -e "$BUNDLE_DIST_DIR/trendradar-nas/config/output" ]] ||
  fail 'bundle_contains_historical_output'
for cache_dir in .pytest_cache .mypy_cache .ruff_cache; do
  [[ ! -e "$BUNDLE_DIST_DIR/trendradar-nas/config/$cache_dir" ]] ||
    fail "bundle_contains_cache:$cache_dir"
done
if find "$BUNDLE_DIST_DIR/trendradar-nas" -type f \
  \( -name '.env' -o -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) |
  grep -q .; then
  fail 'bundle_contains_forbidden_file'
fi
for uppercase_extension in DB SQLITE SQLITE3; do
  [[ ! -e \
    "$BUNDLE_DIST_DIR/trendradar-nas/config/archive.$uppercase_extension" ]] ||
    fail "bundle_contains_uppercase_database:$uppercase_extension"
done
if tar -tzf "$BUNDLE_DIST_DIR/trendradar-nas.tar.gz" |
  grep -Eiq '(^|/)([.]env|[^/]+[.](db|sqlite|sqlite3))$'; then
  fail 'bundle_archive_contains_forbidden_file'
fi
if tar -tzf "$BUNDLE_DIST_DIR/trendradar-nas.tar.gz" |
  grep -Fq 'trendradar-nas/config/output/'; then
  fail 'bundle_archive_contains_historical_output'
fi
if tar -tzf "$BUNDLE_DIST_DIR/trendradar-nas.tar.gz" |
  grep -Eq 'trendradar-nas/config/[.](pytest|mypy|ruff)_cache/'; then
  fail 'bundle_archive_contains_cache'
fi

printf '%s\n' 'old directory marker' > \
  "$BUNDLE_DIST_DIR/trendradar-nas/old-directory-marker.txt"
OLD_ARCHIVE_CKSUM="$(cksum "$BUNDLE_DIST_DIR/trendradar-nas.tar.gz")"
cat >"$FAKE_BIN/mv" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
count=0
if [[ -f "$MV_FAIL_STATE" ]]; then
  read -r count <"$MV_FAIL_STATE"
fi
count=$((count + 1))
printf '%s\n' "$count" >"$MV_FAIL_STATE"
if [[ "$count" -eq 2 ]]; then
  exit 73
fi
exec "$REAL_MV" "$@"
SH
chmod +x "$FAKE_BIN/mv"
if PATH="$FAKE_BIN:$PATH" MV_FAIL_STATE="$MV_FAIL_STATE" \
  REAL_MV="$SYSTEM_MV" CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" \
  DIST_ROOT="$BUNDLE_DIST_DIR" "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_publish_failure_fixture_succeeded'
fi
grep -Fq 'old directory marker' \
  "$BUNDLE_DIST_DIR/trendradar-nas/old-directory-marker.txt" ||
  fail 'bundle_publish_failure_lost_old_directory'
[[ "$(cksum "$BUNDLE_DIST_DIR/trendradar-nas.tar.gz")" == "$OLD_ARCHIVE_CKSUM" ]] ||
  fail 'bundle_publish_failure_changed_old_archive'

cp "$BUNDLE_CONFIG_DIR/config.yaml" "$TEMP_DIR/config.yaml.saved"
cat >>"$BUNDLE_CONFIG_DIR/config.yaml" <<'YAML'
filter:
  method: ai
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_duplicate_filter_fixture_succeeded'
fi
cp "$TEMP_DIR/config.yaml.saved" "$BUNDLE_CONFIG_DIR/config.yaml"

cat >"$BUNDLE_CONFIG_DIR/config.yaml" <<'YAML'
filter:
  method: keyword
  method: ai
ai:
  api_key: ""
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_duplicate_filter_method_fixture_succeeded'
fi
cp "$TEMP_DIR/config.yaml.saved" "$BUNDLE_CONFIG_DIR/config.yaml"

for filter_fixture in missing non-scalar ai; do
  case "$filter_fixture" in
    missing) printf '%s\n' 'filter: {}' >"$BUNDLE_CONFIG_DIR/config.yaml" ;;
    non-scalar)
      printf 'filter:\n  method: [keyword]\n' >"$BUNDLE_CONFIG_DIR/config.yaml"
      ;;
    ai) printf 'filter:\n  method: ai\n' >"$BUNDLE_CONFIG_DIR/config.yaml" ;;
  esac
  if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
    "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
    fail "bundle_filter_${filter_fixture}_fixture_succeeded"
  fi
done
cp "$TEMP_DIR/config.yaml.saved" "$BUNDLE_CONFIG_DIR/config.yaml"

printf '%s\n' '- {token: inline-leading-secret}' > \
  "$BUNDLE_CONFIG_DIR/inline-secret.yaml"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_inline_leading_secret_fixture_succeeded'
fi
if grep -Fq 'inline-leading-secret' "$BUNDLE_LOG"; then
  fail 'bundle_inline_leading_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/inline-secret.yaml"

printf '%s\n' '- {name: x, "api_key": "inline-later-secret"}' > \
  "$BUNDLE_CONFIG_DIR/inline-secret.yaml"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_inline_later_secret_fixture_succeeded'
fi
if grep -Fq 'inline-later-secret' "$BUNDLE_LOG"; then
  fail 'bundle_inline_later_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/inline-secret.yaml"

printf '%s\n' 'credentials: [token: bracket-secret-value]' > \
  "$BUNDLE_CONFIG_DIR/bracket-secret.yaml"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_bracket_secret_fixture_succeeded'
fi
if grep -Fq 'bracket-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_bracket_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/bracket-secret.yaml"

cat >"$BUNDLE_CONFIG_DIR/multiline-secret.yaml" <<'YAML'
credentials:
  token:
    multiline-secret-value
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_multiline_secret_fixture_succeeded'
fi
if grep -Fq 'multiline-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_multiline_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/multiline-secret.yaml"

cat >"$BUNDLE_CONFIG_DIR/block-secret.yaml" <<'YAML'
credentials:
  token: |
    nonempty-block-secret-value
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_block_secret_fixture_succeeded'
fi
if grep -Fq 'nonempty-block-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_block_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/block-secret.yaml"

for fixture in quoted-null quoted-tilde; do
  case "$fixture" in
    quoted-null) quoted_value='"null"' ;;
    quoted-tilde) quoted_value='"~"' ;;
  esac
  printf 'credentials:\n  token: %s\n' "$quoted_value" > \
    "$BUNDLE_CONFIG_DIR/$fixture.yaml"
  if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
    "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
    fail "bundle_${fixture}_fixture_succeeded"
  fi
  if grep -Fq "$quoted_value" "$BUNDLE_LOG"; then
    fail "bundle_${fixture}_value_logged"
  fi
  rm "$BUNDLE_CONFIG_DIR/$fixture.yaml"
done

cat >"$BUNDLE_CONFIG_DIR/block-scalar.yaml" <<'YAML'
credentials:
  token: |
    null
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_block_null_fixture_succeeded'
fi
if grep -Fq 'null' "$BUNDLE_LOG"; then
  fail 'bundle_block_null_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/block-scalar.yaml"

cat >"$BUNDLE_CONFIG_DIR/explicit-key.yaml" <<'YAML'
credentials:
  ? token
  : explicit-key-secret-value
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_explicit_key_fixture_succeeded'
fi
if grep -Fq 'explicit-key-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_explicit_key_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/explicit-key.yaml"

cat >"$BUNDLE_CONFIG_DIR/unicode-key.yaml" <<'YAML'
credentials:
  "\u0074oken": unicode-key-secret-value
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_unicode_key_fixture_succeeded'
fi
if grep -Fq 'unicode-key-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_unicode_key_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/unicode-key.yaml"

cat >"$BUNDLE_CONFIG_DIR/duplicate-key.yaml" <<'YAML'
credentials:
  token: duplicate-yaml-secret-value
  token: ""
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_duplicate_yaml_key_fixture_succeeded'
fi
if grep -Fq 'duplicate-yaml-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_duplicate_yaml_key_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/duplicate-key.yaml"

printf '%s\n' 'credentials: [invalid-yaml-secret-value' > \
  "$BUNDLE_CONFIG_DIR/invalid-config.yaml"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_invalid_yaml_fixture_succeeded'
fi
if grep -Fq 'invalid-yaml-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_invalid_yaml_value_logged'
fi
grep -Fq 'invalid_yaml:invalid-config.yaml' "$BUNDLE_LOG" ||
  fail 'bundle_invalid_yaml_filename_missing'
rm "$BUNDLE_CONFIG_DIR/invalid-config.yaml"

cat >"$BUNDLE_CONFIG_DIR/yaml-pattern.yaml" <<'YAML'
metadata: ghp_yamlpattern123456
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_yaml_pattern_fixture_succeeded'
fi
if grep -Fq 'ghp_yamlpattern123456' "$BUNDLE_LOG"; then
  fail 'bundle_yaml_pattern_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/yaml-pattern.yaml"

for compound_field in bot_token secret_access_key access_token; do
  compound_value="${compound_field}-secret-value"
  printf 'credentials:\n  %s: %s\n' "$compound_field" "$compound_value" > \
    "$BUNDLE_CONFIG_DIR/$compound_field.yaml"
  if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
    "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
    fail "bundle_${compound_field}_fixture_succeeded"
  fi
  if grep -Fq "$compound_value" "$BUNDLE_LOG"; then
    fail "bundle_${compound_field}_value_logged"
  fi
  rm "$BUNDLE_CONFIG_DIR/$compound_field.yaml"
done

cat >"$BUNDLE_CONFIG_DIR/json-secret.json" <<'JSON'
{
  "nested": {
    "password": "nonempty-json-secret-value"
  }
}
JSON
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_json_secret_fixture_succeeded'
fi
if grep -Fq 'nonempty-json-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_json_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/json-secret.json"

cat >"$BUNDLE_CONFIG_DIR/json-pattern.json" <<'JSON'
{
  "metadata": "https://example.test/hooks/json-webhook-secret"
}
JSON
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_json_pattern_fixture_succeeded'
fi
if grep -Fq 'json-webhook-secret' "$BUNDLE_LOG"; then
  fail 'bundle_json_pattern_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/json-pattern.json"

for hook_fixture in slack feishu generic; do
  case "$hook_fixture" in
    slack) hook_url='https://hooks.slack.com/services/T000/B000/SLACKSECRET' ;;
    feishu) hook_url='https://open.feishu.cn/open-apis/bot/v2/hook/FEISHUSECRET' ;;
    generic) hook_url='https://example.test/hook/GENERICSECRET' ;;
  esac
  printf 'metadata = "%s"\n' "$hook_url" > \
    "$BUNDLE_CONFIG_DIR/$hook_fixture-hook.txt"
  if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
    "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
    fail "bundle_${hook_fixture}_hook_fixture_succeeded"
  fi
  if grep -Fq "$hook_url" "$BUNDLE_LOG"; then
    fail "bundle_${hook_fixture}_hook_value_logged"
  fi
  rm "$BUNDLE_CONFIG_DIR/$hook_fixture-hook.txt"
done

printf '%s\n' '{"token": "null"}' > \
  "$BUNDLE_CONFIG_DIR/json-string-null.json"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_json_string_null_fixture_succeeded'
fi
if grep -Fq '"null"' "$BUNDLE_LOG"; then
  fail 'bundle_json_string_null_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/json-string-null.json"

printf '%s\n' '{"token": "duplicate-json-secret-value", "token": ""}' > \
  "$BUNDLE_CONFIG_DIR/json-duplicate-secret.json"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_json_duplicate_secret_fixture_succeeded'
fi
if grep -Fq 'duplicate-json-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_json_duplicate_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/json-duplicate-secret.json"

printf '%s\n' '{"token": "invalid-json-secret-value"' > \
  "$BUNDLE_CONFIG_DIR/invalid-secret.json"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_invalid_json_fixture_succeeded'
fi
if grep -Fq 'invalid-json-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_invalid_json_value_logged'
fi
grep -Fq 'invalid_json:invalid-secret.json' "$BUNDLE_LOG" ||
  fail 'bundle_invalid_json_filename_missing'
rm "$BUNDLE_CONFIG_DIR/invalid-secret.json"

printf '%s\n' 'token = "plain-text-secret-value"' > \
  "$BUNDLE_CONFIG_DIR/plaintext-secret.txt"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_plaintext_secret_fixture_succeeded'
fi
if grep -Fq 'plain-text-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_plaintext_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/plaintext-secret.txt"

printf '%s\n' 'export TOKEN="exported-plain-secret-value"' > \
  "$BUNDLE_CONFIG_DIR/exported-secret.txt"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_exported_secret_fixture_succeeded'
fi
if grep -Fq 'exported-plain-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_exported_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/exported-secret.txt"

printf '\xff\xfet\x00o\x00k\x00e\x00n\x00=\x00u\x00t\x00f\x001\x006\x00-\x00s\x00e\x00c\x00r\x00e\x00t\x00' > \
  "$BUNDLE_CONFIG_DIR/encoded-config.txt"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_non_utf8_fixture_succeeded'
fi
grep -Fq 'unreadable_or_non_utf8:encoded-config.txt' "$BUNDLE_LOG" ||
  fail 'bundle_non_utf8_filename_missing'
if grep -Fq 'utf16-secret' "$BUNDLE_LOG"; then
  fail 'bundle_non_utf8_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/encoded-config.txt"

for compound_field in bot_token access_token secret_access_key; do
  compound_value="${compound_field}-plaintext-value"
  printf '%s = "%s"\n' "$compound_field" "$compound_value" > \
    "$BUNDLE_CONFIG_DIR/$compound_field.txt"
  if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
    "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
    fail "bundle_${compound_field}_plaintext_fixture_succeeded"
  fi
  if grep -Fq "$compound_value" "$BUNDLE_LOG"; then
    fail "bundle_${compound_field}_plaintext_value_logged"
  fi
  rm "$BUNDLE_CONFIG_DIR/$compound_field.txt"
done

cat >"$BUNDLE_CONFIG_DIR/list-secret.yaml" <<'YAML'
credentials:
  - token: plain-secret-value
YAML
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_list_secret_fixture_succeeded'
fi
if grep -Fq 'plain-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_list_secret_value_logged'
fi
rm "$BUNDLE_CONFIG_DIR/list-secret.yaml"

printf '%s\n' 'api_key: "test-secret-value"' >>"$BUNDLE_CONFIG_DIR/config.yaml"
if CONFIG_SOURCE="$BUNDLE_CONFIG_DIR" DIST_ROOT="$BUNDLE_DIST_DIR" \
  "$BUILD_BUNDLE_FILE" >"$BUNDLE_LOG" 2>&1; then
  fail 'bundle_secret_fixture_succeeded'
fi
if grep -Fq 'test-secret-value' "$BUNDLE_LOG"; then
  fail 'bundle_secret_value_logged'
fi

mkdir -p \
  "$OUTPUT_DIR/html/2026-07-04" \
  "$OUTPUT_DIR/news" \
  "$OUTPUT_DIR/rss" \
  "$OUTPUT_DIR/meta" \
  "$OUTPUT_DIR/config"
printf '%s\n' 'NAS index fixture' >"$OUTPUT_DIR/index.html"
printf '%s\n' 'NAS dated report fixture' >"$OUTPUT_DIR/html/2026-07-04/report.html"
printf '%s\n' 'NAS uppercase report fixture' >"$OUTPUT_DIR/html/2026-07-04/uppercase.HTML"
printf '%s\n' 'private news database' >"$OUTPUT_DIR/news/private.db"
printf '%s\n' 'private rss database' >"$OUTPUT_DIR/rss/private.db"
printf '%s\n' 'private metadata database' >"$OUTPUT_DIR/meta/private.db"
printf '%s\n' 'private config database' >"$OUTPUT_DIR/config/private.sqlite"
printf '%s\n' 'private YAML configuration' >"$OUTPUT_DIR/config/private.yaml"
printf '%s\n' 'private HTML text' >"$OUTPUT_DIR/html/private.txt"
printf '%s\n' 'private HTML settings' >"$OUTPUT_DIR/html/settings.ini"
printf '%s\n' 'private hidden HTML' >"$OUTPUT_DIR/html/.private.html"
printf '%s\n' 'private HTML database' >"$OUTPUT_DIR/html/private.db"
printf '%s\n' 'private SQLite 3 database' >"$OUTPUT_DIR/html/private.sqlite3"
printf '%s\n' 'private disguised database' >"$OUTPUT_DIR/html/private.db.html"
printf '%s\n' 'private disguised environment' >"$OUTPUT_DIR/html/private.env.HTML"
printf '%s\n' 'private environment fixture' >"$OUTPUT_DIR/.env"
printf '%s\n' 'private undeclared fixture' >"$OUTPUT_DIR/private.txt"
ln -s ../news/private.db "$OUTPUT_DIR/html/database.html"
ln -s ../config/private.yaml "$OUTPUT_DIR/html/config.html"

"${COMPOSE[@]}" up -d --no-deps report-web >/dev/null

"${COMPOSE[@]}" exec -T report-web \
  wget -qO- http://127.0.0.1/ | grep -Fq 'NAS index fixture' ||
  fail 'index_not_readable'
"${COMPOSE[@]}" exec -T report-web \
  wget -qO- http://127.0.0.1/html/2026-07-04/report.html |
  grep -Fq 'NAS dated report fixture' || fail 'dated_report_not_readable'
"${COMPOSE[@]}" exec -T report-web \
  wget -qO- http://127.0.0.1/html/2026-07-04/uppercase.HTML |
  grep -Fq 'NAS uppercase report fixture' || fail 'uppercase_report_not_readable'

for path in \
  news/private.db \
  news//private.db \
  rss/private.db \
  meta/private.db \
  config/private.sqlite \
  html/private.txt \
  html/settings.ini \
  html/.private.html \
  html/%2eprivate.html \
  html/private.db \
  html/private.sqlite3 \
  html/private.db.html \
  html/private.env.HTML \
  html/database.html \
  html/config.html \
  .env \
  private.txt; do
  require_rejected_status "$path"
done

require_body_absent html/database.html 'private news database'
require_body_absent html/config.html 'private YAML configuration'

printf 'nas_integration=passed\n'
