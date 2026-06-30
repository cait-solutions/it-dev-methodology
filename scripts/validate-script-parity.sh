#!/bin/bash
# validate-script-parity.sh — dual-copy parity gate (closes G-122)
# Bash 3.2+ compatible (no associative arrays, no ${var,,})
#
# Контракт dual-copy (ADR-014): каждый скрипт существующий И в scripts/ И в
# templates/scripts/ обязан быть байт-идентичным. Канон = scripts/ (исполняется
# на methodology-platform), templates/scripts/ = consumer-delivery копия.
# Любая правка — синхронно в обе. Намеренные расхождения запрещены (whitelist = slope).
#
# Scope: intersection-only. Файлы существующие только в одной стороне — легитимны:
#   только scripts/            → methodology-internal (sync-methodology.sh, mermaid-link.py)
#   только templates/scripts/  → consumer-only обёртки (consumer-pull.sh и т.п.)
#
# Guard: запускается только на methodology-platform ([ -d commands ]).
# Consumer не имеет dual-copy → exit 2 (SKIP, не PASS).
#
# Usage: bash scripts/validate-script-parity.sh
# Exit 0 = parity OK; Exit 1 = drift найден; Exit 2 = SKIP (не methodology-platform).

set -u

if [ ! -d "commands" ] || [ ! -d "templates/scripts" ]; then
  echo "INFO: not methodology-platform (no commands/ + templates/scripts/) — parity check N/A."
  exit 2
fi

ERRORS=0
CHECKED=0

# Scope: top-level templates/scripts/* AND the lib/ subdir (source-able shared libs,
# e.g. read-workspace-repos.sh, gh-account.sh — also under ADR-014 dual-copy contract).
# Mirror path mapping: templates/scripts/<rel> ↔ scripts/<rel>.
for tf in templates/scripts/* templates/scripts/lib/*; do
  [ -f "$tf" ] || continue
  rel="${tf#templates/scripts/}"   # keeps the lib/ prefix for subdir files
  sf="scripts/$rel"
  [ -f "$sf" ] || continue   # consumer-only файл — не intersection
  CHECKED=$((CHECKED+1))
  if ! diff -q "$sf" "$tf" > /dev/null 2>&1; then
    ERRORS=$((ERRORS+1))
    lines="$(diff "$sf" "$tf" | wc -l | tr -d ' ')"
    s_date="$(git log -1 --format=%ci -- "$sf" 2>/dev/null | cut -c1-10)"
    t_date="$(git log -1 --format=%ci -- "$tf" 2>/dev/null | cut -c1-10)"
    echo "[ERROR] parity: $rel — копии расходятся ($lines diff-строк; scripts/=$s_date templates/=$t_date)"
    echo "        Направление выравнивания: свежая дата = intended → перенеси изменение в отставшую копию."
  fi
done

echo "[INFO]  parity: $CHECKED intersection-пар проверено, $ERRORS drift"

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "❌ Dual-copy drift (G-122 класс): правка одной копии без второй."
  echo "   Выровняй пары выше и повтори. Контракт: ADR-014."
  exit 1
fi
exit 0
