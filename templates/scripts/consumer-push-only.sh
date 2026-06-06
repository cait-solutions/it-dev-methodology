#!/usr/bin/env bash
#
# consumer-push-only.sh — push agent branch to remote without merge.
#
# Simple push: git push origin <agent_branch> → <agent_branch>
# No merge, no MR/PR, no target-branch selection, no questions.
#
# Usage:
#   bash scripts/consumer-push-only.sh
#
# Config read from CLAUDE.local.md ## Branching:
#   agent_branch:  ai-dev  (default: ai-dev)
#
# Note: pushes agent_branch as configured in CLAUDE.local.md,
# not necessarily the current git HEAD branch.

set -euo pipefail

CONFIG="${CONSUMER_PUSH_CONFIG:-CLAUDE.local.md}"

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

# ---------------------------------------------------------------------------
# Wire credential helper for HTTPS
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
    echo "    Push может вернуть 403. Залогинься: gh auth login"
  fi
}
_ensure_gh_account

# ---------------------------------------------------------------------------
# Show what will be pushed
# ---------------------------------------------------------------------------
echo ""
echo "Push:"
echo "  branch: ${AGENT_BRANCH}"
echo "  remote: ${REMOTE_URL}"
echo ""
echo "Коммиты которые улетят:"
git log --oneline "origin/${AGENT_BRANCH}..${AGENT_BRANCH}" 2>/dev/null || \
  git log --oneline -5 "${AGENT_BRANCH}" 2>/dev/null || true
echo ""

# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------
if ! git push origin "${AGENT_BRANCH}:${AGENT_BRANCH}"; then
  echo ""
  echo "❌ Push не прошёл (403 / permission denied)."
  echo "   Варианты:"
  echo "   a) gh auth login → повторить /push"
  echo "   b) git remote set-url origin https://<user>:<pat>@<host>/<ns>/<repo>.git"
  echo "   c) Для GitLab: настрой SSH-ключ или Personal Access Token"
  exit 1
fi

echo ""
echo "✅ Pushed: ${AGENT_BRANCH}"
