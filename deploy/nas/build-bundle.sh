#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_SOURCE="${CONFIG_SOURCE:-$REPO_ROOT/../TrendRadar/config}"
DIST_ROOT="${DIST_ROOT:-$REPO_ROOT/dist}"
BUNDLE_NAME='trendradar-nas'

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
command -v ruby >/dev/null 2>&1 || fail 'ruby_not_found'

mkdir -p "$DIST_ROOT" || fail 'dist_root_create_failed'
CONFIG_SOURCE="$(cd "$CONFIG_SOURCE" && pwd -P)"
DIST_ROOT="$(cd "$DIST_ROOT" && pwd -P)"
FINAL_DIR="$DIST_ROOT/$BUNDLE_NAME"
FINAL_ARCHIVE="$DIST_ROOT/$BUNDLE_NAME.tar.gz"
LOCK_DIR="$DIST_ROOT/.${BUNDLE_NAME}.lock"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  fail 'bundle_locked'
fi

LOCK_HELD=true
STAGING_DIR=''
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
  if [[ -n "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
  fi
  if [[ "$LOCK_HELD" == 'true' ]]; then
    if ! rmdir "$LOCK_DIR" 2>/dev/null; then
      printf 'bundle_build=failed reason=lock_release_failed\n' >&2
      if [[ "$exit_status" -eq 0 ]]; then
        exit_status=1
      fi
    fi
  fi
  exit "$exit_status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "$CONFIG_SOURCE" == "$DIST_ROOT" ]] ||
  [[ "$CONFIG_SOURCE" == "$DIST_ROOT/"* ]] ||
  [[ "$DIST_ROOT" == "$CONFIG_SOURCE/"* ]]; then
  fail 'config_dist_overlap'
fi

STAGING_DIR="$(mktemp -d "$DIST_ROOT/.${BUNDLE_NAME}.build.XXXXXX")" ||
  fail 'staging_create_failed'
MANIFEST="$STAGING_DIR/config-manifest"
BUNDLE_DIR="$STAGING_DIR/$BUNDLE_NAME"
mkdir -p "$BUNDLE_DIR/config" "$BUNDLE_DIR/output" || fail 'staging_layout_failed'
cp "$SCRIPT_DIR/docker-compose.yml" "$BUNDLE_DIR/docker-compose.yml" ||
  fail 'template_copy_failed'
cp "$SCRIPT_DIR/.env.example" "$BUNDLE_DIR/.env.example" || fail 'template_copy_failed'
cp "$SCRIPT_DIR/nginx.conf" "$BUNDLE_DIR/nginx.conf" || fail 'template_copy_failed'
cp "$SCRIPT_DIR/README.md" "$BUNDLE_DIR/README.md" || fail 'template_copy_failed'

is_excluded_config_directory() {
  local name="$1"

  case "$name" in
    .git | output | __pycache__ | cache | .tox | .nox | *_cache | *.cache) return 0 ;;
    *) return 1 ;;
  esac
}

path_has_excluded_config_directory() {
  local remaining="$1"
  local component

  while [[ "$remaining" == */* ]]; do
    component="${remaining%%/*}"
    is_excluded_config_directory "$component" && return 0
    remaining="${remaining#*/}"
  done
  return 1
}

if ! find "$CONFIG_SOURCE" -type f -print0 >"$MANIFEST"; then
  fail 'find_failed'
fi

while IFS= read -r -d '' source_path; do
  relative_path="${source_path#"$CONFIG_SOURCE"/}"
  path_has_excluded_config_directory "$relative_path" && continue
  case "${relative_path##*/}" in
    .env | .git) continue ;;
  esac
  filename_lower="$(
    printf '%s' "${relative_path##*/}" | tr '[:upper:]' '[:lower:]'
  )"
  case "$filename_lower" in
    *.db | *.sqlite | *.sqlite3 | *.pyc) continue ;;
  esac
  destination="$BUNDLE_DIR/config/$relative_path"
  mkdir -p "$(dirname "$destination")" || fail 'config_copy_failed'
  cp -p "$source_path" "$destination" || fail 'config_copy_failed'
