#!/usr/bin/env bash
#
# git-credential-from-env.sh — git credential helper with multi-host routing.
#
# Reads .claude/secrets-manifest.yaml entries, matches git's request host
# against each entry's service_url, returns the matched entry's value from
# the canonical store (.env / shared / process env).
#
# v4.41.0+ schema v2: per-entry service_url enables multi-host routing.
# Routing is by HOST, never by key name — user picks any key name (closes G-077).
# Match order: (1) service_url host match → (2) service-field host-token match →
# (3) literal GITHUB_PAT for github.com (v1 backward-compat) → (4) actionable stderr hint.
#
# Setup (one-time, per repo OR globally):
#
#   git config credential."https://github.com".helper \
#     "!bash $(pwd)/scripts/git-credential-from-env.sh"
#
#   git config credential."https://code.nexchance.de".helper \
#     "!bash $(pwd)/scripts/git-credential-from-env.sh"
#
# Protocol (git credential helper spec):
#   git invokes us with one of: get | store | erase
#   stdin: `key=value\n` lines, blank line terminates
#   for `get`, print `username=...\npassword=...\n\n` to stdout

set -euo pipefail

ACTION="${1:-}"

# Only handle `get`. `store`/`erase` no-ops (we don't cache).
if [[ "$ACTION" != "get" ]]; then
  exit 0
fi

# Read git's request into associative arrays (bash 3.2 — use parallel arrays).
REQ_KEYS=()
REQ_VALS=()
while IFS= read -r line; do
  # Strip CR (Windows line endings)
  line="${line%$'\r'}"
  [[ -z "$line" ]] && break
  k="${line%%=*}"
  v="${line#*=}"
  REQ_KEYS+=("$k")
  REQ_VALS+=("$v")
done

# Extract host from request.
REQ_HOST=""
for i in "${!REQ_KEYS[@]}"; do
  if [[ "${REQ_KEYS[$i]}" == "host" ]]; then
    REQ_HOST="${REQ_VALS[$i]}"
    break
  fi
done

# Resolve manifest + shared path.
MANIFEST=".claude/secrets-manifest.yaml"
SHARED_ENV="${HOME}/.config/it-dev/secrets.env"
if [[ -f "$MANIFEST" ]]; then
  custom=$(grep -E "^[[:space:]]*shared_path:" "$MANIFEST" 2>/dev/null \
           | head -1 | sed 's/.*shared_path:[[:space:]]*//' \
           | tr -d '"'"'"'' | tr -d '[:space:]' || true)
  [[ -n "${custom:-}" ]] && SHARED_ENV="${custom/#\~/$HOME}"
fi

# Lookup value for a given key from priority chain.
# Echoes value if found, returns 1 if not.
_lookup_value() {
  local key="$1"
  local value=""

  if [[ -f ".env" ]]; then
    value=$(grep -E "^${key}=" ".env" 2>/dev/null | head -1 \
            | sed -E "s/^${key}=//" \
            | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' || true)
    [[ -n "$value" ]] && { echo "$value"; return 0; }
  fi

  if [[ -f "$SHARED_ENV" ]]; then
    value=$(grep -E "^${key}=" "$SHARED_ENV" 2>/dev/null | head -1 \
            | sed -E "s/^${key}=//" \
            | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/' || true)
    [[ -n "$value" ]] && { echo "$value"; return 0; }
  fi

  if [[ -n "${!key:-}" ]]; then
    echo "${!key}"
    return 0
  fi

  return 1
}

# Extract hostname from a URL string. "https://github.com" → "github.com";
# "https://code.nexchance.de:443/path" → "code.nexchance.de".
_hostname_from_url() {
  local url="$1"
  # Strip scheme
  url="${url#http://}"
  url="${url#https://}"
  url="${url#ssh://}"
  url="${url#git://}"
  # Take part before first / : ?
  url="${url%%/*}"
  url="${url%%:*}"
  url="${url%%\?*}"
  echo "$url"
}

# Walk through manifest entries, find first with matching hostname.
# Outputs: matched KEY, and login (if any) to MATCHED_KEY / MATCHED_LOGIN vars.
MATCHED_KEY=""
MATCHED_LOGIN=""
MULTI_MATCH=()

if [[ -f "$MANIFEST" && -n "$REQ_HOST" ]]; then
  # Parse manifest entries into key+service_url+login tuples via awk.
  # Per-entry block: starts with `  - key:`, ends at next `  - key:` or EOF.
  while IFS=$'\t' read -r m_key m_url m_login; do
    [[ -z "$m_key" ]] && continue
    [[ -z "$m_url" ]] && continue
    m_host=$(_hostname_from_url "$m_url")
    if [[ "$m_host" == "$REQ_HOST" ]]; then
      if [[ -z "$MATCHED_KEY" ]]; then
        MATCHED_KEY="$m_key"
        MATCHED_LOGIN="$m_login"
      fi
      MULTI_MATCH+=("$m_key")
    fi
  done < <(awk '
    /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      if (cur_key) print cur_key "\t" cur_url "\t" cur_login
      cur_key=$0; sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", cur_key)
      gsub(/[[:space:]"'"'"']/, "", cur_key)
      cur_url=""; cur_login=""
      next
    }
    cur_key && /^[[:space:]]*service_url:[[:space:]]*/ {
      cur_url=$0; sub(/^[[:space:]]*service_url:[[:space:]]*/, "", cur_url)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_url)
      gsub(/[[:space:]]+$/, "", cur_url)
    }
    cur_key && /^[[:space:]]*login:[[:space:]]*/ {
      cur_login=$0; sub(/^[[:space:]]*login:[[:space:]]*/, "", cur_login)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_login)
      gsub(/[[:space:]]+$/, "", cur_login)
    }
    END { if (cur_key) print cur_key "\t" cur_url "\t" cur_login }
  ' "$MANIFEST")
