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
# 1. Pre-flight dirty check on .claude/ BEFORE sync (closes a17ecc1 class).
#    WHY before sync: after sync all written files appear as M (modified) —
#    a post-sync dirty check would always fire. This check detects parallel
#    sessions that have uncommitted .claude/ work BEFORE we overwrite anything.
# ---------------------------------------------------------------------------
PRE_DIRTY=$(git -C "$CONSUMER_PATH" status --short -- .claude/ 2>/dev/null \
            | grep -v "^$" | head -1)
if [ -n "$PRE_DIRTY" ]; then
  echo "  ⚠️  $CONSUMER_NAME: dirty .claude/ перед синком — пропуск (паралельна сесія?)" >&2
  echo "      Грязний: $PRE_DIRTY" >&2
  echo "      Вирішіть: /sync-audit Gap 17, потім повторіть /push-consumers" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Sync with manifest
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
# 3. Nothing to commit?
# ---------------------------------------------------------------------------
if [ -z "$CHANGED_PATHS" ]; then
  echo "  ℹ️  $CONSUMER_NAME: нічого не змінилось — коміт не потрібен"
  exit 0
fi

# ---------------------------------------------------------------------------
# 4. Git add + commit — explicit pathspec only (closes a17ecc1).
#    git add $CHANGED_PATHS stages ONLY sync-written files (tracks new untracked too);
#    gitignored manifest entries (.claude/commands/*, .claude/hooks/*, .claude/skills/*
#    are DERIVED copies, gitignored in consumers) are silently skipped by `git add`.
#
#    COMMIT scope = trackable staged subset of OUR manifest, computed via
#    `git diff --cached --name-only -- $CHANGED_PATHS`:
#      • pathspec `-- $CHANGED_PATHS` keeps parallel-safety (never another session's
#        staged work — only our manifest paths), preserving the a17ecc1 guarantee;
#      • unlike `git commit <pathspec>`, `git diff -- <pathspec>` does NOT abort on
#        gitignored/untracked entries — it silently drops them and returns exit 0.
#    WHY (closes silent-non-commit, domain:git-push): the previous
#    `git commit $CHANGED_PATHS` passed gitignored paths as pathspec → git aborted the
#    WHOLE commit ("pathspec '.claude/commands/...' did not match any file(s) known to
#    git") → exit non-zero → treated as "already up to date" → tracked files (CLAUDE.md,
#    scripts/*) silently never committed/pushed across the consumer fleet.
# ---------------------------------------------------------------------------
MSG="sync methodology ${NEW_VER:-?}"
# shellcheck disable=SC2086
git -C "$CONSUMER_PATH" add -- $CHANGED_PATHS 2>/dev/null || true

# shellcheck disable=SC2086
COMMIT_PATHS=$(git -C "$CONSUMER_PATH" diff --cached --name-only -- $CHANGED_PATHS 2>/dev/null | grep -v "^$")
if [ -z "$COMMIT_PATHS" ]; then
  echo "  ℹ️  $CONSUMER_NAME: немає trackable змін для коміту (manifest = derived/gitignored або вже актуально)"
  exit 0
fi

COMMIT_ERR="$(mktemp 2>/dev/null || echo "/tmp/commit_err_$$")"
# shellcheck disable=SC2086
if ! git -C "$CONSUMER_PATH" commit $COMMIT_PATHS -m "$MSG" 2>"$COMMIT_ERR"; then
  echo "  ❌ $CONSUMER_NAME: commit failed:" >&2
  cat "$COMMIT_ERR" 2>/dev/null | head -3 | sed 's/^/      /' >&2
  rm -f "$COMMIT_ERR" 2>/dev/null || true
  exit 1
fi
rm -f "$COMMIT_ERR" 2>/dev/null || true
N_FILES=$(echo "$COMMIT_PATHS" | grep -c . )
echo "  ✅ commit: '$MSG' (${N_FILES} файлів)"

# ---------------------------------------------------------------------------
# 5. gh-account check (closes P-012 / P-013 / domain:git-push)
#    Reads EXPLICIT gh_account from CLAUDE.local.md whitelist — not URL-derived.
#    This is the step that was bypassed when logic was inline in push-consumers.md.
# ---------------------------------------------------------------------------
CLAUDE_LOCAL="$METH_DIR/CLAUDE.local.md"
if ! bash "$METH_DIR/scripts/check-gh-account.sh" "$CONSUMER_PATH" "$CLAUDE_LOCAL"; then
  echo "  ❌ $CONSUMER_NAME: push пропущений — gh-account check failed (дивись вище)" >&2
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
  # Pull to confirm local stays current after push (ff-only: safe no-op if already equal,
  # catches fast-forward updates from parallel sessions).
  PULL_OUT=$(git -C "$CONSUMER_PATH" pull --ff-only origin "$BRANCH" 2>&1) || true
  if echo "$PULL_OUT" | grep -q "Fast-forward"; then
    echo "  📥 pull --ff-only: fast-forward applied"
  fi
  exit 0
fi

echo "  ❌ $CONSUMER_NAME: push failed (exit $PUSH_EXIT):" >&2
echo "$PUSH_ERR" | head -5 | sed 's/^/      /' >&2

if echo "$PUSH_ERR" | grep -qiE 'repository not found|not found|does not exist|404'; then
  echo "  → 404: репо не існує на remote. Перевір: git -C \"$CONSUMER_PATH\" remote -v" >&2
elif echo "$PUSH_ERR" | grep -qiE '403|permission|denied|forbidden'; then
  ACTIVE=$(gh api user -q .login 2>/dev/null || echo "unknown")
  echo "  → 403: wrong gh account (активний: $ACTIVE). Запусти check-gh-account.sh вручну." >&2
elif echo "$PUSH_ERR" | grep -qiE 'GH006|protected branch'; then
  echo "  → Branch protection: потрібен PR. Push-only не дозволений." >&2
elif echo "$PUSH_ERR" | grep -qiE 'network|resolve|timed out'; then
  echo "  → Мережа недоступна. Повтори пізніше." >&2
fi
exit 1
