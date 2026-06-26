#!/usr/bin/env bash
#
# set-secret.sh — atomically add/update a secret + its manifest metadata.
#
# v4.41.0+ schema v2:
#   - Interactive mode (no value arg): prompts for service_name, service_url,
#     login (optional), expires_at (optional), value (via `read -s`),
#     re-paste confirmation. Writes to .env + manifest atomically.
#   - Inline mode (legacy): `bash scripts/set-secret.sh KEY value
#                            [--service NAME] [--url URL] [--login LOGIN]
#                            [--expires YYYY-MM-DD] [--no-confirm]`
#     for scripting / CI/CD (read -s would hang in non-tty).
#
# Atomic invariants:
#   - Both .env value AND manifest metadata updated, or NEITHER.
#   - SIGINT (Ctrl+C) → trap → cleanup tmp files + release flock + rollback.
#   - Backup of prior .env saved to .env.backup-{timestamp} (24h retention).
#
# Exit codes:
#   0  success
#   1  value validation failed
#   2  usage error
#   3  write / permission / lock error
#   4  high-sensitivity key blocked from --shared scope
#   5  user aborted (Ctrl+C or confirmation declined)

set -uo pipefail

SHARED_ENV="${HOME}/.config/it-dev/secrets.env"
MANIFEST=".claude/secrets-manifest.yaml"

# Config defaults — overridable in CLAUDE.local.md ## Secrets.
DEFAULT_URL_SCHEME="https"
BACKUP_RETENTION_HOURS="24"

if [[ -f "CLAUDE.local.md" ]]; then
  _lcl=$(awk '/^##[[:space:]]+Secrets/{f=1; next} /^## /{f=0} f' CLAUDE.local.md 2>/dev/null)
  _v=$(echo "$_lcl" | grep -E "^[[:space:]]*default_url_scheme:" | head -1 \
       | sed 's/.*default_url_scheme:[[:space:]]*//' | tr -d '"'"'"'' | tr -d '[:space:]')
  [[ -n "$_v" ]] && DEFAULT_URL_SCHEME="$_v"
  _v=$(echo "$_lcl" | grep -E "^[[:space:]]*backup_retention_hours:" | head -1 \
       | sed 's/.*backup_retention_hours:[[:space:]]*//' | tr -d '"'"'"'' | tr -d '[:space:]')
  [[ -n "$_v" ]] && BACKUP_RETENTION_HOURS="$_v"
fi

usage() {
  cat >&2 <<'EOF'
Usage:
  bash scripts/set-secret.sh KEY                                    # interactive
  bash scripts/set-secret.sh KEY value                              # inline value
  bash scripts/set-secret.sh KEY value --service NAME --url URL    # inline + metadata
  bash scripts/set-secret.sh --shared KEY [value] [opts]           # write to shared

Options (inline mode):
  --service NAME      Human-readable service name (e.g. "GitHub")
  --url URL           Service URL (e.g. "https://github.com")
  --login LOGIN       Optional username/account
  --expires DATE      ISO-8601 date (YYYY-MM-DD)
  --no-confirm        Skip value re-paste confirmation (for CI)
  --shared            Write to ~/.config/it-dev/secrets.env (shared scope)

Examples:
  bash scripts/set-secret.sh GITHUB_PAT                             # all-interactive
  bash scripts/set-secret.sh GITHUB_PAT ghp_xxx --service GitHub --url https://github.com

After setting, agents in any session use this secret automatically.
EOF
  exit 2
}

# Parse args.
SCOPE="project"
KEY=""
VALUE=""
OPT_SERVICE=""
OPT_URL=""
OPT_LOGIN=""
OPT_EXPIRES=""
NO_CONFIRM=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --shared)       SCOPE="shared"; shift ;;
    --service)      OPT_SERVICE="$2"; shift 2 ;;
    --url)          OPT_URL="$2"; shift 2 ;;
    --login)        OPT_LOGIN="$2"; shift 2 ;;
    --expires)      OPT_EXPIRES="$2"; shift 2 ;;
    --no-confirm)   NO_CONFIRM=true; shift ;;
    --help|-h)      usage ;;
    -*)             echo "Unknown option: $1" >&2; usage ;;
    *)
      if [[ -z "$KEY" ]]; then
        KEY="$1"
      elif [[ -z "$VALUE" ]]; then
        VALUE="$1"
      else
        echo "Unexpected arg: $1" >&2; usage
      fi
      shift
      ;;
  esac
