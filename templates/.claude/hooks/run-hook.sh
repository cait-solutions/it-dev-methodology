#!/usr/bin/env sh
#
# run-hook.sh — interpreter-agnostic launcher for .claude/hooks/*.py
#
# WHY: settings.json hooks были захардкожены под один интерпретатор
# ("python3 .claude/hooks/X.py" или "py ..."). На Windows доступен только `py`
# (Python Launcher), на Linux/Mac — `python3`. Хардкод → hook падает молча на
# "чужой" платформе → SessionStart/PreToolUse/PostToolUse не срабатывают,
# auto-update + sync-audit + security-хуки мертвы без предупреждения. (closes G-081)
#
# FIX: единый резолвер (один источник, не 7 inline-копий в JSON).
# settings.json вызывает: sh .claude/hooks/run-hook.sh <hook-file.py> [args...]
#
# Резолвер: python3 → py → python (первый доступный). Py3.10+ требование
# методологии остаётся; этот скрипт лишь находит ЧЕМ запустить.
#
# POSIX sh (не bash) — максимальная переносимость; Git-Bash (Windows) / dash / sh safe.

set -u

if [ "$#" -lt 1 ]; then
    echo "run-hook.sh: ERROR — no hook file given" >&2
    exit 2
fi

HOOK_FILE="$1"
shift

# Резолвер интерпретатора. python3 первым (Linux/Mac/CI преобладают),
# py для Windows Python Launcher, python — legacy fallback.
PYTHON=""
for _cmd in python3 py python; do
    if command -v "$_cmd" >/dev/null 2>&1; then
        PYTHON="$_cmd"
        break
    fi
done

if [ -z "$PYTHON" ]; then
    echo "run-hook.sh: ERROR — Python не найден (tried: python3, py, python). Hook '$HOOK_FILE' пропущен." >&2
    # exit 0 — не блокировать tool-вызов из-за отсутствия Python (graceful).
    # Hook просто не отработает; методология требует Py3.10+ отдельно.
    exit 0
fi

# Путь к hook относительно расположения этого скрипта (.claude/hooks/).
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_PATH="$HOOK_DIR/$HOOK_FILE"

if [ ! -f "$HOOK_PATH" ]; then
    echo "run-hook.sh: ERROR — hook не найден: $HOOK_PATH" >&2
    exit 0
fi

exec "$PYTHON" "$HOOK_PATH" "$@"
