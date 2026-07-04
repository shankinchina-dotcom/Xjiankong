#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_SOURCE="${CONFIG_SOURCE:-$REPO_ROOT/../TrendRadar/config}"
DIST_ROOT="${DIST_ROOT:-$REPO_ROOT/dist}"
BUNDLE_NAME='trendradar-nas'
FINAL_DIR="$DIST_ROOT/$BUNDLE_NAME"
FINAL_ARCHIVE="$DIST_ROOT/$BUNDLE_NAME.tar.gz"

fail() {
  printf 'bundle_build=failed reason=%s\n' "$1" >&2
  exit 1
}

require_nonempty() {
  local path="$1"
  [[ -s "$path" ]] || fail "missing_or_empty:$path"
}

require_nonempty "$CONFIG_SOURCE/config.yaml"
require_nonempty "$CONFIG_SOURCE/frequency_words.txt"
command -v python3 >/dev/null 2>&1 || fail 'python3_not_found'

python3 - "$CONFIG_SOURCE" <<'PY'
import os
import re
import sys

config_root = os.path.realpath(sys.argv[1])
excluded_names = {'.env'}
excluded_dirs = {'.git', '.cache', '__pycache__', 'cache', 'output'}
excluded_suffixes = ('.db', '.sqlite', '.sqlite3', '.pyc')
secret_fields = {'api_key', 'webhook_url', 'token', 'secret', 'password'}
credential_patterns = (
    ('api_key_pattern', re.compile(r'(?i)\bsk-[a-z0-9_-]{8,}')),
    ('github_token_pattern', re.compile(
        r'(?i)\b(?:gh[opusr]_[a-z0-9]{12,}|github_pat_[a-z0-9_]{12,})'
    )),
    ('webhook_url_pattern', re.compile(
        r'(?i)https?://[^\s"\'<>]*(?:webhook|hooks/)[^\s"\'<>]*'
    )),
)


def strip_comment(value):
    quote = None
    escaped = False
    for index, char in enumerate(value):
        if escaped:
            escaped = False
            continue
        if char == '\\' and quote == '"':
            escaped = True
            continue
        if char in ('"', "'"):
            if quote is None:
                quote = char
            elif quote == char:
                quote = None
            continue
        if char == '#' and quote is None:
            return value[:index]
    return value


def scalar_value(value):
    value = strip_comment(value).strip().rstrip(',').strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
        value = value[1:-1].strip()
    return value


def is_allowed_empty_or_env(value):
    if value.lower() in ('', 'null', '~'):
        return True
    return re.fullmatch(r'\$\{[A-Za-z_][A-Za-z0-9_]*\}', value) is not None


config_path = os.path.join(config_root, 'config.yaml')
with open(config_path, encoding='utf-8') as handle:
    config_lines = handle.readlines()

filter_indent = None
filter_method = None
for line in config_lines:
    clean = strip_comment(line.rstrip('\n'))
    if not clean.strip():
        continue
    indent = len(clean) - len(clean.lstrip())
    if filter_indent is None:
        if re.fullmatch(r'\s*filter\s*:\s*', clean):
            filter_indent = indent
        continue
    if indent <= filter_indent:
        break
    match = re.match(r'\s*method\s*:\s*(.*?)\s*$', clean)
    if match:
        filter_method = scalar_value(match.group(1))
        break

if filter_method != 'keyword':
    print('bundle_build=failed reason=config_filter_method_not_keyword', file=sys.stderr)
    sys.exit(1)

field_pattern = re.compile(
    r'^\s*(?:[-,{]\s*)?["\']?(api_key|webhook_url|token|secret|password)'
    r'["\']?\s*:\s*(.*?)\s*$' ,
    re.IGNORECASE,
)

for directory, dirnames, filenames in os.walk(config_root, followlinks=False):
    dirnames[:] = [name for name in dirnames if name not in excluded_dirs]
    for filename in filenames:
        if filename in excluded_names or filename.lower().endswith(excluded_suffixes):
            continue
        path = os.path.join(directory, filename)
        if os.path.islink(path):
            continue
        relative = os.path.relpath(path, config_root)
        try:
            with open(path, encoding='utf-8') as handle:
                content = handle.read()
        except (UnicodeDecodeError, OSError):
            continue
        for line in content.splitlines():
            match = field_pattern.match(line)
            if match:
                field = match.group(1).lower()
                value = scalar_value(match.group(2))
                if field in secret_fields and not is_allowed_empty_or_env(value):
                    print(
                        f'bundle_build=failed reason=secret_field:{relative}:{field}',
                        file=sys.stderr,
                    )
                    sys.exit(1)
        for label, pattern in credential_patterns:
            if pattern.search(content):
                print(
                    f'bundle_build=failed reason={label}:{relative}',
                    file=sys.stderr,
                )
                sys.exit(1)
