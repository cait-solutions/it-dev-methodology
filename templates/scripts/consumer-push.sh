#!/usr/bin/env bash
#
# consumer-push.sh — push ai-dev branch and merge into develop (or main).
#
# Platform-aware: detects GitHub vs GitLab from remote URL.
# Mode-aware: solo = push directly into target; team = push branch + show MR/PR URL.
#
# Usage:
#   bash scripts/consumer-push.sh [--main]
#
#   (no args)  — push ai-dev → develop (asks if develop not found on remote)
#   --main     — push ai-dev → main directly, no questions
#
# Config read from CLAUDE.local.md ## Branching:
#   mode:              solo | team   (default: solo)
#   agent_branch:      ai-dev        (default: ai-dev)
#   remote_platform:   auto | github | gitlab   (default: auto — detect from remote URL)
#
# Override remote_platform in CLAUDE.local.md if auto-detection misidentifies your host.

set -euo pipefail

CONFIG="${CONSUMER_PUSH_CONFIG:-CLAUDE.local.md}"

# ---------------------------------------------------------------------------
# Argument validation — whitelist: only --main or empty
# ---------------------------------------------------------------------------
ARG="${1:-}"
if [[ -n "$ARG" && "$ARG" != "--main" ]]; then
  echo "❌ Неизвестный аргумент: $ARG"
  echo "   Допустимо: (без аргументов) или --main"
  exit 1
fi
FORCE_MAIN=false
[[ "$ARG" == "--main" ]] && FORCE_MAIN=true

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

MODE=$(_get_field "mode" "solo")
AGENT_BRANCH=$(_get_field "agent_branch" "ai-dev")
REMOTE_PLATFORM=$(_get_field "remote_platform" "auto")

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
if [[ -z "$REMOTE_URL" ]]; then
  echo "❌ git remote 'origin' не настроен. Добавь: git remote add origin <url>"
  exit 1
fi

_detect_platform() {
  local url="$1" host=""
  # Extract host from https:// or git@ URLs
  case "$url" in
    https://*)
      host="${url#https://}"; host="${host%%/*}"; host="${host%%:*}"
      ;;
    git@*)
      # git@host:namespace/repo.git  or  git@host:port/namespace/repo.git
      host="${url#git@}"; host="${host%%:*}"
      ;;
    *)
      host=""
      ;;
  esac

  case "$host" in
    github.com) echo "github" ;;
    *)          echo "gitlab" ;;  # conservative: all non-github HTTPS/SSH → gitlab-compatible
  esac
}

if [[ "$REMOTE_PLATFORM" == "auto" || -z "$REMOTE_PLATFORM" ]]; then
  PLATFORM=$(_detect_platform "$REMOTE_URL")
  echo "🔍 Платформа определена: $PLATFORM (из $REMOTE_URL)"
  echo "   Чтобы зафиксировать — добавь 'remote_platform: $PLATFORM' в CLAUDE.local.md ## Branching"
else
  PLATFORM="$REMOTE_PLATFORM"
fi

# ---------------------------------------------------------------------------
# Determine target branch
# ---------------------------------------------------------------------------
if [[ "$FORCE_MAIN" == "true" ]]; then
  TARGET_BRANCH="main"
  echo "📌 --main: цель → main"
else
  # Check if develop exists on remote
  if git ls-remote --exit-code --heads origin develop > /dev/null 2>&1; then
    TARGET_BRANCH="develop"
  else
    echo ""
    echo "⚠️  Ветка 'develop' не найдена на remote."
    printf "   Push в 'main'? (y/n): "
    read -r ANSWER
    case "$ANSWER" in
      y|Y|yes|YES) TARGET_BRANCH="main" ;;
      *)
        echo "❌ Отменено."
        exit 0
        ;;
    esac
  fi
fi

# ---------------------------------------------------------------------------
# Show what will be pushed
# ---------------------------------------------------------------------------
echo ""
echo "Конфигурация push:"
echo "  mode:          $MODE"
echo "  platform:      $PLATFORM"
echo "  from:          $AGENT_BRANCH"
echo "  to:            $TARGET_BRANCH"
echo "  remote:        $REMOTE_URL"
echo ""
echo "Коммиты которые улетят:"
git log --oneline "origin/${TARGET_BRANCH}..${AGENT_BRANCH}" 2>/dev/null || \
  git log --oneline -5 "${AGENT_BRANCH}" 2>/dev/null || true
echo ""

