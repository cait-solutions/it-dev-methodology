#!/bin/bash
# update-mermaid-links.sh — auto-update mermaid.live URLs in .md files
#
# For each ```mermaid block in .md files:
#   - If link is missing → inserts link + code block with URL above the block
#   - If link is stale   → replaces URL in link line and code block
#
# Usage:
#   bash scripts/update-mermaid-links.sh [--root DIR] [--dry-run] [FILE...]
#
#   --root DIR   Walk all .md files under DIR (default: current dir)
#   --dry-run    Print changes without writing
#   FILE...      Update specific files only (ignores --root)
#
# Examples:
#   # Update all maps in documentation repo:
#   bash scripts/update-mermaid-links.sh --root ../it-dev-methodology-documentation
#
#   # Update single file:
#   bash scripts/update-mermaid-links.sh ../it-dev-methodology-documentation/docs/product/USER-MAP.md
#
#   # Two-repo update (methodology-platform standard):
#   bash scripts/update-mermaid-links.sh --root .
#   bash scripts/update-mermaid-links.sh --root ../it-dev-methodology-documentation
#
# Exit 0 always. Returns count of updated links on stdout summary line.
#
# Bash 3.2+ compatible; requires Python 3.10+

set -e

ROOT="."
DRY_RUN=0
SPECIFIC_FILES=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)    ROOT="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --*)       echo "Unknown flag: $1" >&2; exit 2 ;;
        *)         SPECIFIC_FILES+=("$1"); shift ;;
    esac
done

PYTHON=""
for _cmd in py python3 python; do
    command -v "$_cmd" >/dev/null 2>&1 && PYTHON="$_cmd" && break
done

if [ -z "$PYTHON" ]; then
    echo "ERROR: Python not found (tried: py, python3, python)" >&2
    exit 2
fi

# Locate mermaid-link.py relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MERMAID_LINK_PY="$SCRIPT_DIR/mermaid-link.py"
if [ ! -f "$MERMAID_LINK_PY" ]; then
    echo "ERROR: mermaid-link.py not found at $MERMAID_LINK_PY" >&2
    exit 2
fi

TMPPY=$(mktemp)
trap 'rm -f "$TMPPY"' EXIT

cat > "$TMPPY" << 'PYEOF'
#!/usr/bin/env python3
"""
update-mermaid-links worker — reads file list from argv, updates links in-place.
Called by update-mermaid-links.sh with:
  python worker.py <dry_run:0|1> <mermaid_link_py> <file1> [file2 ...]
"""
import sys
import os
import re
import json
import zlib
# Force UTF-8 stdout on Windows (cp1252 can't encode emoji in print)
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
import base64

DRY_RUN     = sys.argv[1] == "1"
MERMAID_PY  = sys.argv[2]   # unused directly — we inline encode_mermaid
FILES       = sys.argv[3:]

BASE_URL    = "https://mermaid.live"
LINK_RE     = re.compile(r'(https://mermaid\.live[^\)\s]+)')
LINK_LINE_RE = re.compile(r'^(>\s*🔗\s*\[.*?\]\()https://mermaid\.live[^\)]+(\).*)')
LEGACY_HINT_RE = re.compile(r'^>\s*_\(обновить ссылку')
WINDOW      = 5
EXCLUDE_DIRS = {'.git', 'consumers'}


def encode_mermaid(code):
    state = json.dumps(
        {
            "code": code,
            "mermaid": json.dumps({"theme": "default"}, separators=(',', ':')),
            "autoSync": True,
            "updateDiagram": True,
        },
        separators=(',', ':'),
        ensure_ascii=False,
    )
    compressed = zlib.compress(state.encode('utf-8'), 9)
    encoded = base64.urlsafe_b64encode(compressed).decode('ascii').rstrip('=')
    return BASE_URL + "/edit#pako:" + encoded


def find_md_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in sorted(dirnames) if d not in EXCLUDE_DIRS]
        for fn in sorted(filenames):
            if fn.endswith('.md') and not fn.endswith('.template.md'):
                yield os.path.join(dirpath, fn)


