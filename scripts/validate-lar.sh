#!/usr/bin/env bash
# validate-lar.sh — проверить что файлы в LIVING-ARTIFACTS.md существуют на диске
# Exit 0 = OK или WARN-SKIP (LAR не найден — легитимно), Exit 1 = MISSING_FILE entries found
# Usage: bash scripts/validate-lar.sh [--root <dir>] [--lar <path>] [--doc-root <dir>]
#   --root <dir>      code repo root to resolve relative paths against (default: .)
#   --lar  <path>     explicit path to LIVING-ARTIFACTS.md (auto-detect if omitted)
#   --doc-root <dir>  optional second root for two-repo setups (doc repo);
#                     paths not found under --root are retried under --doc-root
#
# Auto-detect order (если --lar не задан):
#   1. $ROOT/docs/architecture/LIVING-ARTIFACTS.md
#   2. $DOC_ROOT/docs/architecture/LIVING-ARTIFACTS.md  (если --doc-root задан)
#   3. doc_repo_path из CLAUDE.local.md ## Auto-update (для two-repo без явного --doc-root)
# WARN-SKIP если нигде не найден (exit 0 — легитимное отсутствие).

set -euo pipefail

echo "=== validate-lar.sh ==="

# Parse args
ROOT="."
LAR_PATH=""
DOC_ROOT=""
while [ $# -gt 0 ]; do
    case "$1" in
        --root)
            ROOT="$2"
            shift 2
            ;;
        --lar)
            LAR_PATH="$2"
            shift 2
            ;;
        --doc-root)
            DOC_ROOT="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

# Normalize root to absolute
ROOT_ABS="$(cd "$ROOT" && pwd)"

# Normalize doc-root if provided — graceful check before cd
ROOT2_ABS=""
if [ -n "$DOC_ROOT" ]; then
    if [ ! -d "$DOC_ROOT" ]; then
        echo "WARNING: --doc-root '$DOC_ROOT' does not exist — two-repo path resolution disabled" >&2
    else
        ROOT2_ABS="$(cd "$DOC_ROOT" && pwd)"
    fi
fi

# Auto-detect LAR path if not provided (3-level search)
if [ -z "$LAR_PATH" ]; then
    SEARCHED_PATHS=""

    # Level 1: standard single-repo location under --root
    CANDIDATE="$ROOT_ABS/docs/architecture/LIVING-ARTIFACTS.md"
    SEARCHED_PATHS="$SEARCHED_PATHS $CANDIDATE"
    if [ -f "$CANDIDATE" ]; then
        LAR_PATH="$CANDIDATE"
    fi

    # Level 2: --doc-root if provided
    if [ -z "$LAR_PATH" ] && [ -n "$ROOT2_ABS" ]; then
        CANDIDATE="$ROOT2_ABS/docs/architecture/LIVING-ARTIFACTS.md"
        SEARCHED_PATHS="$SEARCHED_PATHS $CANDIDATE"
        if [ -f "$CANDIDATE" ]; then
            LAR_PATH="$CANDIDATE"
        fi
    fi

    # Level 3: doc_repo_path from CLAUDE.local.md ## Auto-update (two-repo without explicit --doc-root)
    if [ -z "$LAR_PATH" ]; then
        CLAUDE_LOCAL="$ROOT_ABS/CLAUDE.local.md"
        if [ -f "$CLAUDE_LOCAL" ]; then
            # Extract doc_repo_path value — grep line, strip key prefix, trim whitespace/quotes
            DOC_REPO_RAW=$(grep -A 10 "## Auto-update" "$CLAUDE_LOCAL" 2>/dev/null | grep "doc_repo_path:" | sed 's/.*doc_repo_path:[[:space:]]*//' | tr -d '"'"'" | tr -d '[:space:]')
            if [ -n "$DOC_REPO_RAW" ] && [ "$DOC_REPO_RAW" != "null" ]; then
                # Resolve relative to ROOT_ABS
                if [ -d "$ROOT_ABS/$DOC_REPO_RAW" ]; then
                    DOC_REPO_ABS="$(cd "$ROOT_ABS/$DOC_REPO_RAW" && pwd)"
                elif [ -d "$DOC_REPO_RAW" ]; then
                    DOC_REPO_ABS="$(cd "$DOC_REPO_RAW" && pwd)"
                else
                    DOC_REPO_ABS=""
                fi
                if [ -n "$DOC_REPO_ABS" ]; then
                    CANDIDATE="$DOC_REPO_ABS/docs/architecture/LIVING-ARTIFACTS.md"
                    SEARCHED_PATHS="$SEARCHED_PATHS $CANDIDATE"
                    if [ -f "$CANDIDATE" ]; then
                        LAR_PATH="$CANDIDATE"
                        # Also set ROOT2_ABS for path resolution if not already set
                        [ -z "$ROOT2_ABS" ] && ROOT2_ABS="$DOC_REPO_ABS"
                    fi
                fi
            else
                echo "WARN: doc_repo_path не распознан в CLAUDE.local.md — пропускаю level-3 поиск"
            fi
        fi
    fi

    if [ -z "$LAR_PATH" ]; then
        echo "WARN-SKIP: LIVING-ARTIFACTS.md не найден (искал:$SEARCHED_PATHS) — Gap 10 not applicable"
        exit 0
    fi
