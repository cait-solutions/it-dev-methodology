#!/usr/bin/env bash
# validate-work-home.sh — hygiene detector: scratch/draft файлы вне work/ (closes artifact-storage-rule).
#
# Назначение: правило хранения артефактов (CLAUDE.md § Artifact Storage Rule) говорит
#   эфемерное → scratchpad (вне репо) / gitignored _tmp_*; продукты работы → work/<stream>/.
# Этот детектор делает РЕЦИДИВ ВИДИМЫМ: warn если scratch/draft-файлы физически лежат в
# корне репо (а не в scratchpad вне репо или в work/). Считает evidence с дня 1 (Ось 5:
# эскалация warn→error откладывается до подтверждённого рецидива, но СЧЁТЧИК работает сразу).
#
# ВАЖНО: использует физический `find` (не `git ls-files`) — намеренно видит и gitignored
# _tmp_* (они не засоряют git, но засоряют рабочее дерево). Это и есть hygiene-visibility.
#
# Severity: warn. deploy-push.sh вызывает с `|| true` — НЕ блокирует деплой (Ось 5).
# Exit 0 = корень чист (или пропущено); Exit 1 = найдены stray-файлы (для test-validators harness).
#
# Usage: bash scripts/validate-work-home.sh [--root DIR]
# Вызывается из: deploy-push.sh methodology-gate (warn-блок, после schema-skill parity).

set -u

ROOT="."
if [ "${1:-}" = "--root" ]; then
  ROOT="${2:-.}"
fi

if [ ! -d "$ROOT" ]; then
  echo "INFO: root '$ROOT' не найден — work-home check N/A."
  exit 0
fi

# Stray-паттерны: scratch/draft/tmp в КОРНЕ (top-level), исключая work/.
# -maxdepth 1: только корень (вложенное в подпапки — не наша забота).
STRAY=$(
  find "$ROOT" -maxdepth 1 \
    \( -name '_tmp_*' -o -name '.tmp-*' -o -name '*.tmp' -o -name '_scratch*' \) \
    2>/dev/null | grep -vE '(^|/)work($|/)' || true
)

if [ -n "$STRAY" ]; then
  echo "[WARN] work-home: scratch/draft-файлы в корне репо (правило: эфемерное → scratchpad вне репо / gitignored; продукты работы → work/<stream>/):"
  echo "$STRAY" | sed 's/^/  /'
  echo "[WARN] переместить в work/<stream>/ (если durable) или удалить/в scratchpad (если эфемерное). См. CLAUDE.md § Artifact Storage Rule."
  exit 1
fi

echo "[ok] work-home hygiene: корень чист (нет stray scratch/draft в root)."
exit 0
