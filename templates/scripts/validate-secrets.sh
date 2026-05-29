#!/usr/bin/env bash
#
# validate-secrets.sh — compare manifest vs actual .env state + hygiene warns.
#
# v4.41.0+ schema v2: also displays metadata + warns on stale rotation,
# upcoming expiry, missing v2-recommended fields.
#
# Checks:
#   1. Every `required: true` key present somewhere in priority chain.
#   2. .env permissions warning (POSIX 600 / 400 expected).
#   3. Orphan keys in .env not declared in manifest (warning).
#   4. Placeholder values ("changeme", "your_token_here", etc.)
#   5. [v2] last_rotated older than rotation_warn_days → warn.
#   6. [v2] expires_at within expiry_warn_days → warn.
#   7. [v2] how_to_obtain_verified_at older than how_to_obtain_warn_days → warn.
#   8. [v2] service_url missing for v2 manifests → warn (rec'd).
#
# Output: human-readable; NO secret values printed.
#
# Exit codes:
#   0  all required present, no critical issues
#   1  ≥1 required key missing
#   2  manifest not found
#   3  manifest parse error

set -uo pipefail

MANIFEST=".claude/secrets-manifest.yaml"
SHARED_ENV="${HOME}/.config/it-dev/secrets.env"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found." >&2
  echo "       Run: bash scripts/new-project-init.sh" >&2
  exit 2
fi

# Resolve custom shared_path + thresholds.
_cfg_get() {
  local field="$1" default="$2"
  local v
  v=$(grep -E "^[[:space:]]*${field}:" "$MANIFEST" 2>/dev/null \
      | head -1 | sed "s/.*${field}:[[:space:]]*//" \
      | tr -d '"'"'"'' | tr -d '[:space:]' || true)
  echo "${v:-$default}"
}

custom_shared=$(_cfg_get "shared_path" "")
[[ -n "$custom_shared" ]] && SHARED_ENV="${custom_shared/#\~/$HOME}"

ROTATION_WARN_DAYS=$(_cfg_get "rotation_warn_days" "90")
EXPIRY_WARN_DAYS=$(_cfg_get "expiry_warn_days" "7")
HOW_TO_OBTAIN_WARN_DAYS=$(_cfg_get "how_to_obtain_warn_days" "180")
STRICT_SCHEMA=$(_cfg_get "strict_schema" "false")

# Override from CLAUDE.local.md ## Secrets if exists (per-developer config).
if [[ -f "CLAUDE.local.md" ]]; then
  _local_get() {
    local field="$1" default="$2"
    local v
    v=$(awk '/^##[[:space:]]+Secrets/{f=1; next} /^## /{f=0} f' CLAUDE.local.md 2>/dev/null \
        | grep -E "^[[:space:]]*${field}:" | head -1 \
        | sed "s/.*${field}:[[:space:]]*//" | tr -d '"'"'"'' | tr -d '[:space:]' || true)
    echo "${v:-$default}"
  }
  ROTATION_WARN_DAYS=$(_local_get "rotation_warn_days" "$ROTATION_WARN_DAYS")
  EXPIRY_WARN_DAYS=$(_local_get "expiry_warn_days" "$EXPIRY_WARN_DAYS")
  HOW_TO_OBTAIN_WARN_DAYS=$(_local_get "how_to_obtain_warn_days" "$HOW_TO_OBTAIN_WARN_DAYS")
fi

# Detect manifest version.
MANIFEST_VER=$(grep -E "^manifest_version:" "$MANIFEST" | head -1 \
               | sed 's/.*manifest_version:[[:space:]]*//' | tr -d '[:space:]' || true)
[[ -z "$MANIFEST_VER" ]] && MANIFEST_VER="1"

PLACEHOLDER_RE='^(changeme|your[-_]?token|paste[-_]?here|TODO|xxx+|placeholder|<.*>)$'

