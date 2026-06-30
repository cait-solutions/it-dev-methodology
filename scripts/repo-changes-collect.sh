#!/usr/bin/env bash
#
# repo-changes-collect.sh — READ-ONLY collector of recent repo changes across the
# workspace. Dumps raw, structured per-repo data for /last-repo-changes to synthesize
# into a plain-language report. Never pulls, never mutates branches.
#
# Usage:
#   bash scripts/repo-changes-collect.sh [WINDOW] [--no-fetch]
#     WINDOW (optional):
#       <N>          last N commits on the current branch (e.g. 30)
#       <since>      git --since spec (e.g. "3 days ago", "2026-06-28")
#       (default)    delta of the last pull/merge (ORIG_HEAD..HEAD); fallback: last 25
#     --no-fetch     skip git fetch (use cached refs — fast after /pull)
#
# Per repo it emits four blocks:
#   DIVERGENCE  — ahead/behind per local branch vs its upstream
#   PULLED      — what the last pull/merge landed (full commit messages + DEVLOG diff)
#   AVAILABLE   — what's on remote but not yet local (full messages + DEVLOG diff)
#   STRUCTURAL  — diffstat with rename detection (file moves / restructures)
#
# Causality source of truth = the incoming DEVLOG.md diff ([fix:X]/[feat:X] entries
# written by the author), NOT reconstruction from diffstat. DEVLOG lives in the
# *-documentation repo (two-repo); code-repos without DEVLOG fall back to commit bodies.
#
# ⚠️  MUST be run from WITHIN a repo that has .claude/ present (hook-relative paths).

set -uo pipefail   # NOT -e: per-repo git failures must be graceful, not abort the run

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/.." && pwd)"

# --- Hook-safety guard -------------------------------------------------------
if [[ ! -d "${REPO_ROOT}/.claude" ]]; then
  echo "❌ Нет .claude/ в корне репо: ${REPO_ROOT}"
  echo "   Запускай /last-repo-changes из сессии своего проекта, не из соседнего репо."
  exit 1
fi

# --- Args --------------------------------------------------------------------
WINDOW=""
DO_FETCH=1
for arg in "$@"; do
  case "$arg" in
    --no-fetch) DO_FETCH=0 ;;
    *) WINDOW="$arg" ;;
  esac
done

# --- Load shared workspace enumerator (with inline fallback if lib absent) ----
LIB="${SELF_DIR}/lib/read-workspace-repos.sh"
if [[ -f "$LIB" ]]; then
  # shellcheck disable=SC1090
  . "$LIB"
