#!/usr/bin/env bash
#
# consumer-pull.sh — pull agent branch from remote (ff-only).
#
# Safe pull: git pull --ff-only origin <agent_branch>
# Shows preview of incoming commits before applying. Fails explicitly on
# diverged history (no auto-merge, no rebase surprises).
#
# Usage:
#   bash scripts/consumer-pull.sh
#
# Config read from CLAUDE.local.md ## Branching:
#   agent_branch:  ai-dev  (default: ai-dev)
#
# ⚠️  MUST be run from WITHIN this repo's session (where .claude/hooks/ exists).
#    Claude Code hooks use relative paths — if CWD lacks .claude/, ALL Bash
#    commands fail including cd, echo, git. Run /pull from your project's own
#    session, not from another repo's session context.

set -euo pipefail

CONFIG="${CONSUMER_PULL_CONFIG:-CLAUDE.local.md}"

# ---------------------------------------------------------------------------
# Hook-safety guard: verify we are inside a repo with .claude/ present.
# This prevents the "hook CWD crash" where Claude Code hooks resolve relative
# to CWD — if .claude/hooks/ is missing, every Bash call (including cd) fails.
# ---------------------------------------------------------------------------
if [[ ! -d ".claude" ]]; then
  echo "❌ Нет .claude/ в текущей директории."
  echo "   Этот скрипт должен запускаться из корня проекта со .claude/ (не из соседнего репо)."
  echo "   CWD сейчас: $(pwd)"
  echo "   Переключи сессию или CD в корень своего проекта."
  exit 1
fi

# ---------------------------------------------------------------------------
# Read config from CLAUDE.local.md ## Branching section
# ---------------------------------------------------------------------------
_get_field() {
  local field="$1" default="$2"
  if [[ ! -f "$CONFIG" ]]; then echo "$default"; return; fi
  local value
  value=$(awk '/^## Branching/{f=1; next} /^## /{f=0} f{print}' "$CONFIG" \
          | grep -E "^[[:space:]]*${field}:" | head -1 \
          | sed "s/.*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '\r[:space:]')
  echo "${value:-$default}"
}

AGENT_BRANCH=$(_get_field "agent_branch" "ai-dev")

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
if [[ -z "$REMOTE_URL" ]]; then
  echo "❌ git remote 'origin' не настроен. Добавь: git remote add origin <url>"
  exit 1
fi

# Detached HEAD guard
HEAD_REF=$(git symbolic-ref HEAD 2>/dev/null || echo "")
if [[ -z "$HEAD_REF" ]]; then
  echo "⚠️  Detached HEAD — репо не на ветке."
  echo "   Переключись: git checkout ${AGENT_BRANCH}"
  exit 1
fi

CURRENT_BRANCH="${HEAD_REF#refs/heads/}"
if [[ "$CURRENT_BRANCH" != "$AGENT_BRANCH" ]]; then
  echo "⚠️  Текущая ветка: ${CURRENT_BRANCH}"
  echo "   Pull настроен для: ${AGENT_BRANCH}"
  echo "   Переключись: git checkout ${AGENT_BRANCH}"
  exit 1
fi

# Uncommitted changes guard
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "⚠️  Есть незакоммиченные изменения."
  echo "   Закоммить или stash перед pull:"
  echo "     git stash   — временно убрать"
  echo "     git status  — посмотреть что"
  exit 1
fi

# ---------------------------------------------------------------------------
# Wire credential helper for HTTPS (same pattern as consumer-push-only.sh)
# ---------------------------------------------------------------------------
_wire_credential_helper() {
  local helper_path host
  case "$REMOTE_URL" in
    https://*) : ;;
    *) return 0 ;;
  esac
  helper_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-credential-from-env.sh"
  [[ -f "$helper_path" ]] || return 0
  host="${REMOTE_URL#https://}"; host="${host%%/*}"; host="${host%%:*}"
  [[ -n "$host" ]] || return 0
  if git config --get "credential.https://${host}.helper" >/dev/null 2>&1; then
    return 0
  fi
  git config "credential.https://${host}.helper" "!bash ${helper_path}"
  echo "🔑 credential helper настроен для ${host}"
}
_wire_credential_helper

