#!/usr/bin/env bash
#
# validate-secrets.sh — compare .claude/secrets-manifest.yaml vs actual .env state.
#
# Checks:
#   1. Every `required: true` key from manifest is present in some source.
#   2. .env permissions are restrictive (600 or stricter on POSIX).
#   3. Reports "orphan" keys in .env that are NOT in manifest (warning only).
#   4. Detects values that look like placeholders ("changeme", "your_token_here", etc.)
#
# Output goes to stdout for human reading; secret VALUES are never printed.
# Only key names + status flags are emitted.
#
# Exit codes:
#   0 — all required present, no critical issues
#   1 — at least one required key missing
#   2 — manifest not found
#   3 — manifest parse error

set -euo pipefail

MANIFEST=".claude/secrets-manifest.yaml"
SHARED_ENV="${HOME}/.config/it-dev/secrets.env"

if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: $MANIFEST not found." >&2
  echo "       Run: bash scripts/new-project-init.sh   (creates manifest from template)" >&2
  exit 2
fi

# Resolve custom shared_path from manifest if set.
custom_shared=$(grep -E "^[[:space:]]*shared_path:" "$MANIFEST" 2>/dev/null \
                | head -1 | sed 's/.*shared_path:[[:space:]]*//' \
                | tr -d '"'"'"'' | tr -d '[:space:]' || true)
if [[ -n "${custom_shared:-}" ]]; then
  SHARED_ENV="${custom_shared/#\~/$HOME}"
fi

PLACEHOLDER_RE='^(changeme|your[-_]?token|paste[-_]?here|TODO|xxx+|placeholder|<.*>)$'

# Collect manifest keys + required flags.
# Format produced: "KEY required:true|false"
manifest_keys=$(awk '
  /^[[:space:]]*-[[:space:]]*key:/ {
    sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "")
    gsub(/[[:space:]"'"'"']/, "")
    cur=$0
    req="false"
    next
  }
  cur && /^[[:space:]]*required:[[:space:]]*true/ { req="true" }
  cur && /^[[:space:]]*-[[:space:]]*key:/ {
    print cur, req
    sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "")
    gsub(/[[:space:]"'"'"']/, "")
    cur=$0
    req="false"
    next
  }
  END { if (cur) print cur, req }
' "$MANIFEST")

if [[ -z "$manifest_keys" ]]; then
  echo "ERROR: no secrets declared in $MANIFEST" >&2
  exit 3
fi

# Helper: look up a key, return "found:<source>" or "missing".
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
  if [[ -f "$SHARED_ENV" ]] && grep -qE "^${key}=." "$SHARED_ENV"; then
    echo "found:shared"
    return
  fi
  if [[ -n "${!key:-}" ]]; then
    echo "found:env"
    return
  fi
  echo "missing"
}

echo "Secrets manifest validation:"
echo "  Manifest: $MANIFEST"
echo "  Per-project .env: $([[ -f .env ]] && echo present || echo absent)"
echo "  Shared $SHARED_ENV: $([[ -f $SHARED_ENV ]] && echo present || echo absent)"
echo ""

missing_required=0
total_required=0
declared_keys=""

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  key=$(echo "$line" | awk '{print $1}')
  req=$(echo "$line" | awk '{print $2}')
  declared_keys="$declared_keys $key"
  loc=$(_locate "$key")
  case "$loc" in
    found:*)
      printf "  ✅ %-30s (%s)\n" "$key" "${loc#found:}"
      ;;
    placeholder:*)
      printf "  ⚠️  %-30s (placeholder value in %s — not real)\n" "$key" "${loc#placeholder:}"
      [[ "$req" == "true" ]] && missing_required=$((missing_required+1))
      [[ "$req" == "true" ]] && total_required=$((total_required+1))
      ;;
    missing)
      if [[ "$req" == "true" ]]; then
        printf "  ❌ %-30s (REQUIRED, missing)\n" "$key"
        missing_required=$((missing_required+1))
        total_required=$((total_required+1))
      else
        printf "  ◯  %-30s (optional, not set)\n" "$key"
      fi
      ;;
  esac
done <<< "$manifest_keys"

# Orphan check — keys in .env not declared in manifest.
if [[ -f ".env" ]]; then
  echo ""
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    key="${line%%=*}"
    [[ "$key" == "$line" ]] && continue  # no = sign
    if ! echo "$declared_keys" | grep -qw "$key"; then
      printf "  ⚠️  %-30s (in .env but not declared in manifest — add it or remove)\n" "$key"
    fi
  done < ".env"
fi

# Permission check.
if [[ -f ".env" ]]; then
  if command -v stat >/dev/null 2>&1; then
    # Try GNU stat (-c), then BSD stat (-f). Silently skip on Windows Git Bash.
    perm=$(stat -c '%a' .env 2>/dev/null || stat -f '%Lp' .env 2>/dev/null || echo "")
    if [[ -n "$perm" && "$perm" != "600" && "$perm" != "400" ]]; then
      echo ""
      echo "  ⚠️  .env permissions: $perm (recommended: 600)"
      echo "      Fix: chmod 600 .env"
    fi
  fi
fi

echo ""
if [[ "$missing_required" -gt 0 ]]; then
  echo "❌ $missing_required of $total_required required secret(s) missing."
  echo "   For each missing key, run: bash scripts/set-secret.sh KEY <value>"
  echo "   Or view how_to_obtain in: $MANIFEST"
  exit 1
fi

echo "✅ All required secrets present."
exit 0