# ---------------------------------------------------------------------------
# Wire credential helper for HTTPS (same pattern as deploy-push.sh)
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
_ensure_gh_account() {
  command -v gh >/dev/null 2>&1 || return 0
  [[ "$PLATFORM" == "github" ]] || return 0
  local owner active
  owner="${REMOTE_URL#https://github.com/}"; owner="${owner%%/*}"
  [[ -n "$owner" ]] || return 0
  active=$(gh api user -q .login 2>/dev/null || echo "")
  [[ "$active" == "$owner" ]] && return 0
  if gh auth status 2>/dev/null | grep -q "account ${owner} "; then
    gh auth switch --user "$owner" >/dev/null 2>&1 && \
      echo "🔄 gh account: ${active:-none} → ${owner}"
  else
    echo "⚠️  gh: аккаунт '${owner}' не залогинен (активен: ${active:-none})."
    echo "    Push может вернуть 403. Залогинься: gh auth login --user ${owner}"
  fi
}
_ensure_gh_account

_print_credential_help() {
  echo ""
  echo "❌ Push не прошёл (403 / permission denied)."
  echo "   Варианты:"
  echo "   a) gh auth login → повторить /push-merge"
  echo "   b) git remote set-url origin https://<user>:<pat>@<host>/<ns>/<repo>.git"
  echo "   c) Для GitLab: настрой SSH-ключ или Personal Access Token"
}

# ---------------------------------------------------------------------------
# Push
# ---------------------------------------------------------------------------
if [[ "$MODE" == "solo" ]]; then
  # Solo: push directly into target branch (no MR/PR needed)
  echo "▶ Solo mode → git push origin ${AGENT_BRANCH}:${TARGET_BRANCH}"
  if ! git push origin "${AGENT_BRANCH}:${TARGET_BRANCH}"; then
    _print_credential_help
    exit 1
  fi
  echo ""
  echo "✅ Pushed: ${AGENT_BRANCH} → ${TARGET_BRANCH}"

else
  # Team mode: push the agent branch, show MR/PR URL for human review
  echo "▶ Team mode → git push origin ${AGENT_BRANCH}:${AGENT_BRANCH}"
  if ! git push origin "${AGENT_BRANCH}:${AGENT_BRANCH}" 2>&1; then
    _print_credential_help
    exit 1
  fi
  echo ""

  # Build MR/PR URL
  _BASE="${REMOTE_URL%.git}"
  if [[ "$PLATFORM" == "github" ]]; then
    PR_URL="${_BASE}/compare/${TARGET_BRANCH}...${AGENT_BRANCH}?expand=1"
    echo "✅ Ветка опубликована. Создай PR:"
    echo "   $PR_URL"
    # Try gh pr create if available
    if command -v gh >/dev/null 2>&1; then
      LAST_MSG=$(git log -1 --format="%s" "${AGENT_BRANCH}" 2>/dev/null || echo "Deploy from ${AGENT_BRANCH}")
      echo ""
      echo "   Или через CLI:"
      echo "   gh pr create --base ${TARGET_BRANCH} --head ${AGENT_BRANCH} --title \"${LAST_MSG}\""
    fi
  else
    # GitLab-compatible: build MR URL
    # Extract host and namespace/repo from URL
    case "$REMOTE_URL" in
      https://*)
        _rest="${REMOTE_URL#https://}"
        _host="${_rest%%/*}"
        _path="${_rest#*/}"
        _path="${_path%.git}"
        ;;
      git@*)
        _hostpart="${REMOTE_URL#git@}"
        _host="${_hostpart%%:*}"
        _path="${_hostpart#*:}"
        _path="${_path%.git}"
        ;;
      *)
        _host=""; _path=""
        ;;
    esac
    if [[ -n "$_host" && -n "$_path" ]]; then
      MR_URL="https://${_host}/${_path}/-/merge_requests/new?merge_request[source_branch]=${AGENT_BRANCH}&merge_request[target_branch]=${TARGET_BRANCH}"
      echo "✅ Ветка опубликована. Создай MR:"
      echo "   $MR_URL"
    else
      echo "✅ Ветка опубликована. Создай MR вручную:"
      echo "   ${AGENT_BRANCH} → ${TARGET_BRANCH}"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Update triggers.json last_deploy.date (portable sed, no python/jq)
# ---------------------------------------------------------------------------
_update_triggers() {
  local triggers_file=".claude/state/triggers.json"
  [[ -f "$triggers_file" ]] || return 0
  local today
  today=$(date -u +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
  # Replace "date": "YYYY-MM-DD" inside last_deploy block — portable sed
  # Works on bash 3.2 (macOS/Git Bash), no perl/python needed
  sed -i.bak 's/"last_deploy":[[:space:]]*{[^}]*}/"last_deploy": {"date": "'"$today"'", "status": "ok"}/' \
    "$triggers_file" 2>/dev/null || true
  rm -f "${triggers_file}.bak" 2>/dev/null || true
}
_update_triggers

echo ""
echo "🎉 Готово."