done <"$MANIFEST"

python3 - "$BUNDLE_DIR" <<'PY'
import json
import os
import re
import sys

config_root = os.path.realpath(sys.argv[1])
exact_secret_fields = {'api_key', 'webhook_url', 'token', 'secret', 'password'}
credential_patterns = (
    ('api_key_pattern', re.compile(r'(?i)\bsk-[a-z0-9_-]{8,}')),
    ('github_token_pattern', re.compile(
        r'(?i)\b(?:gh[opusr]_[a-z0-9]{12,}|github_pat_[a-z0-9_]{12,})'
    )),
    ('webhook_url_pattern', re.compile(
        r'(?i)https?://[^\s"\'<>]*(?:hooks[.]slack[.]com/services/'
        r'|/bot/v2/hook/|/hooks?/|webhook)[^\s"\'<>]*'
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


def is_env_placeholder(value):
    return re.fullmatch(
        r'\$\{[A-Za-z_][A-Za-z0-9_]*(?::-)?\}', value
    ) is not None


def normalized_field(value):
    return value.lower().replace('-', '_')


def is_secret_field(field):
    if field in exact_secret_fields:
        return True
    if 'api_key' in field or 'webhook_url' in field:
        return True
    return any(word in {'token', 'secret', 'password'} for word in field.split('_'))


def is_allowed_json_value(value):
    return value is None or (
        isinstance(value, str) and (not value or is_env_placeholder(value))
    )


def is_allowed_text_value(raw_value):
    value = strip_comment(raw_value).strip()
    if not value:
        return True
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
        quoted_value = value[1:-1]
        return not quoted_value or is_env_placeholder(quoted_value)
    return is_env_placeholder(value)


def fail_secret(relative, field):
    print(
        f'bundle_build=failed reason=secret_field:{relative}:{field}',
        file=sys.stderr,
    )
    sys.exit(1)


class JsonPairs(list):
    pass


def check_json_value(value, relative):
    if isinstance(value, JsonPairs):
        for key, child in value:
            field = normalized_field(key)
            if is_secret_field(field) and not is_allowed_json_value(child):
                fail_secret(relative, field)
            check_json_value(child, relative)
    elif isinstance(value, list):
        for child in value:
            check_json_value(child, relative)


assignment_pattern = re.compile(
    r'^\s*(?:export[ \t]+)?(?P<field>[A-Za-z_][A-Za-z0-9_-]*)'
    r'\s*[:=]\s*(?P<value>.*?)\s*$'
)

for directory, dirnames, filenames in os.walk(config_root, followlinks=False):
    for filename in filenames:
        path = os.path.join(directory, filename)
        if os.path.islink(path):
            continue
        relative = os.path.relpath(path, config_root)
        try:
            with open(path, encoding='utf-8') as handle:
                content = handle.read()
        except (UnicodeDecodeError, OSError):
            print(
                f'bundle_build=failed reason=unreadable_or_non_utf8:{relative}',
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
        if relative.lower().endswith('.json'):
            try:
                json_value = json.loads(content, object_pairs_hook=JsonPairs)
            except (json.JSONDecodeError, RecursionError):
                print(
                    f'bundle_build=failed reason=invalid_json:{relative}',
                    file=sys.stderr,
                )
                sys.exit(1)
            check_json_value(json_value, relative)
            continue
        if relative.lower().endswith(('.yaml', '.yml')):
            continue
        for line in content.splitlines():
            match = assignment_pattern.match(line)
            if not match:
                continue
            field = normalized_field(match.group('field'))
            if is_secret_field(field) and not is_allowed_text_value(
                match.group('value')
            ):
                fail_secret(relative, field)
PY

ruby -rpsych - "$BUNDLE_DIR" <<'RUBY'
config_root = File.realpath(ARGV.fetch(0))
exact_secret_fields = %w[api_key webhook_url token secret password].freeze
block_styles = [
  Psych::Nodes::Scalar::LITERAL,
  Psych::Nodes::Scalar::FOLDED
].freeze
env_pattern = /\A\$\{[A-Za-z_][A-Za-z0-9_]*(?::-)?\}\z/

def normalized_field(value)
  value.downcase.tr('-', '_')
end

def secret_field?(field, exact_secret_fields)
  return true if exact_secret_fields.include?(field)
  return true if field.include?('api_key') || field.include?('webhook_url')

  field.split('_').any? { |word| %w[token secret password].include?(word) }
end

def allowed_sensitive_value?(node, block_styles, env_pattern)
  if node.is_a?(Psych::Nodes::Scalar)
    value = node.value
    return true if value.empty?
    if block_styles.include?(node.style)
      block_value = value.sub(/\n+\z/, '')
      return block_value.empty? || env_pattern.match?(block_value)
    end
    return true if env_pattern.match?(value)
    return node.plain && node.tag.nil? && %w[null ~].include?(value.downcase)
  end
  if node.is_a?(Psych::Nodes::Mapping) || node.is_a?(Psych::Nodes::Sequence)
    return Array(node.children).empty?
  end

  false
end

def fail_secret(relative, field)
  warn "bundle_build=failed reason=secret_field:#{relative}:#{field}"
  exit 1
end

def fail_filter(relative)
  warn "bundle_build=failed reason=config_filter_invalid:#{relative}"
  exit 1
end

def validate_filter(ast, relative)
  documents = Array(ast.children)
  fail_filter(relative) unless documents.length == 1
  root = documents.first.root
  fail_filter(relative) unless root.is_a?(Psych::Nodes::Mapping)

  filters = Array(root.children).each_slice(2).select do |key, _value|
    key.is_a?(Psych::Nodes::Scalar) && key.value == 'filter'
  end
  fail_filter(relative) unless filters.length == 1
  filter_value = filters.first[1]
  fail_filter(relative) unless filter_value.is_a?(Psych::Nodes::Mapping)

  methods = Array(filter_value.children).each_slice(2).select do |key, _value|
    key.is_a?(Psych::Nodes::Scalar) && key.value == 'method'
  end
  fail_filter(relative) unless methods.length == 1
  method_value = methods.first[1]
  fail_filter(relative) unless method_value.is_a?(Psych::Nodes::Scalar)
  fail_filter(relative) unless method_value.value == 'keyword'
end

def visit_yaml(node, relative, exact_secret_fields, block_styles, env_pattern)
  return if node.nil?

  if node.is_a?(Psych::Nodes::Mapping)
    Array(node.children).each_slice(2) do |key, value|
      if key.is_a?(Psych::Nodes::Scalar)
        field = normalized_field(key.value)
        if secret_field?(field, exact_secret_fields) &&
           !allowed_sensitive_value?(value, block_styles, env_pattern)
          fail_secret(relative, field)
        end
      end
      visit_yaml(key, relative, exact_secret_fields, block_styles, env_pattern)
      visit_yaml(value, relative, exact_secret_fields, block_styles, env_pattern)
    end
  else
    Array(node.respond_to?(:children) ? node.children : nil).each do |child|
      visit_yaml(child, relative, exact_secret_fields, block_styles, env_pattern)
    end
  end
end

Dir.glob(File.join(config_root, '**', '*'), File::FNM_DOTMATCH).sort.each do |path|
  relative = path.delete_prefix("#{config_root}/")
  next unless File.file?(path) && !File.symlink?(path)
  filename = File.basename(path)
  next unless ['.yaml', '.yml'].include?(File.extname(filename).downcase)

  begin
    ast = Psych.parse_stream(File.read(path, encoding: 'UTF-8'), relative)
  rescue Psych::SyntaxError, ArgumentError
    warn "bundle_build=failed reason=invalid_yaml:#{relative}"
    exit 1
  end
  validate_filter(ast, relative) if relative == 'config/config.yaml'
  visit_yaml(ast, relative, exact_secret_fields, block_styles, env_pattern)
end
RUBY

tar -czf "$STAGING_DIR/$BUNDLE_NAME.tar.gz" -C "$STAGING_DIR" "$BUNDLE_NAME" ||
  fail 'archive_create_failed'

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
