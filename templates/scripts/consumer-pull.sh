#!/usr/bin/env bash
#
# consumer-pull.sh — pull all workspace repos from remote (ff-only).
#
# Reads .code-workspace to discover all repos, then for each:
#   git fetch origin <agent_branch>
#   git pull --ff-only origin <agent_branch>
#
# Skips: it-dev-methodology (methodology source — pulled separately via sync-methodology.sh)
# Includes: all other repos including *-documentation repos
#
# Usage:
#   bash scripts/consumer-pull.sh
#
# Config read from CLAUDE.local.md:
#   ## Consumers → workspace_file  (path to .code-workspace, relative to repo root)
#   ## Branching → agent_branch    (default branch per repo from its CLAUDE.local.md)
#
# ⚠️  MUST be run from WITHIN a repo that has .claude/hooks/ present.
#    Claude Code hooks use relative paths — if CWD lacks .claude/, ALL Bash
#    commands fail including cd, echo, git. Run /pull from your project's own
#    session, not from another repo's session context.

set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SELF_DIR/.." && pwd)"
CONFIG="${CONSUMER_PULL_CONFIG:-${REPO_ROOT}/CLAUDE.local.md}"

# ---------------------------------------------------------------------------
# Hook-safety guard
# ---------------------------------------------------------------------------
if [[ ! -d "${REPO_ROOT}/.claude" ]]; then
  echo "❌ Нет .claude/ в корне репо: ${REPO_ROOT}"
  echo "   Запускай /pull из сессии своего проекта, не из соседнего репо."
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_get_field() {
  local file="$1" section="$2" field="$3" default="$4"
  if [[ ! -f "$file" ]]; then echo "$default"; return; fi
  local value
  value=$(awk "/^## ${section}/{f=1; next} /^## /{f=0} f{print}" "$file" \
          | grep -E "^[[:space:]]*${field}:" | head -1 \
          | sed "s/.*${field}:[[:space:]]*//" | sed 's/[[:space:]]*#.*$//' | tr -d '\r[:space:]')
  echo "${value:-$default}"
}

_sanitize() {
  sed 's/x-access-token:[^@]*@/x-access-token:***@/g' \
  | sed 's/oauth2:[^@]*@/oauth2:***@/g' \
  | sed 's|https://[^:]*:[^@]*@|https://***:***@|g'
}

# ---------------------------------------------------------------------------
# Discover workspace file
# ---------------------------------------------------------------------------
WORKSPACE_FILE_REL=$(_get_field "$CONFIG" "Consumers" "workspace_file" "")
if [[ -n "$WORKSPACE_FILE_REL" ]]; then
  WORKSPACE_FILE="$(cd "$REPO_ROOT" && cd "$(dirname "$WORKSPACE_FILE_REL")" 2>/dev/null && pwd)/$(basename "$WORKSPACE_FILE_REL")"
