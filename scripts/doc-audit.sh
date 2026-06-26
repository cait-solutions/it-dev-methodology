#!/bin/bash
# doc-audit.sh — полный аудит актуальности документации и диаграмм (реализация /doc-audit)
# Bash 3.2+ compatible (no associative arrays, no ${var,,})
#
# Ручной on-demand прогон ВСЕХ механических валидаторов содержимого одним вызовом —
# в отличие от cadence-аудитов (/architecture-audit ≥5 планов, /retro ≥15) и
# деплой-gate (только перед push). Closes класс «detection фрагментирован,
# нет ручного "проверь всё сейчас"» (G-122 / P-009 remediation-путь).
#
# Оси (каждая graceful-skip если скрипт/вход отсутствует — consumer может не иметь всех):
#   parity         — dual-copy scripts/ ↔ templates/scripts/ (methodology-platform only)
#   maps-coverage  — команды/skills/скрипты в картах + diagram-freshness + node-readability
#   mermaid-links  — mermaid.live URL соответствует коду диаграммы (оба репо)
#   mermaid-syntax — антипаттерны mermaid (транслит и т.п.)
#   links          — внутренние .md ссылки резолвятся
#   doc-freshness  — docs/services/*/OVERVIEW.md «Обновлён:» vs git log
#   lar            — LIVING-ARTIFACTS реестр: файлы существуют
#   artifact-map   — ARTIFACT-MAP консистентность с commands/
#
# НЕ делает: semantic drift диаграмм vs код (/architecture-audit), adoption drift
# методология↔консьюмер (push-consumers delivery). Presence/freshness ≠ semantics (P-009).
#
# Usage: bash scripts/doc-audit.sh [--doc-root DIR] [--fix]
#   --doc-root DIR  корень documentation-репо (two-repo, напр. ../it-dev-methodology-documentation)
#                   default "." (single-repo consumer)
#   --fix           ПЕРЕД проверкой авто-обновить все mermaid.live ссылки
#                   (update-mermaid-links.sh на оба корня) — «проверить И обновить» режим.
#                   Только ссылки (детерминированный fix); содержимое диаграмм/карт не трогает.
# Exit 0 = ошибок нет (WARN допустимы), 1 = есть ошибки.

set -u

DOC_ROOT="."
FIX=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --doc-root) DOC_ROOT="$2"; shift 2 ;;
    --fix)      FIX=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

SUMMARY=""
TOTAL_ERRORS=0
TOTAL_WARNS=0

# _run <axis-name> <warn-grep-pattern> <cmd...>
# Запускает ось, печатает вывод, классифицирует: SKIP / PASS / WARN / FAIL.
_run() {
  axis="$1"; warn_pat="$2"; shift 2
  script_path="$1"
  if [ ! -f "$script_path" ]; then
    SUMMARY="${SUMMARY}
  ⚪ SKIP  ${axis} — скрипт не найден (старая версия методологии или consumer-scope)"
    return 0
  fi
  echo ""
  echo "════ ${axis} ════"
  tmp="$(mktemp)"
  bash "$@" > "$tmp" 2>&1
  rc=$?
  cat "$tmp"
  warns="$(grep -c "$warn_pat" "$tmp" 2>/dev/null)"
  [ -z "$warns" ] && warns=0
  rm -f "$tmp"
  if [ "$rc" -eq 2 ]; then
    # Exit 2 = SKIP (axis not applicable: no docs/services, not a git repo, нет входа).
    # Methodology validators use exit 2 for "не применимо" — это НЕ ошибка. Без этой
    # ветки SKIP ложно классифицировался как FAIL (doc-freshness на two-repo без сервисов).
    SUMMARY="${SUMMARY}
  ⚪ SKIP  ${axis} — не применимо (exit 2)"
  elif [ "$rc" -ne 0 ]; then
    TOTAL_ERRORS=$((TOTAL_ERRORS+1))
    SUMMARY="${SUMMARY}
  🔴 FAIL  ${axis} — exit ${rc} (см. вывод выше)"
  elif [ "$warns" -gt 0 ]; then
    TOTAL_WARNS=$((TOTAL_WARNS+warns))
    SUMMARY="${SUMMARY}
  🟡 WARN  ${axis} — ${warns} предупреждений"
  else
    SUMMARY="${SUMMARY}
  ✅ PASS  ${axis}"
  fi
}

