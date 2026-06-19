#!/usr/bin/env bash
#
# push-consumer-single.sh — atomic sync+commit+push for one consumer repo.
#
# WHY (P-013, closes domain:git-push recurrence class v6.9.2):
#   /push-consumers Шаг 5 Режим B contained inline pseudocode with $(dirname "$0")
#   for path resolution. Agents reading markdown reimplement this inline each session,
#   bypassing check-gh-account.sh → push under wrong account → 404/403.
#   This script is the L4 structural fix: one callable black-box, no inline logic needed.
#
# Called by /push-consumers Шаг 5 Режим B (one call per whitelisted consumer).
#
# Usage:
#   bash scripts/push-consumer-single.sh <consumer-abs-path> <branch> [methodology-dir]
#
#   consumer-abs-path  — absolute path to the consumer repo
#   branch             — target branch (from CLAUDE.local.md auto_commit_consumers)
#   methodology-dir    — path to methodology repo (default: script-dir/..)
#
# Exit codes:
#   0 = pushed successfully (or nothing to push — already up to date)
#   1 = not pushed: sync fail / gh-account fail / push fail
#   2 = usage error (wrong args)
#
# Bash 3.2+ compatible (no ${var,,}, no associative arrays).

set -uo pipefail

CONSUMER_PATH="${1:-}"
BRANCH="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METH_DIR="${3:-$(cd "$SCRIPT_DIR/.." && pwd)}"

if [ -z "$CONSUMER_PATH" ] || [ -z "$BRANCH" ]; then
  echo "Usage: $0 <consumer-abs-path> <branch> [methodology-dir]" >&2
  exit 2
fi

CONSUMER_NAME="$(basename "$CONSUMER_PATH")"

# ---------------------------------------------------------------------------
# 1. Sync with manifest
# ---------------------------------------------------------------------------
echo "→ Синкаю $CONSUMER_NAME..."
MANIFEST_OUT=$(bash "$METH_DIR/scripts/sync-methodology.sh" "$CONSUMER_PATH" --print-changed 2>&1)
SYNC_EXIT=$?

if [ $SYNC_EXIT -ne 0 ]; then
  echo "  ❌ $CONSUMER_NAME: sync failed (exit $SYNC_EXIT)" >&2
  echo "$MANIFEST_OUT" | head -5 | sed 's/^/      /' >&2
  exit 1
fi

NEW_VER=$(grep "methodology:" "$CONSUMER_PATH/.claude/.version" 2>/dev/null \
          | sed 's/methodology:[[:space:]]*//' | tr -d '\r ')
echo "  ✅ sync → ${NEW_VER:-unknown}"

# Extract changed paths (CHANGED: prefix from --print-changed output)
CHANGED_PATHS=$(echo "$MANIFEST_OUT" | grep "^CHANGED:" | sed 's/^CHANGED://' | tr '\n' ' ' | sed 's/[[:space:]]*$//')

# ---------------------------------------------------------------------------
# 2. Nothing to commit?
# ---------------------------------------------------------------------------
if [ -z "$CHANGED_PATHS" ]; then
  echo "  ℹ️  $CONSUMER_NAME: манифест пустой — нечего коммитить"
  exit 0
fi

# ---------------------------------------------------------------------------
# 3. Symmetric dirty-check on manifest paths only (closes a17ecc1 class)
# ---------------------------------------------------------------------------
DIRTY=$(git -C "$CONSUMER_PATH" status --short $CHANGED_PATHS 2>/dev/null \
        | grep -v "^$" | head -1)
if [ -n "$DIRTY" ]; then
  echo "  ⚠️  $CONSUMER_NAME: dirty manifest-путь (параллельная сессия?) — пропуск commit+push" >&2
  echo "      Грязный: $DIRTY" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. Git commit — explicit pathspec only (NEVER git add, closes a17ecc1)
# ---------------------------------------------------------------------------
MSG="sync methodology ${NEW_VER:-?}"
# shellcheck disable=SC2086
if ! git -C "$CONSUMER_PATH" commit $CHANGED_PATHS -m "$MSG" 2>/dev/null; then
  echo "  ℹ️  $CONSUMER_NAME: нечего коммитить (уже актуально)"
  exit 0
fi
echo "  ✅ commit: '$MSG'"

# ---------------------------------------------------------------------------
# 5. gh-account check (closes P-012 / P-013 / domain:git-push)
#    Reads EXPLICIT gh_account from CLAUDE.local.md whitelist — not URL-derived.
#    This is the step that was bypassed when logic was inline in push-consumers.md.
# ---------------------------------------------------------------------------
CLAUDE_LOCAL="$METH_DIR/CLAUDE.local.md"
if ! bash "$METH_DIR/scripts/check-gh-account.sh" "$CONSUMER_PATH" "$CLAUDE_LOCAL"; then
  echo "  ❌ $CONSUMER_NAME: push пропущен — gh-account check failed (см. вывод выше)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 6. Push with error classification
# ---------------------------------------------------------------------------
PUSH_ERRFILE="$(mktemp 2>/dev/null || echo "/tmp/push_err_$$")"
LC_ALL=C git -C "$CONSUMER_PATH" push origin "HEAD:$BRANCH" 2>"$PUSH_ERRFILE"
PUSH_EXIT=$?
PUSH_ERR="$(cat "$PUSH_ERRFILE" 2>/dev/null)"
rm -f "$PUSH_ERRFILE" 2>/dev/null || true

if [ $PUSH_EXIT -eq 0 ]; then
  echo "  ✅ push → $BRANCH"
  exit 0
fi

echo "  ❌ $CONSUMER_NAME: push failed (exit $PUSH_EXIT):" >&2
echo "$PUSH_ERR" | head -5 | sed 's/^/      /' >&2

if echo "$PUSH_ERR" | grep -qiE 'repository not found|not found|does not exist|404'; then
  echo "  → 404: репо не существует на remote. Проверь: git -C \"$CONSUMER_PATH\" remote -v" >&2
elif echo "$PUSH_ERR" | grep -qiE '403|permission|denied|forbidden'; then
  ACTIVE=$(gh api user -q .login 2>/dev/null || echo "unknown")
  echo "  → 403: wrong gh account (активен: $ACTIVE). Запусти check-gh-account.sh вручную." >&2
elif echo "$PUSH_ERR" | grep -qiE 'GH006|protected branch'; then
  echo "  → Branch protection: нужен PR. Push-only не разрешён." >&2
elif echo "$PUSH_ERR" | grep -qiE 'network|resolve|timed out'; then
  echo "  → Сеть недоступна. Повтори позже." >&2
fi
exit 1
