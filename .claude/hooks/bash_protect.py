# AUTO-GENERATED from methodology-platform v2.4.0
# Synced: 2026-05-16
# DO NOT EDIT — changes will be overwritten on next sync
# Modify via PR to https://github.com/cait-solutions/it-dev-methodology
# Emergency override: edit locally + open PR within 48h

"""
PreToolUse hook for Bash — blocks destructive commands.

Wired in .claude/settings.json under "hooks.PreToolUse" with matcher "Bash".
Exit code 2 blocks the tool call; stderr is shown to the user.

Extend the regex list below for project-specific dangerous patterns.
"""
import sys
import json
import re

DANGEROUS_PATTERNS = [
    r'rm\s+-rf',
    r'DROP\s+TABLE',
    r'DROP\s+DATABASE',
    r'TRUNCATE\s+',
    r'docker\s+system\s+prune',
    r'docker\s+volume\s+prune',
    r'git\s+push\s+(-f|--force)',
    r'git\s+reset\s+--hard',
    r'git\s+clean\s+-f',
    r':>\s*[^\s]+\.env',
    r'mkfs\.',
]

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command", "")

for pattern in DANGEROUS_PATTERNS:
    if re.search(pattern, cmd, re.IGNORECASE):
        sys.stderr.write(f"BLOCKED: dangerous command matches /{pattern}/: {cmd[:120]}\n")
        sys.exit(2)