echo "=== doc-audit.sh — полный аудит документации (doc-root: ${DOC_ROOT}) ==="

# --fix: авто-обновление всех mermaid.live ссылок ДО проверки (оба корня).
# Единственный безопасный auto-fix: URL детерминированно генерируется из кода диаграммы.
if [ "$FIX" -eq 1 ] && [ -f "scripts/update-mermaid-links.sh" ]; then
  echo ""
  echo "════ --fix: обновление mermaid-ссылок ════"
  bash scripts/update-mermaid-links.sh || true
  if [ "$DOC_ROOT" != "." ] && [ -d "$DOC_ROOT" ]; then
    bash scripts/update-mermaid-links.sh --root "$DOC_ROOT" || true
  fi
fi

# 1. Dual-copy parity (G-122) — methodology-platform only, внутри guard
_run "parity (dual-copy scripts↔templates)" '^\[ERROR\]' scripts/validate-script-parity.sh

# 1b. Consumer-delivery hygiene — orphan-в-templates/scripts (methodology-platform only, warn)
_run "consumer-delivery (orphan scripts)" '^\[WARN\]' scripts/validate-consumer-delivery.sh

# 2. Maps coverage + diagram-freshness + node-readability (report-режим, не gate)
_run "maps-coverage (+freshness +node-readability)" '^\[WARN\]' scripts/validate-maps-coverage.sh --report

# 3. Mermaid links — код-репо
_run "mermaid-links (code repo)" 'STALE_LINK\|MISSING_LINK' scripts/validate-mermaid-links.sh

# 3b. Mermaid links — doc-репо (two-repo only)
if [ "$DOC_ROOT" != "." ] && [ -d "$DOC_ROOT" ]; then
  _run "mermaid-links (doc repo)" 'STALE_LINK\|MISSING_LINK' scripts/validate-mermaid-links.sh --root "$DOC_ROOT"
fi

# 4. Mermaid syntax-антипаттерны
_run "mermaid-syntax (code repo)" 'WARN' scripts/validate-mermaid-syntax.sh
if [ "$DOC_ROOT" != "." ] && [ -d "$DOC_ROOT" ]; then
  _run "mermaid-syntax (doc repo)" 'WARN' scripts/validate-mermaid-syntax.sh --root "$DOC_ROOT"
fi

# 5. Внутренние ссылки
_run "links (doc root)" 'BROKEN_LINK' scripts/validate-links.sh --root "$DOC_ROOT" --ignore-exit

# 6. OVERVIEW freshness (docs/services — graceful если нет)
_run "doc-freshness (OVERVIEW vs git)" 'STALE\|MISSING' scripts/validate-doc-freshness.sh --root "$DOC_ROOT" --ignore-exit

# 7. Living Artifact Registry — файлы реестра существуют
_run "lar (LIVING-ARTIFACTS registry)" 'WARN' scripts/validate-lar.sh

# 8. ARTIFACT-MAP консистентность
if [ -f "$DOC_ROOT/docs/product/ARTIFACT-MAP.md" ]; then
  _run "artifact-map" 'WARN\|MISSING' scripts/validate-artifact-map.sh --artifact-map "$DOC_ROOT/docs/product/ARTIFACT-MAP.md" --ignore-exit
elif [ -f "docs/product/ARTIFACT-MAP.md" ]; then
  _run "artifact-map" 'WARN\|MISSING' scripts/validate-artifact-map.sh --artifact-map "docs/product/ARTIFACT-MAP.md" --ignore-exit
else
  SUMMARY="${SUMMARY}
  ⚪ SKIP  artifact-map — docs/product/ARTIFACT-MAP.md не найден"
fi

echo ""
echo "════════════════════════════════════════════"
echo "=== doc-audit Summary ===${SUMMARY}"
echo ""
echo "Итого: ${TOTAL_ERRORS} осей с ошибками, ${TOTAL_WARNS} предупреждений."
if [ "$TOTAL_ERRORS" -gt 0 ]; then
  echo "❌ Аудит обнаружил ошибки — см. FAIL-оси выше."
  exit 1
fi
if [ "$TOTAL_WARNS" -gt 0 ]; then
  echo "⚠️  Ошибок нет, но есть WARN-долг — приоритизируй через /plan (WARN сам не исчезнет)."
fi
exit 0