done

[[ -z "$KEY" ]] && usage

if ! [[ "$KEY" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
  echo "ERROR: key must be UPPER_SNAKE_CASE: $KEY" >&2
  exit 2
fi

# Read manifest scope for this KEY (before target-file determination).
# Used for scope-routing (prompt) and sensitivity-check softening below.
MANIFEST_SCOPE="per-project"
if [[ -f "$MANIFEST" ]]; then
  _ms=$(awk -v k="$KEY" '
    $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
    found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
    found && /^[[:space:]]*scope:[[:space:]]*/ {
      sub(/^[[:space:]]*scope:[[:space:]]*/, "")
      gsub(/[[:space:]"'"'"']/, "")
      print; exit
    }' "$MANIFEST")
  [[ -n "$_ms" ]] && MANIFEST_SCOPE="$_ms"
fi

# Scope-routing: manifest declares shared but --shared not passed → prompt (TTY only).
# Non-TTY (CI/CD): skip prompt, keep SCOPE=project; caller must pass --shared explicitly.
if [[ "$MANIFEST_SCOPE" == "shared" && "$SCOPE" == "project" && -t 0 ]]; then
  printf 'ℹ️  Manifest declares scope:shared for %s → write to %s? [Y/n] ' "$KEY" "$SHARED_ENV"
  read -r _scope_confirm
  if [[ -z "$_scope_confirm" || "$_scope_confirm" =~ ^[Yy] ]]; then
    SCOPE="shared"
  fi
fi

# Determine target file.
if [[ "$SCOPE" == "shared" ]]; then
  TARGET="$SHARED_ENV"
  mkdir -p "$(dirname "$TARGET")"
  chmod 700 "$(dirname "$TARGET")" 2>/dev/null || true
else
  TARGET=".env"
  [[ -f "$TARGET" ]] || touch "$TARGET"
fi

LOCK="${TARGET}.lock"
TMP="${TARGET}.tmp.$$"
MANIFEST_TMP="${MANIFEST}.tmp.$$"
BACKUP=""

# Trap cleanup: SIGINT/SIGTERM/exit → remove tmp, release lock, restore if needed.
_cleanup() {
  local code=$?
  [[ -f "$TMP" ]] && rm -f "$TMP" 2>/dev/null || true
  [[ -f "$MANIFEST_TMP" ]] && rm -f "$MANIFEST_TMP" 2>/dev/null || true
  if [[ -d "$LOCK" ]]; then
    rmdir "$LOCK" 2>/dev/null || true
  fi
  if [[ $code -ne 0 && -n "$BACKUP" && -f "$BACKUP" ]]; then
    echo "" >&2
    echo "⚠️  Operation aborted (exit $code). Original .env preserved." >&2
    echo "    Backup at: $BACKUP" >&2
  fi
  exit $code
}
trap _cleanup INT TERM EXIT

# Acquire lock.
if command -v flock >/dev/null 2>&1; then
  exec 200>"$LOCK"
  if ! flock -x -w 5 200; then
    echo "ERROR: could not acquire lock on $LOCK after 5s" >&2
    exit 3
  fi
else
  tries=0
  while ! mkdir "$LOCK" 2>/dev/null; do
    tries=$((tries+1))
    [[ $tries -gt 50 ]] && { echo "ERROR: lock $LOCK busy" >&2; exit 3; }
    sleep 0.1
  done
fi

# ---- Determine if interactive mode needed ----
INTERACTIVE=false
if [[ -z "$VALUE" ]]; then
  if [[ -t 0 ]]; then
    INTERACTIVE=true
  else
    echo "ERROR: no value provided and stdin is not a tty (CI/CD mode requires inline value)" >&2
    echo "       Usage: bash scripts/set-secret.sh KEY value [opts]" >&2
    exit 2
  fi
fi

# ---- Interactive prompts ----
if $INTERACTIVE; then
  echo ""
  echo "🔐 Adding/updating secret: $KEY"
  echo "   (Press Ctrl+C anytime to abort safely.)"
  echo ""

  # Check if entry exists in manifest — show current metadata if so.
  if [[ -f "$MANIFEST" ]] && grep -qE "^[[:space:]]*-[[:space:]]*key:[[:space:]]*${KEY}[[:space:]]*$" "$MANIFEST"; then
    echo "ℹ️  Entry exists in manifest. Press Enter to keep current value of any field."
    cur_sn=$(awk -v k="$KEY" '
      $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
      found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
      found && /^[[:space:]]*service_name:[[:space:]]*/ {
        sub(/^[[:space:]]*service_name:[[:space:]]*/, "")
        gsub(/^["'"'"']|["'"'"']$/, "")
        print; exit
      }' "$MANIFEST")
    cur_url=$(awk -v k="$KEY" '
      $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
      found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
      found && /^[[:space:]]*service_url:[[:space:]]*/ {
        sub(/^[[:space:]]*service_url:[[:space:]]*/, "")
        gsub(/^["'"'"']|["'"'"']$/, "")
        print; exit
      }' "$MANIFEST")
    cur_login=$(awk -v k="$KEY" '
      $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
      found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
      found && /^[[:space:]]*login:[[:space:]]*/ {
        sub(/^[[:space:]]*login:[[:space:]]*/, "")
        gsub(/^["'"'"']|["'"'"']$/, "")
        print; exit
      }' "$MANIFEST")
    [[ -n "$cur_sn" ]] && OPT_SERVICE="$cur_sn"
    [[ -n "$cur_url" ]] && OPT_URL="$cur_url"
    [[ -n "$cur_login" ]] && OPT_LOGIN="$cur_login"
  fi

  printf 'Service name (e.g. "GitHub", "GitLab Nexchance", "OpenAI API") [%s]: ' "${OPT_SERVICE:-blank to skip}"
  read -r _input
  [[ -n "$_input" ]] && OPT_SERVICE="$_input"

  printf 'Service URL (e.g. https://github.com) [%s]: ' "${OPT_URL:-blank to skip}"
  read -r _input
  if [[ -n "$_input" ]]; then
    # Auto-prepend scheme if just hostname provided.
    if ! [[ "$_input" =~ ^[a-z]+:// ]]; then
      _input="${DEFAULT_URL_SCHEME}://${_input}"
    fi
    OPT_URL="$_input"
  fi

  printf 'Login (username/email — blank for token-only auth) [%s]: ' "${OPT_LOGIN:-blank}"
  read -r _input
  [[ -n "$_input" ]] && OPT_LOGIN="$_input"

  printf 'Expires at (ISO-8601 date YYYY-MM-DD — blank if no expiry) [%s]: ' "${OPT_EXPIRES:-blank}"
  read -r _input
  [[ -n "$_input" ]] && OPT_EXPIRES="$_input"

  printf 'Token/password value (hidden): '
  read -rs VALUE
  echo ""

  if [[ -z "$VALUE" ]]; then
    echo "ERROR: empty value, aborting." >&2
    exit 1
  fi

  if ! $NO_CONFIRM; then
    printf 'Re-paste to confirm (hidden): '
    read -rs _confirm
    echo ""
    if [[ "$VALUE" != "$_confirm" ]]; then
      echo "ERROR: values do not match, aborting (nothing changed)." >&2
      exit 1
    fi
  fi
fi

# Sanitize value: strip CR/LF (some terminals append them).
VALUE="${VALUE%$'\r'}"
VALUE="${VALUE%$'\n'}"

[[ -z "$VALUE" ]] && { echo "ERROR: empty value" >&2; exit 1; }

# Sensitivity check from manifest.
if [[ "$SCOPE" == "shared" && -f "$MANIFEST" ]]; then
  sens=$(awk -v k="$KEY" '
    $0 ~ "^[[:space:]]*-[[:space:]]*key:[[:space:]]*"k"[[:space:]]*$" { found=1; next }
    found && /^[[:space:]]*-[[:space:]]*key:/ { exit }
    found && /^[[:space:]]*sensitivity:[[:space:]]*/ {
      sub(/^[[:space:]]*sensitivity:[[:space:]]*/, "")
      gsub(/[[:space:]"'"'"']/, "")
      print; exit
    }' "$MANIFEST")
  if [[ "$sens" == "high" && "$MANIFEST_SCOPE" != "shared" ]]; then
    # Block accidental --shared for high-sensitivity keys not declared shared in manifest.
    echo "BLOCKED: $KEY marked sensitivity:high → cannot store in --shared scope." >&2
    echo "Use per-project: bash scripts/set-secret.sh $KEY" >&2
    exit 4
  elif [[ "$sens" == "high" && "$MANIFEST_SCOPE" == "shared" ]]; then
    # Manifest explicitly declares scope:shared → allow, but warn.
    echo "⚠️  sensitivity:high token written to shared location (manifest declares scope:shared)." >&2
  fi
fi

# Backup existing target before overwrite.
if [[ -f "$TARGET" && -s "$TARGET" ]]; then
  ts=$(py -c "import datetime; print(datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))" 2>/dev/null || echo "$$")
  BACKUP="${TARGET}.backup-${ts}"
  cp "$TARGET" "$BACKUP" 2>/dev/null || true
fi

# Write new .env atomically (replace existing KEY line or append).
if [[ -f "$TARGET" ]] && grep -qE "^${KEY}=" "$TARGET"; then
  awk -v key="$KEY" -v val="$VALUE" '
    BEGIN { replaced=0 }
    $0 ~ "^" key "=" {
      if (val ~ /[[:space:]"'"'"'#]/) {
        printf "%s=\"%s\"\n", key, val
      } else {
        printf "%s=%s\n", key, val
      }
      replaced=1
      next
    }
    { print }
  ' "$TARGET" > "$TMP"
else
  [[ -f "$TARGET" ]] && cp "$TARGET" "$TMP" || : > "$TMP"
  if [[ "$VALUE" =~ [[:space:]\"\'#] ]]; then
    printf '%s="%s"\n' "$KEY" "$VALUE" >> "$TMP"
  else
    printf '%s=%s\n' "$KEY" "$VALUE" >> "$TMP"
  fi
fi

mv "$TMP" "$TARGET"
chmod 600 "$TARGET" 2>/dev/null || true

# Windows NTFS chmod 600 verify (once per session).
_chmod_marker="${TMPDIR:-/tmp}/.set-secret-chmod-warned-$$"
if [[ ! -f "$_chmod_marker" ]]; then
  _actual=$(stat -c '%a' "$TARGET" 2>/dev/null || stat -f '%Lp' "$TARGET" 2>/dev/null || echo "")
  if [[ -n "$_actual" && "$_actual" != "600" && "$_actual" != "400" ]]; then
    echo "" >&2
    echo "⚠️  chmod 600 requested but actual: $_actual (Windows NTFS — not enforced)" >&2
    echo "    On shared workstation: icacls \"$TARGET\" /inheritance:r /grant:r \"%USERNAME%:F\"" >&2
    : > "$_chmod_marker" 2>/dev/null || true
  fi
fi

# ---- Update manifest metadata (only for project scope; shared = bare KV) ----
NOW_ISO=$(py -c "import datetime; print(datetime.date.today().isoformat())" 2>/dev/null || echo "")

if [[ "$SCOPE" == "project" && -f "$MANIFEST" ]]; then
  if grep -qE "^[[:space:]]*-[[:space:]]*key:[[:space:]]*${KEY}[[:space:]]*$" "$MANIFEST"; then
    # Existing entry — update fields in place.
    py - "$MANIFEST" "$MANIFEST_TMP" "$KEY" "$OPT_SERVICE" "$OPT_URL" "$OPT_LOGIN" "$OPT_EXPIRES" "$NOW_ISO" <<'PYEOF'
import sys, re
src, dst, key, sn, url, login, expires, now_iso = sys.argv[1:]
with open(src, encoding='utf-8') as f:
    lines = f.readlines()

out = []
in_entry = False
fields_set = {'service_name': False, 'service_url': False, 'login': False,
              'expires_at': False, 'last_rotated': False}
key_re = re.compile(rf'^(\s*-\s*key:\s*){re.escape(key)}\s*$')
next_entry_re = re.compile(r'^\s*-\s*key:\s*')
field_re = re.compile(r'^(\s*)(service_name|service_url|login|expires_at|last_rotated|how_to_obtain_verified_at):\s*')

def fmt_field(name, val, indent='    '):
    if val == '':
        return f'{indent}{name}: ""\n'
    return f'{indent}{name}: "{val}"\n'

i = 0
while i < len(lines):
    line = lines[i]
    if not in_entry and key_re.match(line):
        in_entry = True
        out.append(line)
        i += 1
        continue
    if in_entry and next_entry_re.match(line):
        # End of our entry — insert any missing fields before this line
        if not fields_set['service_name'] and sn: out.append(fmt_field('service_name', sn))
        if not fields_set['service_url'] and url: out.append(fmt_field('service_url', url))
        if not fields_set['login'] and login: out.append(fmt_field('login', login))
        if not fields_set['expires_at'] and expires: out.append(fmt_field('expires_at', expires))
        if not fields_set['last_rotated']: out.append(fmt_field('last_rotated', now_iso))
        in_entry = False
        out.append(line)
        i += 1
        continue
    if in_entry:
        m = field_re.match(line)
        if m:
            field = m.group(2)
            # IMPORTANT: only REPLACE existing field if new value is non-empty.
            # Empty string from CLI means "no override" → preserve existing line.
            if field == 'service_name':
                if sn:
                    out.append(fmt_field('service_name', sn, m.group(1)))
                else:
                    out.append(line)  # preserve existing
                fields_set['service_name'] = True
                i += 1; continue
            if field == 'service_url':
                if url:
                    out.append(fmt_field('service_url', url, m.group(1)))
                else:
                    out.append(line)
                fields_set['service_url'] = True
                i += 1; continue
            if field == 'login':
                if login:
                    out.append(fmt_field('login', login, m.group(1)))
                else:
                    out.append(line)
                fields_set['login'] = True
                i += 1; continue
            if field == 'expires_at':
                if expires:
                    out.append(fmt_field('expires_at', expires, m.group(1)))
                else:
                    out.append(line)
                fields_set['expires_at'] = True
                i += 1; continue
            if field == 'last_rotated':
                # Always update last_rotated on every set-secret invocation
                out.append(fmt_field('last_rotated', now_iso, m.group(1)))
                fields_set['last_rotated'] = True
                i += 1; continue
    out.append(line)
    i += 1

# If we never hit next entry, flush at EOF.
if in_entry:
    if not fields_set['service_name'] and sn: out.append(fmt_field('service_name', sn))
    if not fields_set['service_url'] and url: out.append(fmt_field('service_url', url))
    if not fields_set['login'] and login: out.append(fmt_field('login', login))
    if not fields_set['expires_at'] and expires: out.append(fmt_field('expires_at', expires))
    if not fields_set['last_rotated']: out.append(fmt_field('last_rotated', now_iso))

with open(dst, 'w', encoding='utf-8') as f:
    f.writelines(out)
PYEOF
    if [[ -f "$MANIFEST_TMP" && -s "$MANIFEST_TMP" ]]; then
      mv "$MANIFEST_TMP" "$MANIFEST"
    fi
  else
    # New entry — append minimal stub at end of secrets: list.
    cat >> "$MANIFEST" <<EOF

  - key: $KEY
    purpose: "(added via set-secret.sh on $NOW_ISO)"
    service_name: "${OPT_SERVICE}"
    service_url: "${OPT_URL}"
    login: "${OPT_LOGIN}"
    required: false
    scope: per-project
    sensitivity: medium
    token_pattern: null
    last_rotated: "${NOW_ISO}"
$([[ -n "$OPT_EXPIRES" ]] && echo "    expires_at: \"${OPT_EXPIRES}\"")
    how_to_obtain: |
      (no instructions yet — edit $MANIFEST to add)
EOF
  fi
fi

# Release lock.
if [[ -d "$LOCK" ]]; then
  rmdir "$LOCK" 2>/dev/null || true
fi

# Disable trap cleanup (success path).
trap - INT TERM EXIT

# Cleanup old backups.
if [[ -d "$(dirname "$TARGET")" ]]; then
  py -c "
import os, time, glob
retention_secs = int('${BACKUP_RETENTION_HOURS}') * 3600
now = time.time()
for f in glob.glob('${TARGET}.backup-*'):
    try:
        if now - os.path.getmtime(f) > retention_secs:
            os.unlink(f)
    except Exception:
        pass
" 2>/dev/null || true
fi

# Summary.
echo "" >&2
echo "✅ Set $KEY in $TARGET" >&2
[[ -n "$OPT_SERVICE" ]] && echo "   Service: $OPT_SERVICE" >&2
[[ -n "$OPT_URL" ]]     && echo "   URL:     $OPT_URL" >&2
[[ -n "$OPT_LOGIN" ]]   && echo "   Login:   $OPT_LOGIN" >&2
[[ -n "$OPT_EXPIRES" ]] && echo "   Expires: $OPT_EXPIRES" >&2
[[ -n "$BACKUP" ]]      && echo "   Backup:  $BACKUP (auto-removed after ${BACKUP_RETENTION_HOURS}h)" >&2
echo "" >&2
echo "   Verify:  bash scripts/check-secret.sh $KEY" >&2
echo "   View:    bash scripts/secrets-show.sh $KEY" >&2