else
  echo "⚠  lib/read-workspace-repos.sh не найдена — sync методологию (PLAN-D lib)."
  echo "   Использую inline-fallback энумератор."
  _rwr_get_field() {
    local file="$1" section="$2" field="$3" default="$4"
    [[ -f "$file" ]] || { echo "$default"; return; }
    local v; v=$(awk "/^## ${section}/{f=1; next} /^## /{f=0} f{print}" "$file" \
          | grep -E "^[[:space:]]*${field}:" | head -1 \
          | sed "s/.*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '\r')
    echo "${v:-$default}"
  }
  read_workspace_repos() {
    local cfg="${1:-${REPO_ROOT}/CLAUDE.local.md}" py="" _c
    for _c in py python3 python; do command -v "$_c" >/dev/null 2>&1 && { py="$_c"; break; }; done
    [[ -z "$py" ]] && { echo "no python" >&2; return 1; }
    local ws_rel ws_file
    ws_rel=$(_rwr_get_field "$cfg" "Consumers" "workspace_file" "")
    if [[ -n "$ws_rel" ]]; then
      ws_file="$(cd "$REPO_ROOT" && cd "$(dirname "$ws_rel")" 2>/dev/null && pwd)/$(basename "$ws_rel")"
    else
      ws_file=$(ls "$REPO_ROOT"/../*.code-workspace 2>/dev/null | head -1 || true)
    fi
    [[ -z "$ws_file" || ! -f "$ws_file" ]] && { echo "no workspace" >&2; return 1; }
    "$py" -c "
import json,sys,pathlib
ws=pathlib.Path(sys.argv[1]); d=ws.parent
data=json.loads(ws.read_text(encoding='utf-8'))
for f in data.get('folders',[]): print((d/f['path']).resolve())
" "$ws_file" 2>/dev/null | tr -d '\r' | while IFS= read -r p; do
      [[ -d "$p/.git" ]] || continue
      [[ "$(basename "$p")" == "it-dev-methodology" ]] && continue
      printf '%s\t%s\n' "$p" "$(_rwr_get_field "$p/CLAUDE.local.md" "Branching" "agent_branch" "ai-dev")"
    done
  }
fi

_sanitize() {
  sed 's/x-access-token:[^@]*@/x-access-token:***@/g' \
  | sed 's/oauth2:[^@]*@/oauth2:***@/g' \
  | sed 's|https://[^:]*:[^@]*@|https://***:***@|g'
}

REPOS_RAW=$(read_workspace_repos) || {
  echo "❌ Не удалось перечислить repos workspace. Проверь workspace_file в CLAUDE.local.md ## Consumers."
  exit 1
}

echo "# RAW repo changes (read-only collect) — для синтеза /last-repo-changes"
[[ "$DO_FETCH" -eq 1 ]] && echo "# fetch: ON" || echo "# fetch: OFF (--no-fetch, по кэшу)"
[[ -n "$WINDOW" ]] && echo "# window: ${WINDOW}" || echo "# window: last-pull delta (ORIG_HEAD..HEAD), fallback last 25"
echo ""

# Resolve range base for the PULLED block, given current branch.
_pulled_base() {
  local rp="$1" head_sha="$2"
  if [[ -n "$WINDOW" ]]; then
    if [[ "$WINDOW" =~ ^[0-9]+$ ]]; then
      git -C "$rp" rev-parse "HEAD~${WINDOW}" 2>/dev/null || git -C "$rp" rev-list --max-parents=0 HEAD 2>/dev/null | head -1
    else
      # since-spec: base = first commit before the since window
      git -C "$rp" rev-list -1 --before="$WINDOW" HEAD 2>/dev/null || echo ""
    fi
    return
  fi
  # default: last pull/merge delta via ORIG_HEAD if it's a real ancestor
  local orig; orig=$(git -C "$rp" rev-parse --verify -q ORIG_HEAD 2>/dev/null || true)
  if [[ -n "$orig" ]] && git -C "$rp" merge-base --is-ancestor "$orig" "$head_sha" 2>/dev/null && [[ "$orig" != "$head_sha" ]]; then
    echo "$orig"
  else
    git -C "$rp" rev-parse "HEAD~25" 2>/dev/null || git -C "$rp" rev-list --max-parents=0 HEAD 2>/dev/null | head -1
  fi
}

# DEVLOG diff for a range — added lines only (the new author-written entries).
_devlog_diff() {
  local rp="$1" range="$2"
  [[ -f "$rp/DEVLOG.md" ]] || { echo "  (нет DEVLOG.md в этом репо — причина из commit-сообщений)"; return; }
  local d; d=$(git -C "$rp" diff "$range" -- DEVLOG.md 2>/dev/null | grep -E '^\+' | grep -v '^+++' | sed 's/^+//' | grep -vE '^[[:space:]]*$' | head -40 || true)
  if [[ -n "$d" ]]; then printf '%s\n' "$d" | sed 's/^/  │ /'; else echo "  (DEVLOG без новых строк в диапазоне)"; fi
}

while IFS=$'\t' read -r repo_path branch; do
  [[ -z "$repo_path" ]] && continue
  [[ ! -d "$repo_path/.git" ]] && continue
  repo_name="$(basename "$repo_path")"

  echo "════════════════════════════════════════════════════"
  echo "## ${repo_name}  (agent_branch intent: ${branch})"

  if [[ -z "$(git -C "$repo_path" remote get-url origin 2>/dev/null || true)" ]]; then
    echo "   ✗ нет origin remote — пропуск"; echo ""; continue
  fi
  cur=$(git -C "$repo_path" symbolic-ref --short HEAD 2>/dev/null || echo "")
  [[ -z "$cur" ]] && { echo "   ✗ detached HEAD — пропуск"; echo ""; continue; }

  if [[ "$DO_FETCH" -eq 1 ]]; then
    if ! git -C "$repo_path" fetch origin >/dev/null 2>&1; then
      echo "   ⚠  fetch не прошёл (auth/network?) — данные по кэшу, могут быть stale"
    fi
  fi

  head_sha=$(git -C "$repo_path" rev-parse HEAD 2>/dev/null || true)

  # --- DIVERGENCE: ahead/behind per branch vs upstream ----------------------
  echo "### DIVERGENCE (ветка: ahead/behind vs upstream)"
  any_div=0
  while IFS=' ' read -r lref uref; do
    [[ -z "$lref" || -z "$uref" ]] && continue
    counts=$(git -C "$repo_path" rev-list --left-right --count "${lref}...${uref}" 2>/dev/null | tr -d '\r' || true)
    [[ -z "$counts" ]] && continue
    a=$(echo "$counts" | awk '{print $1}'); b=$(echo "$counts" | awk '{print $2}')
    if [[ "${a:-0}" -gt 0 || "${b:-0}" -gt 0 ]]; then
      mark=""; [[ "$lref" == "$cur" ]] && mark=" (текущая)"
      echo "   ⚠  ${lref}: ahead ${a}, behind ${b}${mark}"; any_div=1
    fi
  done < <(git -C "$repo_path" for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads/ 2>/dev/null | tr -d '\r')
  [[ "$any_div" -eq 0 ]] && echo "   ✓ все ветки в синке с upstream"

  # --- PULLED: last pull/merge delta on current branch ----------------------
  base=$(_pulled_base "$repo_path" "$head_sha")
  echo "### PULLED — что подтянулось/наработано недавно на ${cur}"
  if [[ -n "$base" && "$base" != "$head_sha" ]]; then
    pulled=$(git -C "$repo_path" log --format='• %h %s%n    %b' "${base}..${head_sha}" 2>/dev/null | sed 's/^/   /' | head -60 || true)
    if [[ -n "$pulled" ]]; then
      printf '%s\n' "$pulled"
      echo "   ── DEVLOG (причины, источник правды):"
      _devlog_diff "$repo_path" "${base}..${head_sha}"
    else
      echo "   (нет коммитов в диапазоне)"
    fi
  else
    echo "   (нет недавнего диапазона — свежий репо или нет ORIG_HEAD)"
  fi

  # --- AVAILABLE: on remote, not yet local ----------------------------------
  echo "### AVAILABLE — на remote, ещё НЕ локально (origin/${cur})"
  if git -C "$repo_path" show-ref --verify --quiet "refs/remotes/origin/${cur}"; then
    avail=$(git -C "$repo_path" log --format='• %h %s%n    %b' "${cur}..origin/${cur}" 2>/dev/null | sed 's/^/   /' | head -40 || true)
    if [[ -n "$avail" ]]; then
      printf '%s\n' "$avail"
      echo "   ── DEVLOG входящих (причины):"
      _devlog_diff "$repo_path" "${cur}..origin/${cur}"
    else
      echo "   ✓ нечего тянуть (локально актуально)"
    fi
  else
    echo "   (нет origin/${cur} — локальная ветка без upstream)"
  fi

  # --- STRUCTURAL: diffstat with rename detection ---------------------------
  echo "### STRUCTURAL — изменения файлов (renames/moves) в PULLED диапазоне"
  if [[ -n "$base" && "$base" != "$head_sha" ]]; then
    git -C "$repo_path" diff --stat -M "${base}..${head_sha}" 2>/dev/null | sed 's/^/   /' | head -30 || echo "   (нет)"
  else
    echo "   (нет диапазона)"
  fi
  echo ""
done <<< "$REPOS_RAW"

echo "════════════════════════════════════════════════════"
echo "# Конец сырых данных. Синтезируй отчёт простым языком, сгруппированный по смыслу."
