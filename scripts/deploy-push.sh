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
# Exported for GH006 classifier message (which protected branch rejected the push)
PROTECTED_BRANCH="$INTEGRATION_BRANCH"

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
# gh-account derivation: single source of truth = scripts/lib/gh-account.sh
# (council [opinion:git-account-ssot]). Defensive source — inline fallback if the
# lib is absent (older clone mid-migration): fallback = URL-owner only, no cache.
# ---------------------------------------------------------------------------
_DP_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_DP_SELF_DIR/lib/gh-account.sh" ]; then
  # shellcheck source=scripts/lib/gh-account.sh
  . "$_DP_SELF_DIR/lib/gh-account.sh"
else
  gh_owner_from_url() {
    case "${1:-}" in
      https://github.com/*) local o="${1#https://github.com/}"; o="${o%%/*}"; printf '%s\n' "${o%.git}" ;;
      *) printf '%s\n' "" ;;
    esac
  }
  gh_remote_url()      { git -C "${1:-.}" remote get-url origin 2>/dev/null || true; }
  gh_active_account()  { command -v gh >/dev/null 2>&1 || { echo ""; return 0; }; gh api user -q .login 2>/dev/null || echo ""; }
  gh_resolve_account() { gh_owner_from_url "$(gh_remote_url "${1:-.}")"; }
  gh_cache_put()       { :; }   # no cache without lib — derivation still correct (URL-owner)
fi

# ---------------------------------------------------------------------------
# Ensure correct gh account before push (closes G-083).
# Машина может иметь несколько gh-аккаунтов (gh auth login --user X). Push в
# github.com/<owner>/<repo> требует активного аккаунта с доступом к <owner>.
# 403 при push под чужим активным аккаунтом — НЕ "нет токена", а wrong account.
# Требуемый аккаунт резолвится через gh_resolve_account (learned cache → URL-owner)
# и переключается если есть среди залогиненных. Это L4: deploy сам восстанавливается,
# не полагаясь на память агента. Только github.com (gh не управляет gitlab/self-hosted).
# ---------------------------------------------------------------------------
_ensure_gh_account() {
  command -v gh >/dev/null 2>&1 || return 0
  local want active
  want="$(gh_resolve_account .)"
  [[ -n "$want" ]] || return 0              # не github.com → gh не применим
  active="$(gh_active_account)"
  [[ "$active" == "$want" ]] && return 0    # уже правильный
  if gh auth status 2>/dev/null | grep -q "account ${want} "; then
    if gh auth switch --user "$want" >/dev/null 2>&1; then
      echo "🔄 gh account: ${active:-none} → ${want} (для push в ${want}/*)"
    fi
  else
    echo "⚠️  gh: аккаунт '${want}' не залогинен (активен: ${active:-none})."
    echo "    Push может вернуть 403. Залогинься: gh auth login --user ${want}"
  fi
}
_ensure_gh_account

# _persist_gh_cache — record (remote-URL → active gh account) AFTER a confirmed
# successful push. Machine-written → never drifts like a hand-typed whitelist field.
# Only github.com; no-op without the lib (gh_cache_put stub) or non-github remote.
_persist_gh_cache() {
  command -v gh >/dev/null 2>&1 || return 0
  local url owner active
  url="$(gh_remote_url .)"
  owner="$(gh_owner_from_url "$url")"
  [[ -n "$owner" ]] || return 0
  active="$(gh_active_account)"
  [[ -n "$active" ]] || return 0
  gh_cache_put "$url" "$active"
}

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