# Parse full entries.
_parse_manifest() {
  awk '
    /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      if (cur_key) print cur_key "\t" cur_req "\t" cur_sn "\t" cur_url "\t" cur_rot "\t" cur_exp "\t" cur_ver
      cur_key=$0; sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", cur_key)
      gsub(/[[:space:]"'"'"']/, "", cur_key)
      cur_req="false"; cur_sn=""; cur_url=""; cur_rot=""; cur_exp=""; cur_ver=""
      next
    }
    cur_key && /^[[:space:]]*required:[[:space:]]*true/ { cur_req="true" }
    cur_key && /^[[:space:]]*service_name:[[:space:]]*/ {
      cur_sn=$0; sub(/^[[:space:]]*service_name:[[:space:]]*/, "", cur_sn)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_sn); gsub(/[[:space:]]+$/, "", cur_sn)
    }
    cur_key && /^[[:space:]]*service_url:[[:space:]]*/ {
      cur_url=$0; sub(/^[[:space:]]*service_url:[[:space:]]*/, "", cur_url)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_url); gsub(/[[:space:]]+$/, "", cur_url)
    }
    cur_key && /^[[:space:]]*last_rotated:[[:space:]]*/ {
      cur_rot=$0; sub(/^[[:space:]]*last_rotated:[[:space:]]*/, "", cur_rot)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_rot); gsub(/[[:space:]]+$/, "", cur_rot)
    }
    cur_key && /^[[:space:]]*expires_at:[[:space:]]*/ {
      cur_exp=$0; sub(/^[[:space:]]*expires_at:[[:space:]]*/, "", cur_exp)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_exp); gsub(/[[:space:]]+$/, "", cur_exp)
    }
    cur_key && /^[[:space:]]*how_to_obtain_verified_at:[[:space:]]*/ {
      cur_ver=$0; sub(/^[[:space:]]*how_to_obtain_verified_at:[[:space:]]*/, "", cur_ver)
      gsub(/^["'"'"']|["'"'"']$/, "", cur_ver); gsub(/[[:space:]]+$/, "", cur_ver)
    }
    END { if (cur_key) print cur_key "\t" cur_req "\t" cur_sn "\t" cur_url "\t" cur_rot "\t" cur_exp "\t" cur_ver }
  ' "$MANIFEST"
}

# Locate value status without disclosure.
_locate() {
  local key="$1"
  if [[ -f ".env" ]] && grep -qE "^${key}=." ".env"; then
    local val
    val=$(grep -E "^${key}=" ".env" | head -1 | sed -E "s/^${key}=//; s/^\"(.*)\"$/\1/")
    if echo "$val" | grep -Eqi "$PLACEHOLDER_RE"; then
      echo "placeholder:.env"
    else
      echo "found:.env"
    fi
    return
  fi
  [[ -f "$SHARED_ENV" ]] && grep -qE "^${key}=." "$SHARED_ENV" && { echo "found:shared"; return; }
  [[ -n "${!key:-}" ]] && { echo "found:env"; return; }
  echo "missing"
}

# Days-since helper using python (portable, no GNU date dependency).
_days_since() {
  local date_str="$1"
  py -c "
import sys, datetime
try:
    d = datetime.date.fromisoformat('${date_str}'.split('T')[0])
    delta = (datetime.date.today() - d).days
    print(delta)
except Exception:
    print(-1)
" 2>/dev/null || echo "-1"
}

_days_until() {
  local date_str="$1"
  py -c "
import sys, datetime
try:
    d = datetime.date.fromisoformat('${date_str}'.split('T')[0])
    delta = (d - datetime.date.today()).days
    print(delta)
except Exception:
    print(99999)
" 2>/dev/null || echo "99999"
}

echo "Secrets manifest validation (schema v${MANIFEST_VER}):"
echo "  Manifest:        $MANIFEST"
echo "  Per-project .env: $([[ -f .env ]] && echo present || echo absent)"
echo "  Shared $SHARED_ENV: $([[ -f $SHARED_ENV ]] && echo present || echo absent)"
echo ""

missing_required=0
total_required=0
declared_keys=""
warns=0

