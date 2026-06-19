#!/usr/bin/env bash
#
# check-gh-account.sh — pre-push helper: переключает gh аккаунт перед push в consumer repo.
#
# WHY (P-012, domain:git-push кластер v6.9.0):
#   /push-consumers Шаг 5 Режим B раньше угадывал нужный аккаунт из remote URL owner.
#   Это ненадёжно: URL может быть неверным → owner неверный → push под wrong account.
#   Этот скрипт читает EXPLICIT gh_account из CLAUDE.local.md whitelist — не URL-derived.
#   Приоритет: whitelist gh_account > URL-derived fallback (backward compat).
#
# NOTE: whitelist gh_account приоритетнее secrets-manifest.yaml — whitelist специфичен
#   к этому репо и задан владельцем явно.
#
# Usage: bash scripts/check-gh-account.sh <consumer-abs-path> [claude-local-path]
#   consumer-abs-path — абсолютный путь к consumer repo
#   claude-local-path — путь к CLAUDE.local.md (default: <script-dir>/../CLAUDE.local.md)
#
# Exit 0 = готов к push (аккаунт проверен и при необходимости переключён).
# Exit 1 = push невозможен (нужный аккаунт не залогинен, нет gh CLI, и т.п.).
#
# Bash 3.2+ compatible.

set -uo pipefail

CONSUMER_PATH="${1:-}"
if [ -z "$CONSUMER_PATH" ]; then
  echo "Usage: $0 <consumer-abs-path> [claude-local-path]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${2:-$SCRIPT_DIR/../CLAUDE.local.md}"

# _get_gh_account: find gh_account for a given path in auto_commit_consumers whitelist.
# Outputs: the gh_account value, or empty string if not found/not set.
_get_gh_account_from_whitelist() {
  local target_path="$1"
  local config="$2"
  [ -f "$config" ] || { echo ""; return; }

  awk -v target="$target_path" '
    /^```yaml/ && !in_block { in_block=1; next }
    /^```/ && in_block       { in_block=0; in_consumers=0; next }
    !in_block                { next }
    /auto_commit_consumers:/ { in_consumers=1; next }
    !in_consumers            { next }
    /^  - path:/ {
      entry_path = $0
      sub(/^[^:]*:[[:space:]]*/, "", entry_path)
      sub(/[[:space:]]*#.*$/,     "", entry_path)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", entry_path)
      entry_gh = ""
      in_target = (entry_path == target)
    }
    /^[[:space:]]+gh_account:/ && in_target {
      gh = $0
      sub(/^[^:]*:[[:space:]]*/, "", gh)
      sub(/[[:space:]]*#.*$/,     "", gh)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", gh)
      entry_gh = gh
    }
    # When a new entry starts, output the previous if it was the target
    /^  - path:/ && in_target && entry_gh != "" { print entry_gh; exit }
    END { if (in_target && entry_gh != "") print entry_gh }
  ' "$config"
}

# Normalize consumer path for comparison with whitelist entries (relative to methodology dir)
METHODOLOGY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Compute relative path from methodology dir to consumer path
# (whitelist stores paths like ../it-dev-methodology-documentation)
REL_PATH=""
if [ -d "$CONSUMER_PATH" ]; then
  ABS_CONSUMER="$(cd "$CONSUMER_PATH" && pwd)"
  # Try to compute a relative path by removing methodology dir prefix
  # Works if consumer is a sibling: METHODOLOGY_DIR/../consumer → ../consumer
  PARENT="$(cd "$METHODOLOGY_DIR/.." && pwd)"
  if [ "${ABS_CONSUMER#$PARENT/}" != "$ABS_CONSUMER" ]; then
    SIBLING="${ABS_CONSUMER#$PARENT/}"
    REL_PATH="../$SIBLING"
  fi
fi

# Look up gh_account in whitelist
GH_ACCOUNT=""
if [ -n "$REL_PATH" ]; then
  GH_ACCOUNT="$(_get_gh_account_from_whitelist "$REL_PATH" "$CONFIG")"
fi

# Fallback: if not in whitelist or no gh_account, derive from remote URL owner
if [ -z "$GH_ACCOUNT" ]; then
  REMOTE_URL="$(git -C "$CONSUMER_PATH" remote get-url origin 2>/dev/null || true)"
  case "$REMOTE_URL" in
    https://github.com/*)
      OWNER="${REMOTE_URL#https://github.com/}"
      OWNER="${OWNER%%/*}"
      OWNER="${OWNER%.git}"
      GH_ACCOUNT="$OWNER"
      echo "  🔍 check-gh-account: gh_account не найден в whitelist — fallback к URL owner: $GH_ACCOUNT" >&2
      ;;
    *)
      # Not github.com — no gh CLI action needed
      exit 0
      ;;
  esac
fi

# If gh CLI is not available — warn and skip (don't block push)
if ! command -v gh >/dev/null 2>&1; then
  echo "  🟡 check-gh-account: gh CLI не найден — switch пропущен." >&2
  exit 0
fi

# Check active account
ACTIVE="$(gh api user -q .login 2>/dev/null || echo "")"

if [ "$ACTIVE" = "$GH_ACCOUNT" ]; then
  echo "  ✅ gh account: $GH_ACCOUNT (уже активен)"
  exit 0
fi

# Try to switch
if gh auth status 2>/dev/null | grep -q "account ${GH_ACCOUNT} "; then
  if gh auth switch --user "$GH_ACCOUNT" >/dev/null 2>&1; then
    echo "  🔄 gh account: ${ACTIVE:-none} → $GH_ACCOUNT"
    exit 0
  else
    echo "  ❌ gh auth switch --user $GH_ACCOUNT не удался." >&2
    exit 1
  fi
else
  echo "  ❌ gh: аккаунт '$GH_ACCOUNT' не залогинен (активен: ${ACTIVE:-none})." >&2
  echo "     Залогинься: gh auth login --user $GH_ACCOUNT" >&2
  exit 1
fi
