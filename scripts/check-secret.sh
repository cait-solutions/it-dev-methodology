#!/usr/bin/env bash
#
# check-secret.sh — agent-safe boolean check: does a secret exist?
#
# Exit codes are the ONLY output:
#   0 — secret found in at least one source (per-project, shared, or env)
#   1 — secret NOT found
#   2 — usage error
#
# Usage:
#   bash scripts/check-secret.sh KEY
#
# This is what agents use BEFORE attempting an operation:
#   if ! bash scripts/check-secret.sh GITHUB_PAT; then
#     # show how_to_obtain to user, block
#   fi
#
# Bash 3.2 compatible.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/check-secret.sh KEY" >&2
  exit 2
fi

KEY="$1"
SHARED_ENV="${HOME}/.config/it-dev/secrets.env"

MANIFEST=".claude/secrets-manifest.yaml"
if [[ -f "$MANIFEST" ]]; then
  custom_shared=$(grep -E "^[[:space:]]*shared_path:" "$MANIFEST" 2>/dev/null \
                  | head -1 | sed 's/.*shared_path:[[:space:]]*//' \
                  | tr -d '"'"'"'' | tr -d '[:space:]' || true)
  if [[ -n "${custom_shared:-}" ]]; then
    SHARED_ENV="${custom_shared/#\~/$HOME}"
  fi
fi

# Check each source for a non-empty value. Existence of KEY= alone (empty value)
# counts as NOT set — empty is a placeholder, not a value.
_has_value() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  local line
  line=$(grep -E "^${KEY}=" "$file" 2>/dev/null | head -1 || true)
  [[ -z "$line" ]] && return 1
  local value
  value="${line#${KEY}=}"
  # Strip surrounding quotes
  value=$(echo "$value" | sed -E 's/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
  [[ -n "$value" ]]
}

if _has_value ".env"; then exit 0; fi
if _has_value "$SHARED_ENV"; then exit 0; fi
if [[ -n "${!KEY:-}" ]]; then exit 0; fi

exit 1
