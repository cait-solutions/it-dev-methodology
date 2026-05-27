#!/bin/bash
# validate-artifact-map.sh — Level 4 structural validation of ARTIFACT-MAP
# Bash 3.2+ compatible (no associative arrays, no ${var,,})
#
# Usage: bash scripts/validate-artifact-map.sh [--artifact-map PATH] [--commands-dir PATH] [--ignore-exit]
# Exit 0 = clean; Exit 1 = issues found (review before deploy)
#
# Checks:
#   W→RW    : --> edge where command also reads the artifact (should be ===)
#   LANG    : node IDs contain Cyrillic characters (must be ASCII)
#   COVERAGE: command in Command Reference table has no matching node label in Mermaid
#   ISLAND  : node declared in Mermaid has zero edges (warning, not error)

set -e
ARTIFACT_MAP="templates/ARTIFACT-MAP.template.md"
COMMANDS_DIR="commands"
IGNORE_EXIT=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --artifact-map) ARTIFACT_MAP="$2"; shift 2 ;;
        --commands-dir) COMMANDS_DIR="$2"; shift 2 ;;
        --ignore-exit)  IGNORE_EXIT=1; shift ;;
        *) echo "Unknown arg: $1"; exit 2 ;;
    esac
done

if [ ! -f "$ARTIFACT_MAP" ]; then
    echo "ERROR: ARTIFACT_MAP not found: $ARTIFACT_MAP"
    exit 2
fi

# Map command node name → command filename (Bash 3.2 compatible: no assoc arrays)
node_to_file() {
    case "$1" in
        Plan)    echo "plan.md" ;;
        Code)    echo "code.md" ;;
        Review)  echo "review.md" ;;
        Deploy)  echo "deploy.md" ;;
        Retro)   echo "retro.md" ;;
        Arch)    echo "architecture-audit.md" ;;
        SyncV)   echo "sync-vision.md" ;;
        Diag)    echo "diagnose.md" ;;
        PCheck)  echo "product-check.md" ;;
        PReview) echo "product-review.md" ;;
        PVision) echo "product-vision.md" ;;
        Onboard) echo "onboard.md" ;;
        *)       echo "" ;;
    esac
}

# Map artifact node name → search term for grep in command files
node_to_artifact() {
    case "$1" in
        SM)   echo "SYSTEM-MAP" ;;
        PROD) echo "PRODUCT" ;;
        CLM)  echo "CLAUDE" ;;
        ADR)  echo "adr|ADR" ;;
        UM)   echo "USER-MAP" ;;
        ID)   echo "IDEAS" ;;
        HY)   echo "HYPOTHESES|HYPOTH" ;;
        DL)   echo "DEVLOG" ;;
        TJ)   echo "triggers" ;;
        AM)   echo "ARTIFACT-MAP" ;;
        INB)  echo "inbox|Inbox" ;;
        RM)   echo "ROADMAP" ;;
        VI)   echo "VISION" ;;
        OQ)   echo "OPEN-QUESTIONS|OQ-" ;;
        RI)   echo "RISKS" ;;
        *)    echo "" ;;
    esac
}

# Verified W-only edges: command mentions artifact but does NOT read it as semantic input.
# Format: "SRC-->TGT" (no spaces). Add here after manual verification.
VERIFIED_W="
Deploy-->DL
Arch-->DL
PReview-->PROD
SyncV-->OQ
SyncV-->DL
"

is_verified_w() {
    echo "$VERIFIED_W" | grep -qF "$1-->$2"
}

errors=0
checked=0

echo "=== validate-artifact-map.sh ==="
echo "Artifact map: $ARTIFACT_MAP"
echo "Commands dir: $COMMANDS_DIR"
echo ""
echo "--- Check 1: W→RW (arrow type misclassification) ---"
echo ""