else
  WORKSPACE_FILE=$(ls "$REPO_ROOT"/../*.code-workspace 2>/dev/null | head -1 || true)
fi

if [[ -z "$WORKSPACE_FILE" || ! -f "$WORKSPACE_FILE" ]]; then
  echo "❌ .code-workspace не найден."
  echo "   Укажи workspace_file в CLAUDE.local.md ## Consumers"
  echo "   или добавь .code-workspace в родительскую директорию."
  exit 1
fi

echo "Workspace: ${WORKSPACE_FILE}"

# ---------------------------------------------------------------------------
# Parse workspace repos via Python (avoid bash JSON parsing)
# Interpreter-резолвер (closes G-097, рецидив G-081): на Windows доступен только
# `py` (Python Launcher), python3 отсутствует. Пробуем py → python3 → python.
# Без резолвера скрипт падал на голом `python3` → деградировал в «пуллю вручную».
# ---------------------------------------------------------------------------
PYTHON_BIN=""
for _cmd in py python3 python; do
  if command -v "$_cmd" >/dev/null 2>&1; then PYTHON_BIN="$_cmd"; break; fi
done
if [[ -z "$PYTHON_BIN" ]]; then
  echo "❌ Python не найден (пробовал: py, python3, python). Установи Python или добавь в PATH."
  exit 1
fi

REPOS_RAW=$("$PYTHON_BIN" -c "
import json, sys, pathlib
ws = pathlib.Path(sys.argv[1])
ws_dir = ws.parent
try:
    data = json.loads(ws.read_text(encoding='utf-8'))
except Exception as e:
    print('ERROR:' + str(e), file=sys.stderr)
    sys.exit(1)
for f in data.get('folders', []):
    p = (ws_dir / f['path']).resolve()
    print(p)
" "$WORKSPACE_FILE" 2>&1) || {
  echo "❌ Не удалось распарсить workspace: $REPOS_RAW"
  exit 1
}

# ---------------------------------------------------------------------------
# Methodology repo name — skip it
# ---------------------------------------------------------------------------
METHODOLOGY_REPO_NAME="it-dev-methodology"

# ---------------------------------------------------------------------------
# Pull loop
# ---------------------------------------------------------------------------
PULLED=0
UP_TO_DATE=0
SKIPPED=0
ERRORS=0
TOTAL=0

echo ""

while IFS= read -r repo_path; do
  [[ -z "$repo_path" ]] && continue
  [[ ! -d "$repo_path" ]] && continue
  [[ ! -d "${repo_path}/.git" ]] && continue

  repo_name="$(basename "$repo_path")"

  # Skip methodology source repo
  if [[ "$repo_name" == "$METHODOLOGY_REPO_NAME" ]]; then
    echo "⏭  ${repo_name} — пропущен (methodology source)"
    continue
  fi

  TOTAL=$((TOTAL + 1))

  # Read agent_branch from this repo's CLAUDE.local.md
  branch=$(_get_field "${repo_path}/CLAUDE.local.md" "Branching" "agent_branch" "ai-dev")

  echo "── ${repo_name} (branch: ${branch})"

  # Check remote exists
  remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || true)
  if [[ -z "$remote_url" ]]; then
    echo "   ✗ SKIP — no origin remote"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Check uncommitted changes
  if ! git -C "$repo_path" diff --quiet 2>/dev/null || \
     ! git -C "$repo_path" diff --cached --quiet 2>/dev/null; then
    echo "   ✗ SKIP — незакоммиченные изменения (stash и повтори)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Check we're on the right branch (or branch exists)
  current_branch=$(git -C "$repo_path" symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [[ -z "$current_branch" ]]; then
    echo "   ✗ SKIP — detached HEAD"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  if [[ "$current_branch" != "$branch" ]]; then
    echo "   ⚠  текущая ветка: ${current_branch}, ожидалась: ${branch} — переключаюсь"
    git -C "$repo_path" checkout "$branch" 2>/dev/null || {
      echo "   ✗ SKIP — не удалось переключиться на ${branch}"
      SKIPPED=$((SKIPPED + 1))
      continue
    }
  fi

  prev_sha=$(git -C "$repo_path" rev-parse HEAD 2>/dev/null || true)

  # Fetch
  fetch_out=$(git -C "$repo_path" fetch origin "$branch" 2>&1 | _sanitize || true)
  fetch_exit=$?
  if [[ $fetch_exit -ne 0 ]]; then
    echo "   ✗ SKIP — fetch failed: $(echo "$fetch_out" | head -2)"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check incoming
  incoming=$(git -C "$repo_path" log --oneline "${branch}..origin/${branch}" 2>/dev/null || true)
  if [[ -z "$incoming" ]]; then
    echo "   ✓ up to date"
    UP_TO_DATE=$((UP_TO_DATE + 1))
    continue
  fi

  # Pull --ff-only
  pull_out=$(git -C "$repo_path" pull --ff-only origin "$branch" 2>&1 | _sanitize || true)
  pull_exit=$?
  if [[ $pull_exit -ne 0 ]]; then
    echo "   ✗ SKIP — ff-only failed (история разошлась)"
    echo "      git log --oneline --graph origin/${branch}...${branch}"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  head_sha=$(git -C "$repo_path" rev-parse HEAD 2>/dev/null || true)
  n_commits=$(git -C "$repo_path" log --oneline "${prev_sha}..${head_sha}" 2>/dev/null | wc -l | tr -d ' ')
  echo "   ✓ pulled ${n_commits} коммит(ов)"
  echo "$incoming" | head -5 | sed 's/^/      /'
  PULLED=$((PULLED + 1))

done <<< "$REPOS_RAW"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "────────────────────────────────"
echo "✅ /pull done"
echo "   Repos: ${TOTAL} обработано"
echo "   Pulled: ${PULLED}  |  Up to date: ${UP_TO_DATE}  |  Skipped: ${SKIPPED}  |  Errors: ${ERRORS}"
if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "   ⚠  ${ERRORS} репо с ошибками — проверь вывод выше."
  echo "      Типичные причины: ff-only failed (rebase нужен), fetch auth error."
fi
