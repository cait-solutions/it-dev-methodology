#!/bin/bash
# validate-artifact-size.sh — контроль размера И плотности запретов в артефактах-инструкциях
#
# Зачем: раздутые артефакты-инструкции (CLAUDE.md, USER-MAP, runtime-промпты бота)
#   (1) агент скимит длинный текст → теряется сигнал;
#   (2) обилие запретов в runtime-промпте ПОДАВЛЯЕТ tool invocation (модель тонет
#       в "ЗАПРЕЩЕНО/СТОП" и перестаёт звать инструменты).
# Размер сам по себе НЕ приговор (9286 символов few-shot могут быть ОК). Поэтому скрипт
# меряет ДВЕ оси и выдаёт WARNING (не блок) — финальный суд за агентом в /review.
#
# Две оси:
#   SIZE_EXCEEDED — размер файла > budget (символы)
#   PROMPT_BLOAT  — плотность запретов > порога (маркеры подавления на 1000 символов)
#
# Budget и пути берутся из CLAUDE.local.md секции "## Artifact budgets" (если есть) +
# встроенные дефолты для методологических артефактов. Если конфига нет — мерятся
# только дефолтные артефакты.
#
# Usage: bash scripts/validate-artifact-size.sh [--root DIR]
# Exit 0 всегда (WARNING-семантика, не блок — как URL_TOO_LONG в validate-mermaid-links).
#
# Bash 3.2+ совместим; требует Python 3.10+.

set -e

ROOT="."
while [ "$#" -gt 0 ]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 2 ;;
    esac
done

PYTHON=""
for _cmd in py python3 python; do
    command -v "$_cmd" >/dev/null 2>&1 && PYTHON="$_cmd" && break
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python not found (tried: py, python3, python)"
    exit 2
fi

TMPPY=$(mktemp)
trap 'rm -f "$TMPPY"' EXIT

cat > "$TMPPY" << 'PYEOF'
#!/usr/bin/env python3
import sys
import os
import re
import glob

# Windows консоль по умолчанию cp1252 → UnicodeEncodeError на кириллице/em-dash.
# Принудительно UTF-8 для вывода (Python 3.7+).
try:
    sys.stdout.reconfigure(encoding='utf-8')
except (AttributeError, ValueError):
    pass

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'

# Встроенные дефолты для методологических артефактов (символы).
# Консьюмер переопределяет/расширяет через CLAUDE.local.md "## Artifact budgets".
DEFAULT_BUDGETS = {
    'CLAUDE.md': 14000,
    'CLAUDE.local.md': 8000,
    'PRODUCT.md': 16000,
    'docs/product/USER-MAP.md': 16000,
    'docs/architecture/SYSTEM-MAP.md': 16000,
    # Команды методологии — контроль разрастания (VISION Ось 5 Enforcement).
    # Превышение = кандидат на cut-not-add разбор в /review. Агент скимит длинную
    # команду → ценные шаги тонут (тот же класс что PROMPT_BLOAT у runtime-промптов).
    'commands/*.md': 24000,
    '.claude/commands/*.md': 24000,
}

# Маркеры подавления tool invocation — высокая плотность = prompt bloat сигнал.
PROHIBITION_MARKERS = [
    r'ЗАПРЕЩ', r'\bСТОП\b', r'НИКОГДА', r'НЕЛЬЗЯ', r'НЕ\s+ДЕЛАЙ',
    r'\bNEVER\b', r"\bDON'?T\b", r'MUST\s+NOT', r'❌', r'⛔', r'🚫',
]
PROHIBITION_RE = re.compile('|'.join(PROHIBITION_MARKERS), re.IGNORECASE)
EXCLAIM_RE = re.compile(r'!{2,}')
# Плотность запретов на 1000 символов выше которой → PROMPT_BLOAT
DENSITY_THRESHOLD = 8.0


def parse_budgets_from_claude_local(root):
    """Читает '## Artifact budgets' из CLAUDE.local.md. Формат строк:
       - glob-pattern: NNNN
       Пример:  - agents/*.py: 4000
    """
    budgets = {}
    path = os.path.join(root, 'CLAUDE.local.md')
    if not os.path.isfile(path):
        return budgets
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
    except OSError:
        return budgets
    in_section = False
    line_re = re.compile(r'^\s*[-*]\s*`?([^`:]+?)`?\s*:\s*(\d+)\s*$')
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('#'):
            in_section = 'artifact budget' in stripped.lower()
            continue
        if in_section:
            m = line_re.match(line)
            if m:
                budgets[m.group(1).strip()] = int(m.group(2))
    return budgets


def measure(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
    except OSError:
        return None
    size = len(text)
    prohibitions = len(PROHIBITION_RE.findall(text))
    exclaims = len(EXCLAIM_RE.findall(text))
    density = ((prohibitions + exclaims) / size * 1000) if size else 0.0
    return size, prohibitions + exclaims, density


def resolve_files(root, pattern):
    full = os.path.join(root, pattern)
    return [p for p in glob.glob(full, recursive=True) if os.path.isfile(p)]


def main():
    configured = parse_budgets_from_claude_local(ROOT)
    # Объединить: дефолты + конфиг консьюмера (конфиг переопределяет)
    budgets = dict(DEFAULT_BUDGETS)
    budgets.update(configured)

    warnings = 0
    checked = 0

    for pattern, budget in sorted(budgets.items()):
        for path in sorted(resolve_files(ROOT, pattern)):
            m = measure(path)
            if m is None:
                continue
            checked += 1
            size, marker_count, density = m
            rel = os.path.relpath(path, ROOT)

            if size > budget:
                ratio = size / budget
                print("WARNING  SIZE_EXCEEDED  {} ({} > budget {}, {:.1f}x)".format(
                    rel, size, budget, ratio))
                print("         Раздут по размеру. Разобрать в /review: сжать или контент оправдан?")
                warnings += 1

            if density > DENSITY_THRESHOLD:
                print("WARNING  PROMPT_BLOAT   {} ({} запретов/эмфазы, плотность {:.1f}/1000 символов)".format(
                    rel, marker_count, density))
                print("         Высокая плотность запретов → риск подавления tool invocation.")
                print("         Разобрать в /review: душит ли обилие 'ЗАПРЕЩЕНО/СТОП' вызов инструментов?")
                warnings += 1

    print()
    print("Checked: {} artifact(s) against budgets".format(checked))
    if not configured:
        print("NB: CLAUDE.local.md '## Artifact budgets' не задан — проверены только дефолтные")
        print("    методологические артефакты. Добавь секцию для runtime-промптов продукта.")
    print()
    if warnings > 0:
        print("WARN: {} warning(s) (SIZE_EXCEEDED / PROMPT_BLOAT) — не блокирует, разобрать в /review".format(warnings))
    else:
        print("OK: все проверенные артефакты в пределах budget и плотности.")
    sys.exit(0)


main()
PYEOF

echo "=== validate-artifact-size.sh ==="
echo "Root: $ROOT"
echo ""

"$PYTHON" "$TMPPY" "$ROOT"
