#!/usr/bin/env bash
# validate-lar.sh — проверить что файлы в LIVING-ARTIFACTS.md существуют на диске
# Exit 0 = OK, Exit 1 = MISSING_FILE entries found, Exit 2 = WARN-SKIP (LAR не найден — легитимно)
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

# Note: deliberately NOT using set -e — sub-validators may exit non-zero for findings;
# we capture and report those as WARNs without aborting the entire run.

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
        exit 2
    fi
else
    # Resolve relative to cwd
    if [ ! -f "$LAR_PATH" ]; then
        echo "WARN-SKIP: LAR file not found: $LAR_PATH"
        exit 2
    fi
fi

echo "LAR: $LAR_PATH"
echo "Root: $ROOT_ABS"
[ -n "$ROOT2_ABS" ] && echo "Doc-root: $ROOT2_ABS"

# ---------------------------------------------------------------------------
# V2: auto:* marker runner
# Markers parsed from the full LAR row (grep, not column-parse — robust to | in cells)
# Enum: auto:exists | auto:mermaid-links | auto:mermaid-syntax | auto:date-coupling=<glob>
#       auto:diagram-freshness | (no marker = exists-only)
# ---------------------------------------------------------------------------

MISSING=0
CHECKED=0
AUTO_CHECKED=0
EXISTS_ONLY=0

# Resolve script dir for sibling validators
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Timeout budget (seconds) for nested sub-validator delegation. Any auto:* marker
# that delegates to another validator runs under this cap so a slow/hung sub-scan
# cannot block the whole LAR run (and, via doc-audit, the whole audit).
# Configurable: override LAR_MARKER_TIMEOUT in the environment. Default 60s.
LAR_MARKER_TIMEOUT="${LAR_MARKER_TIMEOUT:-60}"

# _with_timeout <cmd...> — run a sub-validator under LAR_MARKER_TIMEOUT.
# Graceful: if `timeout` is unavailable (some minimal shells), run unguarded
# (no worse than the historical behaviour). Exit 124 = timed out.
_with_timeout() {
    if command -v timeout >/dev/null 2>&1; then
        timeout "$LAR_MARKER_TIMEOUT" "$@"
    else
        "$@"
    fi
}

_resolve_path() {
    local p="$1"
    if [ -f "$ROOT_ABS/$p" ] || [ -d "$ROOT_ABS/$p" ]; then
        echo "$ROOT_ABS/$p"
    elif [ -n "$ROOT2_ABS" ] && ([ -f "$ROOT2_ABS/$p" ] || [ -d "$ROOT2_ABS/$p" ]); then
        echo "$ROOT2_ABS/$p"
    else
        echo ""
    fi
}