PY

mkdir -p "$DIST_ROOT"
STAGING_DIR="$(mktemp -d "$DIST_ROOT/.${BUNDLE_NAME}.build.XXXXXX")"
PREVIOUS_DIR="$DIST_ROOT/.${BUNDLE_NAME}.previous.$$"
PREVIOUS_ARCHIVE="$DIST_ROOT/.${BUNDLE_NAME}.tar.gz.previous.$$"
PUBLISH_COMMITTED=false
DIR_PUBLISH_STARTED=false
ARCHIVE_PUBLISH_STARTED=false

cleanup() {
  local exit_status="$?"

  trap - EXIT HUP INT TERM
  set +e
  if [[ "$PUBLISH_COMMITTED" != 'true' ]]; then
    if [[ -e "$PREVIOUS_DIR" ]]; then
      rm -rf "$FINAL_DIR"
      mv "$PREVIOUS_DIR" "$FINAL_DIR"
    elif [[ "$DIR_PUBLISH_STARTED" == 'true' ]]; then
      rm -rf "$FINAL_DIR"
    fi

    if [[ -e "$PREVIOUS_ARCHIVE" ]]; then
      rm -f "$FINAL_ARCHIVE"
      mv "$PREVIOUS_ARCHIVE" "$FINAL_ARCHIVE"
    elif [[ "$ARCHIVE_PUBLISH_STARTED" == 'true' ]]; then
      rm -f "$FINAL_ARCHIVE"
    fi
  else
    rm -rf "$PREVIOUS_DIR"
    rm -f "$PREVIOUS_ARCHIVE"
  fi
  rm -rf "$STAGING_DIR"
  exit "$exit_status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

BUNDLE_DIR="$STAGING_DIR/$BUNDLE_NAME"
mkdir -p "$BUNDLE_DIR/config" "$BUNDLE_DIR/output"
cp "$SCRIPT_DIR/compose.yaml" "$BUNDLE_DIR/compose.yaml"
cp "$SCRIPT_DIR/.env.example" "$BUNDLE_DIR/.env.example"
cp "$SCRIPT_DIR/nginx.conf" "$BUNDLE_DIR/nginx.conf"
cp "$SCRIPT_DIR/README.md" "$BUNDLE_DIR/README.md"

while IFS= read -r -d '' source_path; do
  relative_path="${source_path#"$CONFIG_SOURCE"/}"
  case "/$relative_path/" in
    */.git/* | */.cache/* | */__pycache__/* | */cache/* | */output/*) continue ;;
  esac
  case "${relative_path##*/}" in
    .env | *.db | *.sqlite | *.sqlite3 | *.pyc) continue ;;
  esac
  destination="$BUNDLE_DIR/config/$relative_path"
  mkdir -p "$(dirname "$destination")"
  cp -p "$source_path" "$destination"
done < <(find "$CONFIG_SOURCE" -type f -print0)

tar -czf "$STAGING_DIR/$BUNDLE_NAME.tar.gz" -C "$STAGING_DIR" "$BUNDLE_NAME"

if [[ -e "$FINAL_DIR" ]]; then
  mv "$FINAL_DIR" "$PREVIOUS_DIR"
fi
if [[ -e "$FINAL_ARCHIVE" ]]; then
  mv "$FINAL_ARCHIVE" "$PREVIOUS_ARCHIVE"
fi

DIR_PUBLISH_STARTED=true
mv "$BUNDLE_DIR" "$FINAL_DIR" || fail 'publish_directory_failed'
ARCHIVE_PUBLISH_STARTED=true
mv "$STAGING_DIR/$BUNDLE_NAME.tar.gz" "$FINAL_ARCHIVE" ||
  fail 'publish_archive_failed'

PUBLISH_COMMITTED=true
printf 'bundle_build=passed output=%s\n' "$FINAL_ARCHIVE"