while IFS=$'\t' read -r key req sn url rot exp ver; do
  [[ -z "$key" ]] && continue
  declared_keys="$declared_keys $key"
  loc=$(_locate "$key")

  case "$loc" in
    found:*)
      printf "  ✅ %-25s (%s)" "$key" "${loc#found:}"
      [[ -n "$sn" ]] && printf "  →  %s" "$sn"
      echo ""
      ;;
    placeholder:*)
      printf "  ⚠️  %-25s (placeholder value in %s — not real)\n" "$key" "${loc#placeholder:}"
      [[ "$req" == "true" ]] && missing_required=$((missing_required+1)) && total_required=$((total_required+1))
      warns=$((warns+1))
      ;;
    missing)
      if [[ "$req" == "true" ]]; then
        printf "  ❌ %-25s (REQUIRED, missing)" "$key"
        [[ -n "$sn" ]] && printf "  →  %s" "$sn"
        echo ""
        missing_required=$((missing_required+1))
        total_required=$((total_required+1))
      else
        printf "  ◯  %-25s (optional, not set)\n" "$key"
      fi
      ;;
  esac

  # v2 hygiene checks (only for found entries with v2 fields).
  if [[ "$loc" =~ ^found ]]; then
    if [[ -n "$rot" ]]; then
      days=$(_days_since "$rot")
      if [[ "$days" -gt "$ROTATION_WARN_DAYS" ]]; then
        printf "       ⚠️  rotation: last_rotated %s (%d days ago, > %d)\n" "$rot" "$days" "$ROTATION_WARN_DAYS"
        warns=$((warns+1))
      fi
    fi
    if [[ -n "$exp" ]]; then
      days=$(_days_until "$exp")
      if [[ "$days" -lt 0 ]]; then
        printf "       🚨 EXPIRED: %s (%d days ago)\n" "$exp" "$((0 - days))"
        warns=$((warns+1))
      elif [[ "$days" -le "$EXPIRY_WARN_DAYS" ]]; then
        printf "       ⚠️  expires soon: %s (in %d days, threshold %d)\n" "$exp" "$days" "$EXPIRY_WARN_DAYS"
        warns=$((warns+1))
      fi
    fi
    if [[ -n "$ver" ]]; then
      days=$(_days_since "$ver")
      if [[ "$days" -gt "$HOW_TO_OBTAIN_WARN_DAYS" ]]; then
        printf "       ⚠️  how_to_obtain unchecked %d days (re-verify with /secrets --verify-link %s)\n" "$days" "$key"
        warns=$((warns+1))
      fi
    fi
    # Missing v2 fields warn (for v2 manifests).
    if [[ "$MANIFEST_VER" == "2" && -z "$url" ]]; then
      printf "       ⚠️  service_url missing (v2-recommended)\n"
      warns=$((warns+1))
    fi
  fi
done < <(_parse_manifest)

# Orphan keys in .env not declared.
if [[ -f ".env" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    key="${line%%=*}"
    [[ "$key" == "$line" ]] && continue
    if ! echo "$declared_keys" | grep -qw "$key"; then
      printf "  ⚠️  %-25s (in .env but not declared in manifest — add it or remove)\n" "$key"
      warns=$((warns+1))
    fi
  done < ".env"
fi

# Permission check.
if [[ -f ".env" ]] && command -v stat >/dev/null 2>&1; then
  perm=$(stat -c '%a' .env 2>/dev/null || stat -f '%Lp' .env 2>/dev/null || echo "")
  if [[ -n "$perm" && "$perm" != "600" && "$perm" != "400" ]]; then
    echo ""
    echo "  ⚠️  .env permissions: $perm (recommended: 600)"
    echo "      Fix: chmod 600 .env  (Windows NTFS: see CLAUDE.md § Secrets Scope limits)"
    warns=$((warns+1))
  fi
fi

echo ""
if [[ "$missing_required" -gt 0 ]]; then
  echo "❌ $missing_required of $total_required required secret(s) missing."
  echo "   For each missing key, run: bash scripts/set-secret.sh KEY  (interactive)"
  echo "   View how_to_obtain in: $MANIFEST"
  exit 1
fi

if [[ "$warns" -gt 0 ]]; then
  echo "✅ All required secrets present. ($warns warning(s) above — review)"
else
  echo "✅ All required secrets present."
fi
exit 0
