#!/usr/bin/env bash
#
# secrets-edit.sh — interactively edit METADATA only (value untouched).
#
# For value updates, use secrets-update.sh.
#
# Usage:
#   bash scripts/secrets-edit.sh KEY
#
# Exit codes:
#   0  success
#   1  KEY not found
#   2  usage error
#   5  user aborted

set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/secrets-edit.sh KEY" >&2
  exit 2
fi

KEY="$1"
MANIFEST=".claude/secrets-manifest.yaml"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found" >&2
  exit 1
fi

if ! grep -qE "^[[:space:]]*-[[:space:]]*key:[[:space:]]*${KEY}[[:space:]]*$" "$MANIFEST"; then
  echo "ERROR: $KEY not declared in manifest" >&2
  exit 1
fi

if [[ ! -t 0 ]]; then
  echo "ERROR: secrets-edit.sh requires interactive tty" >&2
  exit 2
fi

# Show current metadata.
bash "$(dirname "$0")/secrets-show.sh" "$KEY"
echo ""
echo "Press Enter to keep current value of any field."
echo ""

# Read current values for default display.
_get_field() {
  local field="$1"
  awk -v k="$KEY" -v f="$field" '
    $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
    found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
    found && $0 ~ "^[[:space:]]*"f":[[:space:]]*" {
      sub("^[[:space:]]*"f":[[:space:]]*", "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      gsub(/[[:space:]]+$/, "")
      print; exit
    }' "$MANIFEST"
}

cur_sn=$(_get_field service_name)
cur_url=$(_get_field service_url)
cur_login=$(_get_field login)
cur_exp=$(_get_field expires_at)

new_sn="$cur_sn"
new_url="$cur_url"
new_login="$cur_login"
new_exp="$cur_exp"

printf 'Service name [%s]: ' "${cur_sn:-blank}"
read -r _input
[[ -n "$_input" ]] && new_sn="$_input"

printf 'Service URL [%s]: ' "${cur_url:-blank}"
read -r _input
[[ -n "$_input" ]] && new_url="$_input"

printf 'Login [%s]: ' "${cur_login:-blank}"
read -r _input
if [[ -n "$_input" ]]; then
  if [[ "$_input" == "-" ]]; then
    new_login=""
  else
    new_login="$_input"
  fi
fi

printf 'Expires at YYYY-MM-DD [%s]: ' "${cur_exp:-blank}"
read -r _input
if [[ -n "$_input" ]]; then
  if [[ "$_input" == "-" ]]; then
    new_exp=""
  else
    new_exp="$_input"
  fi
fi

# Apply metadata-only update via python (do NOT touch .env).
LOCK="${MANIFEST}.lock"
TMP="${MANIFEST}.tmp.$$"

_cleanup() {
  local code=$?
  [[ -f "$TMP" ]] && rm -f "$TMP" 2>/dev/null || true
  [[ -d "$LOCK" ]] && rmdir "$LOCK" 2>/dev/null || true
  exit $code
}
trap _cleanup INT TERM EXIT

# Lock
tries=0
while ! mkdir "$LOCK" 2>/dev/null; do
  tries=$((tries+1))
  [[ $tries -gt 50 ]] && { echo "ERROR: lock busy" >&2; exit 3; }
  sleep 0.1
done

py - "$MANIFEST" "$TMP" "$KEY" "$new_sn" "$new_url" "$new_login" "$new_exp" <<'PYEOF'
import sys, re
src, dst, key, sn, url, login, expires = sys.argv[1:]
with open(src, encoding='utf-8') as f:
    lines = f.readlines()

out = []
in_entry = False
fields_done = set()
key_re = re.compile(rf'^(\s*-\s*key:\s*){re.escape(key)}\s*$')
next_entry_re = re.compile(r'^\s*-\s*key:\s*')

def fmt(name, val, indent='    '):
    return f'{indent}{name}: "{val}"\n'

def fmt_blank(name, indent='    '):
    return f'{indent}{name}: ""\n'

i = 0
while i < len(lines):
    line = lines[i]
    if not in_entry and key_re.match(line):
        in_entry = True
        out.append(line)
        i += 1; continue
    if in_entry and next_entry_re.match(line):
        # Flush any not-yet-written fields before next entry.
        if 'service_name' not in fields_done and sn:
            out.append(fmt('service_name', sn))
        if 'service_url' not in fields_done and url:
            out.append(fmt('service_url', url))
        if 'login' not in fields_done and login:
            out.append(fmt('login', login))
        if 'expires_at' not in fields_done and expires:
            out.append(fmt('expires_at', expires))
        in_entry = False
        out.append(line)
        i += 1; continue
    if in_entry:
        m = re.match(r'^(\s*)(service_name|service_url|login|expires_at):\s*', line)
        if m:
            indent, field = m.group(1), m.group(2)
            val = {'service_name': sn, 'service_url': url, 'login': login, 'expires_at': expires}[field]
            if val:
                out.append(fmt(field, val, indent))
            elif field in ('login', 'expires_at'):
                out.append(fmt_blank(field, indent))
            fields_done.add(field)
            i += 1; continue
    out.append(line)
    i += 1

if in_entry:
    if 'service_name' not in fields_done and sn: out.append(fmt('service_name', sn))
    if 'service_url' not in fields_done and url: out.append(fmt('service_url', url))
    if 'login' not in fields_done and login: out.append(fmt('login', login))
    if 'expires_at' not in fields_done and expires: out.append(fmt('expires_at', expires))

with open(dst, 'w', encoding='utf-8') as f:
    f.writelines(out)
PYEOF

if [[ -s "$TMP" ]]; then
  mv "$TMP" "$MANIFEST"
fi

rmdir "$LOCK" 2>/dev/null || true
trap - INT TERM EXIT

echo ""
echo "✅ Metadata updated for $KEY (value unchanged)"
echo "   View: bash scripts/secrets-show.sh $KEY"
