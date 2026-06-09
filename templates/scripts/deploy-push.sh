#!/usr/bin/env bash
#
# deploy-push.sh — reads branching config from CLAUDE.local.md and runs the correct git push.
#
# Eliminates manual conditional logic for agents: run this script instead of writing
# git push commands directly. The script reads mode (solo|team) and chooses the
# correct push target, preventing the class of error where solo pattern (ai-dev:main)
# is used in a team-mode project.
#
# Usage:
#   bash scripts/deploy-push.sh [path/to/CLAUDE.local.md]
#   Default config path: CLAUDE.local.md (in current directory)

set -euo pipefail

CONFIG="${1:-CLAUDE.local.md}"

_get_field() {
  local field="$1"
  local default="$2"
  if [[ ! -f "$CONFIG" ]]; then
    echo "$default"
    return
  fi
  local value
  # Extract value after 'field:', strip inline '# comment', then strip CR/whitespace.
  # (Template yaml ships inline comments, e.g. `worktree_isolation: off  # ...` —
  #  without comment-stripping the value would read as 'off#...'.)
  value=$(awk '/^## Branching/{f=1; next} /^## /{f=0} f{print}' "$CONFIG" \
          | grep -E "^[[:space:]]*${field}:" | head -1 \
          | sed "s/.*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '\r[:space:]')
  echo "${value:-$default}"
}

MODE=$(_get_field "mode" "solo")
AGENT_BRANCH=$(_get_field "agent_branch" "ai-dev")
PRODUCTION_BRANCH=$(_get_field "production_branch" "main")
INTEGRATION_BRANCH=$(_get_field "integration_branch" "$PRODUCTION_BRANCH")
PR_TOOL=$(_get_field "pr_tool" "manual")
WORKTREE_ISOLATION=$(_get_field "worktree_isolation" "off")

# ---------------------------------------------------------------------------
# Concurrent-session isolation (closes P-001): when worktree_isolation: auto,
# the deploy branch is the CURRENT branch (a namespaced ai-dev/<task> from an
# isolated worktree), NOT the shared agent_branch. Reading the current branch
# avoids the class-bug where hardcoded agent_branch pushes the wrong worktree's
# branch. When isolation is off, behavior is unchanged (current branch == agent_branch).
# ---------------------------------------------------------------------------
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "$AGENT_BRANCH")
if [[ "$WORKTREE_ISOLATION" == "auto" ]]; then
  PUSH_BRANCH="$CURRENT_BRANCH"
else
  PUSH_BRANCH="$AGENT_BRANCH"
fi

echo "Branching config (from $CONFIG):"
echo "  mode:               $MODE"
echo "  agent_branch:       $AGENT_BRANCH"
echo "  worktree_isolation: $WORKTREE_ISOLATION"
echo "  push_branch:        $PUSH_BRANCH"
echo "  production_branch:  $PRODUCTION_BRANCH"
[[ "$MODE" == "team" ]] && echo "  integration_branch: $INTEGRATION_BRANCH"
[[ "$MODE" == "team" ]] && echo "  pr_tool:            $PR_TOOL"
echo ""

# ---------------------------------------------------------------------------
# Auto-wire credential helper (S3 / closes G-079: orphaned helper).
# For HTTPS remotes, configure git-credential-from-env.sh as the credential
# helper BEFORE push, so `git push` authenticates via helper stdin — the token
# NEVER appears in any command argv (the confirmed leak vector). Idempotent:
# skips if already configured, if remote is SSH (no token needed), or if the
# helper script is absent. This removes the agent's incentive to fall back to
# `git remote set-url https://user:TOKEN@...` when auth is needed.
# ---------------------------------------------------------------------------
_wire_credential_helper() {
  local remote_url helper_path host
  remote_url=$(git remote get-url origin 2>/dev/null || true)
  # SSH remote → no token, no helper needed.
  case "$remote_url" in
    https://*) : ;;                       # proceed
    *) return 0 ;;                        # ssh/git/empty → nothing to wire
  esac
  # Locate the helper script relative to THIS script (works in code or doc repo).
  helper_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/git-credential-from-env.sh"
  [[ -f "$helper_path" ]] || return 0     # helper absent → leave git defaults
  # Extract host: https://host/... → host
  host="${remote_url#https://}"; host="${host%%/*}"; host="${host%%:*}"
  [[ -n "$host" ]] || return 0
  # Already configured for this host? (idempotent)
  if git config --get "credential.https://${host}.helper" >/dev/null 2>&1; then
    return 0
  fi
  git config "credential.https://${host}.helper" "!bash ${helper_path}"
  echo "🔑 credential helper wired for ${host} (token via helper stdin, not argv)"
}
_wire_credential_helper