# Ensure correct gh account for GitHub
_detect_github() {
  case "$REMOTE_URL" in
    https://github.com/*|git@github.com:*) echo "github" ;;
    *) echo "other" ;;
  esac
}
_ensure_gh_account() {
  command -v gh >/dev/null 2>&1 || return 0
  [[ "$(_detect_github)" == "github" ]] || return 0
  local owner active
  case "$REMOTE_URL" in
    https://github.com/*) owner="${REMOTE_URL#https://github.com/}"; owner="${owner%%/*}" ;;
    git@github.com:*)     owner="${REMOTE_URL#git@github.com:}"; owner="${owner%%/*}" ;;
    *) return 0 ;;
  esac
  [[ -n "$owner" ]] || return 0
  active=$(gh api user -q .login 2>/dev/null || echo "")
  [[ "$active" == "$owner" ]] && return 0
  if gh auth status 2>/dev/null | grep -q "account ${owner} "; then
    gh auth switch --user "$owner" >/dev/null 2>&1 && \
      echo "🔄 gh account: ${active:-none} → ${owner}"
  else
    echo "⚠️  gh: аккаунт '${owner}' не залогинен (активен: ${active:-none})."
    echo "    Pull может вернуть 403. Залогинься: gh auth login"
  fi
}
_ensure_gh_account

# ---------------------------------------------------------------------------
# Fetch + preview incoming commits
# ---------------------------------------------------------------------------
echo ""
echo "Fetch origin/${AGENT_BRANCH} ..."
git fetch origin "${AGENT_BRANCH}" 2>&1 || {
  echo "❌ Fetch не прошёл."
  echo "   Проверь подключение и права доступа к ${REMOTE_URL}"
  exit 1
}

INCOMING=$(git log --oneline "${AGENT_BRANCH}..origin/${AGENT_BRANCH}" 2>/dev/null || true)
if [[ -z "$INCOMING" ]]; then
  echo ""
  echo "✅ Уже актуально — новых коммитов нет."
  echo "   branch: ${AGENT_BRANCH}"
  echo "   remote: ${REMOTE_URL}"
  exit 0
fi

echo ""
echo "Входящие коммиты:"
echo "$INCOMING"
echo ""
echo "branch: ${AGENT_BRANCH}"
echo "remote: ${REMOTE_URL}"
echo ""

# ---------------------------------------------------------------------------
# Pull --ff-only (safe: fails explicitly on diverged history)
# ---------------------------------------------------------------------------
if ! git pull --ff-only origin "${AGENT_BRANCH}"; then
  echo ""
  echo "❌ Pull --ff-only не прошёл: история разошлась."
  echo ""
  echo "Это значит что локальная ветка содержит коммиты которых нет на remote,"
  echo "а remote содержит коммиты которых нет локально."
  echo ""
  echo "Варианты:"
  echo "  a) Посмотреть расхождение:"
  echo "       git log --oneline --graph origin/${AGENT_BRANCH}...${AGENT_BRANCH}"
  echo "  b) Принять remote-версию (потерять локальные коммиты):"
  echo "       git reset --hard origin/${AGENT_BRANCH}   # ⚠️ деструктивно — уточни у пользователя"
  echo "  c) Rebase поверх remote:"
  echo "       git rebase origin/${AGENT_BRANCH}         # может потребовать разрешения конфликтов"
  echo "  d) Попросить пользователя разрешить вручную в терминале"
  exit 1
fi

echo ""
echo "✅ Pulled: ${AGENT_BRANCH} (ff-only)"
echo "   Local теперь совпадает с origin/${AGENT_BRANCH}"
