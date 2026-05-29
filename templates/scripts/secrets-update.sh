#!/usr/bin/env bash
#
# secrets-update.sh — interactively update VALUE only (metadata untouched).
#
# Use this when rotating a secret. For metadata edits, use secrets-edit.sh.
#
# Usage:
#   bash scripts/secrets-update.sh KEY
#
# Flow:
#   1. Reads current metadata from manifest (KEY must exist)
#   2. Shows masked preview of current value (first 4 + last 4 chars + ...)
#   3. Prompts for new value via `read -s`
#   4. Re-paste confirmation
#   5. Atomic backup + write + manifest last_rotated update
#
# Exit codes:
#   0  success
#   1  KEY not found
#   2  usage error
#   5  user aborted

set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/secrets-update.sh KEY" >&2
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
  echo "       Use: bash scripts/set-secret.sh $KEY  (for new entries)" >&2
  exit 1
fi

if [[ ! -t 0 ]]; then
  echo "ERROR: secrets-update.sh requires interactive tty" >&2
  echo "       For scripting use: bash scripts/set-secret.sh $KEY value" >&2
  exit 2
fi

# Show masked current value (no full disclosure).
cur=""
if [[ -f ".env" ]]; then
  cur=$(grep -E "^${KEY}=" ".env" 2>/dev/null | head -1 | sed -E "s/^${KEY}=//" \
        | sed -E 's/^"(.*)"$/\1/' || true)
fi

echo ""
echo "🔄 Updating value for: $KEY"
if [[ -n "$cur" && "${#cur}" -ge 8 ]]; then
  masked="${cur:0:4}...${cur: -4}"
  echo "   Current (masked):  $masked  (length: ${#cur})"
elif [[ -n "$cur" ]]; then
  echo "   Current: (set, < 8 chars — not masking)"
else
  echo "   Current: (not set)"
fi
echo ""
echo "   Metadata (service/url/login/expires) will be UNCHANGED."
echo "   To edit metadata: bash scripts/secrets-edit.sh $KEY"
echo ""

printf 'New value (hidden): '
read -rs new_val
echo ""

if [[ -z "$new_val" ]]; then
  echo "ERROR: empty value, aborting" >&2
  exit 5
fi

printf 'Re-paste new value: '
read -rs confirm
echo ""

if [[ "$new_val" != "$confirm" ]]; then
  echo "ERROR: values mismatch, aborting (nothing changed)" >&2
  exit 5
fi

# Delegate to set-secret.sh inline mode (will update last_rotated automatically).
echo ""
echo "Applying update..."
bash "$(dirname "$0")/set-secret.sh" "$KEY" "$new_val" --no-confirm
