#!/bin/bash
# build-knowledge-index.sh
# Builds KNOWLEDGE.md index from DEVLOG [research:X] and [opinion:X] tagged entries.
# DEVLOG remains source of truth; output is a derived read-only index.
#
# Usage (methodology, two-repo):
#   bash scripts/build-knowledge-index.sh \
#     ../it-dev-methodology-documentation/DEVLOG.md \
#     ../it-dev-methodology-documentation/KNOWLEDGE.md
#
# Usage (consumer, single-repo):
#   bash scripts/build-knowledge-index.sh DEVLOG.md KNOWLEDGE.md
#   Or with defaults: bash scripts/build-knowledge-index.sh
#
# Requires: bash 3.2+, GNU grep

DEVLOG="${1:-DEVLOG.md}"
OUTPUT="${2:-KNOWLEDGE.md}"
TODAY=$(date +%Y-%m-%d 2>/dev/null || echo "")

if [ ! -f "$DEVLOG" ]; then
    echo "ERROR: DEVLOG not found: $DEVLOG" >&2
    echo "  Usage: bash scripts/build-knowledge-index.sh <DEVLOG_PATH> <OUTPUT_PATH>" >&2
    exit 1
fi

# Match only lines that START with optional backtick then [research: or [opinion:
# This excludes: ## headers, inline mentions in prose, template examples
RESEARCH=$(grep -E '^.?\[research:[a-zA-Z0-9_-]+\]' "$DEVLOG" | grep -v '^#' | sed 's/^`//; s/`$//')
OPINION=$(grep -E '^.?\[opinion:[a-zA-Z0-9_-]+\]' "$DEVLOG" | grep -v '^#' | sed 's/^`//; s/`$//')

{
    cat << 'HDR'
# KNOWLEDGE.md — Knowledge Index

> **Производный индекс** над DEVLOG `[research:X]` и `[opinion:X]` записями.
> DEVLOG остаётся источником правды — этот файл перезаписывается скриптом.
>
> **Обновить:** `bash scripts/build-knowledge-index.sh [DEVLOG] [OUTPUT]`
> Или автоматически через `/retro` Шаг 5.5

HDR
    echo "**Обновлён:** $TODAY"
    echo ""
    echo "---"
    echo ""
    echo "## Research findings (\`[research:X]\`)"
    echo ""
    if [ -z "$RESEARCH" ]; then
        echo "_Нет записей. Появятся после первого \`[research:slug]\` тега в DEVLOG._"
    else
        echo "$RESEARCH" | while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            echo "- $entry"
        done
    fi
    echo ""
    echo "---"
    echo ""
    echo "## Opinion log (\`[opinion:X]\`)"
    echo ""
    if [ -z "$OPINION" ]; then
        echo "_Нет записей. Появятся после первого \`[opinion:slug]\` тега в DEVLOG._"
    else
        echo "$OPINION" | while IFS= read -r entry; do
            [ -z "$entry" ] && continue
            echo "- $entry"
        done
    fi
    echo ""
    echo "---"
    echo ""
    echo "_Сгенерировано: ${TODAY}_"
} > "$OUTPUT"

echo "OK: KNOWLEDGE.md -> $OUTPUT"
