#!/usr/bin/env python3
"""
mermaid-link.py — generate mermaid.live shareable URLs from Mermaid diagram code.

Usage:
    # Extract first ```mermaid block from a markdown file:
    python scripts/mermaid-link.py docs/architecture/SYSTEM-MAP.md

    # Extract ALL ```mermaid blocks (one URL per block):
    python scripts/mermaid-link.py --all docs/product/USER-MAP.md

    # Pass code directly:
    python scripts/mermaid-link.py --code "graph TD\n  A-->B"

    # Read from stdin:
    echo "graph TD\n  A-->B" | python scripts/mermaid-link.py -

Output:
    mermaid.live edit URL(s) printed to stdout, one per line.
    Paste above the ```mermaid block as:
        > 🔗 [Открыть в Mermaid Live](<url>)

Self-hosted:
    Change BASE_URL below to your own mermaid-live-editor instance.
"""

import sys
import json
import zlib
import base64
import re

BASE_URL = "https://mermaid.live"


def encode_mermaid(code: str) -> str:
    """Encode Mermaid diagram code into a mermaid.live edit URL (pako format)."""
    state = json.dumps(
        {"code": code, "mermaid": {"theme": "default"}},
        separators=(',', ':'),
        ensure_ascii=False,
    )
    # pako.deflate uses raw deflate (RFC 1951), equivalent to zlib wbits=-15
    compressor = zlib.compressobj(level=6, wbits=-15)
    deflated = compressor.compress(state.encode('utf-8')) + compressor.flush()
    encoded = base64.urlsafe_b64encode(deflated).decode('ascii').rstrip('=')
    return f"{BASE_URL}/edit#pako:{encoded}"


def extract_mermaid_blocks(text: str) -> list[str]:
    """Return list of all ```mermaid ... ``` code blocks (content only)."""
    return [
        m.group(1).strip()
        for m in re.finditer(r'```mermaid\n(.*?)```', text, re.DOTALL)
    ]


def main() -> None:
    args = sys.argv[1:]

    if not args:
        print(__doc__, file=sys.stderr)
        sys.exit(1)

    all_blocks = '--all' in args
    args = [a for a in args if a != '--all']

    if args[0] == '--code':
        if len(args) < 2:
            print("Error: --code requires a diagram string argument.", file=sys.stderr)
            sys.exit(1)
        codes = [args[1].replace('\\n', '\n')]

    elif args[0] == '-':
        raw = sys.stdin.read()
        blocks = extract_mermaid_blocks(raw)
        codes = blocks if blocks else [raw.strip()]

    else:
        path = args[0]
        try:
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
        except FileNotFoundError:
            print(f"Error: file not found: {path}", file=sys.stderr)
            sys.exit(1)

        blocks = extract_mermaid_blocks(content)
        if not blocks:
            print(f"No ```mermaid block found in {path}", file=sys.stderr)
            sys.exit(1)

        codes = blocks if all_blocks else [blocks[0]]

    for code in codes:
        print(encode_mermaid(code))


if __name__ == '__main__':
    main()
