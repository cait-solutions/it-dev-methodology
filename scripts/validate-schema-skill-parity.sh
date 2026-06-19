#!/bin/bash
# validate-schema-skill-parity.sh — schema↔knowledge-skill drift detector (closes G-120)
# Bash 3.2+ compatible (no associative arrays, no ${var,,})
#
# КОРЕНЬ (G-120): механизм заводят в consumer-facing schema-template (новое поле,
# напр. `type: file` в secrets-manifest.yaml.template, v6.4.7), но НЕ зеркалят в
# парный knowledge-skill (SKILL.md) — поверхность авто-активации, которую агент
# консультирует в runtime. Итог: механизм невидим агенту → агент re-derive'ит с нуля.
#
# Детектор сверяет: каждое поле, документированное в schema-template, упомянуто ли
# (literal token) в парном SKILL.md. Отсутствие = drift-сигнал.
#
# ⚠️ Честный регулятор-level: L3 DETECT (присутствие токена), НЕ L4 семантика — ловит
#    «поле не упомянуто вообще», не «упомянуто неверно». Severity по умолчанию WARN
#    (как validate-maps-coverage NODE_READABILITY) чтобы избежать brittleness и
#    whitelist-slope. Escalate: SCHEMA_SKILL_SEVERITY=error.
#
# Guard: methodology-platform only ([ -d commands ] && [ -d skills ]). Consumer не
# авторит skills/schema → exit 2 (SKIP, не PASS).
#
# Usage: bash scripts/validate-schema-skill-parity.sh
# Exit 0 = OK или только WARN; Exit 1 = drift при severity=error; Exit 2 = SKIP.

set -u

SEVERITY="${SCHEMA_SKILL_SEVERITY:-warn}"   # warn | error

if [ ! -d "commands" ] || [ ! -d "skills" ]; then
  echo "INFO: not methodology-platform (no commands/ + skills/) — schema↔skill parity N/A."
  exit 2
fi

# --- Declarative pairs: "schema_template|skill_md" (одна пара на строку) ---
# Расширять при появлении новой schema↔skill пары. triggers.json.template НЕ здесь:
# его потребляют команды, не knowledge-skill.
PAIRS="templates/secrets-manifest.yaml.template|skills/secrets-management/SKILL.md"

# SKIP-набор. Две обоснованные категории (⛔ держать МИНИМАЛЬНЫМ — whitelist = slope):
#  1. Универсально-очевидные per-entry ключи (в любом примере секрета, без capability-специфики).
#  2. config:-блок операционные пороги (потребляются validate-secrets.sh, НЕ agent-knowledge
#     per-entry capability; skill «Configurable values» покрывает их концептуально).
SKIP_FIELDS=" key purpose required scope sensitivity token_pattern manifest_version config \
 entropy_threshold extra_patterns hook_enabled scrub_paths shared_path "

TOTAL_MISSING=0
PAIRS_CHECKED=0

# here-string → цикл в основном процессе, счётчики выживают (Bash 3.2 safe)
while IFS='|' read -r schema skill; do
  [ -z "$schema" ] && continue
  if [ ! -f "$schema" ]; then
    echo "[INFO]  schema-template отсутствует ($schema) — пропуск пары."
    continue
  fi
  if [ ! -f "$skill" ]; then
    echo "[WARN]  парный skill отсутствует ($skill) для $schema."
    continue
  fi
  PAIRS_CHECKED=$((PAIRS_CHECKED + 1))

  # Имена полей, документированных в schema-template (per-entry ключи): строки вида
  # `#   <field>:  ...` (комментарий-документация) ИЛИ `<field>:` в примерах.
  fields="$(grep -oE '^[[:space:]]*#?[[:space:]]*[a-z][a-z0-9_]+:' "$schema" 2>/dev/null \
            | sed -E 's/[[:space:]#]//g; s/:$//' \
            | sort -u)"

  missing=""
  for f in $fields; do
    case "$SKIP_FIELDS" in
      *" $f "*) continue ;;
    esac
    if ! grep -qF "$f" "$skill" 2>/dev/null; then
      missing="$missing $f"
      TOTAL_MISSING=$((TOTAL_MISSING + 1))
    fi
  done

  if [ -n "$missing" ]; then
    _lvl="$([ "$SEVERITY" = error ] && echo ERROR || echo WARN)"
    echo "[$_lvl] schema↔skill drift: поля в $schema НЕ упомянуты в $skill:"
    echo "       $missing"
    echo "        → опиши в skill (G-120: механизм невидим агенту) ИЛИ оставь если поле не для agent-knowledge."
  else
    echo "[OK]    $schema ↔ $skill — все capability-поля документированы."
  fi
done <<EOF
$PAIRS
EOF

echo ""
echo "[INFO]  $PAIRS_CHECKED пар проверено, $TOTAL_MISSING недокументированных полей."

if [ "$TOTAL_MISSING" -gt 0 ]; then
  if [ "$SEVERITY" = error ]; then
    echo "❌ schema↔skill drift (G-120 класс): $TOTAL_MISSING поле(й) не зеркалированы. severity=error → блок."
    exit 1
  fi
  echo "🔵 schema↔skill drift (G-120 класс): $TOTAL_MISSING поле(й) не зеркалированы (severity=warn — не блок)."
  echo "   Escalate: SCHEMA_SKILL_SEVERITY=error bash scripts/validate-schema-skill-parity.sh"
  exit 0
fi
echo "✅ schema↔skill parity OK."
exit 0
