#!/usr/bin/env bash
#
# migrate-agent-to-product-gaps.sh — interactive AGENT-GAPS → PRODUCT-GAPS migration.
#
# Iterates через Gap-ID entries в AGENT-GAPS.md, presents each one с auto-classification hint,
# asks user: keep in AGENT-GAPS (s) / move to PRODUCT-GAPS (m) / skip (k).
#
# Manual trigger only — НЕ runs автоматически. Bootstrap скрипт не зависит от этого.
#
# Usage:
#   bash scripts/migrate-agent-to-product-gaps.sh [--dry-run] [--root DIR]
#
# Flags:
#   --dry-run   — report classifications + suggestions без правки файлов
#   --root DIR  — корень проекта (default: pwd)
#
# Behavior:
#   1. Parse AGENT-GAPS.md → list of Gap-ID records
#   2. For each: extract Категория, Что пропустил, Гипотеза
#   3. Auto-classify hint:
#      prompt-gap / context-gap / assumption-gap / state-stale / logic-gap → STAY (agent)
#      completeness-gap / scope-gap → AMBIGUOUS (suggest MOVE, user decides)
#   4. Show record + hint + prompt: (s)tay / (m)ove / (k)ip
#   5. On 'm': write to PRODUCT-GAPS.md with new P-NNN id; remove from AGENT-GAPS.md
#   6. Final report: N stay / M moved / K skipped
#   7. Log to DEVLOG.md: [methodology-migration] entry
#
# Safety: dry-run first, then actual run. Backup AGENT-GAPS.md перед write.

set -e

ROOT="."
DRY_RUN=false

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown arg: $1"; exit 2 ;;
    esac
done

AGENT_FILE="$ROOT/AGENT-GAPS.md"
PRODUCT_FILE="$ROOT/PRODUCT-GAPS.md"

if [ ! -f "$AGENT_FILE" ]; then
    echo "ERROR: $AGENT_FILE not found"
    exit 1
fi

if [ ! -f "$PRODUCT_FILE" ]; then
    echo "ERROR: $PRODUCT_FILE not found. Bootstrap его from templates/PRODUCT-GAPS.md.template сначала."
    exit 1
fi

# Find Python for parsing/processing
PYTHON=""
for _cmd in py python3 python; do
    command -v "$_cmd" >/dev/null 2>&1 && PYTHON="$_cmd" && break
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python not found (tried: py, python3, python)"
    exit 2
fi

# Backup before run
if [ "$DRY_RUN" = "false" ]; then
    cp "$AGENT_FILE" "${AGENT_FILE}.bak"
    echo "Backup created: ${AGENT_FILE}.bak"
fi

TMPPY=$(mktemp)
trap 'rm -f "$TMPPY"' EXIT

cat > "$TMPPY" << 'PYEOF'
#!/usr/bin/env python3
"""Interactive migration AGENT-GAPS → PRODUCT-GAPS.

Parses Gap-ID records, presents one at a time with classification hint,
asks user to keep / move / skip.
"""
import sys
import re
import os
from datetime import date

try:
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stdin.reconfigure(encoding='utf-8')
except (AttributeError, ValueError):
    pass

ROOT = sys.argv[1]
DRY_RUN = sys.argv[2] == "true"
AGENT_FILE = os.path.join(ROOT, "AGENT-GAPS.md")
PRODUCT_FILE = os.path.join(ROOT, "PRODUCT-GAPS.md")

# Auto-classification hint
STAY_CATEGORIES = {"prompt-gap", "context-gap", "assumption-gap", "state-stale", "logic-gap"}
MOVE_CATEGORIES = {"completeness-gap", "scope-gap"}


def parse_records(text):
    """Split AGENT-GAPS.md by --- separators and extract Gap-ID blocks."""
    # Find ## Записи section
    m = re.search(r'^## Записи\b', text, re.MULTILINE)
    if not m:
        return [], text, ""

    header = text[:m.end()]
    body = text[m.end():]

    # Split body by Gap-ID blocks
    records = []
    block_pattern = re.compile(r'(---\s*\nGap-ID:\s*(G-\d+).*?)(?=---\s*\nGap-ID:|\Z)', re.DOTALL)
    for m in block_pattern.finditer(body):
        block = m.group(1).strip()
        gap_id = m.group(2)
        records.append((gap_id, block))

    return records, header, body


def get_category(block):
    m = re.search(r'^Категория:\s*(.+)$', block, re.MULTILINE)
    return m.group(1).strip().split()[0] if m else "unknown"


def get_summary(block):
    m = re.search(r'^Что пропустил:\s*(.+)$', block, re.MULTILINE)
    return m.group(1).strip()[:200] if m else "(no summary)"


def classify_hint(category):
    if category in STAY_CATEGORIES:
        return "stay", f"Категория '{category}' — agent reasoning failure"
    if category in MOVE_CATEGORIES:
        return "move", f"Категория '{category}' — AMBIGUOUS (часто product coverage gap)"
    return "ambiguous", f"Категория '{category}' — определи вручную"


def next_product_id(product_text):
    """Find max P-NNN, return next."""
    ids = re.findall(r'Gap-ID:\s*P-(\d+)', product_text)
    if not ids:
        return 1
    return max(int(i) for i in ids) + 1


