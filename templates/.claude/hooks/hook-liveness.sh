#!/usr/bin/env sh
#
# hook-liveness.sh — fate-independent hook-existence detector (L4 primary).
#
# WHY (closes G-087 recursive hole — повтор 3-й раз):
#   check_hook_health() ловит «settings.json ссылается на hook которого нет на диске»,
#   НО она живёт ВНУТРИ auto-update-watchdog.py, запускаемого через run-hook.sh.
#   Если отсутствует САМ run-hook.sh — auto-update-watchdog не стартует → check_hook_health
#   не вызывается → дыру некому детектить. Детектор отсутствующих хуков сам недоступен,
#   потому что его раннер отсутствует. Рекурсия.
#   Реальный инцидент: erp синкнут на старую версию, run-hook.sh + iteration-watchdog.py
#   физически отсутствовали, settings.json на них ссылался → все 7 хуков молча падали
#   (sh: run-hook.sh: No such file) → escalation-механизм мёртв, повтор reasoning-залипания.
#
# FIX: этот скрипт — pure POSIX sh, вызывается из SessionStart НАПРЯМУЮ
#   (sh .claude/hooks/hook-liveness.sh), БЕЗ run-hook.sh. Он проверяет наличие на диске
#   каждого hook упомянутого в settings.json — ВКЛЮЧАЯ run-hook.sh. Так он способен
#   сообщить об отсутствии run-hook.sh НЕ используя run-hook.sh. Рекурсия разорвана.
#
#   Комплементарен, НЕ дубль:
#     • check_hook_health (auto-update-watchdog, runtime) — ловит missing-files КОГДА хуки живы;
#     • hook-liveness.sh (SessionStart, БЕЗ run-hook.sh) — ловит missing-files КОГДА run-hook.sh мёртв;
#     • /plan Подшаг -0.4 (always-read команда) — ловит когда hook-подсистема не запущена вовсе.
#   Три fate-independent детектора, разные failure modes. См. project hook-delivery-triad.
#
# Detection-логика ЗЕРКАЛИТ canon: auto-update-watchdog.template.py:211-215
#   (дуальный паттерн: прямой `.claude/hooks/X` + через `run-hook.sh X`, затем -f test).
#   Любое расхождение между детекторами = drift — менять синхронно во всех трёх местах.
#
# POSIX sh (не bash) — Git-Bash (Windows) / dash / sh safe. Zero зависимостей: только
#   grep/sed/test — нет Python, нет run-hook.sh. Его собственное отсутствие = катастрофический
#   no-sync (заметный иначе) — тот же accepted residual что для run-hook.sh.

set -u

# Расположение этого скрипта (.claude/hooks/) → корень проекта на два уровня выше.
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOKS_ROOT="$HOOK_DIR"
SETTINGS="$HOOK_DIR/../settings.json"

# Нет settings.json → bootstrap-ситуация, нечего проверять (graceful, exit 0).
[ -f "$SETTINGS" ] || exit 0

# Извлечь имена hook-файлов из settings.json — ДВА паттерна (зеркало canon regex):
#   1) прямой вызов:   .claude/hooks/X            (ловит run-hook.sh, hook-liveness.sh, *.py)
#   2) через wrapper:  run-hook.sh X              (ловит X.py запускаемые через раннер)
# sort -u — дедуп (run-hook.sh попадёт оба раза: как .claude/hooks/run-hook.sh и не попадёт во 2-й).
referenced="$(
    {
        grep -oE '\.claude/hooks/[A-Za-z0-9._-]+' "$SETTINGS" 2>/dev/null | sed 's#.*\.claude/hooks/##'
        grep -oE 'run-hook\.sh[[:space:]]+[A-Za-z0-9._-]+' "$SETTINGS" 2>/dev/null | sed 's#run-hook\.sh[[:space:]]*##'
    } | sort -u
)"

missing=""
for h in $referenced; do
    [ -z "$h" ] && continue
    if [ ! -f "$HOOKS_ROOT/$h" ]; then
        missing="$missing $h"
    fi
done

if [ -n "$missing" ]; then
    echo "⚠️ HOOK DRIFT (hook-liveness) — settings.json ссылается на отсутствующие hook-файлы:" >&2
    for h in $missing; do
        echo "   • .claude/hooks/$h — НЕ найден на диске" >&2
    done
    echo "   Следствие: эти хуки молча падают (sh: No such file) → защита/детекторы/escalation мертвы." >&2
    echo "   Причина: методология обновилась, но full sync не прогонялся в этом проекте." >&2
    echo "   Рекомендация: запусти 'bash <methodology>/scripts/sync-methodology.sh .' и перезапусти сессию." >&2
fi

# Non-blocking: всегда exit 0, чтобы не ломать запуск сессии из-за warning.
exit 0
