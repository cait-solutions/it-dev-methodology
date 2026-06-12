#!/usr/bin/env sh
#
# maps-freshness-liveness.sh — fate-independent maps-link freshness detector (L4).
#
# WHY (closes BS-4 / P-009 trigger-path-gap):
#   post-edit-watchdog.py (PostToolUse, matcher Edit|Write) авто-обновляет mermaid-ссылки
#   ТОЛЬКО когда агент правит .md с mermaid через Edit/Write tool. Слепые пути:
#     • правка карты через Bash (sed -i / >> / mv / cp / tee) — нет Edit/Write события;
#     • изменение кода/команды/скрипта — карта устаревает по содержанию, но сам .md
#       с mermaid не редактировался → pattern ```mermaid не встретился в diff → hook молчит.
#   Итог: «гарантия актуальности при изменениях агентом БЕЗ команды /code» (запрос владельца)
#   покрывала только Edit/Write по .md. Этот hook закрывает ОСТАЛЬНЫЕ пути post-hoc.
#
# FIX: SessionStart hook (pure POSIX sh, вызывается НАПРЯМУЮ — sh .claude/hooks/maps-freshness-liveness.sh,
#   БЕЗ run-hook.sh, как hook-liveness.sh). На старте сессии смотрит `git diff` изменённых
#   .md-файлов содержащих ```mermaid → если есть → запускает validate-mermaid-links.sh.
#   STALE_LINK / MISSING_LINK → warning «карта правлена вне /code, ссылки устарели».
#   Git-diff agnostic к ИНСТРУМЕНТУ правки — ловит Edit/Write/Bash/ручное единообразно.
#
#   Комплементарен, НЕ дубль post-edit-watchdog:
#     • post-edit-watchdog (PostToolUse) — реагирует В МОМЕНТ Edit/Write с mermaid (proactive);
#     • maps-freshness-liveness (SessionStart) — ловит ЛЮБОЙ путь правки post-hoc (reactive backstop).
#   Разные failure modes, разное время срабатывания. См. project hook-delivery-triad.
#
# Detection-логика git-diff ЗЕРКАЛИТ hook-liveness.sh философию (fate-independent,
#   pure-sh, БЕЗ run-hook.sh). Любое расхождение при добавлении хука = drift —
#   обновлять /plan Подшаг -0.4 liveness-set синхронно.
#
# POSIX sh (не bash) — Git-Bash (Windows) / dash / sh safe. Зависимости: git, grep + сам
#   validate-mermaid-links.sh (если отсутствует → graceful skip). Non-blocking: всегда exit 0.

set -u

# Расположение: .claude/hooks/ → корень проекта на два уровня выше.
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$HOOK_DIR/../.." && pwd)"

cd "$PROJECT_ROOT" 2>/dev/null || exit 0

# Нет git → нечего диффать (graceful, exit 0).
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# Валидатор отсутствует (consumer на старой версии без mermaid infra) → graceful skip.
VALIDATOR="scripts/validate-mermaid-links.sh"
[ -f "$VALIDATOR" ] || exit 0

# Какие .md изменены относительно HEAD (working tree + staged, без committed-and-pushed).
# --diff-filter=d исключает удаления (удалённый файл нечего валидировать).
changed_md="$(git diff HEAD --name-only --diff-filter=d 2>/dev/null | grep -E '\.md$' || true)"
[ -n "$changed_md" ] || exit 0

# Из изменённых .md — только те что содержат ```mermaid (остальные ссылок не имеют).
maps_changed=""
for f in $changed_md; do
    [ -f "$f" ] || continue
    if grep -q '```mermaid' "$f" 2>/dev/null; then
        maps_changed="$maps_changed $f"
    fi
done
[ -n "$maps_changed" ] || exit 0

# Есть изменённые карты → проверить свежесть ссылок (валидатор работает по --root,
# не по списку файлов; запускаем по корню, --ignore-exit чтобы не падать — нам нужен
# только вывод STALE/MISSING для surfacing, не exit-код).
result="$(bash "$VALIDATOR" --ignore-exit 2>&1 || true)"
stale="$(printf '%s\n' "$result" | grep -E 'STALE_LINK|MISSING_LINK' || true)"

if [ -n "$stale" ]; then
    echo "⚠️ MAPS FRESHNESS (liveness) — изменённые карты содержат устаревшие/отсутствующие mermaid-ссылки:" >&2
    printf '%s\n' "$stale" | sed 's/^/   /' >&2
    echo "   Причина: карта правилась вне /code (Bash-правка, ручное редактирование, или изменён код без обновления карты)." >&2
    echo "   post-edit-watchdog не сработал (нет Edit/Write с mermaid). Рекомендация:" >&2
    echo "     bash scripts/update-mermaid-links.sh   # обновит ссылки во всех .md" >&2
fi

# Non-blocking: всегда exit 0, чтобы не ломать запуск сессии из-за warning.
exit 0