fi

# Warn on multi-match (stderr, non-fatal — git ignores helper stderr).
if [[ ${#MULTI_MATCH[@]} -gt 1 ]]; then
  echo "WARN: multiple manifest entries match host '$REQ_HOST': ${MULTI_MATCH[*]}; using ${MATCHED_KEY}" >&2
  echo "WARN: if wrong, add account-specific service_url paths or use distinct hostnames" >&2
fi

# Fallback chain (closes G-077: hardcoded GITHUB_PAT vs user-defined key names).
# Routing is primarily by service_url (above). If no service_url match, try —
# in order — so user-chosen key names work without renaming to GITHUB_PAT:
if [[ -z "$MATCHED_KEY" && -f "$MANIFEST" && -n "$REQ_HOST" ]]; then
  # (a) manifest entry whose `service` field names this host (e.g. service: GitHub
  #     for github.com) — host token match, case-insensitive, no service_url needed.
  host_token="${REQ_HOST%%.*}"   # github.com → github
  while IFS=$'\t' read -r m_key m_svc m_login; do
    [[ -z "$m_key" ]] && continue
    # lowercase compare (bash 3.2 — use tr, not ${,,})
    svc_lc=$(printf '%s' "$m_svc" | tr '[:upper:]' '[:lower:]')
    tok_lc=$(printf '%s' "$host_token" | tr '[:upper:]' '[:lower:]')
    if [[ -n "$m_svc" && "$svc_lc" == *"$tok_lc"* ]]; then
      MATCHED_KEY="$m_key"; MATCHED_LOGIN="$m_login"; break
    fi
  done < <(awk '
    /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      if (cur_key) print cur_key "\t" cur_svc "\t" cur_login
      cur_key=$0; sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", cur_key)
      gsub(/[[:space:]"'"'"']/, "", cur_key); cur_svc=""; cur_login=""; next
    }
    cur_key && /^[[:space:]]*service:[[:space:]]*/ {
      cur_svc=$0; sub(/^[[:space:]]*service:[[:space:]]*/, "", cur_svc)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_svc); gsub(/[[:space:]]+$/, "", cur_svc)
    }
    cur_key && /^[[:space:]]*login:[[:space:]]*/ {
      cur_login=$0; sub(/^[[:space:]]*login:[[:space:]]*/, "", cur_login)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_login); gsub(/[[:space:]]+$/, "", cur_login)
    }
    END { if (cur_key) print cur_key "\t" cur_svc "\t" cur_login }
  ' "$MANIFEST")
fi

# (b) v1 backward-compat — literal GITHUB_PAT for github.com (only if still no match).
if [[ -z "$MATCHED_KEY" && "$REQ_HOST" == "github.com" ]]; then
  if value=$(_lookup_value "GITHUB_PAT" 2>/dev/null); then
    MATCHED_KEY="GITHUB_PAT"
    MATCHED_LOGIN="oauth2"
  fi
fi

# Still no match? Emit actionable hint to stderr (git ignores it, но видно в логах/агенту):
# объясняет ЧТО сделать вместо молчаливого падения → агент не лезет за токеном вручную.
if [[ -z "$MATCHED_KEY" && -n "$REQ_HOST" ]]; then
  echo "git-credential-from-env: нет ключа для '$REQ_HOST' в $MANIFEST." >&2
  echo "  Добавь любому своему ключу поле service_url: https://$REQ_HOST (имя ключа любое — routing по хосту, НЕ по имени)." >&2
fi

# No match? Exit 0 silently — git will try next helper (gh CLI, manager, etc).
if [[ -z "$MATCHED_KEY" ]]; then
  exit 0
fi

# Resolve value.
if ! value=$(_lookup_value "$MATCHED_KEY"); then
  # Key declared in manifest but not set in .env — silent exit.
  exit 0
fi

# Default login to "oauth2" if blank (GitHub PAT convention).
[[ -z "$MATCHED_LOGIN" ]] && MATCHED_LOGIN="oauth2"

# Return to git.
printf 'username=%s\n' "$MATCHED_LOGIN"
printf 'password=%s\n' "$value"
printf '\n'
