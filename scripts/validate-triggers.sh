#!/usr/bin/env bash
# validate-triggers.sh — проверить что triggers.json не содержит дубль-ключей
# (global.X и top-level X одновременно).
#
# Canonical global keys (зеркало templates/triggers.json.template "global" block —
# ОБНОВЛЯТЬ СИНХРОННО при изменении шаблона):
#   last_sync_vision, last_retro, last_product_review, last_product_check,
#   last_product_vision, last_user_map_sync, last_architecture_audit
#
# Exit 0 = OK или WARN-SKIP (файл не найден — легитимно)
# Exit 1 = найдены дубль-ключи

set -euo pipefail

echo "=== validate-triggers.sh ==="

# Resolve triggers.json path
ROOT="."
while [ $# -gt 0 ]; do
    case "$1" in
        --root) ROOT="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

ROOT_ABS="$(cd "$ROOT" && pwd)"
TRIGGERS_FILE="$ROOT_ABS/.claude/state/triggers.json"

if [ ! -f "$TRIGGERS_FILE" ]; then
    echo "WARN-SKIP: triggers.json not found at $TRIGGERS_FILE — Gap 2 not applicable"
    exit 0
fi

echo "File: $TRIGGERS_FILE"

# Interpreter-agnostic python resolver (closes G-081/G-097)
_PY=""
for _cmd in python3 py python; do
    command -v "$_cmd" >/dev/null 2>&1 && _PY="$_cmd" && break
done

if [ -z "$_PY" ]; then
    echo "WARN-SKIP: Python not found (tried python3, py, python) — validate-triggers.sh требует Python"
    exit 0
fi

# Canonical global keys — зеркало templates/triggers.json.template "global" block
GLOBAL_KEYS="last_sync_vision last_retro last_product_review last_product_check last_product_vision last_user_map_sync last_architecture_audit"

VIOLATIONS=0

"$_PY" - "$TRIGGERS_FILE" "$GLOBAL_KEYS" <<'PYEOF'
import json, sys

triggers_file = sys.argv[1]
global_keys = sys.argv[2].split()

with open(triggers_file, encoding="utf-8-sig") as f:
    data = json.load(f)

global_block = data.get("global", {})
violations = 0

for key in global_keys:
    in_global = key in global_block
    in_top = key in data
    if in_global and in_top:
        print(f"DUPLICATE: '{key}' exists both under global.{key} AND as top-level {key}")
        print(f"  global.{key}.date  = {global_block.get(key, {}).get('date')}")
        print(f"  {key}.date         = {data[key].get('date')}")
        violations += 1

if violations == 0:
    top_count = sum(1 for k in global_keys if k in data)
    global_count = sum(1 for k in global_keys if k in global_block)
    print(f"OK: no duplicate keys (global: {global_count}, top-level duplicates: 0)")
    sys.exit(0)
else:
    print(f"\nRESULT: {violations} duplicate key(s) — fix triggers.json or run migration")
    sys.exit(1)
PYEOF

VIOLATIONS=$?
exit $VIOLATIONS