# Parse Mermaid block: find lines with --> (W edges), skip === and -.->, skip comments
while IFS= read -r line; do
    # Skip comment lines
    echo "$line" | grep -q -- '%%' && continue
    # Skip if not a --> line
    echo "$line" | grep -qE -- '[A-Za-z]+[[:space:]]*-->' || continue
    # Skip === lines (already RW)
    echo "$line" | grep -q -- '===' && continue
    # Skip -.-> lines (R only)
    echo "$line" | grep -q -- '-\.->' && continue
    # Skip --x lines (C)
    echo "$line" | grep -q -- '\-\-x' && continue

    # Extract source node (first identifier before -->)
    src=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*-->.*//' | tr -d ' ')

    # Extract target node (last identifier after last |)
    tgt=$(echo "$line" | sed 's/.*|[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d ' ')

    cmd_file=$(node_to_file "$src")
    artifact=$(node_to_artifact "$tgt")

    # Skip if not a command→artifact pair we know about
    [ -z "$cmd_file" ] && continue
    [ -z "$artifact" ] && continue

    full_path="$COMMANDS_DIR/$cmd_file"
    [ -f "$full_path" ] || continue

    checked=$((checked + 1))

    artifact_in_file=0
    grep -Eqi -- "$artifact" "$full_path" 2>/dev/null && artifact_in_file=1

    if [ "$artifact_in_file" -eq 1 ]; then
        if is_verified_w "$src" "$tgt"; then
            continue
        fi
        has_read_context=0
        grep -Eqi -- "Читает|читать|прочитать" "$full_path" 2>/dev/null && has_read_context=1
        if [ "$has_read_context" -eq 1 ]; then
            echo "⚠️  W→RW candidate: $src --> $tgt"
            echo "   $cmd_file references '$artifact' + has read context (Читает/читать)"
            echo "   Consider: --> should be === (RW)"
            echo ""
            errors=$((errors + 1))
        fi
    fi
done < "$ARTIFACT_MAP"

echo "Checked: $checked W-edges"
echo ""
if [ "$errors" -gt 0 ]; then
    echo "⚠️  W→RW: $errors potential mismatch(es) — consider changing --> to ==="
else
    echo "✅ W→RW: no mismatches."
fi

echo ""
echo "--- Checks 2-4: Language / Coverage / Island (Python) ---"
echo ""

PYTHON=""
for _cmd in py python3 python; do
    command -v "$_cmd" >/dev/null 2>&1 && PYTHON="$_cmd" && break
done

py_exit=0

if [ -z "$PYTHON" ]; then
    echo "⚠️  Python not found (tried: py, python3, python) — checks 2-4 skipped."
else
    TMPPY=$(mktemp)
    trap 'rm -f "$TMPPY"' EXIT

    cat > "$TMPPY" << 'PYEOF'
#!/usr/bin/env python3
"""validate-artifact-map: language, coverage, island node checks."""
import sys
import re

NODE_DECL_RE = re.compile(r'^\s*([A-Za-z_]\w*)\s*[\[\(\{]')
CYRILLIC_RE = re.compile(u'[Ѐ-ӿ]')
SKIP_KW = ('classDef', 'class ', 'linkStyle', 'direction', 'subgraph', 'end')
CMD_TABLE_RE = re.compile(r'^\|\s*`?(/[\w-]+)`?\s*\|')
ARROW_PAT = ('-->', '-.->', '===', '--x')


def has_arrow(s):
    return any(a in s for a in ARROW_PAT)


def extract_blocks(text):
    return [m.group(1).strip() for m in re.finditer(r'```mermaid\n(.*?)```', text, re.DOTALL)]


def parse_block(block):
    node_ids = []
    edge_sources = set()
    edge_targets = set()
    for line in block.split('\n'):
        s = line.strip()
        if not s or s.startswith('%%') or s.startswith('//'):
            continue
        if any(s.startswith(kw) for kw in SKIP_KW):
            continue

        if has_arrow(s):
            # Edge source: identifier before first arrow token
            m = re.match(r'^\s*([A-Za-z_]\w*)\s*(?:-->|-\.->|===|--x)', s)
            if m:
                edge_sources.add(m.group(1))
            # Edge target: identifier after |...|  following arrow
            m2 = re.search(r'(?:-->|-\.->|===|--x)\s*(?:\|[^|]*\|\s*)?([A-Za-z_]\w*)', s)
            if m2:
                edge_targets.add(m2.group(1))
        else:
            # Pure node declaration
            m3 = NODE_DECL_RE.match(s)
            if m3 and 'TODO:' not in s:
                node_ids.append(m3.group(1))
    return node_ids, edge_sources, edge_targets


def extract_table_commands(text):
    cmds = []
    in_cmd_ref = False
    for line in text.split('\n'):
        if 'Command Reference' in line:
            in_cmd_ref = True
        if in_cmd_ref:
            m = CMD_TABLE_RE.match(line)
            if m:
                cmds.append(m.group(1))
    return cmds


def main():
    path = sys.argv[1]
    with open(path, encoding='utf-8', errors='replace') as f:
        content = f.read()

    blocks = extract_blocks(content)
    if not blocks:
        print("No mermaid blocks found — checks skipped.")
        sys.exit(0)

    # Use last block (full diagram) for authoritative checks; all blocks for language
    full_block = blocks[-1]
    all_text = '\n'.join(blocks)

    node_ids_full, edge_src, edge_tgt = parse_block(full_block)
    node_ids_all, _, _ = parse_block(all_text)
    all_referenced = edge_src | edge_tgt

    table_cmds = extract_table_commands(content)

    errors = 0
    warnings = 0

    # Check L: node ID language (no Cyrillic)
    seen = set()
    for nid in node_ids_all:
        if nid in seen:
            continue
        seen.add(nid)
        if CYRILLIC_RE.search(nid):
            print(u'⚠️  LANG     node ID \'{}\' contains Cyrillic — must be ASCII'.format(nid))
            errors += 1

    # Check C: command table → Mermaid coverage (full block)
    for cmd in sorted(set(table_cmds)):
        # Look for command as node label: quoted command string like "/plan
        search = '"' + cmd
        if search not in full_block and "'" + cmd not in full_block:
            print(u'⚠️  COVERAGE command \'{}\' not found as node label in Mermaid'.format(cmd))
            print(u'   Add a node with label containing "{}..." to the diagram.'.format(cmd))
            errors += 1

    # Check I: island nodes (zero edges) — WARNING only
    seen2 = set()
    for nid in node_ids_full:
        if nid in seen2:
            continue
        seen2.add(nid)
        if nid not in all_referenced:
            print(u'⚠️  ISLAND   node \'{}\' has no edges — missing relationship?'.format(nid))
            warnings += 1

    print()
    if errors > 0:
        print('FAIL: {} error(s) found (LANG or COVERAGE).'.format(errors))
        if warnings > 0:
            print('WARN: {} island warning(s).'.format(warnings))
        sys.exit(1)
    elif warnings > 0:
        print('WARN: {} island node(s) — not blocking, review if intentional.'.format(warnings))
        sys.exit(0)
    else:
        print('OK: language, coverage, island checks passed.')
        sys.exit(0)


main()
PYEOF

    PYTHONIOENCODING=utf-8 "$PYTHON" "$TMPPY" "$ARTIFACT_MAP" || py_exit=$?
fi

echo ""
total_errors=$((errors + py_exit))

if [ "$total_errors" -gt 0 ]; then
    echo "❌ ARTIFACT-MAP validation failed. Review findings above."
    echo "   W→RW: change --> to === where command reads artifact as input"
    echo "   LANG: rename node ID to ASCII"
    echo "   COVERAGE: add missing node or remove command from table"
    [ "$IGNORE_EXIT" -eq 0 ] && exit 1
else
    echo "✅ All ARTIFACT-MAP checks passed."
fi

exit 0