# SSOT для git-remote (closes P-006) — см. consumer-push.sh для полного описания.
_manifest_git_url() {
  local manifest=".claude/secrets-manifest.yaml"
  [[ -f "$manifest" ]] || return 0
  local flagged
  flagged=$(awk '
    /^[[:space:]]*-[[:space:]]*key:/ { url=""; flag=0 }
    /^[[:space:]]*service_url:/ { u=$0; sub(/.*service_url:[[:space:]]*/,"",u); gsub(/^"|"$/,"",u); url=u }
    /^[[:space:]]*git_remote:[[:space:]]*true/ { flag=1 }
    flag && url != "" { print url; exit }
  ' "$manifest" 2>/dev/null)
  if [[ -n "$flagged" ]]; then echo "$flagged"; return 0; fi
  local git_urls count
  git_urls=$(grep -E '^[[:space:]]*service_url:' "$manifest" 2>/dev/null \
    | sed -E 's/.*service_url:[[:space:]]*"?([^"]*)"?.*/\1/' \
    | grep -E '\.git$' | grep -v '^$' | sort -u)
  count=$(echo "$git_urls" | grep -c . )
  if [[ "$count" == "1" ]]; then echo "$git_urls"; return 0; fi
  return 0
}

_check_remote_alignment() {
  local manifest_url; manifest_url="$(_manifest_git_url)"
  [[ -z "$manifest_url" ]] && return 0
  local cur norm_cur norm_manifest
  cur="$(_dp_remote_url)"
  norm_cur=$(echo "$cur" | sed -E 's#\.git/?$##; s#/$##')
  norm_manifest=$(echo "$manifest_url" | sed -E 's#\.git/?$##; s#/$##')
  [[ "$norm_cur" == "$norm_manifest" ]] && return 0
  echo ""
  echo "⚠️  git remote ≠ secrets-manifest (manifest — источник правды о git-remote):"
  echo "    git remote origin : ${cur}"
  echo "    manifest service_url: ${manifest_url}  (ты вводил его при добавлении git-секрета)"
  echo ""
  printf "    Выровнять? git remote set-url origin %s (y/n): " "$manifest_url"
  local _ans; read -r _ans
  case "$_ans" in
    y|Y|yes|YES)
      if git remote set-url origin "$manifest_url"; then
        _wire_credential_helper
        _ensure_gh_account
        echo "    ✅ remote выровнен под manifest → ${manifest_url}"
      else
        echo "    ❌ git remote set-url не прошёл — продолжаю с текущим remote."
      fi ;;
    *) echo "    Оставлен текущий remote. Push пойдёт в ${cur}." ;;
  esac
}

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
  elif echo "$err" | grep -qiE 'GH006|protected branch|refusing to allow|cannot be pushed'; then
    echo "   🔒 Branch protection active on ${url} (GH006)."
    echo "      Direct push to '${PROTECTED_BRANCH:-main}' is blocked — this is expected."
    echo "      ✅ Normal path: deploy-push.sh creates a PR (auto-merge) — no action needed."
    echo "      🚨 Emergency bypass: bash scripts/setup-branch-protection.sh --off --yes"
    echo "                           git push ... && bash scripts/setup-branch-protection.sh"
  elif echo "$err" | grep -qiE '403|permission|denied|forbidden|access denied'; then
    echo "   🔒 Доступ запрещён (403)."
    case "$url" in
      https://github.com/*)
        if command -v gh >/dev/null 2>&1; then
          local owner active
          owner="$(gh_owner_from_url "$url")"
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