def convert_to_product_record(block, new_id):
    """Convert AGENT-GAPS Gap-ID block to PRODUCT-GAPS format."""
    # Extract fields
    fields = {}
    for line in block.split('\n'):
        m = re.match(r'^([А-ЯЁA-Z][А-яёA-Za-z\s\-]+?):\s*(.+)$', line)
        if m:
            fields[m.group(1).strip()] = m.group(2).strip()

    today = date.today().isoformat()
    original_id = fields.get("Gap-ID", "G-???")
    original_date = fields.get("Дата", today)
    original_category = fields.get("Категория", "unknown")
    original_context = fields.get("Контекст", "(migrated from AGENT-GAPS)")
    original_what = fields.get("Что пропустил", "(see original)")
    original_hypothesis = fields.get("Гипотеза", "(see original)")
    original_fix = fields.get("Potential fix", "")
    original_status = fields.get("Статус", "open")

    # Map agent category → product category heuristic
    product_category_map = {
        "completeness-gap": "edge-case-gap",
        "scope-gap": "feature-gap",
    }
    product_category = product_category_map.get(original_category, "edge-case-gap")

    return f"""---
Gap-ID: P-{new_id:03d}
Дата: {today}
Контекст: [migrated from {original_id}] {original_context}
Что не покрывает: {original_what}
Severity: 🟡 Medium
Категория: {product_category}
Use case (затронут): [уточни после миграции — какой сценарий пользователя]
Сигнал источник: retro pattern
Гипотеза почему не покрыто: {original_hypothesis}
Potential fix: {original_fix}
Связано с: {original_id} (migrated source)
Статус: {original_status}
---
"""


def main():
    with open(AGENT_FILE, encoding='utf-8') as f:
        agent_text = f.read()
    with open(PRODUCT_FILE, encoding='utf-8') as f:
        product_text = f.read()

    records, header_part, body_part = parse_records(agent_text)
    if not records:
        print("No Gap-ID records found in AGENT-GAPS.md")
        return 0

    stay = 0
    moved = 0
    skipped = 0
    moves = []  # list of (gap_id, block) to move
    next_p = next_product_id(product_text)

    print(f"\n{'=' * 70}")
    print(f"AGENT-GAPS migration — {len(records)} records found")
    print(f"Mode: {'DRY-RUN (no file changes)' if DRY_RUN else 'INTERACTIVE (will modify files)'}")
    print(f"{'=' * 70}\n")

    for i, (gap_id, block) in enumerate(records, 1):
        category = get_category(block)
        summary = get_summary(block)
        hint, reason = classify_hint(category)

        print(f"\n[{i}/{len(records)}] {gap_id}")
        print(f"  Категория: {category}")
        print(f"  Что пропустил: {summary}")
        print(f"  💡 Hint: {hint.upper()} — {reason}")

        if DRY_RUN:
            print(f"  → Would suggest: {hint}")
            if hint == "move":
                moves.append((gap_id, block))
            continue

        while True:
            choice = input(f"  Action: (s)tay / (m)ove / (k)ip > ").strip().lower()
            if choice in ("s", "m", "k"):
                break
            print("  Invalid choice. Use s/m/k.")

        if choice == "s":
            stay += 1
            print(f"  ✓ Stay in AGENT-GAPS")
        elif choice == "m":
            moves.append((gap_id, block))
            moved += 1
            print(f"  ✓ Move to PRODUCT-GAPS")
        else:
            skipped += 1
            print(f"  ⏩ Skipped")

    if DRY_RUN:
        print(f"\n{'=' * 70}")
        print(f"DRY-RUN Summary: {len(moves)} would move, {len(records) - len(moves)} would stay")
        print(f"{'=' * 70}\n")
        return 0

    # Actually move records
    if moves:
        # Append to PRODUCT-GAPS
        new_records = []
        for gap_id, block in moves:
            new_record = convert_to_product_record(block, next_p)
            new_records.append(new_record)
            next_p += 1

        # Insert before <!-- Новые сверху --> if exists, else append
        marker = "<!-- Новые сверху -->"
        if marker in product_text:
            insert_at = product_text.index(marker) + len(marker)
            new_product = product_text[:insert_at] + "\n\n" + "\n".join(new_records) + product_text[insert_at:]
        else:
            new_product = product_text.rstrip() + "\n\n" + "\n".join(new_records)

        with open(PRODUCT_FILE, "w", encoding="utf-8") as f:
            f.write(new_product)

        # Remove from AGENT-GAPS
        agent_remaining = agent_text
        for gap_id, block in moves:
            # Remove block + preceding/following --- если есть
            pattern = re.compile(r'---\s*\nGap-ID:\s*' + re.escape(gap_id) + r'.*?(?=---\s*\nGap-ID:|\Z)', re.DOTALL)
            agent_remaining = pattern.sub("", agent_remaining)

        with open(AGENT_FILE, "w", encoding="utf-8") as f:
            f.write(agent_remaining)

    # Final report
    print(f"\n{'=' * 70}")
    print(f"Migration complete:")
    print(f"  Stay in AGENT-GAPS: {stay}")
    print(f"  Moved to PRODUCT-GAPS: {moved}")
    print(f"  Skipped: {skipped}")
    print(f"{'=' * 70}\n")

    if moved > 0:
        print(f"DEVLOG entry suggestion:")
        print(f"  [methodology-migration] {date.today().isoformat()}: AGENT→PRODUCT gaps — {stay} stay / {moved} moved / {skipped} skipped")

    return 0


sys.exit(main())
PYEOF

"$PYTHON" "$TMPPY" "$ROOT" "$DRY_RUN"
