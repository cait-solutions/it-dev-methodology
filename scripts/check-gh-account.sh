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
      in_target = (entry_path == target)
      next
    }
    # Emit IMMEDIATELY on the gh_account line while in the target entry.
    # (Was a deferred print on the NEXT path line — dead code: the path rule reset
    # in_target before the deferred print ran, so only the LAST entry ever resolved.
    # Closes the fleet-wide whitelist false-negative.)
    /^[[:space:]]+gh_account:/ && in_target {
      gh = $0
      sub(/^[^:]*:[[:space:]]*/, "", gh)
      sub(/[[:space:]]*#.*$/,     "", gh)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", gh)
      print gh
      exit
    }
  ' "$config"
}

# List all auto_commit_consumers '- path:' values (raw, as written in whitelist).
_list_whitelist_paths() {
  local config="$1"
  [ -f "$config" ] || return
  awk '
    /^```yaml/ && !in_block { in_block=1; next }
    /^```/ && in_block       { in_block=0; in_consumers=0; next }
    !in_block                { next }
    /auto_commit_consumers:/ { in_consumers=1; next }
    !in_consumers            { next }
    /^  - path:/ {
      ep=$0; sub(/^[^:]*:[[:space:]]*/,"",ep); sub(/[[:space:]]*#.*$/,"",ep)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",ep)
      print ep
    }
  ' "$config"
}

# Internal test hook — hermetic regression testing of the whitelist parser with NO gh
# side-effects: check-gh-account.sh --lookup-whitelist <exact-entry-path> <config-file>
# Prints the gh_account for an exact whitelist '- path:' value (or empty), then exits.
if [ "$CONSUMER_PATH" = "--lookup-whitelist" ]; then
  _get_gh_account_from_whitelist "${2:-}" "${3:-}"
  exit 0
fi

# Match consumer to a whitelist entry by resolving BOTH to absolute paths.
# (The old sibling-only relative match silently missed nested consumers such as
#  ../../URAI/legal_ai_assistant-documentation → empty REL_PATH → whitelist never queried.)
METHODOLOGY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GH_ACCOUNT=""
if [ -d "$CONSUMER_PATH" ]; then
  ABS_CONSUMER="$(cd "$CONSUMER_PATH" && pwd)"
  _matched_entry=""
  # Process-substitution (NOT `_list... | while`) so $_matched_entry survives the loop:
  # a pipe runs the while-body in a subshell in Bash 3.2 and the assignment is lost.
  while IFS= read -r _entry; do
    [ -n "$_entry" ] || continue
    _abs_entry="$( cd "$METHODOLOGY_DIR" 2>/dev/null && cd "$_entry" 2>/dev/null && pwd )"
    if [ -n "$_abs_entry" ] && [ "$_abs_entry" = "$ABS_CONSUMER" ]; then
      _matched_entry="$_entry"
      break
    fi
  done < <(_list_whitelist_paths "$CONFIG")
  if [ -n "$_matched_entry" ]; then
    GH_ACCOUNT="$(_get_gh_account_from_whitelist "$_matched_entry" "$CONFIG")"
  fi
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