# ---------------------------------------------------------------------------
# Maps-coverage gate (PLAN-A v5.47.0): methodology-platform only.
# Double guard: [ -d commands ] — only methodology-platform has commands/ source dir.
# [ -f scripts/sync-methodology.sh ] — second guard: consumers may have commands/ copy.
# Both guards must pass → we're in methodology-platform → run the gate.
# ---------------------------------------------------------------------------
if [ -d "commands" ] && [ -f "scripts/sync-methodology.sh" ]; then
  # Dual-copy parity gate (G-122 / ADR-014): drift между scripts/ и templates/scripts/
  # всегда баг — error-severity (блок), не WARN. Запускается ПЕРВЫМ: расхождение копий
  # делает остальные gates недостоверными (они исполняют возможно-устаревший канон).
  if [ -f "scripts/validate-script-parity.sh" ]; then
    echo "▶ Script-parity gate (methodology-platform)..."
    _PARITY_EXIT=0
    bash scripts/validate-script-parity.sh || _PARITY_EXIT=$?
    if [ "$_PARITY_EXIT" -eq 1 ]; then
      echo "❌ BLOCKED: dual-copy drift — выровняй пары scripts/ ↔ templates/scripts/, затем повтори деплой." >&2
      exit 1
    elif [ "$_PARITY_EXIT" -eq 2 ]; then
      echo "⚡ Script-parity: SKIP (not methodology-platform) — OK."
    fi
  fi
  # Schema↔skill parity detector (G-120): новое поле consumer-facing schema без зеркала
  # в парном knowledge-skill (SKILL.md) → механизм невидим агенту в runtime. L3 DETECT
  # (token-presence, не семантика) → severity=warn (surfaced, не блок) чтобы не brittle и
  # без whitelist-slope. Escalate вручную: SCHEMA_SKILL_SEVERITY=error.
  if [ -f "scripts/validate-schema-skill-parity.sh" ]; then
    echo "▶ Schema↔skill parity detector (methodology-platform)..."
    bash scripts/validate-schema-skill-parity.sh || true   # warn-severity → не блокирует деплой
  fi
  # Work-home hygiene detector (artifact-storage-rule): scratch/draft-файлы в корне вне work/.
  # warn-severity (|| true) → НЕ блокирует деплой (Ось 5: эскалация warn→error по evidence
  # рецидива, но счётчик-видимость работает с дня 1). Делает litter видимым на каждом деплое.
  if [ -f "scripts/validate-work-home.sh" ]; then
    echo "▶ Work-home hygiene detector (methodology-platform)..."
    bash scripts/validate-work-home.sh || true
  fi
  # Validator-harness gate (PLAN-03 / G-112): proof-of-rejection — доказать что сами
  # валидаторы отклоняют плохой ввод, прежде чем доверять их PASS в maps-coverage.
  # Guard: if [ -f ... ] — graceful skip если harness не установлен (migration-window).
  if [ -f "scripts/test-validators.sh" ]; then
    echo "▶ Validator-harness gate (methodology-platform)..."
    if ! bash scripts/test-validators.sh; then
      echo "❌ BLOCKED: валидатор не отклонил плохой ввод (false-green, G-112). Почини валидатор/фикстур." >&2
      exit 1
    fi
  fi
  # GH-accounts correctness warn (council [opinion:git-account-ssot], v7.24.0):
  # gh_account стало OPTIONAL pre-seed — derivation = lib/gh-account.sh (learned cache →
  # URL-owner). Раньше это был presence-gate (exit 1 если поле отсутствует), но он ПРОПУСКАЛ
  # инцидент 2026-06-30 (поле было PRESENT но STALE). Теперь warn-only: surfaces stale
  # pre-seed, не блокирует (URL/cache побеждают). Graceful-skip если скрипт отсутствует.
  if [ -f "scripts/validate-gh-accounts.sh" ]; then
    echo "▶ GH-accounts correctness warn (methodology-platform)..."
    bash scripts/validate-gh-accounts.sh || true   # warn-only — никогда не блокирует
  fi
  echo "▶ Maps-coverage gate (methodology-platform)..."
  # tee-pattern: show output in realtime AND capture for WARN count (G-119 surfacing)
  _MAPS_TMP="$(mktemp)"
  bash scripts/validate-maps-coverage.sh 2>&1 | tee "$_MAPS_TMP"
  _MAPS_EXIT="${PIPESTATUS[0]}"
  _MAPS_WARN_COUNT="$(grep -c '^\[WARN\]' "$_MAPS_TMP" 2>/dev/null || true)"
  rm -f "$_MAPS_TMP"
  if [ "$_MAPS_EXIT" -ne 0 ]; then
    echo "❌ BLOCKED: maps coverage failed — добавь недостающие строки карт, затем повтори деплой." >&2
    exit 1
  fi
  # Mermaid links gate (amendment): artifact-agnostic — catches stale/missing links
  # in ANY .md with mermaid (living maps, Design Specs, future artifact types).
  DOC_ROOT_RESOLVED="$(bash scripts/validate-maps-coverage.sh --print-doc-root 2>/dev/null || true)"
  echo "▶ Mermaid links gate (code repo)..."
  _MERMAID_EXIT=0
  bash scripts/validate-mermaid-links.sh || _MERMAID_EXIT=$?
  if [ "$_MERMAID_EXIT" -eq 1 ]; then
    echo "❌ BLOCKED: stale or missing mermaid.live links in code repo." >&2
    exit 1
  elif [ "$_MERMAID_EXIT" -eq 2 ]; then
    echo "⚡ Mermaid links (code repo): SKIP — no .md files found."
  fi
  if [ -n "$DOC_ROOT_RESOLVED" ]; then
    echo "▶ Mermaid links gate (doc repo: $DOC_ROOT_RESOLVED)..."
    _MERMAID_DOC_EXIT=0
    bash scripts/validate-mermaid-links.sh --root "$DOC_ROOT_RESOLVED" || _MERMAID_DOC_EXIT=$?
    if [ "$_MERMAID_DOC_EXIT" -eq 1 ]; then
      echo "❌ BLOCKED: stale or missing mermaid.live links in doc repo." >&2
      exit 1
    elif [ "$_MERMAID_DOC_EXIT" -eq 2 ]; then
      echo "⚡ Mermaid links (doc repo): SKIP — no .md files found."
    fi
  fi
  echo "✅ Maps-coverage gate passed."
  # Explicit WARN surfacing: WARNs don't block deploy but must not be invisible (G-119, RPN=384)
  if [ "${_MAPS_WARN_COUNT:-0}" -gt 0 ]; then
    echo "" >&2
    echo "⚠️  ${_MAPS_WARN_COUNT} предупреждений карт — проверь [WARN] выше перед следующим деплоем." >&2
  fi
  echo ""