# ---------------------------------------------------------------------------
# Ensure correct gh account before push (closes G-083).
# Машина может иметь несколько gh-аккаунтов (gh auth login --user X). Push в
# github.com/<owner>/<repo> требует активного аккаунта с доступом к <owner>.
# 403 при push под чужим активным аккаунтом — НЕ "нет токена", а wrong account.
# Деривируем требуемый аккаунт из owner remote-а и переключаем если есть среди
# залогиненных. Это L4: deploy сам восстанавливается, не полагаясь на память агента.
# Только github.com (gh не управляет gitlab/self-hosted).
# ---------------------------------------------------------------------------
_ensure_gh_account() {
  command -v gh >/dev/null 2>&1 || return 0
  local remote_url owner
  remote_url=$(git remote get-url origin 2>/dev/null || true)
  case "$remote_url" in
    https://github.com/*) : ;;
    *) return 0 ;;                          # не github.com → gh не применим
  esac
  owner="${remote_url#https://github.com/}"; owner="${owner%%/*}"
  [[ -n "$owner" ]] || return 0
  local active
  active=$(gh api user -q .login 2>/dev/null || echo "")
  [[ "$active" == "$owner" ]] && return 0   # уже правильный
  if gh auth status 2>/dev/null | grep -q "account ${owner} "; then
    if gh auth switch --user "$owner" >/dev/null 2>&1; then
      echo "🔄 gh account: ${active:-none} → ${owner} (для push в ${owner}/*)"
    fi
  else
    echo "⚠️  gh: аккаунт '${owner}' не залогинен (активен: ${active:-none})."
    echo "    Push может вернуть 403. Залогинься: gh auth login --user ${owner}"
  fi
}
_ensure_gh_account

# ---------------------------------------------------------------------------
# Push-failure classification (closes G-083 level-4 + P-005).
# Раньше git push был ГОЛЫЙ (без проверки exit) → при провале скрипт продолжал
# в gh pr create на непушнутой ветке (каскад ошибок). Теперь _push прерывает
# до gh-pr-create и классифицирует причину (404/403/network) вместо «нужен PAT».
# ---------------------------------------------------------------------------
_dp_remote_url() { git remote get-url origin 2>/dev/null || true; }
_remote_host() {
  local u; u="$(_dp_remote_url)"
  case "$u" in
    https://*) local h="${u#https://}"; h="${h%%/*}"; echo "${h%%:*}" ;;
    git@*)     local h="${u#git@}"; echo "${h%%:*}" ;;
    *)         echo "" ;;
  esac
}
_manifest_hosts() {
  local manifest=".claude/secrets-manifest.yaml"
  [[ -f "$manifest" ]] || return 0
  grep -E '^[[:space:]]*service_url:' "$manifest" 2>/dev/null \
    | sed -E 's/.*service_url:[[:space:]]*"?([^"]*)"?.*/\1/' \
    | sed -E 's#^https?://##; s#/.*$##; s#:.*$##' \
    | grep -v '^$' | sort -u
}
_sanitize() { sed -E 's#://[^@/[:space:]]+@#://***@#g'; }