else
    # Resolve relative to cwd
    if [ ! -f "$LAR_PATH" ]; then
        echo "WARN-SKIP: LAR file not found: $LAR_PATH"
        exit 0
    fi
fi

echo "LAR: $LAR_PATH"
echo "Root: $ROOT_ABS"
[ -n "$ROOT2_ABS" ] && echo "Doc-root: $ROOT2_ABS"

# Extract artifact paths from LAR table rows
# Pattern: lines starting with "| \`path\`" — capture the backtick-quoted path
# Handles both relative paths (scripts/x.sh) and repo-relative (commands/x.md)
# Skip header rows, skip rows with {{placeholders}}, skip meta-entries

MISSING=0
CHECKED=0
SKIP_PATTERNS="LIVING-ARTIFACTS\|{{" # skip self-reference and templates

while IFS= read -r line; do
    # Only process table rows with backtick-quoted first column: | `path` |
    # Line must start with "| `" to be a data row
    case "$line" in
        "| \`"*)  ;;  # data row — continue processing
        *)         continue ;;
    esac

    # Extract content between FIRST pair of backticks (POSIX-compatible, non-greedy via [^`]*)
    # Important: sed ".*`X`.*" is greedy — it matches the LAST backtick pair.
    # To get the FIRST pair, strip from the beginning up to (not including) the first backtick,
    # then take everything up to the next backtick.
    path_raw=$(echo "$line" | sed "s/[^\`]*\`\([^\`]*\)\`.*/\1/")

    [ -z "$path_raw" ] && continue

    # If sed returned something still containing a backtick, no clean extraction
    case "$path_raw" in
        *"\`"*) continue ;;
    esac

    # Skip self-reference and template placeholders
    case "$path_raw" in
        *LIVING-ARTIFACTS*|*"{{"*) continue ;;
    esac

    # Skip glob/wildcard entries (e.g. commands/*.md)
    case "$path_raw" in
        *"*"*) continue ;;
    esac

    # Skip paths with spaces (descriptions, not paths)
    case "$path_raw" in
        *" "*) continue ;;
    esac

    CHECKED=$((CHECKED + 1))
    FULL_PATH="$ROOT_ABS/$path_raw"

    # Two-repo: if not found in primary root, retry in doc-root
    if [ ! -f "$FULL_PATH" ] && [ ! -d "$FULL_PATH" ]; then
        if [ -n "$ROOT2_ABS" ] && ([ -f "$ROOT2_ABS/$path_raw" ] || [ -d "$ROOT2_ABS/$path_raw" ]); then
            # Found in doc-root — OK
            continue
        fi
        echo "MISSING_FILE: $path_raw  (resolved: $FULL_PATH)"
        MISSING=$((MISSING + 1))
    fi

done < "$LAR_PATH"

echo ""
echo "Checked: $CHECKED paths"

if [ "$MISSING" -gt 0 ]; then
    echo "RESULT: $MISSING MISSING_FILE(s) — fix paths in LIVING-ARTIFACTS.md or create missing files"
    exit 1
else
    echo "OK: All $CHECKED paths in LIVING-ARTIFACTS.md exist on disk."
    exit 0
fi