_run_marker() {
    local marker="$1"
    local artifact_path="$2"
    local resolved
    resolved="$(_resolve_path "$artifact_path")"

    case "$marker" in
        auto:exists)
            # Existence already handled in outer loop — skip
            ;;
        auto:mermaid-links)
            if [ -n "$resolved" ] && [ -f "$SCRIPT_DIR/validate-mermaid-links.sh" ]; then
                out=$(_with_timeout bash "$SCRIPT_DIR/validate-mermaid-links.sh" "$resolved" 2>&1)
                if [ $? -eq 124 ]; then
                    echo "[WARN]  auto:mermaid-links: $artifact_path — sub-validator timed out (>${LAR_MARKER_TIMEOUT}s), skipped"
                elif echo "$out" | grep -qE "MISSING|STALE"; then
                    echo "[WARN]  auto:mermaid-links: $artifact_path — $(echo "$out" | grep -E "MISSING|STALE" | head -1)"
                fi
            else
                echo "[WARN]  auto:mermaid-links: validate-mermaid-links.sh not found or artifact missing: $artifact_path"
            fi
            AUTO_CHECKED=$((AUTO_CHECKED+1))
            ;;
        auto:mermaid-syntax)
            if [ -n "$resolved" ] && [ -f "$SCRIPT_DIR/validate-mermaid-syntax.sh" ]; then
                out=$(_with_timeout bash "$SCRIPT_DIR/validate-mermaid-syntax.sh" "$resolved" 2>&1)
                if [ $? -eq 124 ]; then
                    echo "[WARN]  auto:mermaid-syntax: $artifact_path — sub-validator timed out (>${LAR_MARKER_TIMEOUT}s), skipped"
                elif echo "$out" | grep -qE "\[WARN\]|\[ERROR\]"; then
                    echo "[WARN]  auto:mermaid-syntax: $artifact_path — $(echo "$out" | grep -E "\[WARN\]|\[ERROR\]" | head -1)"
                fi
            else
                echo "[WARN]  auto:mermaid-syntax: validate-mermaid-syntax.sh not found or artifact missing: $artifact_path"
            fi
            AUTO_CHECKED=$((AUTO_CHECKED+1))
            ;;
        auto:diagram-freshness)
            # DEPRECATED (v7.2.3, no-op): historically re-ran `validate-maps-coverage.sh
            # --report` here — a FULL repo scan that doc-audit already runs as its own
            # maps-coverage axis. On a Drive-backed Windows FS that cold re-scan took
            # >2min and hung the whole audit (doc-audit lar-hang). Diagram freshness is
            # already covered by the maps-coverage axis (in doc-audit) and by per-row
            # auto:mermaid-* markers. Kept as a recognised enum value (no-op) so consumer
            # LAR rows that still carry the marker don't error after sync — just remove it.
            AUTO_CHECKED=$((AUTO_CHECKED+1))
            ;;
        auto:date-coupling=*)
            local glob_pattern="${marker#auto:date-coupling=}"
            if [ -n "$resolved" ] && [ -f "$resolved" ]; then
                # The find + per-file `git log` loop walks the whole repo glob — on a
                # Drive-backed FS this can be slow (same hazard class as the diagram-freshness
                # hang). Cap the entire scan under LAR_MARKER_TIMEOUT; on timeout, warn + skip.
                dc_out=$(_with_timeout bash -c '
                    artifact_ts=$(git -C "$1" log -1 --format="%at" -- "$2" 2>/dev/null)
                    newest_ts=0
                    _tmpglob=$(mktemp)
                    find "$1" -path "$1/$3" -type f 2>/dev/null > "$_tmpglob"
                    while IFS= read -r code_file; do
                        code_ts=$(git -C "$1" log -1 --format="%at" -- "$code_file" 2>/dev/null)
                        if [ -n "$code_ts" ] && [ "$code_ts" -gt "$newest_ts" ] 2>/dev/null; then
                            newest_ts="$code_ts"
                        fi
                    done < "$_tmpglob"
                    rm -f "$_tmpglob"
                    if [ -n "$artifact_ts" ] && [ "$newest_ts" -gt 0 ] 2>/dev/null; then
                        delta=$((newest_ts - artifact_ts))
                        if [ "$delta" -gt 86400 ] 2>/dev/null; then
                            echo "STALE $((delta/86400))"
                        fi
                    fi
                ' _ "$ROOT_ABS" "$artifact_path" "$glob_pattern" 2>/dev/null)
                if [ $? -eq 124 ]; then
                    echo "[WARN]  auto:date-coupling: $artifact_path — scan timed out (>${LAR_MARKER_TIMEOUT}s), skipped"
                elif [ "${dc_out%% *}" = "STALE" ]; then
                    echo "[WARN]  auto:date-coupling: $artifact_path is older than code glob '$glob_pattern' by ${dc_out##* }d"
                fi
            fi
            AUTO_CHECKED=$((AUTO_CHECKED+1))
            ;;
        auto:*)
            echo "[WARN]  Unknown auto: marker '$marker' in LAR row: $artifact_path (enum: exists/mermaid-links/mermaid-syntax/diagram-freshness/date-coupling=<glob>)"
            ;;
    esac
}

while IFS= read -r line; do
    # Only process table rows with backtick-quoted first column: | `path` |
    case "$line" in
        "| \`"*)  ;;  # data row — continue processing
        *)         continue ;;
    esac

    # Extract content between FIRST pair of backticks
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

    # Skip glob/wildcard entries (existence-only via glob check below)
    case "$path_raw" in
        *"*"*) continue ;;
    esac

    # Skip paths with spaces (descriptions, not paths)
    case "$path_raw" in
        *" "*) continue ;;
    esac

    CHECKED=$((CHECKED + 1))

    # --- Existence check ---
    FULL_PATH="$ROOT_ABS/$path_raw"
    exists_ok=1
    if [ ! -f "$FULL_PATH" ] && [ ! -d "$FULL_PATH" ]; then
        if [ -n "$ROOT2_ABS" ] && ([ -f "$ROOT2_ABS/$path_raw" ] || [ -d "$ROOT2_ABS/$path_raw" ]); then
            : # found in doc-root
        else
            echo "MISSING_FILE: $path_raw  (resolved: $FULL_PATH)"
            MISSING=$((MISSING + 1))
            exists_ok=0
        fi
    fi

    # --- auto:* marker processing (V2) ---
    # Extract all auto:* markers from the full line (grep all occurrences)
    markers=$(echo "$line" | grep -oE 'auto:[a-z-]+(=[^`[:space:]|]+)?' | sort -u)

    if [ -z "$markers" ]; then
        EXISTS_ONLY=$((EXISTS_ONLY+1))
    else
        while IFS= read -r marker; do
            [ -z "$marker" ] && continue
            [ "$exists_ok" = "0" ] && continue  # skip auto-checks if file missing
            _run_marker "$marker" "$path_raw"
        done <<MARKEOF
$markers
MARKEOF
    fi

done < "$LAR_PATH"

echo ""
echo "Checked: $CHECKED paths (auto-checked: $AUTO_CHECKED, existence-only: $EXISTS_ONLY)"

if [ "$MISSING" -gt 0 ]; then
    echo "RESULT: $MISSING MISSING_FILE(s) — fix paths in LIVING-ARTIFACTS.md or create missing files"
    exit 1
else
    echo "OK: All $CHECKED paths in LIVING-ARTIFACTS.md exist on disk."
    exit 0
fi
