#!/bin/bash
# validate-artifact-map.sh — Level 4 structural validation of ARTIFACT-MAP arrow types
# Bash 3.2+ compatible (no associative arrays, no ${var,,})
#
# Usage: bash scripts/validate-artifact-map.sh [--artifact-map PATH] [--commands-dir PATH]
# Exit 0 = clean; Exit 1 = W→RW mismatches found (review before deploy)
#
# What it checks:
#   For each --> (W) edge where source is a command node:
#     grep the command file for the target artifact in a "Читает" context
#     If found → flag as W→RW candidate (command reads artifact as input before writing)
#
# False positive handling:
#   Exit 1 is a WARNING, not a hard block — developer reviews and confirms.
#   Use --ignore-exit to suppress non-zero exit in CI while keeping output.

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
        ADR)  echo "adr\|ADR" ;;
        UM)   echo "USER-MAP" ;;
        ID)   echo "IDEAS" ;;
        HY)   echo "HYPOTHESES\|HYPOTH" ;;
        DL)   echo "DEVLOG" ;;
        TJ)   echo "triggers" ;;
        AM)   echo "ARTIFACT-MAP" ;;
        INB)  echo "inbox\|Inbox" ;;
        RM)   echo "ROADMAP" ;;
        VI)   echo "VISION" ;;
        OQ)   echo "OPEN-QUESTIONS\|OQ-" ;;
        RI)   echo "RISKS" ;;
        *)    echo "" ;;
    esac
}

errors=0
checked=0

echo "=== validate-artifact-map.sh ==="
echo "Artifact map: $ARTIFACT_MAP"
echo "Commands dir: $COMMANDS_DIR"
echo ""
echo "Checking --> (W) edges for potential W→RW misclassification..."
echo ""

# Parse Mermaid block: find lines with --> (W edges), skip === and -.->, skip comments
while IFS= read -r line; do
    # Skip comment lines
    echo "$line" | grep -q '%%' && continue
    # Skip if not a --> line
    echo "$line" | grep -qE '[A-Za-z]+[[:space:]]*-->' || continue
    # Skip === lines (already RW)
    echo "$line" | grep -q '===' && continue
    # Skip -.-> lines (R only)
    echo "$line" | grep -q '-\.->' && continue
    # Skip --x lines (C)
    echo "$line" | grep -q '\-\-x' && continue

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

    # Check if command reads the artifact:
    # Condition 1: artifact appears in a "Читает" line in the command file
    # Condition 2: artifact appears in file AND file has explicit read language
    artifact_in_file=0
    grep -qi "$artifact" "$full_path" 2>/dev/null && artifact_in_file=1

    if [ "$artifact_in_file" -eq 1 ]; then
        has_read_context=0
        grep -qi "Читает\|читать\|прочитать" "$full_path" 2>/dev/null && has_read_context=1
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
    echo "❌ Found $errors potential W→RW mismatch(es)."
    echo "   Review each candidate: does the command read this artifact as logical input?"
    echo "   If yes → change --> to === in ARTIFACT-MAP"
    echo "   If no  → false positive, ignore"
    [ "$IGNORE_EXIT" -eq 0 ] && exit 1
else
    echo "✅ No W→RW mismatches detected."
fi

exit 0
