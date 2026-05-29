#!/usr/bin/env bash
#
# secrets-show.sh — display secrets manifest metadata WITHOUT values.
#
# Usage:
#   bash scripts/secrets-show.sh                # tabular list
#   bash scripts/secrets-show.sh KEY            # detailed view of one entry
#
# Output NEVER includes secret values.
#
# Exit codes:
#   0  success
#   1  KEY not found in manifest
#   2  manifest not found

set -uo pipefail

MANIFEST=".claude/secrets-manifest.yaml"
SHARED_ENV="${HOME}/.config/it-dev/secrets.env"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found." >&2
  echo "       Run: bash scripts/new-project-init.sh   (creates manifest)" >&2
  exit 2
fi

custom=$(grep -E "^[[:space:]]*shared_path:" "$MANIFEST" 2>/dev/null \
         | head -1 | sed 's/.*shared_path:[[:space:]]*//' \
         | tr -d '"'"'"'' | tr -d '[:space:]' || true)
[[ -n "${custom:-}" ]] && SHARED_ENV="${custom/#\~/$HOME}"

_parse_manifest() {
  awk '
    /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      if (cur_key) print cur_key "\t" cur_sn "\t" cur_url "\t" cur_login "\t" cur_req "\t" cur_rot "\t" cur_exp
      cur_key=$0; sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", cur_key)
      gsub(/[[:space:]"'"'"']/, "", cur_key)
      cur_sn=""; cur_url=""; cur_login=""; cur_req="false"; cur_rot=""; cur_exp=""
      next
    }
    cur_key && /^[[:space:]]*service_name:[[:space:]]*/ {
      cur_sn=$0; sub(/^[[:space:]]*service_name:[[:space:]]*/, "", cur_sn)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_sn); gsub(/[[:space:]]+$/, "", cur_sn)
    }
    cur_key && /^[[:space:]]*service_url:[[:space:]]*/ {
      cur_url=$0; sub(/^[[:space:]]*service_url:[[:space:]]*/, "", cur_url)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_url); gsub(/[[:space:]]+$/, "", cur_url)
    }
    cur_key && /^[[:space:]]*login:[[:space:]]*/ {
      cur_login=$0; sub(/^[[:space:]]*login:[[:space:]]*/, "", cur_login)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_login); gsub(/[[:space:]]+$/, "", cur_login)
    }
    cur_key && /^[[:space:]]*required:[[:space:]]*true/ { cur_req="true" }
    cur_key && /^[[:space:]]*last_rotated:[[:space:]]*/ {
      cur_rot=$0; sub(/^[[:space:]]*last_rotated:[[:space:]]*/, "", cur_rot)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_rot); gsub(/[[:space:]]+$/, "", cur_rot)
    }
    cur_key && /^[[:space:]]*expires_at:[[:space:]]*/ {
      cur_exp=$0; sub(/^[[:space:]]*expires_at:[[:space:]]*/, "", cur_exp)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_exp); gsub(/[[:space:]]+$/, "", cur_exp)
    }
    END { if (cur_key) print cur_key "\t" cur_sn "\t" cur_url "\t" cur_login "\t" cur_req "\t" cur_rot "\t" cur_exp }
  ' "$MANIFEST"
}

_value_status() {
  local key="$1"
  if [[ -f ".env" ]] && grep -qE "^${key}=." ".env"; then
    echo "set (.env)"
  elif [[ -f "$SHARED_ENV" ]] && grep -qE "^${key}=." "$SHARED_ENV"; then
    echo "set (shared)"
  elif [[ -n "${!key:-}" ]]; then
    echo "set (env var)"
  else
    echo "MISSING"
  fi
}

if [[ $# -ge 1 ]]; then
  KEY="$1"
  found=false
  while IFS=$'\t' read -r m_key m_sn m_url m_login m_req m_rot m_exp; do
    if [[ "$m_key" == "$KEY" ]]; then
      found=true
      echo "Secret: $m_key"
      echo "  Service name:  ${m_sn:-(not set)}"
      echo "  Service URL:   ${m_url:-(not set)}"
      echo "  Login:         ${m_login:-(not set)}"
      echo "  Required:      $m_req"
      echo "  Last rotated:  ${m_rot:-never}"
      echo "  Expires at:    ${m_exp:-(no expiry tracked)}"
      echo "  Value status:  $(_value_status "$m_key")"
      echo ""
      echo "  (Metadata only — secret value never shown.)"
      echo "  Edit metadata: bash scripts/secrets-edit.sh $m_key"
      echo "  Update value:  bash scripts/secrets-update.sh $m_key"
      break
    fi
  done < <(_parse_manifest)
  if ! $found; then
    echo "ERROR: $KEY not found in $MANIFEST" >&2
    echo "       Available keys:" >&2
    _parse_manifest | cut -f1 | sed 's/^/         /' >&2
    exit 1
  fi
  exit 0
fi

echo "Secrets manifest: $MANIFEST"
echo ""
printf "%-22s  %-26s  %-26s  %-16s  %s\n" "KEY" "SERVICE" "URL" "LOGIN" "STATUS"
printf "%-22s  %-26s  %-26s  %-16s  %s\n" \
  "----------------------" "--------------------------" \
  "--------------------------" "----------------" "------------"

while IFS=$'\t' read -r m_key m_sn m_url m_login m_req m_rot m_exp; do
  [[ -z "$m_key" ]] && continue
  printf "%-22s  %-26s  %-26s  %-16s  %s\n" \
    "$m_key" "${m_sn:0:26}" "${m_url:0:26}" "${m_login:0:16}" \
    "$(_value_status "$m_key")"
done < <(_parse_manifest)

echo ""
echo "Detail:  bash scripts/secrets-show.sh KEY"
echo "Add:     bash scripts/set-secret.sh KEY        (interactive)"
echo "Audit:   bash scripts/validate-secrets.sh"