def update_file(path):
    try:
        with open(path, encoding='utf-8') as f:
            original = f.read()
            lines = original.splitlines(keepends=True)
    except OSError as e:
        print(f"SKIP {path}: {e}", file=sys.stderr)
        return 0

    updated = list(lines)
    changes = 0
    i = 0

    while i < len(updated):
        stripped = updated[i].rstrip('\n').strip()

        # Skip non-mermaid fenced blocks
        if not stripped.startswith('```') or stripped == '```mermaid':
            if stripped != '```mermaid':
                i += 1
                continue

        if stripped == '```mermaid':
            block_start = i
            i += 1
            block_lines = []
            while i < len(updated) and updated[i].rstrip('\n').strip() != '```':
                block_lines.append(updated[i])
                i += 1
            code = ''.join(block_lines).strip()

            if not code or 'TODO:' in code:
                i += 1
                continue

            expected_url = encode_mermaid(code)

            # Search for existing mermaid.live link within WINDOW lines above
            window_start = max(0, block_start - WINDOW)
            existing_link_idx = None
            for j in range(window_start, block_start):
                if LINK_RE.search(updated[j]):
                    existing_link_idx = j
                    break

            rel = os.path.relpath(path)

            if existing_link_idx is not None:
                existing_url_m = LINK_RE.search(updated[existing_link_idx])
                url_is_stale = not (existing_url_m and existing_url_m.group(1) == expected_url)

                # Check post-link structure
                cb_idx = existing_link_idx + 1
                has_legacy_hint = (cb_idx < len(updated) and LEGACY_HINT_RE.match(updated[cb_idx]))
                # has_cb examined after potential legacy removal
                next_after_link = cb_idx + (1 if has_legacy_hint else 0)
                has_cb = (next_after_link < len(updated) and updated[next_after_link].rstrip() == '> ```')

                # Nothing to do?
                if not url_is_stale and has_cb and not has_legacy_hint:
                    i += 1
                    continue

                actions = []

                if DRY_RUN:
                    if url_is_stale:
                        actions.append("STALE URL")
                    if has_legacy_hint:
                        actions.append("REMOVE legacy hint")
                    if not has_cb:
                        actions.append("INSERT code block")
                    print(f"FIX      {rel}:{block_start+1}  ({', '.join(actions)})")
                else:
                    # 1. Update URL in link line if stale
                    if url_is_stale:
                        old_line = updated[existing_link_idx]
                        m = LINK_LINE_RE.match(old_line)
                        if m:
                            new_line = m.group(1) + expected_url + m.group(2) + '\n'
                        else:
                            new_line = LINK_RE.sub(expected_url, old_line)
                        updated[existing_link_idx] = new_line
                        actions.append("URL updated")

                    # 2. Remove legacy hint line if present
                    if has_legacy_hint:
                        del updated[cb_idx]
                        actions.append("legacy hint removed")

                    # 3. Ensure code block exists (recompute index after legacy removal)
                    cb_idx = existing_link_idx + 1
                    cb_exists = (cb_idx < len(updated) and updated[cb_idx].rstrip() == '> ```')
                    if not cb_exists:
                        updated.insert(cb_idx, '> ```\n')
                        updated.insert(cb_idx + 1, f'> {expected_url}\n')
                        updated.insert(cb_idx + 2, '> ```\n')
                        actions.append("code block inserted")
                    else:
                        # cb exists — refresh URL inside if stale
                        url_line_idx = cb_idx + 1
                        if url_line_idx < len(updated) and updated[url_line_idx].startswith('> https://mermaid.live'):
                            if updated[url_line_idx].rstrip() != f'> {expected_url}':
                                updated[url_line_idx] = f'> {expected_url}\n'
                                actions.append("code block URL refreshed")

                    print(f"UPDATED  {rel}:{block_start+1}  ({', '.join(actions)})")
                changes += 1
            else:
                # Missing — insert link + code block with URL above the ```mermaid line
                new_link_line = f'> 🔗 [Открыть в Mermaid Live]({expected_url})\n'
                cb_open  = '> ```\n'
                url_line = f'> {expected_url}\n'
                cb_close = '> ```\n'
                if DRY_RUN:
                    print(f"MISSING  {rel}:{block_start+1}")
                    print(f"  insert: {new_link_line.rstrip()}")
                else:
                    updated.insert(block_start, '\n')
                    updated.insert(block_start, cb_close)
                    updated.insert(block_start, url_line)
                    updated.insert(block_start, cb_open)
                    updated.insert(block_start, new_link_line)
                    # Adjust i for the 5 inserted lines
                    i += 5
                    print(f"UPDATED  MISSING -> inserted  {rel}:{block_start+1}")
                changes += 1

        i += 1

    if changes > 0 and not DRY_RUN:
        new_content = ''.join(updated)
        if new_content != original:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(new_content)

    return changes


def main():
    total = 0
    for path in FILES:
        total += update_file(path)
    print(f"Done: {total} link(s) updated.")
    if DRY_RUN and total > 0:
        print("(dry-run — no files written)")


main()
PYEOF

echo "=== update-mermaid-links.sh ==="
if [ "$DRY_RUN" -eq 1 ]; then
    echo "(dry-run mode — no files written)"
fi
echo ""

# Build file list
if [ "${#SPECIFIC_FILES[@]}" -gt 0 ]; then
    # Specific files passed directly
    "$PYTHON" "$TMPPY" "$DRY_RUN" "$MERMAID_LINK_PY" "${SPECIFIC_FILES[@]}"
else
    # Walk root for all .md files (excluding *.template.md and consumers/)
    TMPLIST=$(mktemp)
    trap 'rm -f "$TMPPY" "$TMPLIST"' EXIT

    find "$ROOT" -name "*.md" \
        ! -name "*.template.md" \
        ! -path "*/.git/*" \
        ! -path "*/consumers/*" \
        | sort > "$TMPLIST"

    FILE_COUNT=$(wc -l < "$TMPLIST" | tr -d ' ')
    echo "Scanning $FILE_COUNT .md files under: $ROOT"
    echo ""

    # Pass files to python worker
    xargs -a "$TMPLIST" "$PYTHON" "$TMPPY" "$DRY_RUN" "$MERMAID_LINK_PY"
fi
