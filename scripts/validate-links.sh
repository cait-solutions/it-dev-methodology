#!/bin/bash
# validate-links.sh — Docs-as-Code internal link-check (broken markdown links)
# Walks all .md files, verifies every [text](relative/path) resolves to a real file.
# Bash 3.2+ compatible; requires Python 3.10+
#
# Usage: bash scripts/validate-links.sh [--root DIR] [--ignore-exit]
# Exit 0 = all links resolve; Exit 1 = BROKEN_LINK found; Exit 2 = no python
#
# Checks per [text](target):
#   BROKEN_LINK — target is a relative file path that does not exist on disk
#
# Skips (not broken — intentionally out of scope):
#   - external URLs (http://, https://, mailto:)
#   - pure anchors (#section)
#   - {{placeholder}} template variables
#   - cross-repo paths (../<other-repo>/...) — validated only if that repo present;
#     absent → SKIP (single-repo consumer doesn't have sibling repos) — closes G-076 spirit
#   - *.template.md files (contain placeholder links by design)
#   - .git/, consumers/

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

# Windows cp1252 stdout breaks on non-ASCII paths — force utf-8 (closes G-018 class)
try:
    sys.stdout.reconfigure(encoding='utf-8')
except (AttributeError, ValueError):
    pass

# [text](target) — capture target; ignore images ![..](..) same handling (also a link)
LINK_RE = re.compile(r'\[[^\]]*\]\(([^)]+)\)')
# .claude/ = synced banner-prefixed copies (derived, not canon); relative links there
# resolve from a different depth than canon — validate canon (commands/, commands-local/),
# not the derived copies. consumers/ = external snapshots. .git/ always.
EXCLUDE_DIRS = {'.git', 'consumers', '.claude'}


def is_skippable(target):
    t = target.strip()
    if not t:
        return True
    # external
    if t.startswith(('http://', 'https://', 'mailto:', 'tel:')):
        return True
    # pure anchor
    if t.startswith('#'):
        return True
    # template placeholder / illustrative tokens in prose ({{x}}, <x>, bare "url"/"path")
    if '{{' in t or '}}' in t or '<' in t or '>' in t:
        return True
    if ' ' in t:  # real paths don't contain spaces in this codebase; prose example
        return True
    # glob patterns / placeholder names (ADR-NNN-*.md, *.template) — illustrative, not real
    if '*' in t or 'NNN' in t:
        return True
    # Only validate things that LOOK like file paths: explicit relative prefix,
    # contains a slash, or has a known doc/code extension. Otherwise it's an
    # illustrative token inside prose (e.g. "[Открыть](url)") — not a real link.
    looks_like_path = (
        t.startswith(('./', '../', '/'))
        or '/' in t
        or re.search(r'\.(md|sh|py|json|yaml|yml|txt|template)(\#|$)', t) is not None
    )
    if not looks_like_path:
        return True
    return False


def resolve_target(md_path, target):
    # strip anchor fragment
    path_part = target.split('#', 1)[0].strip()
    if not path_part:
        return None  # was pure anchor, already skipped
    base_dir = os.path.dirname(md_path)
    return os.path.normpath(os.path.join(base_dir, path_part))


def check_file(path, root):
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.readlines()
    except OSError as e:
        print("SKIP {}: {}".format(path, e), file=sys.stderr)
        return 0

    errors = 0
    in_code_fence = False
    for lineno, line in enumerate(lines, 1):
        stripped = line.strip()
        # skip fenced code blocks (links inside code are examples, not real)
        if stripped.startswith('```'):
            in_code_fence = not in_code_fence
            continue
        if in_code_fence:
            continue
        for m in LINK_RE.finditer(line):
            target = m.group(1)
            if is_skippable(target):
                continue
            resolved = resolve_target(path, target)
            if resolved is None:
                continue
            # cross-repo sibling path (../<other>/) that doesn't exist → SKIP, not broken
            # (single-repo consumer legitimately lacks sibling repos)
            if target.strip().startswith('..') and not os.path.exists(resolved):
                # only flag if the FIRST path segment (sibling repo root) exists but
                # the file within is missing; if whole sibling absent → skip
                sibling_root = os.path.normpath(os.path.join(os.path.dirname(path), target.split('/', 1)[0] if '/' in target else target))
                # climb to the repo-level dir (..)
                top = os.path.normpath(os.path.join(os.path.dirname(path), target.split('/')[0]))
                # find first existing ancestor under root
                if not os.path.exists(top):
                    continue  # entire sibling tree absent → not our concern
            if not os.path.exists(resolved):
                print("ERROR    BROKEN_LINK   {}:{}".format(path, lineno))
                print("         [...]({}) -> {} does not exist".format(target, resolved))
                print()
                errors += 1
    return errors


def find_md_files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in sorted(dirnames) if d not in EXCLUDE_DIRS]
        for fn in sorted(filenames):
            if not fn.endswith('.md'):
                continue
            # template files contain placeholder/illustrative links by design
            if fn.endswith('.template.md') or fn == '_TEMPLATE.md':
                continue
            yield os.path.join(dirpath, fn)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else '.'
    total_errors = 0
    file_count = 0
    for path in find_md_files(root):
        file_count += 1
        total_errors += check_file(path, root)

    print("Checked: {} .md files".format(file_count))
    print()
    if total_errors > 0:
        print("FAIL: {} broken internal link(s)".format(total_errors))
        sys.exit(1)
    else:
        print("OK: All internal markdown links resolve.")
        sys.exit(0)


main()
PYEOF

echo "=== validate-links.sh ==="
echo "Root: $ROOT"
echo ""

exit_code=0
"$PYTHON" "$TMPPY" "$ROOT" || exit_code=$?

if [ "$exit_code" -ne 0 ] && [ "$IGNORE_EXIT" -eq 0 ]; then
    echo ""
    echo "Fix broken links above (typo in path, moved file, or remove the link)."
    exit 1
fi

exit 0