fi

# Monotonic VERSION guard (SYS-007): prevents parallel-worktree VERSION collision.
# If HEAD on integration branch already has VERSION >= our local, auto-bump to HEAD+1.
# Fail-safe: network error or missing VERSION → silently skip (no block).
_bump_version_monotonic() {
  [ -f "VERSION" ] || return 0
  local_ver="$(cat VERSION | tr -d '[:space:]')"
  [ -z "$local_ver" ] && return 0
  git fetch origin "$INTEGRATION_BRANCH" --quiet 2>/dev/null || return 0
  head_ver="$(git show "origin/${INTEGRATION_BRANCH}:VERSION" 2>/dev/null | tr -d '[:space:]')"
  [ -z "$head_ver" ] && return 0
  _lv="${local_ver#v}"; _hv="${head_ver#v}"
  l_maj="$(echo "$_lv" | cut -d. -f1)"; l_min="$(echo "$_lv" | cut -d. -f2)"; l_pat="$(echo "$_lv" | cut -d. -f3)"
  h_maj="$(echo "$_hv" | cut -d. -f1)"; h_min="$(echo "$_hv" | cut -d. -f2)"; h_pat="$(echo "$_hv" | cut -d. -f3)"
  for _c in "$l_maj" "$l_min" "$l_pat" "$h_maj" "$h_min" "$h_pat"; do
    case "$_c" in *[!0-9]*) return 0;; esac
  done
  l_score=$(( l_maj * 10000 + l_min * 100 + l_pat ))
  h_score=$(( h_maj * 10000 + h_min * 100 + h_pat ))
  if [ "$h_score" -ge "$l_score" ]; then
    new_pat=$(( h_pat + 1 ))
    new_ver="v${h_maj}.${h_min}.${new_pat}"
    echo "⚡ VERSION race: HEAD=${head_ver} >= local=${local_ver} → monotonic bump to ${new_ver}"
    echo "$new_ver" > VERSION
    git commit VERSION -m "chore(version): monotonic bump ${local_ver}→${new_ver} (parallel deploy race)"
  fi
}
_bump_version_monotonic

# Log-merge section-count guard (G-117 companion): WARN if union merge-driver
# regressed (append-log sections shrank vs HEAD). Non-blocking — surfaces only.
if [ -f "scripts/validate-log-merge.sh" ]; then
  bash scripts/validate-log-merge.sh HEAD >/dev/null 2>&1 || \
    echo "⚠️  validate-log-merge: проверь секции журналов (union merge-driver?)" >&2
fi

# Pre-push: SSOT alignment (closes P-006) — сверить remote с manifest ДО push.
_check_remote_alignment

if [[ "$MODE" == "team" ]]; then
  echo "▶ Team mode → git push origin ${PUSH_BRANCH}:${PUSH_BRANCH}"
  _push origin "${PUSH_BRANCH}:${PUSH_BRANCH}" || exit 1
  _persist_gh_cache   # success → learn (remote-URL → active account)
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
    # Retry once: GitHub can transiently report "not mergeable" immediately after pr create
    # when branch protection is enabled (merge-conflict-detection runs async).
    if ! gh pr merge "$PR_URL" --merge --delete-branch=false 2>/dev/null; then
      echo "  ⏳ Merge transient failure — retrying in 3s..."
      sleep 3
      gh pr merge "$PR_URL" --merge --delete-branch=false
    fi
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
  _persist_gh_cache   # success → learn (remote-URL → active account)
  echo ""
  echo "✅ Deployed to ${PRODUCTION_BRANCH}"
fi

# Self-apply: синхронизировать .claude/ только для methodology-platform.
# Guard: commands/ source dir + sync-methodology.sh должны существовать.
# Consumers получат только один из этих признаков, не оба → guard false → skip.
if [ -d "commands" ] && [ -f "scripts/sync-methodology.sh" ]; then
  echo ""
  echo "▶ Self-apply (methodology-platform): bash scripts/sync-methodology.sh ."
  bash scripts/sync-methodology.sh .
  echo "✅ Self-applied"
fi
