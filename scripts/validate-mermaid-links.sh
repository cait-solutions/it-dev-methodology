#!/bin/bash
# validate-mermaid-links.sh — Level 4 validation of mermaid.live link freshness
# Covers ALL .md files including gitignored (walk-based, not git-based)
# Bash 3.2+ compatible; requires Python 3.10+ for URL regeneration
#
# Usage: bash scripts/validate-mermaid-links.sh [--root DIR] [--ignore-exit]
# Exit 0 = clean; Exit 1 = MISSING_LINK or STALE_LINK found
#
# Checks per ```mermaid block:
#   MISSING_LINK — no mermaid.live link within 5 lines above the block (only if URL ≤ 2000 chars)
#   STALE_LINK   — existing link URL does not match regenerated URL for current code
#   URL_TOO_LONG — regenerated URL > 2000 chars (warning only — no exit 1)
#
# Skips:
#   *.template.md files (placeholder URLs, not deployed content)
#   consumers/       (external project reference snapshots)
#   .git/            (always)
#   blocks with TODO: in code (unfilled placeholders)
#   blocks where expected URL > 2000 for MISSING_LINK (copy-paste workflow is correct)

set -e

ROOT="."
IGNORE_EXIT=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)        ROOT="$2"; shift 2 ;;
        --ignore-exit) IGNORE_EXIT=1; shift ;;
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
import json
import zlib
import base64

BASE_URL = "https://mermaid.live"
LINK_RE = re.compile(r'(https://mermaid\.live[^\)\s]+)')
WINDOW = 5
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


def check_file(path):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
    except OSError as e:
        print("SKIP {}: {}".format(path, e), file=sys.stderr)
        return 0, 0

    errors = 0
    warnings = 0
    i = 0
    in_code_fence = False
    while i < len(lines):
        stripped = lines[i].rstrip('\n').strip()
        if not in_code_fence and stripped.startswith('```') and stripped != '```mermaid':
            in_code_fence = True
            i += 1
            while i < len(lines) and lines[i].rstrip('\n').strip() != '```':
                i += 1
            in_code_fence = False
            i += 1
            continue
        if stripped == '```mermaid':
            block_start = i
            i += 1
            block_lines = []
            while i < len(lines) and lines[i].rstrip('\n').strip() != '```':
                block_lines.append(lines[i])
                i += 1
            code = ''.join(block_lines).strip()

            if 'TODO:' not in code and code:
                window_start = max(0, block_start - WINDOW)
                window_text = ''.join(lines[window_start:block_start])
                m = LINK_RE.search(window_text)
                found_url = m.group(1) if m else None

                expected_url = encode_mermaid(code)
                url_len = len(expected_url)

                if url_len > 2000:
                    print("WARNING  URL_TOO_LONG  {}:{} (len={})".format(path, block_start + 1, url_len))
                    print("         Simplify diagram (remove style lines) to fit under 2000 chars.")
                    print("         See CLAUDE.md Mermaid link rule for guidance.")
                    print()
                    warnings += 1
                elif found_url is None:
                    print("ERROR    MISSING_LINK  {}:{}".format(path, block_start + 1))
                    print("         No mermaid.live link found within {} lines above block.".format(WINDOW))
                    print("         Fix: py scripts/mermaid-link.py \"{}\"".format(path))
                    print()
                    errors += 1
                elif found_url != expected_url:
                    print("ERROR    STALE_LINK    {}:{}".format(path, block_start + 1))
                    print("         URL does not match current diagram code.")
                    print("         Fix: py scripts/mermaid-link.py \"{}\"".format(path))
                    print()
                    errors += 1

        i += 1

    return errors, warnings


def find_md_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in sorted(dirnames) if d not in EXCLUDE_DIRS]
        for fn in sorted(filenames):
            if fn.endswith('.md') and not fn.endswith('.template.md'):
                yield os.path.join(dirpath, fn)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    total_errors = 0
    total_warnings = 0
    file_count = 0
    for path in find_md_files(root):
        file_count += 1
        e, w = check_file(path)
        total_errors += e
        total_warnings += w

    print("Checked: {} .md files".format(file_count))
    print()
    if total_errors > 0:
        print("FAIL: {} error(s) found (MISSING_LINK or STALE_LINK)".format(total_errors))
        if total_warnings > 0:
            print("WARN: {} warning(s) (URL_TOO_LONG)".format(total_warnings))
        sys.exit(1)
    elif total_warnings > 0:
        print("WARN: {} warning(s) (URL_TOO_LONG) — not blocking".format(total_warnings))
        sys.exit(0)
    else:
        print("OK: All Mermaid blocks have valid mermaid.live links.")
        sys.exit(0)


main()
PYEOF

echo "=== validate-mermaid-links.sh ==="
echo "Root: $ROOT"
echo ""

exit_code=0
"$PYTHON" "$TMPPY" "$ROOT" || exit_code=$?

if [ "$exit_code" -ne 0 ] && [ "$IGNORE_EXIT" -eq 0 ]; then
    echo ""
    echo "Run 'py scripts/mermaid-link.py <file>' to regenerate links."
    exit 1
fi

exit 0
