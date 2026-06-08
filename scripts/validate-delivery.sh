#!/usr/bin/env bash
#
# validate-delivery.sh — delivery-consistency validator (closes R-029 / review-blindness class).
#
# WHY (G-087 → G-088 → v5.12.0/v5.12.1, класс «фикс не доезжает молча»):
#   /review был на 100% статическим: проверял «hook wired в settings.template.json»,
#   но НЕ «sync-methodology.sh реально доставит это wiring консьюмеру».
#   v5.12.0: hook-liveness.sh был wired в template, НО merge_settings_json hook_name()
#   распознавал только .py → .sh-вызов не доставлялся. /review дал "0 critical",
#   delivery-баг поймал только /deploy dogfood (post-merge) → пришлось v5.12.1.
#   Класс повторился 3 раза. /review ни разу не поймал доставку.
#
# ЧТО ПРОВЕРЯЕТ — рассогласование template ↔ sync-парсер (точный класс v5.12.0):
#   Для каждого hook-ref в settings.template.json:
#     (1) Файл существует в templates/.claude/hooks/ (с учётом .template strip)?
#     (2) sync-парсеры РАСПОЗНАЮТ этот ref? — sync доставит wiring только если
#         hook_name() (merge_settings_json) И missing_hooks-extraction (sync) его матчат.
#   Рассогласование (ref есть в template, но парсер не распознаёт) → FAIL.
#
# ПОЧЕМУ статический (не реальный sync): v5.12.0-баг = регексное рассогласование
#   template↔parser. Статическая проверка ловит его БЕЗ дорогого реального sync на
#   temp-копию (без side-effects, детерминированно, встраивается в mandatory validator-прогон).
#
# L4 enforcement: вызывается из validate-template-format.sh (который /code Шаг 11 +
#   /review запускают ОБЯЗАТЕЛЬНО и блокируют на FAIL) — не prose-инструкция «не забудь».
#
# ⚠️ Regex здесь ЗЕРКАЛИТ sync-methodology.sh hook_name() (строки ~392-395):
#     run-hook.sh X  +  .claude/hooks/X.(py|sh)
#   Менять СИНХРОННО в обоих местах. Drift = ложный PASS/FAIL.
#
# Usage: bash scripts/validate-delivery.sh [--root DIR]
# Exit: 0 = consistent, 1 = delivery mismatch found

set -uo pipefail

ROOT="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

SETTINGS_TPL="$ROOT/templates/settings.template.json"
HOOKS_DIR="$ROOT/templates/.claude/hooks"
SYNC="$ROOT/scripts/sync-methodology.sh"
VIOLATIONS=0

warn() { echo "  WARNING: $1" >&2; VIOLATIONS=$((VIOLATIONS + 1)); }
ok()   { echo "  ok: $1"; }

echo "validate-delivery: checking template ↔ sync-parser consistency ($ROOT)"
echo ""

# Guard: нужные файлы на месте (иначе check невалиден, НЕ ложный PASS — closes G-073).
if [ ! -f "$SETTINGS_TPL" ]; then
  echo "  SKIP: settings.template.json не найден ($SETTINGS_TPL) — нечего проверять"
  exit 0
fi
if [ ! -d "$HOOKS_DIR" ]; then
  warn "templates/.claude/hooks/ не найден — settings.template.json ссылается на хуки которых нет"
  echo ""
  echo "FAIL: validate-delivery: $VIOLATIONS violation(s)" >&2
  exit 1
fi

# ── Извлечь hook-refs из settings.template.json (ДВА паттерна, зеркало sync hook_name) ──
#   1) через wrapper:  run-hook.sh X.py
#   2) прямой вызов:   .claude/hooks/X.(py|sh)   (ловит run-hook.sh сам, hook-liveness.sh, *.py)
refs="$(
  {
    grep -oE 'run-hook\.sh[[:space:]]+[A-Za-z0-9._-]+' "$SETTINGS_TPL" 2>/dev/null | sed 's#run-hook\.sh[[:space:]]*##'
    grep -oE '\.claude/hooks/[A-Za-z0-9._-]+\.(py|sh)' "$SETTINGS_TPL" 2>/dev/null | sed 's#.*\.claude/hooks/##'
  } | sort -u
)"

if [ -z "$refs" ]; then
  # 0 совпадений = формат settings.template сменился → check невалиден, НЕ PASS (G-073).
  warn "0 hook-refs извлечено из settings.template.json — формат изменился? Проверь вручную (detection-guard)"
  echo ""
  echo "FAIL: validate-delivery: $VIOLATIONS violation(s)" >&2
  exit 1
fi

# ── Check 1: каждый referenced hook существует на диске в templates/.claude/hooks/ ──
echo "Check 1: referenced hooks present in templates/.claude/hooks/"
for h in $refs; do
  if [ -f "$HOOKS_DIR/$h" ] || [ -f "$HOOKS_DIR/${h%.py}.template.py" ] || [ -f "$HOOKS_DIR/$(echo "$h" | sed 's/\.py$/.template.py/')" ]; then
    ok "$h present"
  else
    warn "$h referenced in settings.template.json но ОТСУТСТВУЕТ в templates/.claude/hooks/ — sync доставит мёртвую ссылку"
  fi
done
echo ""

# ── Check 2: sync-парсер РАСПОЗНАЁТ каждый ref (иначе wiring не доедет — v5.12.0 класс) ──
# Эмулируем hook_name() логику sync: ref распознаётся если .py ИЛИ .sh (дуальный паттерн).
# Если sync hook_name() сузит regex обратно к .py-only — .sh refs здесь зафейлят (ловит регресс).
echo "Check 2: sync hook_name() распознаёт каждый ref (delivery reachability)"
# Извлечь актуальный hook_name regex-класс из sync (что реально распознаётся при доставке).
sync_recognizes_sh=0
if [ -f "$SYNC" ]; then
  if grep -qE 'hooks/\(\?:\?\[A-Za-z0-9._-\]\+\\\.\(\?:py\|sh\)\)|py\|sh' "$SYNC" 2>/dev/null \
     || grep -q 'py|sh' "$SYNC" 2>/dev/null; then
    sync_recognizes_sh=1
  fi
fi
for h in $refs; do
  case "$h" in
    *.py) ok "$h — .py, распознаётся sync hook_name() (always)" ;;
    *.sh)
      if [ "$sync_recognizes_sh" -eq 1 ]; then
        ok "$h — .sh, sync hook_name() распознаёт (py|sh pattern present)"
      else
        warn "$h — .sh-вызов в template, НО sync hook_name() регекс НЕ распознаёт .sh (только .py) → wiring НЕ доедет до консьюмера (это ровно v5.12.0 баг)"
      fi
      ;;
    *) warn "$h — неизвестное расширение, sync-доставка не гарантирована" ;;
  esac
done
echo ""

# ── Summary ──
if [ "$VIOLATIONS" -eq 0 ]; then
  echo "PASS: validate-delivery: template ↔ sync-parser consistent (0 violations)"
  exit 0
else
  echo "FAIL: validate-delivery: $VIOLATIONS delivery-consistency violation(s)" >&2
  echo "  → hook-ref в settings.template.json не доедет до консьюмера через sync. Fix перед merge." >&2
  exit 1
fi