_classify_push_failure() {
  local err="$1" rc="$2"
  local host; host="$(_remote_host)"
  local url; url="$(_dp_remote_url)"
  echo ""
  echo "❌ Push не прошёл (git exit $rc). Причина:"
  if echo "$err" | grep -qiE 'repository not found|not found|does not exist|404'; then
    echo "   📦 Репозиторий не существует на remote: ${url}"
    local mhosts; mhosts="$(_manifest_hosts)"
    if [[ -n "$mhosts" && -n "$host" ]] && ! echo "$mhosts" | grep -qx "$host"; then
      echo ""
      echo "   ⚠️  remote указывает на '${host}', но настроенные секреты — для:"
      echo "$mhosts" | sed 's/^/        • /'
      echo "      Вероятно remote указывает НЕ НА ТУ платформу."
      echo "        git remote -v"
      echo "        git remote set-url origin <правильный-url-из-manifest>"
    else
      echo "   a) Создать репозиторий: gh repo create <owner>/<repo> --private --source=. --push"
      echo "   b) Исправить remote если опечатка: git remote set-url origin <url>"
    fi
  elif echo "$err" | grep -qiE '403|permission|denied|forbidden|access denied'; then
    echo "   🔒 Доступ запрещён (403)."
    case "$url" in
      https://github.com/*)
        if command -v gh >/dev/null 2>&1; then
          local owner active
          owner="${url#https://github.com/}"; owner="${owner%%/*}"
          active=$(gh api user -q .login 2>/dev/null || echo "")
          echo "      Активный gh-аккаунт: ${active:-none}, нужен: ${owner}"
          echo "      Скорее всего НЕ ТОТ активный аккаунт (не отсутствие PAT):"
          echo "        gh auth switch --user ${owner}"
          echo "        повторить deploy"
          echo "      Если ${owner} не залогинен: gh auth login --user ${owner}"
        fi ;;
      *)
        echo "   a) gh auth login → повторить"
        echo "   b) Настрой credential helper / PAT для ${host:-этого хоста}" ;;
    esac
  elif echo "$err" | grep -qiE 'could not resolve|unable to access|connection|timed out|network'; then
    echo "   🌐 Сеть/хост недоступен — это НЕ проблема прав или токена."
    echo "      Проверь подключение и доступность ${host:-remote}, затем повтори."
  else
    echo "   ❓ Причина не распознана автоматически. Вывод git:"
    echo "$err" | _sanitize | sed 's/^/      /'
  fi
}

_push() {
  local errfile rc
  errfile="$(mktemp 2>/dev/null || echo "${TMPDIR:-/tmp}/push_err.$$")"
  LC_ALL=C git push "$@" 2>"$errfile"
  rc=$?
  cat "$errfile" >&2
  if [[ $rc -ne 0 ]]; then
    _classify_push_failure "$(cat "$errfile" 2>/dev/null)" "$rc"
  fi
  rm -f "$errfile" 2>/dev/null || true
  return $rc
}

if [[ "$MODE" == "team" ]]; then
  echo "▶ Team mode → git push origin ${PUSH_BRANCH}:${PUSH_BRANCH}"
  _push origin "${PUSH_BRANCH}:${PUSH_BRANCH}" || exit 1
  echo ""

  if [[ "$PR_TOOL" == "auto-merge" ]]; then
    PR_TITLE=$(git log -1 --format="%s")
    echo "▶ auto-merge → gh pr create + merge"
    PR_URL=$(gh pr create \
      --base "$INTEGRATION_BRANCH" \
      --head "$PUSH_BRANCH" \
      --title "$PR_TITLE" \
      --body "Auto-deploy via deploy-push.sh")
    echo "  PR: $PR_URL"
    gh pr merge "$PR_URL" --merge --delete-branch=false
    echo "✅ Merged: ${PUSH_BRANCH} → ${INTEGRATION_BRANCH}"
  else
    echo "✅ Pushed. Create PR: ${PUSH_BRANCH} → ${INTEGRATION_BRANCH}"
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
    if [[ -n "$REMOTE_URL" ]]; then
      _base="${REMOTE_URL%.git}"
      echo "   GitHub: ${_base}/compare/${INTEGRATION_BRANCH}...${PUSH_BRANCH}?expand=1"
    fi
  fi
else
  echo "▶ Solo mode → git push origin ${PUSH_BRANCH}:${PRODUCTION_BRANCH}"
  _push origin "${PUSH_BRANCH}:${PRODUCTION_BRANCH}" || exit 1
  echo ""
  echo "✅ Deployed to ${PRODUCTION_BRANCH}"
fi
